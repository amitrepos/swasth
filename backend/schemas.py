import re
from pydantic import BaseModel, EmailStr, validator, Field
from typing import Optional, List, Literal
from datetime import date, datetime


# Options
GENDER_OPTIONS = ["Male", "Female", "Other"]
BLOOD_GROUP_OPTIONS = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
MEDICAL_CONDITIONS = ["Diabetes T1", "Diabetes T2", "Hypertension", "Heart Disease", "None", "Other"]
RELATIONSHIP_OPTIONS = ["myself", "father", "mother", "spouse", "son", "daughter", "brother", "sister", "uncle", "aunt", "friend", "other"]
_SPECIAL_CHARS = '!@#$%^&*()_+-=[]{}|;:,.<>?'

# Doctor portal constants — declared here (top of module) so Admin*
# schemas defined before the Doctor Portal section can reference them
# without a load-order foot-gun.
DOCTOR_SPECIALTY_OPTIONS = [
    "General Physician", "Endocrinologist", "Cardiologist", "Diabetologist",
    "Internal Medicine", "Family Medicine",
    # Bihar-pilot additions per Dr. Rajesh's review of PR #100. Keep in
    # sync with lib/constants/doctor_specialties.dart on the Flutter
    # client. BHMS / AYUSH intentionally excluded until legal signs off
    # on telemedicine scope-of-practice for those councils.
    "Gynaecology", "Paediatrics", "General Surgery",
    "Other",
]
CONSENT_TYPE_OPTIONS = ["in_person_exam", "video_consult"]

# NMC registration number — digits, optional state council prefix like "BMCR/".
# Real council numbers are 5-10 digits; reject anything shorter to stop
# trivial identifiers like "1234" from passing validation.
_NMC_PATTERN = re.compile(r'^[A-Z]{0,8}/?\d{5,10}$')

# Phone number — 10-15 digits with an optional leading '+' and no separators.
_PHONE_PATTERN = re.compile(r'^\+?\d{10,15}$')


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


def _validate_phone_number_helper(v: str | None) -> str | None:
    if v is None:
        return v
    stripped = re.sub(r'[\s\-]', '', v)
    if not _PHONE_PATTERN.match(stripped):
        raise ValueError('Phone number must be 10-15 digits, optionally starting with +')
    return stripped


# ---------------------------------------------------------------------------
# Auth schemas
# ---------------------------------------------------------------------------

class UserRegister(BaseModel):
    email: EmailStr
    password: str
    confirm_password: str
    full_name: str = Field(..., min_length=2, max_length=100)
    phone_number: str = Field(..., min_length=10, max_length=15)
    timezone: str = "UTC"  # User's local timezone
    # Optional first-profile fields — used to auto-create "My Health" profile on register
    profile_name: Optional[str] = "My Health"
    age: Optional[int] = Field(None, ge=1, le=150)
    gender: Optional[str] = None
    height: Optional[float] = Field(None, gt=0, le=300)   # cm
    weight: Optional[float] = Field(None, gt=0, le=500)   # kg
    blood_group: Optional[str] = None
    current_medications: Optional[str] = None
    medical_conditions: Optional[List[str]] = None
    other_medical_condition: Optional[str] = None
    # Consent fields — set when user accepts privacy notice during registration
    consent_app_version: Optional[str] = None
    consent_language: Optional[str] = None
    ai_consent: Optional[bool] = None

    @validator('email')
    def normalize_email(cls, v):
        return v.strip().lower()

    @validator('password')
    def validate_password(cls, v):
        return _validate_password_strength(v)

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if 'password' in values and v != values['password']:
            raise ValueError('Passwords do not match')
        return v

    @validator('phone_number')
    def validate_phone_number(cls, v):
        return _validate_phone_number_helper(v)

    @validator('timezone')
    def validate_timezone(cls, v):
        import pytz
        try:
            pytz.timezone(v)
            return v
        except pytz.exceptions.UnknownTimeZoneError:
            raise ValueError(f'Invalid timezone: {v}')

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

    @validator('email')
    def normalize_email(cls, v):
        return v.strip().lower()


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
    is_admin: bool = False
    role: Optional[str] = "patient"
    timezone: str
    email_verified: bool = False
    consent_timestamp: Optional[datetime] = None
    consent_app_version: Optional[str] = None
    consent_language: Optional[str] = None
    ai_consent: Optional[bool] = None
    created_at: datetime

    class Config:
        from_attributes = True


