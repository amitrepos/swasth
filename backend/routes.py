from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Annotated
from datetime import datetime, timedelta
import models
import schemas
import auth
from email_service import email_service
from database import get_db
from config import settings

router = APIRouter()


@router.post("/register", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
def register(user: schemas.UserRegister, db: Session = Depends(get_db)):
    """Register a new user."""
    # Check if user with this email already exists
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Check if "Other" medical condition is provided when "Other" is selected
    if "Other" in user.medical_conditions and not user.other_medical_condition:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please provide details for 'Other' medical condition"
        )
    
    # Create new user
    hashed_password = auth.get_password_hash(user.password)
    db_user = models.User(
        email=user.email,
        password_hash=hashed_password,
        full_name=user.full_name,
        phone_number=user.phone_number,
        age=user.age,
        gender=user.gender,
        height=user.height,
        weight=user.weight,
        blood_group=user.blood_group,
        current_medications=user.current_medications,
        medical_conditions=user.medical_conditions,
        other_medical_condition=user.other_medical_condition
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    return db_user


@router.post("/login", response_model=schemas.Token)
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):
    """Login user and return JWT token."""
    # Find user by email
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Verify password
    if not auth.verify_password(user.password, db_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Create access token
    access_token = auth.create_access_token(data={"sub": db_user.email})
    
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me", response_model=schemas.UserResponse)
def get_current_user_info(
    token: Annotated[str, Depends(auth.oauth2_scheme)],
    db: Session = Depends(get_db)
):
    """Get current user information."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = auth.decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    email: str = payload.get("sub")
    if email is None:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    
    return user


@router.post("/forgot-password")
def request_password_reset(request: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Request password reset OTP."""
    print(f"\n=== FORGOT PASSWORD REQUEST ===")
    print(f"Email: {request.email}")
    
    # Check if user exists
    user = db.query(models.User).filter(models.User.email == request.email).first()
    print(f"User found: {user is not None}")
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User with this email does not exist"
        )
    
    # Generate OTP
    otp = email_service.generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
    
    # Store OTP in database
    db_otp = models.PasswordResetOTP(
        email=request.email,
        otp=otp,
        expires_at=expires_at
    )
    db.add(db_otp)
    db.commit()
    print(f"OTP stored in database: {otp}")
    
    # Send OTP via email
    print(f"Attempting to send email...")
    email_sent = email_service.send_otp_email(request.email, otp)
    print(f"Email service returned: {email_sent}")
    
    if not email_sent:
        print(f"❌ Email sending failed!")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send OTP email. Please try again later."
        )
    
    print(f"✅ Password reset request completed successfully")
    return {
        "message": "OTP sent successfully to your email",
        "expires_in_minutes": settings.OTP_EXPIRE_MINUTES
    }


@router.post("/verify-otp")
def verify_reset_otp(request: schemas.VerifyOTPRequest, db: Session = Depends(get_db)):
    """Verify OTP for password reset."""
    # Find valid OTP
    otp_record = db.query(models.PasswordResetOTP).filter(
        models.PasswordResetOTP.email == request.email,
        models.PasswordResetOTP.otp == request.otp,
        models.PasswordResetOTP.is_used == False,
        models.PasswordResetOTP.expires_at > datetime.utcnow()
    ).first()
    
    if not otp_record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP"
        )
    
    return {"message": "OTP verified successfully"}


@router.post("/reset-password")
def reset_password(request: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    """Reset password using OTP."""
    # Verify OTP first
    otp_record = db.query(models.PasswordResetOTP).filter(
        models.PasswordResetOTP.email == request.email,
        models.PasswordResetOTP.otp == request.otp,
        models.PasswordResetOTP.is_used == False,
        models.PasswordResetOTP.expires_at > datetime.utcnow()
    ).first()
    
    if not otp_record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP"
        )
    
    # Get user
    user = db.query(models.User).filter(models.User.email == request.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Update password
    user.password_hash = auth.get_password_hash(request.new_password)
    user.updated_at = datetime.utcnow()
    
    # Mark OTP as used
    otp_record.is_used = True
    
    db.commit()
    
    return {"message": "Password reset successfully"}


@router.put("/profile", response_model=schemas.UserResponse)
def update_profile(
    profile_update: schemas.UpdateProfileRequest,
    token: Annotated[str, Depends(auth.oauth2_scheme)],
    db: Session = Depends(get_db)
):
    """Update user profile."""
    # Get current user
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = auth.decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    email: str = payload.get("sub")
    if email is None:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    
    # Handle password change
    if profile_update.new_password or profile_update.current_password or profile_update.confirm_password:
        # Validate all password fields are provided
        if not profile_update.current_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Current password is required"
            )
        if not profile_update.new_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="New password is required"
            )
        if not profile_update.confirm_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Confirm password is required"
            )
        
        # Verify current password
        if not auth.verify_password(profile_update.current_password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Current password is incorrect"
            )
        
        # Update password
        user.password_hash = auth.get_password_hash(profile_update.new_password)
        user.updated_at = datetime.utcnow()
    
    # Update other fields if provided
    update_data = profile_update.model_dump(exclude_unset=True, exclude={'current_password', 'new_password', 'confirm_password'})
    
    # Handle "Other" medical condition validation
    if profile_update.medical_conditions and "Other" in profile_update.medical_conditions:
        if not profile_update.other_medical_condition:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Please provide details for 'Other' medical condition"
            )
    
    for field, value in update_data.items():
        if value is not None:
            setattr(user, field, value)
    
    db.commit()
    db.refresh(user)
    
    return user
