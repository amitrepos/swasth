from pydantic import BaseModel, EmailStr, validator, Field
from typing import Optional, List, Literal
from datetime import datetime


# Options
GENDER_OPTIONS = ["Male", "Female", "Other"]
BLOOD_GROUP_OPTIONS = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
MEDICAL_CONDITIONS = ["Diabetes T1", "Diabetes T2", "Hypertension", "Heart Disease", "None", "Other"]
_SPECIAL_CHARS = '!@#$%^&*()_+-=[]{}|;:,.<>?'


def _validate_password_strength(v: str) -> str:
    """Shared password strength validator used across all schemas."""
    if len(v) < 8:
        raise ValueError('Password must be at least 8 characters long')
    if not any(c.isupper() for c in v):
        raise ValueError('Password must contain at least one uppercase letter')
    if not any(c.islower() for c in v):
        raise ValueError('Password must contain at least one lowercase letter')
    if not any(c.isdigit() for c in v):
        raise ValueError('Password must contain at least one number')
    if not any(c in _SPECIAL_CHARS for c in v):
        raise ValueError('Password must contain at least one special character')
    return v


# ---------------------------------------------------------------------------
# Auth schemas
# ---------------------------------------------------------------------------

class UserRegister(BaseModel):
    email: EmailStr
    password: str
    confirm_password: str
    full_name: str = Field(..., min_length=2, max_length=100)
    phone_number: str = Field(..., min_length=10, max_length=15)
    # Optional first-profile fields — used to auto-create "My Health" profile on register
    profile_name: Optional[str] = "My Health"
    age: Optional[int] = Field(None, ge=1, le=150)
    gender: Optional[str] = None
    height: Optional[float] = Field(None, gt=0, le=300)   # cm
    blood_group: Optional[str] = None
    current_medications: Optional[str] = None
    medical_conditions: Optional[List[str]] = None
    other_medical_condition: Optional[str] = None

    @validator('password')
    def validate_password(cls, v):
        return _validate_password_strength(v)

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if 'password' in values and v != values['password']:
            raise ValueError('Passwords do not match')
        return v

    @validator('gender')
    def validate_gender(cls, v):
        if v is not None and v not in GENDER_OPTIONS:
            raise ValueError(f'Gender must be one of: {", ".join(GENDER_OPTIONS)}')
        return v

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
        return _validate_password_strength(v)

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if 'new_password' in values and v != values['new_password']:
            raise ValueError('Passwords do not match')
        return v


class UpdateUserRequest(BaseModel):
    """Auth-level user fields only — name, phone, password change."""
    full_name: Optional[str] = Field(None, min_length=2, max_length=100)
    phone_number: Optional[str] = Field(None, min_length=10, max_length=15)
    current_password: Optional[str] = None
    new_password: Optional[str] = None
    confirm_password: Optional[str] = None

    @validator('new_password')
    def validate_new_password(cls, v):
        if v is not None:
            return _validate_password_strength(v)
        return v

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if v is not None and 'new_password' in values and v != values['new_password']:
            raise ValueError('Passwords do not match')
        return v


# ---------------------------------------------------------------------------
# Profile schemas
# ---------------------------------------------------------------------------

class ProfileCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    age: Optional[int] = Field(None, ge=1, le=150)
    gender: Optional[str] = None
    height: Optional[float] = Field(None, gt=0, le=300)   # cm
    blood_group: Optional[str] = None
    medical_conditions: Optional[List[str]] = None
    other_medical_condition: Optional[str] = None
    current_medications: Optional[str] = None

    @validator('gender')
    def validate_gender(cls, v):
        if v is not None and v not in GENDER_OPTIONS:
            raise ValueError(f'Gender must be one of: {", ".join(GENDER_OPTIONS)}')
        return v

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


class ProfileUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    age: Optional[int] = Field(None, ge=1, le=150)
    gender: Optional[str] = None
    height: Optional[float] = Field(None, gt=0, le=300)
    blood_group: Optional[str] = None
    medical_conditions: Optional[List[str]] = None
    other_medical_condition: Optional[str] = None
    current_medications: Optional[str] = None

    @validator('gender')
    def validate_gender(cls, v):
        if v is not None and v not in GENDER_OPTIONS:
            raise ValueError(f'Gender must be one of: {", ".join(GENDER_OPTIONS)}')
        return v

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


class ProfileResponse(BaseModel):
    id: int
    name: str
    age: Optional[int]
    gender: Optional[str]
    height: Optional[float]
    blood_group: Optional[str]
    medical_conditions: Optional[List[str]]
    other_medical_condition: Optional[str]
    current_medications: Optional[str]
    access_level: str           # "owner" or "viewer" — injected per-user at query time
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Invite schemas
# ---------------------------------------------------------------------------

class InviteRequest(BaseModel):
    email: EmailStr


class InviteResponse(BaseModel):
    id: int
    profile_id: int
    profile_name: str
    invited_by_name: str
    status: str
    expires_at: datetime
    created_at: datetime

    class Config:
        from_attributes = True


class InviteRespondRequest(BaseModel):
    action: Literal["accept", "reject"]


# ---------------------------------------------------------------------------
# Health Reading schemas
# ---------------------------------------------------------------------------

class HealthScoreResponse(BaseModel):
    score: int                          # 0–100
    color: str                          # "green" | "orange" | "red"
    streak_days: int                    # consecutive days with ≥1 reading
    insight: str                        # plain-English encouragement/tip
    today_glucose_status: Optional[str] = None   # NORMAL | HIGH | CRITICAL | LOW
    today_bp_status: Optional[str] = None
    today_glucose_value: Optional[float] = None
    today_bp_systolic: Optional[float] = None
    today_bp_diastolic: Optional[float] = None
    last_logged: Optional[datetime] = None
    profile_age: Optional[int] = None


class HealthReadingCreate(BaseModel):
    profile_id: int
    reading_type: str           # 'glucose' or 'blood_pressure'

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
    profile_id: int
    logged_by: Optional[int]
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