class VerifyEmailOTPRequest(BaseModel):
    otp: str = Field(..., min_length=6, max_length=6)


class ForgotPasswordRequest(BaseModel):
    email: EmailStr

    @validator('email')
    def normalize_email(cls, v):
        return v.strip().lower()


class VerifyOTPRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)

    @validator('email')
    def normalize_email(cls, v):
        return v.strip().lower()


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)
    new_password: str
    confirm_password: str

    @validator('email')
    def normalize_email(cls, v):
        return v.strip().lower()

    @validator('new_password')
    def validate_password(cls, v):
        return _validate_password_strength(v)

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if 'new_password' in values and v != values['new_password']:
            raise ValueError('Passwords do not match')
        return v


class CheckAccountExistsRequest(BaseModel):
    """Request to check if an account exists by email or phone."""
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None

    @validator('email')
    def normalize_email(cls, v):
        return v.strip().lower() if v else v

    @validator('phone_number')
    def validate_phone_number(cls, v):
        return _validate_phone_number_helper(v)


class PhoneOTPRequest(BaseModel):
    """Request to send OTP to phone number."""
    phone_number: str

    @validator('phone_number')
    def validate_phone_number(cls, v):
        return _validate_phone_number_helper(v)


class PhoneOTPVerifyRequest(BaseModel):
    """Request to verify phone OTP and login/register."""
    phone_number: str
    otp: str = Field(..., min_length=6, max_length=6)
    full_name: Optional[str] = Field(None, min_length=2, max_length=100)

    @validator('phone_number')
    def validate_phone_number(cls, v):
        return _validate_phone_number_helper(v)


class UpdateUserRequest(BaseModel):
    """Auth-level user fields only — name, phone, password change."""
    full_name: Optional[str] = Field(None, min_length=2, max_length=100)
    phone_number: Optional[str] = None
    current_password: Optional[str] = None
    new_password: Optional[str] = None
    confirm_password: Optional[str] = None

    @validator('phone_number')
    def validate_phone_number(cls, v):
        return _validate_phone_number_helper(v)

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
    relationship: Optional[str] = None   # "myself", "father", "mother", etc.
    age: Optional[int] = Field(None, ge=1, le=150)
    gender: Optional[str] = None
    height: Optional[float] = Field(None, gt=0, le=300)   # cm
    weight: Optional[float] = Field(None, gt=0, le=500)   # kg
    blood_group: Optional[str] = None
    medical_conditions: Optional[List[str]] = None
    other_medical_condition: Optional[str] = None
    current_medications: Optional[str] = None
    doctor_name: Optional[str] = None
    doctor_specialty: Optional[str] = None
    doctor_whatsapp: Optional[str] = None
    phone_number: Optional[str] = None

    @validator('phone_number')
    def validate_phone_number(cls, v):
        return _validate_phone_number_helper(v)

    @validator('relationship')
    def validate_relationship(cls, v):
        if v is not None and v not in RELATIONSHIP_OPTIONS:
            raise ValueError(f'Relationship must be one of: {", ".join(RELATIONSHIP_OPTIONS)}')
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


class ProfileUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    age: Optional[int] = Field(None, ge=1, le=150)
    gender: Optional[str] = None
    height: Optional[float] = Field(None, gt=0, le=300)
    weight: Optional[float] = Field(None, gt=0, le=500)   # kg
    blood_group: Optional[str] = None
    medical_conditions: Optional[List[str]] = None
    other_medical_condition: Optional[str] = None
    current_medications: Optional[str] = None
    doctor_name: Optional[str] = None
    doctor_specialty: Optional[str] = None
    doctor_whatsapp: Optional[str] = None
    phone_number: Optional[str] = None

    @validator('phone_number')
    def validate_phone_number(cls, v):
        return _validate_phone_number_helper(v)

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
    weight: Optional[float]
    blood_group: Optional[str]
    medical_conditions: Optional[List[str]]
    other_medical_condition: Optional[str]
    current_medications: Optional[str]
    doctor_name: Optional[str] = None
    doctor_specialty: Optional[str] = None
    doctor_whatsapp: Optional[str] = None
    phone_number: Optional[str] = None
    access_level: str           # "owner" or "viewer" — injected per-user at query time
    relationship: Optional[str] = None  # "father", "mother", etc. — only for viewers
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Invite schemas
# ---------------------------------------------------------------------------

class InviteRequest(BaseModel):
    email: EmailStr
    relationship: Optional[str] = None
    access_level: Optional[str] = "viewer"

    @validator('relationship')
    def validate_relationship(cls, v):
        if v is not None and v not in RELATIONSHIP_OPTIONS:
            raise ValueError(f'Relationship must be one of: {", ".join(RELATIONSHIP_OPTIONS)}')
        return v

    @validator('access_level')
    def validate_access_level(cls, v):
        if v not in ("viewer", "editor"):
            raise ValueError('access_level must be "viewer" or "editor"')
        return v


class InviteResponse(BaseModel):
    id: int
    profile_id: int
    profile_name: str
    invited_by_name: str
    relationship: Optional[str] = None
    access_level: Optional[str] = "viewer"
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
    profile_name: Optional[str] = None  # name of the profile (not the logged-in user)
    today_glucose_status: Optional[str] = None   # NORMAL | HIGH | CRITICAL | LOW
    today_bp_status: Optional[str] = None
    today_glucose_value: Optional[float] = None
    today_bp_systolic: Optional[float] = None
    today_bp_diastolic: Optional[float] = None
    last_logged: Optional[datetime] = None
    profile_age: Optional[int] = None
    age_context_bp: Optional[str] = None      # age-specific note for BP reading
    age_context_glucose: Optional[str] = None  # age-specific note for glucose reading

    # 90-day averages for Vital Summary card
    avg_glucose_90d: Optional[float] = None
    prev_avg_glucose_90d: Optional[float] = None  # prior 90-day window for trend
    avg_systolic_90d: Optional[float] = None
    avg_diastolic_90d: Optional[float] = None
    prev_avg_systolic_90d: Optional[float] = None  # prior 90-day window for trend

    # Most recent readings ever (not just today) for Individual Metrics grid
    last_glucose_value: Optional[float] = None
    last_glucose_status: Optional[str] = None
    last_bp_systolic: Optional[float] = None
    last_bp_diastolic: Optional[float] = None
    last_bp_status: Optional[str] = None

    # Actual days with data in 90d window — drives dynamic "N-day avg" label
    glucose_data_days: Optional[int] = None
    bp_data_days: Optional[int] = None

    # BMI (computed from profile height + weight)
    bmi: Optional[float] = None              # kg/m²
    bmi_category: Optional[str] = None       # Underweight | Normal | Overweight | Obese
    profile_height: Optional[float] = None   # cm
    profile_weight: Optional[float] = None   # kg

    # SpO2 (oxygen saturation — from armband or manual entry)
    today_spo2_value: Optional[float] = None
    today_spo2_status: Optional[str] = None   # NORMAL | LOW | CRITICAL
    last_spo2_value: Optional[float] = None
    last_spo2_status: Optional[str] = None
    avg_spo2_90d: Optional[float] = None
    spo2_data_days: Optional[int] = None

    # Steps (from armband or phone pedometer)
    today_steps_count: Optional[int] = None
    today_steps_goal: Optional[int] = None
    last_steps_count: Optional[int] = None
    avg_steps_90d: Optional[float] = None
    steps_data_days: Optional[int] = None

    # Weight fields
    today_weight_value: Optional[float] = None
    last_weight_value: Optional[float] = None
    avg_weight_90d: Optional[float] = None
    weight_data_days: Optional[int] = None


