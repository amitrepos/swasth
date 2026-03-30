from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import models
import schemas
import auth
from email_service import email_service
from database import get_db
from config import settings
from dependencies import get_current_user

router = APIRouter()


@router.post("/register", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
def register(user: schemas.UserRegister, db: Session = Depends(get_db)):
    """Register a new user and create their initial 'My Health' profile."""
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    # 1. Create User (auth only)
    from datetime import datetime
    db_user = models.User(
        email=user.email,
        password_hash=auth.get_password_hash(user.password),
        full_name=user.full_name,
        phone_number=user.phone_number,
        consent_timestamp=datetime.utcnow() if user.consent_app_version else None,
        consent_app_version=user.consent_app_version,
        consent_language=user.consent_language,
    )
    db.add(db_user)
    db.flush()  # Get db_user.id

    # 2. Create Profile
    db_profile = models.Profile(
        name=user.profile_name or "My Health",
        age=user.age,
        gender=user.gender,
        height=user.height,
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
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):
    """Login user and return JWT token."""
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if not db_user or not auth.verify_password(user.password, db_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = auth.create_access_token(data={"sub": db_user.email})
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me", response_model=schemas.UserResponse)
def get_current_user_info(user: models.User = Depends(get_current_user)):
    """Get current user information."""
    return user


@router.post("/forgot-password")
def request_password_reset(request: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Request password reset OTP."""
    user = db.query(models.User).filter(models.User.email == request.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User with this email does not exist"
        )

    otp = email_service.generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

    db.add(models.PasswordResetOTP(email=request.email, otp=otp, expires_at=expires_at))
    db.commit()

    if not email_service.send_otp_email(request.email, otp):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send OTP email. Please try again later."
        )

    return {"message": "OTP sent successfully to your email", "expires_in_minutes": settings.OTP_EXPIRE_MINUTES}


@router.post("/verify-otp")
def verify_reset_otp(request: schemas.VerifyOTPRequest, db: Session = Depends(get_db)):
    """Verify OTP for password reset."""
    otp_record = _get_valid_otp(db, request.email, request.otp)
    if not otp_record:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP")
    return {"message": "OTP verified successfully"}


@router.post("/reset-password")
def reset_password(request: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    """Reset password using OTP."""
    otp_record = _get_valid_otp(db, request.email, request.otp)
    if not otp_record:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP")

    user = db.query(models.User).filter(models.User.email == request.email).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    user.password_hash = auth.get_password_hash(request.new_password)
    user.updated_at = datetime.utcnow()
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

    user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(user)
    return user


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
