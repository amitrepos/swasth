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
    """Register a new user."""
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    if "Other" in user.medical_conditions and not user.other_medical_condition:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please provide details for 'Other' medical condition"
        )

    db_user = models.User(
        email=user.email,
        password_hash=auth.get_password_hash(user.password),
        full_name=user.full_name,
        phone_number=user.phone_number,
        age=user.age,
        gender=user.gender,
        height=user.height,
        weight=user.weight,
        blood_group=user.blood_group,
        current_medications=user.current_medications,
        medical_conditions=user.medical_conditions,
        other_medical_condition=user.other_medical_condition,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
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
    profile_update: schemas.UpdateProfileRequest,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Update user profile."""
    if profile_update.new_password or profile_update.current_password or profile_update.confirm_password:
        if not profile_update.current_password:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Current password is required")
        if not profile_update.new_password:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="New password is required")
        if not profile_update.confirm_password:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Confirm password is required")
        if not auth.verify_password(profile_update.current_password, user.password_hash):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Current password is incorrect")
        user.password_hash = auth.get_password_hash(profile_update.new_password)
        user.updated_at = datetime.utcnow()

    if profile_update.medical_conditions and "Other" in profile_update.medical_conditions:
        if not profile_update.other_medical_condition:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Please provide details for 'Other' medical condition"
            )

    update_data = profile_update.model_dump(
        exclude_unset=True,
        exclude={'current_password', 'new_password', 'confirm_password'},
    )
    for field, value in update_data.items():
        if value is not None:
            setattr(user, field, value)

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