class HealthReadingCreate(BaseModel):
    profile_id: int
    reading_type: str           # 'glucose', 'blood_pressure', 'spo2', 'steps', or 'weight'

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

    # SpO2 fields
    spo2_value: Optional[float] = None
    spo2_unit: Optional[str] = None

    steps_count: Optional[int] = None
    steps_goal: Optional[int] = None

    # Weight fields
    weight_value: Optional[float] = None
    weight_unit: Optional[str] = None

    # Common fields
    value_numeric: float
    unit_display: str
    status_flag: Optional[str] = None
    notes: Optional[str] = None
    reading_timestamp: datetime
    seq: Optional[int] = None                # Device sequence number for BLE deduplication


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
    spo2_value: Optional[float] = None
    spo2_unit: Optional[str] = None
    steps_count: Optional[int] = None
    steps_goal: Optional[int] = None
    weight_value: Optional[float] = None
    weight_unit: Optional[str] = None
    value_numeric: float
    unit_display: str
    status_flag: Optional[str]
    notes: Optional[str]
    reading_timestamp: datetime
    seq: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Meal Logging schemas
# ---------------------------------------------------------------------------

MEAL_CATEGORIES = ["HIGH_CARB", "MODERATE_CARB", "LOW_CARB", "HIGH_PROTEIN", "SWEETS"]
GLUCOSE_IMPACT_OPTIONS = ["HIGH", "MODERATE", "LOW", "VERY_HIGH"]
MEAL_TYPE_OPTIONS = ["BREAKFAST", "LUNCH", "DINNER", "SNACK"]
MEAL_INPUT_METHODS = ["PHOTO_GEMINI", "QUICK_SELECT"]


class MealLogCreate(BaseModel):
    profile_id: int
    category: str
    glucose_impact: str
    meal_type: str
    input_method: str
    timestamp: datetime
    tip_en: Optional[str] = None
    tip_hi: Optional[str] = None
    confidence: Optional[float] = None
    user_confirmed: bool = True
    user_corrected_category: Optional[str] = None

    @validator('category')
    def validate_category(cls, v):
        if v not in MEAL_CATEGORIES:
            raise ValueError(f'category must be one of: {", ".join(MEAL_CATEGORIES)}')
        return v

    @validator('glucose_impact')
    def validate_glucose_impact(cls, v):
        if v not in GLUCOSE_IMPACT_OPTIONS:
            raise ValueError(f'glucose_impact must be one of: {", ".join(GLUCOSE_IMPACT_OPTIONS)}')
        return v

    @validator('meal_type')
    def validate_meal_type(cls, v):
        if v not in MEAL_TYPE_OPTIONS:
            raise ValueError(f'meal_type must be one of: {", ".join(MEAL_TYPE_OPTIONS)}')
        return v

    @validator('input_method')
    def validate_input_method(cls, v):
        if v not in MEAL_INPUT_METHODS:
            raise ValueError(f'input_method must be one of: {", ".join(MEAL_INPUT_METHODS)}')
        return v

    @validator('user_corrected_category')
    def validate_corrected_category(cls, v):
        if v is not None and v not in MEAL_CATEGORIES:
            raise ValueError(f'user_corrected_category must be one of: {", ".join(MEAL_CATEGORIES)}')
        return v


class MealLogResponse(BaseModel):
    id: int
    profile_id: int
    logged_by: Optional[int] = None
    category: str
    glucose_impact: str
    tip_en: Optional[str] = None
    tip_hi: Optional[str] = None
    meal_type: str
    photo_path: Optional[str] = None
    input_method: str
    confidence: Optional[float] = None
    user_confirmed: bool
    user_corrected_category: Optional[str] = None
    timestamp: datetime
    created_at: datetime

    class Config:
        from_attributes = True


class FoodClassificationResponse(BaseModel):
    """Response from Gemini Vision food classification."""
    category: str
    glucose_impact: str
    tip_en: str
    tip_hi: str
    confidence: float


