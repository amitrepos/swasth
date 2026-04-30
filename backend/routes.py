from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
from slowapi import Limiter
from slowapi.util import get_remote_address
import logging
import os
import models
import schemas
import auth
from email_service import email_service
from sms_service import sms_service
from database import get_db
from encryption_service import encrypt_float
from utils.phone import normalize_phone
from config import settings
from dependencies import get_current_user
from encryption_service import hash_email, hash_phone, hash_otp

logger = logging.getLogger(__name__)
router = APIRouter()
_enabled = os.environ.get("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)


@router.post("/register", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
def register(request: Request, user: schemas.UserRegister, db: Session = Depends(get_db)):
    """Register a new user and create their initial 'My Health' profile."""
    user.email = user.email.strip().lower()
    db_user = db.query(models.User).filter(models.User.email_hash == hash_email(user.email)).first()
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
        
    if user.phone_number:
        normalized_phone = normalize_phone(user.phone_number)
        if normalized_phone:
            phone_user = db.query(models.User).filter(models.User.phone_hash == hash_phone(normalized_phone)).first()
            if phone_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Phone number already registered. Please use a different phone number or login."
                )

    # 1. Create User (auth only)
    # Store UTC time directly — convert to local time at read/display time
    now_utc = datetime.now(timezone.utc)
    
    db_user = models.User(
        email=user.email,
        password_hash=auth.get_password_hash(user.password),
        full_name=user.full_name,
        phone_number=normalize_phone(user.phone_number) or None,
        timezone=user.timezone,
        consent_timestamp=now_utc if user.consent_app_version else None,
        consent_app_version=user.consent_app_version,
        consent_language=user.consent_language,
        ai_consent=bool(user.ai_consent) if user.ai_consent else bool(user.consent_app_version),
        ai_consent_timestamp=now_utc if (user.ai_consent or user.consent_app_version) else None,
    )
    db.add(db_user)
    db.flush()  # Get db_user.id

    # 2. Create Profile
    db_profile = models.Profile(
        name=user.profile_name or "My Health",
        age=user.age,
        gender=user.gender,
        height=user.height,
        weight=user.weight,
        blood_group=user.blood_group,
        medical_conditions=user.medical_conditions,
        other_medical_condition=user.other_medical_condition,
        current_medications=user.current_medications,
        phone_number=normalize_phone(user.phone_number) or None,
    )
    db.add(db_profile)
    db.flush()  # Get db_profile.id

    # 3. Create ProfileAccess (owner)
    db_access = models.ProfileAccess(
        user_id=db_user.id,
        profile_id=db_profile.id,
        access_level="owner",
    )
    db.add(db_access)

    # Auto-log first weight reading if provided at registration
    if user.weight is not None:
        try:
            enc = encrypt_float(user.weight)
        except Exception:
            logger.warning("Weight reading encryption failed during registration")
            enc = None
        db.add(models.HealthReading(
            profile_id=db_profile.id,
            logged_by=db_user.id,
            reading_type="weight",
            weight_value=user.weight,
            weight_unit="kg",
            value_numeric=user.weight,
            unit_display="kg",
            reading_timestamp=now_utc,
            weight_value_enc=enc,
        ))

    db.commit()
    db.refresh(db_user)

    # 4. Send welcome email (best-effort)
    try:
        email_service.send_welcome_email(db_user.email, db_user.full_name)
    except Exception:
        pass  # best-effort

    return db_user


@router.post("/check-account")
@limiter.limit("10/minute")
def check_account_exists(
    request: Request,
    body: schemas.CheckAccountExistsRequest,
    db: Session = Depends(get_db),
):
    """Check if an account exists by email or phone number.
    
    Returns:
    - {"exists": true, "login_method": "email_password"} for email accounts
    - {"exists": true, "login_method": "phone_otp"} for phone-only accounts
    - {"exists": false} if no account found
    """
    if body.email:
        body.email = body.email.strip().lower()
        user = db.query(models.User).filter(models.User.email_hash == hash_email(body.email)).first()
        if user:
            return {"exists": True, "login_method": "email_password"}
        return {"exists": False}

    if body.phone_number:
        normalized = normalize_phone(body.phone_number)
        user = db.query(models.User).filter(models.User.phone_hash == hash_phone(normalized)).first()
        if user:
            return {"exists": True, "login_method": "phone_otp"}
        return {"exists": False}
    
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Either email or phone_number must be provided"
    )


