from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address
import os
import pytz
import models
import schemas
import auth
from email_service import email_service
from database import get_db
from config import settings
from dependencies import get_current_user

router = APIRouter()
_enabled = os.environ.get("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)


@router.post("/register", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
def register(request: Request, user: schemas.UserRegister, db: Session = Depends(get_db)):
    """Register a new user and create their initial 'My Health' profile."""
    user.email = user.email.strip().lower()
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    # 1. Create User (auth only)
    # Get UTC time and convert to user's timezone
    user_tz = pytz.timezone(user.timezone)
    now_utc = datetime.now(pytz.UTC)
    now_in_user_tz = now_utc.astimezone(user_tz)
    
    db_user = models.User(
        email=user.email,
        password_hash=auth.get_password_hash(user.password),
        full_name=user.full_name,
        phone_number=user.phone_number,
        timezone=user.timezone,
        consent_timestamp=now_in_user_tz if user.consent_app_version else None,
        consent_app_version=user.consent_app_version,
        consent_language=user.consent_language,
        ai_consent=bool(user.ai_consent) if user.ai_consent else bool(user.consent_app_version),
        ai_consent_timestamp=now_in_user_tz if (user.ai_consent or user.consent_app_version) else None,
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
    
    db.commit()
    db.refresh(db_user)
    
    # 4. Send welcome email
    try:
        email_service.send_welcome_email(db_user.email, db_user.full_name)
    except Exception as e:
        print(f"Error sending welcome email: {e}")

    return db_user


@router.post("/login", response_model=schemas.Token)
@limiter.limit("10/minute")
def login(request: Request, user: schemas.UserLogin, db: Session = Depends(get_db)):
    """Login user and return JWT token."""
    db_user = db.query(models.User).filter(models.User.email == user.email.strip().lower()).first()
    if not db_user or not auth.verify_password(user.password, db_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    # Update last_login with timezone-aware timestamp
    # Handle case where old users might not have timezone set
    user_timezone = db_user.timezone if db_user.timezone else "Asia/Kolkata"
    user_tz = pytz.timezone(user_timezone)
    now_utc = datetime.now(pytz.UTC)
    db_user.last_login_at = now_utc.astimezone(user_tz)
    db.commit()
    access_token = auth.create_access_token(data={"sub": db_user.email})
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me", response_model=schemas.UserResponse)
def get_current_user_info(user: models.User = Depends(get_current_user)):
    """Get current user information."""
    return user


@router.post("/forgot-password")
@limiter.limit("3/minute")
def request_password_reset(request: Request, body: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Request password reset OTP."""
    body.email = body.email.strip().lower()
    user = db.query(models.User).filter(models.User.email == body.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User with this email does not exist"
        )

    otp = email_service.generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

    db.add(models.PasswordResetOTP(email=body.email, otp=otp, expires_at=expires_at))
    db.commit()

    if not email_service.send_otp_email(body.email, otp):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send OTP email. Please try again later."
        )

    return {"message": "OTP sent successfully to your email", "expires_in_minutes": settings.OTP_EXPIRE_MINUTES}


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

    user = db.query(models.User).filter(models.User.email == body.email).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    user.password_hash = auth.get_password_hash(body.new_password)
    # Update timestamp in user's timezone - handle NULL timezone for old users
    user_timezone = user.timezone if user.timezone else "Asia/Kolkata"
    user_tz = pytz.timezone(user_timezone)
    now_utc = datetime.now(pytz.UTC)
    user.updated_at = now_utc.astimezone(user_tz)
    otp_record.is_used = True
    db.commit()
    return {"message": "Password reset successfully"}


@router.put("/profile", response_model=schemas.UserResponse)
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
        user.phone_number = user_update.phone_number

    # Update timestamp in user's timezone - handle NULL timezone for old users
    user_timezone = user.timezone if user.timezone else "Asia/Kolkata"
    user_tz = pytz.timezone(user_timezone)
    now_utc = datetime.now(pytz.UTC)
    user.updated_at = now_utc.astimezone(user_tz)
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
    # Record consent timestamp in user's timezone - handle NULL timezone for old users
    user_timezone = user.timezone if user.timezone else "Asia/Kolkata"
    user_tz = pytz.timezone(user_timezone)
    now_utc = datetime.now(pytz.UTC)
    user.ai_consent_timestamp = now_utc.astimezone(user_tz)
    db.commit()
    return {"message": "AI consent granted"}


# ---------------------------------------------------------------------------
# Account deletion — DPDP Act right to erasure
# ---------------------------------------------------------------------------

@router.delete("/account")
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
        db.query(models.GlucoseReading).filter(models.GlucoseReading.profile_id == pid).delete()
        db.query(models.BPReading).filter(models.BPReading.profile_id == pid).delete()
        db.query(models.AiInsightLog).filter(models.AiInsightLog.profile_id == pid).delete()
        db.query(models.ProfileInvite).filter(models.ProfileInvite.profile_id == pid).delete()
        db.query(models.ProfileAccess).filter(models.ProfileAccess.profile_id == pid).delete()
        db.query(models.Profile).filter(models.Profile.id == pid).delete()

    # 2. Nullify logged_by on readings this user logged on other people's profiles
    db.query(models.GlucoseReading).filter(
        models.GlucoseReading.logged_by == user.id,
    ).update({"logged_by": None})
    db.query(models.BPReading).filter(
        models.BPReading.logged_by == user.id,
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
        models.ProfileInvite.invited_email == user.email.lower(),
    ).delete()
    db.query(models.ProfileInvite).filter(
        models.ProfileInvite.invited_user_id == user.id,
    ).update({"invited_user_id": None})

    # 6. Delete password reset OTPs
    db.query(models.PasswordResetOTP).filter(models.PasswordResetOTP.email == user.email).delete()

    # 7. Delete the user
    db.query(models.User).filter(models.User.id == user.id).delete()

    db.commit()
    return {"message": "Account and all associated data have been permanently deleted"}


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

def _get_valid_otp(db: Session, email: str, otp: str):
    """Return a valid, unused, unexpired OTP record or None."""
    return db.query(models.PasswordResetOTP).filter(
        models.PasswordResetOTP.email == email,
        models.PasswordResetOTP.otp == otp,
        models.PasswordResetOTP.is_used == False,
        models.PasswordResetOTP.expires_at > datetime.utcnow(),
    ).first()