class AdminStatusUpdate(BaseModel):
    """Request body for updating user admin status."""
    is_admin: bool


class AdminSuspendUser(BaseModel):
    """Request body for suspending/reactivating a user."""
    suspend: bool
    reason: str = Field(..., min_length=3, max_length=500)


class AdminVerifyDoctor(BaseModel):
    """Request body for verifying a doctor."""
    notes: Optional[str] = None


class AdminRejectDoctor(BaseModel):
    """Request body for rejecting a doctor verification."""
    reason: str = Field(..., min_length=3, max_length=200)
    notes: Optional[str] = None


class AdminCreateUser(BaseModel):
    """Admin creates a patient or doctor account (G6).

    Doctor-role creation is currently blocked at the endpoint layer — the
    schema still accepts the fields so the admin UI can submit them, but
    the endpoint returns 501 until the first-login doctor-consent flow is
    built (see DPDPA fiduciary consent requirements).
    """
    email: EmailStr
    password: str
    full_name: str = Field(..., min_length=2, max_length=100)
    phone_number: str
    role: str = Field(..., pattern="^(patient|doctor)$")
    nmc_number: Optional[str] = Field(None, min_length=5, max_length=20)
    specialty: Optional[str] = None
    clinic_name: Optional[str] = None

    class Config:
        extra = 'forbid'

    @validator('email')
    def normalize_email(cls, v):
        return v.strip().lower()

    @validator('password')
    def validate_password(cls, v):
        return _validate_password_strength(v)

    @validator('full_name')
    def validate_full_name(cls, v):
        stripped = v.strip()
        if len(stripped) < 2:
            raise ValueError('Full name must be at least 2 characters')
        return stripped

    @validator('phone_number')
    def validate_phone_number(cls, v):
        return _validate_phone_number_helper(v)

    @validator('nmc_number', always=True)
    def nmc_required_for_doctor(cls, v, values):
        if values.get('role') == 'doctor' and not v:
            raise ValueError('NMC number is required for doctor accounts')
        if v is not None:
            normalized = v.strip().upper()
            if not _NMC_PATTERN.match(normalized):
                raise ValueError(
                    'NMC number must be 5-10 digits with an optional state council prefix (e.g. BMCR/123456)'
                )
            return normalized
        return v

    @validator('specialty')
    def validate_specialty(cls, v):
        if v is not None and v not in DOCTOR_SPECIALTY_OPTIONS:
            raise ValueError(f'Specialty must be one of: {", ".join(DOCTOR_SPECIALTY_OPTIONS)}')
        return v


# ---------------------------------------------------------------------------
# Doctor Portal schemas (Module F)
# DOCTOR_SPECIALTY_OPTIONS and CONSENT_TYPE_OPTIONS are declared at the top
# of this module so that Admin* schemas (above) can reference them without
# a forward-reference smell.
# ---------------------------------------------------------------------------


class DoctorRegister(BaseModel):
    """Doctor registration — extends normal user registration."""
    email: EmailStr
    password: str
    confirm_password: str
    full_name: str = Field(..., min_length=2, max_length=100)
    phone_number: str = Field(..., min_length=10, max_length=15)
    nmc_number: str = Field(..., min_length=4, max_length=20)
    specialty: Optional[str] = None
    clinic_name: Optional[str] = None
    timezone: str = "Asia/Kolkata"

    @validator('email')
    def normalize_email(cls, v):
        return v.strip().lower()

    @validator('password')
    def validate_password(cls, v):
        return _validate_password_strength(v)

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if 'password' in values and v != values['password']:
            raise ValueError('Passwords do not match')
        return v

    @validator('specialty')
    def validate_specialty(cls, v):
        if v is not None and v not in DOCTOR_SPECIALTY_OPTIONS:
            raise ValueError(f'Specialty must be one of: {", ".join(DOCTOR_SPECIALTY_OPTIONS)}')
        return v


