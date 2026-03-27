from pydantic import BaseModel, EmailStr, validator, Field
from typing import Optional, List
from datetime import datetime


# Gender options
GENDER_OPTIONS = ["Male", "Female", "Other"]

# Blood group options
BLOOD_GROUP_OPTIONS = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]

# Medical conditions
MEDICAL_CONDITIONS = ["Diabetes T1", "Diabetes T2", "Hypertension", "Heart Disease", "None", "Other"]


class UserRegister(BaseModel):
    email: EmailStr
    password: str
    confirm_password: str
    full_name: str = Field(..., min_length=2, max_length=100)
    phone_number: str = Field(..., min_length=10, max_length=15)
    age: int = Field(..., ge=1, le=150)
    gender: str
    height: float = Field(..., gt=0, le=300)  # in cm
    weight: float = Field(..., gt=0, le=500)  # in kg
    blood_group: str
    current_medications: Optional[str] = None
    medical_conditions: List[str]
    other_medical_condition: Optional[str] = None

    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        if not any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in v):
            raise ValueError('Password must contain at least one special character')
        return v

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if 'password' in values and v != values['password']:
            raise ValueError('Passwords do not match')
        return v

    @validator('gender')
    def validate_gender(cls, v):
        if v not in GENDER_OPTIONS:
            raise ValueError(f'Gender must be one of: {", ".join(GENDER_OPTIONS)}')
        return v

    @validator('blood_group')
    def validate_blood_group(cls, v):
        if v not in BLOOD_GROUP_OPTIONS:
            raise ValueError(f'Blood group must be one of: {", ".join(BLOOD_GROUP_OPTIONS)}')
        return v

    @validator('medical_conditions')
    def validate_medical_conditions(cls, v):
        if not v:
            raise ValueError('At least one medical condition must be selected')
        for condition in v:
            if condition not in MEDICAL_CONDITIONS:
                raise ValueError(f'Invalid medical condition: {condition}')
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    email: Optional[str] = None


class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str
    phone_number: str
    age: int
    gender: str
    height: float
    weight: float
    blood_group: str
    current_medications: Optional[str]
    medical_conditions: List[str]
    other_medical_condition: Optional[str]
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class VerifyOTPRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)
    new_password: str
    confirm_password: str

    @validator('new_password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        if not any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in v):
            raise ValueError('Password must contain at least one special character')
        return v

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if 'new_password' in values and v != values['new_password']:
            raise ValueError('Passwords do not match')
        return v


class UpdateProfileRequest(BaseModel):
    full_name: Optional[str] = Field(None, min_length=2, max_length=100)
    phone_number: Optional[str] = Field(None, min_length=10, max_length=15)
    age: Optional[int] = Field(None, ge=1, le=150)
    height: Optional[float] = Field(None, gt=0, le=300)
    weight: Optional[float] = Field(None, gt=0, le=500)
    blood_group: Optional[str] = None
    current_medications: Optional[str] = None
    medical_conditions: Optional[List[str]] = None
    other_medical_condition: Optional[str] = None
    # Password change fields
    current_password: Optional[str] = None
    new_password: Optional[str] = None
    confirm_password: Optional[str] = None

    @validator('blood_group')
    def validate_blood_group(cls, v):
        if v is not None and v not in BLOOD_GROUP_OPTIONS:
            raise ValueError(f'Blood group must be one of: {", ".join(BLOOD_GROUP_OPTIONS)}')
        return v

    @validator('medical_conditions')
    def validate_medical_conditions(cls, v):
        if v is not None:
            for condition in v:
                if condition not in MEDICAL_CONDITIONS:
                    raise ValueError(f'Invalid medical condition: {condition}')
        return v

    @validator('new_password')
    def validate_new_password(cls, v, values):
        if v is not None:  # Only validate if provided
            if len(v) < 8:
                raise ValueError('Password must be at least 8 characters long')
            if not any(c.isupper() for c in v):
                raise ValueError('Password must contain at least one uppercase letter')
            if not any(c.islower() for c in v):
                raise ValueError('Password must contain at least one lowercase letter')
            if not any(c.isdigit() for c in v):
                raise ValueError('Password must contain at least one number')
            if not any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in v):
                raise ValueError('Password must contain at least one special character')
        return v

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if v is not None and 'new_password' in values and v != values['new_password']:
            raise ValueError('Passwords do not match')
        return v


# Health Reading Schemas
class HealthReadingCreate(BaseModel):
    reading_type: str  # 'glucose' or 'blood_pressure'
    
    # Glucose fields
    glucose_value: Optional[float] = None
    glucose_unit: Optional[str] = None
    sample_type: Optional[str] = None
    
    # BP fields
    systolic: Optional[float] = None
    diastolic: Optional[float] = None
    mean_arterial_pressure: Optional[float] = None
    pulse_rate: Optional[float] = None
    bp_unit: Optional[str] = None
    bp_status: Optional[str] = None
    
    # Common fields
    value_numeric: float
    unit_display: str
    status_flag: Optional[str] = None
    notes: Optional[str] = None
    reading_timestamp: datetime


class HealthReadingResponse(BaseModel):
    id: int
    user_id: int
    reading_type: str
    glucose_value: Optional[float]
    glucose_unit: Optional[str]
    sample_type: Optional[str]
    systolic: Optional[float]
    diastolic: Optional[float]
    mean_arterial_pressure: Optional[float]
    pulse_rate: Optional[float]
    bp_unit: Optional[str]
    bp_status: Optional[str]
    value_numeric: float
    unit_display: str
    status_flag: Optional[str]
    notes: Optional[str]
    reading_timestamp: datetime
    created_at: datetime

    class Config:
        from_attributes = True