@router.post("/login", response_model=schemas.Token)
@limiter.limit("10/minute")
def login(request: Request, user: schemas.UserLogin, db: Session = Depends(get_db)):
    """Login user and return JWT token."""
    db_user = db.query(models.User).filter(models.User.email_hash == hash_email(user.email.strip().lower())).first()
    if not db_user or not auth.verify_password(user.password, db_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    # Update last_login with UTC timestamp (convert to local time at display)
    now_utc = datetime.now(timezone.utc)
    db_user.last_login_at = now_utc
    db.commit()
    access_token = auth.create_access_token(data={"sub": db_user.email})
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me", response_model=schemas.UserResponse)
def get_current_user_info(user: models.User = Depends(get_current_user)):
    """Get current user information."""
    return user


def _send_password_reset_email(email: str, otp: str) -> None:
    """Background worker — dispatches the OTP email after the HTTP handler
    has already returned its generic response. Pulled out of the request
    path so that a registered account doesn't spend a 100–500ms SMTP
    round-trip the enumeration attacker can time. Failures log-only."""
    try:
        if not email_service.send_otp_email(email, otp):
            # Don't leak email-send failures to the client (would confirm
            # the account exists). Log for ops; the user can retry.
            logger.error("forgot_password: send_otp_email failed for registered user")
    except Exception:
        logger.exception("forgot_password: unexpected exception in background email send")


@router.post("/forgot-password")
@limiter.limit("3/minute")
def request_password_reset(
    request: Request,
    body: schemas.ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """Request a password reset OTP.

    Always returns the same response whether the email is registered or not.
    Returning a different response for unknown emails (a 404 "User does not
    exist") lets an attacker enumerate accounts — a DPDPA-relevant leak of
    personal data and an OWASP-recommended fix.

    The actual OTP email send is scheduled as a FastAPI BackgroundTask so
    the endpoint returns in the same ~5ms (DB query only) regardless of
    whether the email is registered. Without this, an attacker could time
    requests to distinguish "account exists" (path includes SMTP round-trip)
    from "account doesn't exist" (path is instant) — the timing side-channel
    Security flagged in PR #139's CONDITIONAL PASS.
    """
    body.email = body.email.strip().lower()
    generic_response = {
        "message": "If an account with that email exists, an OTP has been sent.",
        "expires_in_minutes": settings.OTP_EXPIRE_MINUTES,
    }

    user = db.query(models.User).filter(models.User.email_hash == hash_email(body.email)).first()
    if not user:
        logger.info("forgot_password: unknown email attempt")
        return generic_response

    otp = email_service.generate_otp()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
    db.add(models.PasswordResetOTP(email=body.email, otp=otp, expires_at=expires_at))
    db.commit()

    # Schedule the SMTP send to run AFTER we respond. Both the known-email
    # and unknown-email paths now take the same wall-clock time.
    background_tasks.add_task(_send_password_reset_email, body.email, otp)

    return generic_response


@router.post("/verify-otp")
@limiter.limit("5/minute")
def verify_reset_otp(request: Request, body: schemas.VerifyOTPRequest, db: Session = Depends(get_db)):
    """Verify OTP for password reset."""
    body.email = body.email.strip().lower()
    otp_record = _get_valid_otp(db, body.email, body.otp)
    if not otp_record:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP")
    return {"message": "OTP verified successfully"}


@router.post("/reset-password")
@limiter.limit("5/minute")
def reset_password(request: Request, body: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    """Reset password using OTP."""
    body.email = body.email.strip().lower()
    otp_record = _get_valid_otp(db, body.email, body.otp)
    if not otp_record:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP")

    user = db.query(models.User).filter(models.User.email_hash == hash_email(body.email)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    user.password_hash = auth.get_password_hash(body.new_password)
    # Update timestamp with UTC (convert to local time at display)
    now_utc = datetime.now(timezone.utc)
    user.updated_at = now_utc
    otp_record.is_used = True
    db.commit()
    return {"message": "Password reset successfully"}


@router.put("/me", response_model=schemas.UserResponse)
@router.put("/profile", response_model=schemas.UserResponse, deprecated=True)
def update_profile(
    user_update: schemas.UpdateUserRequest,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Update auth-level user information (name, phone, password)."""
    if user_update.new_password:
        if not user_update.current_password:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Current password is required to change password")
        
        if not auth.verify_password(user_update.current_password, user.password_hash):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Current password is incorrect")
        
        user.password_hash = auth.get_password_hash(user_update.new_password)

    if user_update.full_name:
        user.full_name = user_update.full_name
    
    if user_update.phone_number:
        normalized_phone = normalize_phone(user_update.phone_number)
        if normalized_phone:
            phone_user = db.query(models.User).filter(
                models.User.phone_hash == hash_phone(normalized_phone),
                models.User.id != user.id
            ).first()
            if phone_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Phone number already registered to another account. Please use a different phone number."
                )
        user.phone_number = normalized_phone or None

    # Update timestamp with UTC (convert to local time at display)
    now_utc = datetime.now(timezone.utc)
    user.updated_at = now_utc
    db.commit()
    db.refresh(user)
    return user


# ---------------------------------------------------------------------------
# AI consent — for existing users who registered before AI disclosure was added
# ---------------------------------------------------------------------------

@router.post("/ai-consent")
def grant_ai_consent(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Grant consent for AI-powered health insights (third-party processing)."""
    user.ai_consent = True
    # Record consent timestamp with UTC (convert to local time at display)
    now_utc = datetime.now(timezone.utc)
    user.ai_consent_timestamp = now_utc
    db.commit()
    return {"message": "AI consent granted"}


# ---------------------------------------------------------------------------
# Email verification
# ---------------------------------------------------------------------------

@router.post("/send-email-verification")
@limiter.limit("3/minute")
def send_email_verification(
    request: Request,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Generate and send a new email verification OTP."""
    # Invalidate any previous unused OTPs for this user
    db.query(models.EmailVerificationOTP).filter(
        models.EmailVerificationOTP.user_id == user.id,
        models.EmailVerificationOTP.is_used == False,
    ).update({"is_used": True})

    otp = email_service.generate_otp()
    otp_expires = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

    db.add(models.EmailVerificationOTP(
        user_id=user.id,
        email=user.email,
        otp=otp,  # __init__ hashes via HMAC(PII_KEY)
        expires_at=otp_expires,
    ))
    db.commit()

    email_service.send_email_verification_otp(user.email, otp, user.full_name)

    return {"message": "Verification OTP sent", "expires_in_minutes": settings.OTP_EXPIRE_MINUTES}


@router.post("/verify-email")
@limiter.limit("5/minute")
def verify_email(
    request: Request,
    body: schemas.VerifyEmailOTPRequest,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Verify the user's email address using an OTP."""
    # Idempotent — already verified
    if user.email_verified:
        return {"message": "Email verified successfully"}

    otp_record = db.query(models.EmailVerificationOTP).filter(
        models.EmailVerificationOTP.user_id == user.id,
        models.EmailVerificationOTP.otp_hash == hash_otp(body.otp),
        models.EmailVerificationOTP.is_used == False,
        models.EmailVerificationOTP.expires_at > datetime.now(timezone.utc),
    ).first()

    if not otp_record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP",
        )

    # Mark OTP as used and verify user
    otp_record.is_used = True
    user.email_verified = True
    user.email_verified_at = datetime.now(timezone.utc)
    db.commit()

    return {"message": "Email verified successfully"}


@router.get("/email-verification-status")
def email_verification_status(
    user: models.User = Depends(get_current_user),
):
    """Check whether the current user's email is verified."""
    return {"email_verified": bool(user.email_verified)}


# ---------------------------------------------------------------------------
# Phone OTP authentication (login/registration via SMS)
# ---------------------------------------------------------------------------

@router.post("/phone-otp/send")
@limiter.limit("3/minute")
def send_phone_otp(
    request: Request,
    body: schemas.PhoneOTPRequest,
    db: Session = Depends(get_db),
):
    """Send OTP to phone number for login or registration.
    
    This endpoint is idempotent — if the phone number exists, it's a login flow;
    if not, it's a registration flow. The client will know based on the
    /check-account response.
    """
    normalized = normalize_phone(body.phone_number)
    
    if settings.TWILIO_SERVICE_SID:
        sms_sent = sms_service.send_verify_otp(to_number=normalized)
        if not sms_sent:
            logger.warning(f"Failed to send Verify OTP to {body.phone_number}")
    else:
        # Invalidate any previous unused OTPs for this phone number
        db.query(models.PhoneOTP).filter(
            models.PhoneOTP.phone_hash == hash_phone(normalized),
            models.PhoneOTP.is_used == False,
        ).update({"is_used": True})
    
        # Generate new OTP
        otp = email_service.generate_otp()
        otp_expires = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
    
        db.add(models.PhoneOTP(
            phone_number=normalized,
            otp=otp,  # __init__ hashes via HMAC(PII_KEY)
            expires_at=otp_expires,
        ))
        db.commit()
    
        # Send SMS via Twilio
        sms_sent = sms_service.send_sms(
            to_number=normalized,
            body=f"Your Swasth app verification code is: {otp}. Valid for {settings.OTP_EXPIRE_MINUTES} minutes.",
        )
    
        if not sms_sent:
            logger.warning(f"Failed to send SMS OTP to {body.phone_number}")
            # In development/testing, we still return success so the flow can continue
            # In production, you might want to raise an error
    
    return {
        "message": "OTP sent successfully",
        "expires_in_minutes": settings.OTP_EXPIRE_MINUTES,
    }


@router.post("/phone-otp/verify", response_model=schemas.Token)
@limiter.limit("5/minute")
def verify_phone_otp_and_login(
    request: Request,
    body: schemas.PhoneOTPVerifyRequest,
    db: Session = Depends(get_db),
):
    """Verify phone OTP and login or create account.
    
    If the phone number exists:
    - Verify OTP and login the user
    
    If the phone number doesn't exist:
    - Verify OTP
    - Create a new user account (returns flag for client to complete registration)
    """
    normalized = normalize_phone(body.phone_number)
    
    if settings.TWILIO_SERVICE_SID:
        is_valid = sms_service.check_verify_otp(to_number=normalized, code=body.otp)
        if not is_valid:
            # Twilio specifically handles codes like '123456', if it's not approved, reject
            # But let's allow "123456" in testing/development environments if TWILIO_SMS_NUMBER is not used actually? 
            # Or assume Verify will handle true sending.
            # In dev, maybe "123456" should pass? 
            # Let's strictly rely on verify.
            
            # fallback for default stub test OTPs if really needed, but the user expects twilio integration
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired OTP"
            )
    else:
        # Find valid OTP
        otp_record = db.query(models.PhoneOTP).filter(
            models.PhoneOTP.phone_hash == hash_phone(normalized),
            models.PhoneOTP.otp_hash == hash_otp(body.otp),
            models.PhoneOTP.is_used == False,
            models.PhoneOTP.expires_at > datetime.now(timezone.utc),
        ).first()
    
        if not otp_record:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired OTP"
            )
    
        # Mark OTP as used
        otp_record.is_used = True
        db.commit()

    # Check if user exists
    user = db.query(models.User).filter(
        models.User.phone_hash == hash_phone(normalized)
    ).first()

    if user:
        # LOGIN FLOW: User exists, log them in
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is deactivated"
            )

        # Update last_login
        now_utc = datetime.now(timezone.utc)
        user.last_login_at = now_utc
        db.commit()

        # Generate JWT token
        access_token = auth.create_access_token(data={"sub": user.email})
        return {"access_token": access_token, "token_type": "bearer", "is_new_user": False}
    else:
        # REGISTRATION FLOW: Create minimal account, client will complete profile
        now_utc = datetime.now(timezone.utc)
        
        # Generate a unique email for phone-only users
        import uuid
        temp_email = f"phone_{normalized}@swasth.local"
        
        # Create user with minimal info
        new_user = models.User(
            email=temp_email,
            password_hash=auth.get_password_hash(str(uuid.uuid4())),  # Random password
            full_name=body.full_name or "New User",
            phone_number=normalized,
            timezone="UTC",
            consent_timestamp=now_utc,
            consent_app_version="phone-otp",
            ai_consent=False,
        )
        db.add(new_user)
        db.flush()

        # Create default profile
        new_profile = models.Profile(
            name="My Health",
            phone_number=normalized, # phone_number OK because phone-OTP login requires it
        )
        db.add(new_profile)
        db.flush()

        # Create profile access
        db.add(models.ProfileAccess(
            user_id=new_user.id,
            profile_id=new_profile.id,
            access_level="owner",
        ))
        db.commit()
        db.refresh(new_user)

        # Generate JWT token
        access_token = auth.create_access_token(data={"sub": new_user.email})
        return {"access_token": access_token, "token_type": "bearer", "is_new_user": True}


# ---------------------------------------------------------------------------
# Account deletion — DPDP Act right to erasure
# ---------------------------------------------------------------------------

@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Delete the user's account and ALL associated data (DPDP Act compliance)."""
    # 1. Find all profiles this user owns
    owned_access = db.query(models.ProfileAccess).filter(
        models.ProfileAccess.user_id == user.id,
        models.ProfileAccess.access_level == "owner",
    ).all()

    for access in owned_access:
        pid = access.profile_id
        # Delete readings, AI logs, invites, access entries for owned profiles
        db.query(models.HealthReading).filter(models.HealthReading.profile_id == pid).delete()
        db.query(models.AiInsightLog).filter(models.AiInsightLog.profile_id == pid).delete()
        db.query(models.ProfileInvite).filter(models.ProfileInvite.profile_id == pid).delete()
        db.query(models.ProfileAccess).filter(models.ProfileAccess.profile_id == pid).delete()
        db.query(models.Profile).filter(models.Profile.id == pid).delete()

    # 1.1 Delete WhatsApp Logs (DPDP Act compliance)
    db.query(models.WhatsAppMessageLog).filter(models.WhatsAppMessageLog.user_id == user.id).delete()
    db.query(models.ReportGenerationLog).filter(models.ReportGenerationLog.user_id == user.id).delete()
    
    # Update timestamp with UTC
    now_utc = datetime.now(timezone.utc)

    # 2. Nullify logged_by on readings this user logged on other people's profiles
    db.query(models.HealthReading).filter(
        models.HealthReading.logged_by == user.id,
    ).update({"logged_by": None})

    # 3. Remove any remaining viewer access entries
    db.query(models.ProfileAccess).filter(models.ProfileAccess.user_id == user.id).delete()

    # 4. Clean up ALL invites referencing this user:
    #    - Invites they sent (invited_by_user_id)
    #    - Invites where they are the invitee (invited_user_id or invited_email)
    db.query(models.ProfileInvite).filter(
        models.ProfileInvite.invited_by_user_id == user.id,
    ).delete()
    db.query(models.ProfileInvite).filter(
        models.ProfileInvite.invited_email_hash == hash_email(user.email),
    ).delete()
    db.query(models.ProfileInvite).filter(
        models.ProfileInvite.invited_user_id == user.id,
    ).update({"invited_user_id": None})

    # 6. Delete password reset OTPs and email verification OTPs
    db.query(models.PasswordResetOTP).filter(models.PasswordResetOTP.email_hash == hash_email(user.email)).delete()
    db.query(models.EmailVerificationOTP).filter(models.EmailVerificationOTP.user_id == user.id).delete()

    # 7. Delete the user
    db.query(models.User).filter(models.User.id == user.id).delete()

    db.commit()
    return None


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

def _get_valid_otp(db: Session, email: str, otp: str):
    """Return a valid, unused, unexpired OTP record or None."""
    return db.query(models.PasswordResetOTP).filter(
        models.PasswordResetOTP.email_hash == hash_email(email),
        models.PasswordResetOTP.otp_hash == hash_otp(otp),
        models.PasswordResetOTP.is_used == False,
        models.PasswordResetOTP.expires_at > datetime.now(timezone.utc),
    ).first()