class DoctorProfileResponse(BaseModel):
    """Doctor profile info returned after registration or lookup."""
    user_id: int
    full_name: str
    nmc_number: str
    specialty: Optional[str] = None
    clinic_name: Optional[str] = None
    doctor_code: str
    is_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True


class DoctorCodeLookupResponse(BaseModel):
    """Returned when a patient looks up a doctor code to link."""
    doctor_name: str
    specialty: Optional[str] = None
    clinic_name: Optional[str] = None
    doctor_code: str
    is_verified: bool


class DoctorPatientLinkRequest(BaseModel):
    """Patient requests to link with a doctor."""
    doctor_code: str = Field(..., min_length=4, max_length=8)
    consent_type: str

    @validator('consent_type')
    def validate_consent_type(cls, v):
        if v not in CONSENT_TYPE_OPTIONS:
            raise ValueError(f'consent_type must be one of: {", ".join(CONSENT_TYPE_OPTIONS)}')
        return v


class DoctorPatientLinkResponse(BaseModel):
    """Response after linking patient to doctor."""
    id: int
    doctor_id: int
    doctor_name: str
    profile_id: int
    profile_name: str
    consent_type: str
    is_active: bool
    status: str  # pending_doctor_accept | active | revoked
    created_at: datetime

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Phase 4 — doctor-side accept flow
# ---------------------------------------------------------------------------

class DoctorAcceptRequest(BaseModel):
    """Doctor's NMC attestation when accepting a pending patient link.

    Per NMC 2020 Telemedicine Guidelines § 1.4.1, a Follow-up Consult
    requires that the RMP has examined the patient in-person within the
    last 6 months for the same condition. This schema captures that
    attestation: the doctor declares when the exam happened and what
    was examined.
    """
    examined_on: date = Field(..., description="Date the doctor examined the patient in person")
    examined_for_condition: str = Field(..., min_length=3, max_length=200)

    @validator('examined_on')
    def exam_must_be_recent_and_not_future(cls, v):
        from datetime import date as _date, timedelta as _td
        today = _date.today()
        if v > today:
            raise ValueError('Exam date cannot be in the future')
        if (today - v) > _td(days=183):
            # ~6 months — NMC Follow-up Consult window
            raise ValueError('Exam date must be within the last 6 months')
        return v

    @validator('examined_for_condition')
    def strip_condition(cls, v):
        stripped = v.strip()
        if len(stripped) < 3:
            raise ValueError('Condition must be at least 3 characters')
        return stripped


class DoctorDeclineRequest(BaseModel):
    """Doctor declines a pending patient link request."""
    reason: Optional[str] = Field(None, max_length=500)


class PendingLinkRequest(BaseModel):
    """Row returned by GET /api/doctor/patients/pending."""
    link_id: int
    profile_id: int
    profile_name: str
    profile_age: Optional[int] = None
    profile_gender: Optional[str] = None
    consent_type: str
    consent_granted_at: datetime
    doctor_code_used: Optional[str] = None

    class Config:
        from_attributes = True


class DoctorNoteCreate(BaseModel):
    """Doctor creates a clinical note on a reading."""
    note_text: str = Field(..., min_length=1, max_length=2000)
    reading_id: Optional[int] = None          # null = general note on the profile
    is_shared_with_patient: bool = False


class DoctorNoteResponse(BaseModel):
    id: int
    doctor_id: int
    profile_id: int
    reading_id: Optional[int] = None
    note_text: str
    is_shared_with_patient: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TriagePatientCard(BaseModel):
    """Patient card on the doctor's triage dashboard."""
    profile_id: int
    profile_name: str
    age: Optional[int] = None
    gender: Optional[str] = None
    medical_conditions: Optional[List[str]] = None
    triage_status: str                         # critical / attention / stable / no_data
    triage_reason: Optional[str] = None        # human-readable reason for status
    last_reading_value: Optional[str] = None
    last_reading_type: Optional[str] = None
    last_reading_at: Optional[datetime] = None
    compliance_7d: int = 0
    trend_direction: Optional[str] = None
    link_id: int

    class Config:
        from_attributes = True
