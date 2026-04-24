from sqlalchemy import Column, Integer, String, Float, Text, DateTime, Date, Boolean, ForeignKey, UniqueConstraint, Index, Enum, JSON
from sqlalchemy.sql import func
from database import Base
from encryption_service import (
    encrypt_pii, decrypt_pii,
    encrypt_pii_list, decrypt_pii_list,
    hash_email, hash_phone, hash_nmc,
)
import enum
from typing import Optional, List


def _enc_str(v: Optional[str]) -> Optional[str]:
    """Encrypt a string; empty → None so DB column stays clean."""
    if v is None or v == "":
        return None
    return encrypt_pii(v)


def _enc_int(v: Optional[int]) -> Optional[str]:
    return None if v is None else encrypt_pii(str(v))


def _dec_int(token: Optional[str]) -> Optional[int]:
    plain = decrypt_pii(token)
    if plain is None:
        return None
    try:
        return int(plain)
    except (TypeError, ValueError):
        return None


def _enc_float(v: Optional[float]) -> Optional[str]:
    return None if v is None else encrypt_pii(str(v))


def _dec_float(token: Optional[str]) -> Optional[float]:
    plain = decrypt_pii(token)
    if plain is None:
        return None
    try:
        return float(plain)
    except (TypeError, ValueError):
        return None


class UserRole(str, enum.Enum):
    """User role — determines which dashboard and access level."""
    patient = "patient"
    doctor = "doctor"
    admin = "admin"


class User(Base):
    """Auth identity only. Health data lives in Profile.

    PII (email, full_name, phone_number) is encrypted at rest under
    PII_ENCRYPTION_KEY. Lookups for login (email) and phone-OTP use HMAC
    blind-indexes (email_hash, phone_hash). `password_hash` stays as-is
    — it is already a one-way bcrypt/argon hash, re-encrypting would
    break login.
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    # PII — encrypted. email/phone nullable to support phone-only or email-only accounts.
    email_enc = Column(Text, nullable=True)                                   # AES-256-GCM(email)
    email_hash = Column(String(64), unique=True, index=True, nullable=True)   # HMAC-SHA256(lower(trim(email))) — multiple NULLs allowed
    full_name_enc = Column(Text, nullable=False)                              # AES-256-GCM(full_name)
    phone_number_enc = Column(Text, nullable=True)                            # AES-256-GCM(phone_number) — may be empty for email-only accounts
    phone_hash = Column(String(64), index=True, nullable=True)                # HMAC-SHA256(E.164(phone)) — nullable when no phone

    password_hash = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)

    # Transparent plaintext accessors. Existing callers continue to use
    # `user.email = ...` / `user.email` and we handle encrypt/decrypt + hash
    # internally. Queries must use User.email_hash / User.phone_hash directly.
    _PLAINTEXT_KWARGS = ("email", "full_name", "phone_number")

    def __init__(self, **kwargs):
        plaintexts = {k: kwargs.pop(k) for k in list(kwargs) if k in self._PLAINTEXT_KWARGS}
        super().__init__(**kwargs)
        for k, v in plaintexts.items():
            setattr(self, k, v)

    @property
    def email(self) -> Optional[str]:
        return decrypt_pii(self.email_enc)

    @email.setter
    def email(self, value: Optional[str]) -> None:
        # Empty / None → clear both. Supports phone-only accounts where the
        # backend generated a synthetic email and the user has no real one yet.
        if value is None or value == "":
            self.email_enc = None
            self.email_hash = None
            return
        self.email_enc = encrypt_pii(value)
        self.email_hash = hash_email(value)

    @property
    def full_name(self) -> Optional[str]:
        return decrypt_pii(self.full_name_enc)

    @full_name.setter
    def full_name(self, value: Optional[str]) -> None:
        enc = _enc_str(value)
        if enc is None:
            raise ValueError("User.full_name cannot be empty")
        self.full_name_enc = enc

    @property
    def phone_number(self) -> Optional[str]:
        return decrypt_pii(self.phone_number_enc)

    @phone_number.setter
    def phone_number(self, value: Optional[str]) -> None:
        # Empty / None → clear both columns. Alert dispatch flows treat
        # "no phone" as a valid user state (alert_service skips whatsapp/sms).
        if value is None or value == "":
            self.phone_number_enc = None
            self.phone_hash = None
            return
        self.phone_number_enc = encrypt_pii(value)
        self.phone_hash = hash_phone(value)

    consent_timestamp = Column(DateTime(timezone=True), nullable=True)
    consent_app_version = Column(String, nullable=True)
    consent_language = Column(String, nullable=True)
    ai_consent = Column(Boolean, default=False)
    ai_consent_timestamp = Column(DateTime(timezone=True), nullable=True)
    is_admin = Column(Boolean, default=False, server_default="false")
    role = Column(Enum(UserRole), default=UserRole.patient, server_default="patient", nullable=False)
    timezone = Column(String, default="UTC", server_default="UTC", nullable=False)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    email_verified = Column(Boolean, default=False, server_default="false")
    email_verified_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class Profile(Base):
    """Health identity for a person. One user can own/access many profiles.

    All PII and health-condition free-text is encrypted at rest under
    PII_ENCRYPTION_KEY. Quasi-identifiers (age, gender, blood group, etc.)
    are also encrypted per E17 scope — DPDPA treats them as personal data
    when combined with health readings. Weight stays plaintext here because
    HealthReading is the source of truth for encrypted weight history.
    """
    __tablename__ = "profiles"

    id = Column(Integer, primary_key=True, index=True)

    # Core identity (encrypted)
    name_enc = Column(Text, nullable=False)                           # "My Health", "Papa", "Mummy"
    relationship_enc = Column(Text, nullable=True)                    # "myself", "father", ...
    gender_enc = Column(Text, nullable=True)                          # Male / Female / Other
    age_enc = Column(Text, nullable=True)                             # int as encrypted string
    height_enc = Column(Text, nullable=True)                          # float cm, encrypted string
    blood_group_enc = Column(Text, nullable=True)

    # Weight remains a plain float — current weight snapshot; history lives in HealthReading.weight_value_enc
    weight = Column(Float, nullable=True)                             # kg

    # Health conditions (encrypted)
    medical_conditions_enc = Column(Text, nullable=True)              # JSON-list-of-strings under PII key
    other_medical_condition_enc = Column(Text, nullable=True)
    current_medications_enc = Column(Text, nullable=True)

    # Legacy free-text doctor fields (encrypted). New code should use DoctorPatientLink.
    doctor_name_enc = Column(Text, nullable=True)
    doctor_specialty_enc = Column(Text, nullable=True)
    doctor_whatsapp_enc = Column(Text, nullable=True)

    # Profile's own phone (encrypted + hash for lookup)
    phone_number_enc = Column(Text, nullable=True)
    phone_hash = Column(String(64), index=True, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    _PLAINTEXT_KWARGS = (
        "name", "relationship", "gender", "age", "height", "blood_group",
        "medical_conditions", "other_medical_condition", "current_medications",
        "doctor_name", "doctor_specialty", "doctor_whatsapp", "phone_number",
    )

    def __init__(self, **kwargs):
        plaintexts = {k: kwargs.pop(k) for k in list(kwargs) if k in self._PLAINTEXT_KWARGS}
        super().__init__(**kwargs)
        for k, v in plaintexts.items():
            setattr(self, k, v)

    # --- name (required) ---
    @property
    def name(self) -> Optional[str]:
        return decrypt_pii(self.name_enc)

    @name.setter
    def name(self, value: Optional[str]) -> None:
        enc = _enc_str(value)
        if enc is None:
            raise ValueError("Profile.name cannot be empty")
        self.name_enc = enc

    # --- optional string fields ---
    @property
    def relationship(self) -> Optional[str]:
        return decrypt_pii(self.relationship_enc)

    @relationship.setter
    def relationship(self, value: Optional[str]) -> None:
        self.relationship_enc = _enc_str(value)

    @property
    def gender(self) -> Optional[str]:
        return decrypt_pii(self.gender_enc)

    @gender.setter
    def gender(self, value: Optional[str]) -> None:
        self.gender_enc = _enc_str(value)

    @property
    def blood_group(self) -> Optional[str]:
        return decrypt_pii(self.blood_group_enc)

    @blood_group.setter
    def blood_group(self, value: Optional[str]) -> None:
        self.blood_group_enc = _enc_str(value)

    @property
    def other_medical_condition(self) -> Optional[str]:
        return decrypt_pii(self.other_medical_condition_enc)

    @other_medical_condition.setter
    def other_medical_condition(self, value: Optional[str]) -> None:
        self.other_medical_condition_enc = _enc_str(value)

    @property
    def current_medications(self) -> Optional[str]:
        return decrypt_pii(self.current_medications_enc)

    @current_medications.setter
    def current_medications(self, value: Optional[str]) -> None:
        self.current_medications_enc = _enc_str(value)

    @property
    def doctor_name(self) -> Optional[str]:
        return decrypt_pii(self.doctor_name_enc)

    @doctor_name.setter
    def doctor_name(self, value: Optional[str]) -> None:
        self.doctor_name_enc = _enc_str(value)

    @property
    def doctor_specialty(self) -> Optional[str]:
        return decrypt_pii(self.doctor_specialty_enc)

    @doctor_specialty.setter
    def doctor_specialty(self, value: Optional[str]) -> None:
        self.doctor_specialty_enc = _enc_str(value)

    @property
    def doctor_whatsapp(self) -> Optional[str]:
        return decrypt_pii(self.doctor_whatsapp_enc)

    @doctor_whatsapp.setter
    def doctor_whatsapp(self, value: Optional[str]) -> None:
        self.doctor_whatsapp_enc = _enc_str(value)

    # --- numeric fields ---
    @property
    def age(self) -> Optional[int]:
        return _dec_int(self.age_enc)

    @age.setter
    def age(self, value: Optional[int]) -> None:
        self.age_enc = _enc_int(value)

    @property
    def height(self) -> Optional[float]:
        return _dec_float(self.height_enc)

    @height.setter
    def height(self, value: Optional[float]) -> None:
        self.height_enc = _enc_float(value)

    # --- list field ---
    @property
    def medical_conditions(self) -> Optional[List[str]]:
        return decrypt_pii_list(self.medical_conditions_enc)

    @medical_conditions.setter
    def medical_conditions(self, value: Optional[List[str]]) -> None:
        # None stays None; empty list still encrypts as "[]"
        self.medical_conditions_enc = encrypt_pii_list(value) if value is not None else None

    # --- phone + hash ---
    @property
    def phone_number(self) -> Optional[str]:
        return decrypt_pii(self.phone_number_enc)

    @phone_number.setter
    def phone_number(self, value: Optional[str]) -> None:
        if value is None or value == "":
            self.phone_number_enc = None
            self.phone_hash = None
            return
        self.phone_number_enc = encrypt_pii(value)
        self.phone_hash = hash_phone(value)


class ProfileAccess(Base):
    """Junction table — which users can access which profiles and at what level."""
    __tablename__ = "profile_access"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    access_level = Column(String, nullable=False)                # "owner" or "viewer"
    relationship = Column(String, nullable=True)                 # "father", "mother", "spouse", etc.
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("user_id", "profile_id", name="uq_user_profile"),
    )


class ProfileInvite(Base):
    """Pending invite for a user to gain viewer access to a profile.

    The invitee's email is encrypted (invited_email_enc) with a blind-index
    (invited_email_hash) so the accept flow can still dedupe and look up
    the pending row by email without decrypting the whole table.
    """
    __tablename__ = "profile_invites"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    invited_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    invited_email_enc = Column(Text, nullable=False)
    invited_email_hash = Column(String(64), index=True, nullable=False)
    invited_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    relationship_enc = Column(Text, nullable=True)
    access_level = Column(String, nullable=False, default="viewer", server_default="viewer")  # "viewer" or "editor"
    status = Column(String, nullable=False, default="pending")   # "pending", "accepted", "rejected"
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)

    __table_args__ = (
        # Partial unique index — only prevent duplicate PENDING invites.
        # Accepted/rejected invites should not block re-inviting. Dedupe now
        # uses the HMAC hash instead of plaintext email.
        Index("uq_profile_invite_email_pending", "profile_id", "invited_email_hash",
              unique=True, postgresql_where="status = 'pending'"),
    )

    _PLAINTEXT_KWARGS = ("invited_email", "relationship")

    def __init__(self, **kwargs):
        plaintexts = {k: kwargs.pop(k) for k in list(kwargs) if k in self._PLAINTEXT_KWARGS}
        super().__init__(**kwargs)
        for k, v in plaintexts.items():
            setattr(self, k, v)

    @property
    def invited_email(self) -> Optional[str]:
        return decrypt_pii(self.invited_email_enc)

    @invited_email.setter
    def invited_email(self, value: Optional[str]) -> None:
        enc = _enc_str(value)
        if enc is None:
            raise ValueError("ProfileInvite.invited_email cannot be empty")
        self.invited_email_enc = enc
        h = hash_email(value)
        if h is None:
            raise ValueError("ProfileInvite.invited_email: PII_ENCRYPTION_KEY not configured")
        self.invited_email_hash = h

    @property
    def relationship(self) -> Optional[str]:
        return decrypt_pii(self.relationship_enc)

    @relationship.setter
    def relationship(self, value: Optional[str]) -> None:
        self.relationship_enc = _enc_str(value)


class HealthReading(Base):
    """Health readings (glucose, blood pressure, SpO2, steps). Belongs to a profile, logged by a user."""
    __tablename__ = "health_readings"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    logged_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    # Reading type: 'glucose', 'blood_pressure', 'spo2', or 'steps'
    reading_type = Column(String, nullable=False)

    # Glucose specific fields
    glucose_value = Column(Float, nullable=True)                 # mg/dL
    glucose_unit = Column(String, nullable=True)
    sample_type = Column(String, nullable=True)

    # BP specific fields
    systolic = Column(Float, nullable=True)                      # mmHg
    diastolic = Column(Float, nullable=True)                     # mmHg
    mean_arterial_pressure = Column(Float, nullable=True)
    pulse_rate = Column(Float, nullable=True)                    # bpm
    bp_unit = Column(String, nullable=True)
    bp_status = Column(String, nullable=True)

    # SpO2 fields
    spo2_value = Column(Float, nullable=True)                    # percentage (0-100)
    spo2_unit = Column(String, nullable=True)                    # '%'
    spo2_enc = Column(Text, nullable=True)                       # AES-256-GCM

    # Steps fields
    steps_count = Column(Integer, nullable=True)
    steps_goal = Column(Integer, nullable=True)                  # daily target

    # Weight fields
    weight_value = Column(Float, nullable=True)                  # kg
    weight_unit = Column(String, nullable=True)                  # 'kg'

    # Common fields
    value_numeric = Column(Float, nullable=False)
    unit_display = Column(String, nullable=False)
    status_flag = Column(String, nullable=True)
    notes = Column(Text, nullable=True)

    # AES-256-GCM encrypted copies of sensitive health values (SPDI compliance)
    glucose_value_enc = Column(Text, nullable=True)
    systolic_enc = Column(Text, nullable=True)
    diastolic_enc = Column(Text, nullable=True)
    pulse_rate_enc = Column(Text, nullable=True)
    weight_value_enc = Column(Text, nullable=True)
    notes_enc = Column(Text, nullable=True)

    reading_timestamp = Column(DateTime, nullable=False)
    seq = Column(Integer, nullable=True)                     # Device sequence number for deduplication
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    __table_args__ = (
        Index("ix_readings_profile_time", "profile_id", "reading_timestamp"),
    )


class CriticalAlertLog(Base):
    """Audit log for every critical-value alert dispatch attempt.

    One row per (recipient, channel) per dispatch call. Does not store
    the message body to minimize PHI exposure — only who was notified,
    via which channel, and whether delivery succeeded. See legal doc
    section 11.3 / Q11.9 for retention analysis.
    """
    __tablename__ = "critical_alert_logs"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    reading_id = Column(Integer, ForeignKey("health_readings.id", ondelete="SET NULL"), nullable=True)
    recipient_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    channel = Column(String, nullable=False)              # "email" | "whatsapp" | "sms"
    status = Column(String, nullable=False)               # "sent" | "failed" | "skipped"
    error = Column(Text, nullable=True)                    # populated when status="failed"
    severity = Column(String, nullable=False)              # "CRITICAL" | "HIGH - STAGE 2"
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    __table_args__ = (
        Index("ix_critical_alerts_profile_time", "profile_id", "created_at"),
    )


class AiInsightLog(Base):
    """Audit log for every AI-generated health insight."""
    __tablename__ = "ai_insight_logs"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    model_used = Column(String, nullable=False)          # "gemini-2.5-flash", "deepseek-chat", "rule-based"
    prompt_summary = Column(Text, nullable=True)          # compact patient summary sent to AI
    response_text = Column(Text, nullable=False)          # the full AI response
    fallback_reason = Column(Text, nullable=True)         # null if primary succeeded, error message otherwise
    tokens_used = Column(Integer, nullable=True)          # total tokens (input + output) if available
    latency_ms = Column(Integer, nullable=True)           # response time in milliseconds
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ChatMessage(Base):
    """Individual chat message exchange between user and AI."""
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    user_message = Column(Text, nullable=False)
    ai_response = Column(Text, nullable=False)
    model_used = Column(String, nullable=True)
    tokens_used = Column(Integer, nullable=True)
    latency_ms = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_chat_profile_time", "profile_id", "created_at"),
    )


class ChatContextProfile(Base):
    """Rolling AI-generated summary of all past conversations for a profile."""
    __tablename__ = "chat_context_profiles"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, unique=True)
    summary = Column(Text, nullable=False, default="")
    message_count = Column(Integer, nullable=False, default=0)
    last_updated = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class TrendSummaryCache(Base):
    """Cached AI-generated trend summary per profile/period/day."""
    __tablename__ = "trend_summary_cache"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    period_days = Column(Integer, nullable=False)
    cache_date = Column(Date, nullable=False)
    summary_text = Column(Text, nullable=False)
    model_used = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint('profile_id', 'period_days', 'cache_date', name='uq_trend_summary'),
        Index("ix_trend_cache_lookup", "profile_id", "period_days", "cache_date"),
    )


class MealLog(Base):
    """Food photo classification — carb level detection for glucose correlation."""
    __tablename__ = "meal_logs"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    logged_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    timestamp = Column(DateTime(timezone=True), nullable=False)

    # Classification (NO food naming — only carb level)
    category = Column(String, nullable=False)          # HIGH_CARB, MODERATE_CARB, LOW_CARB, HIGH_PROTEIN, SWEETS
    glucose_impact = Column(String, nullable=False)    # HIGH, MODERATE, LOW, VERY_HIGH

    # Health tip from Gemini
    tip_en = Column(Text, nullable=True)
    tip_hi = Column(Text, nullable=True)

    # Meal context
    meal_type = Column(String, nullable=False)         # BREAKFAST, LUNCH, DINNER, SNACK

    # Photo storage
    photo_path = Column(String, nullable=True)         # Server filesystem path

    # Metadata
    input_method = Column(String, nullable=False)      # PHOTO_GEMINI, QUICK_SELECT
    confidence = Column(Float, nullable=True)          # Gemini confidence score
    user_confirmed = Column(Boolean, default=False)
    user_corrected_category = Column(String, nullable=True)  # If user overrode Gemini

    # Nutrition data (from Gemini Vision analysis)
    total_calories = Column(Float, nullable=True)
    total_carbs_g = Column(Float, nullable=True)
    total_protein_g = Column(Float, nullable=True)
    total_fat_g = Column(Float, nullable=True)
    total_fiber_g = Column(Float, nullable=True)
    meal_score = Column(Integer, nullable=True)        # 1-10 health rating

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_meals_profile_time", "profile_id", "timestamp"),
    )


from encryption_service import hash_otp as _hash_otp


def _otp_email_property(self) -> Optional[str]:
    return decrypt_pii(self.email_enc)


def _otp_phone_property(self) -> Optional[str]:
    return decrypt_pii(self.phone_number_enc)


def _otp_init(self, **kwargs):
    """Shared __init__ for OTP tables that intercepts plaintext email/phone/otp kwargs."""
    email = kwargs.pop("email", None)
    phone_number = kwargs.pop("phone_number", None)
    otp = kwargs.pop("otp", None)
    super(type(self), self).__init__(**kwargs)
    if email is not None:
        enc = encrypt_pii(email)
        h = hash_email(email)
        if enc is None or h is None:
            raise ValueError(f"{type(self).__name__}: PII_ENCRYPTION_KEY not configured")
        self.email_enc = enc
        self.email_hash = h
    if phone_number is not None:
        enc = encrypt_pii(phone_number)
        h = hash_phone(phone_number)
        if enc is None or h is None:
            raise ValueError(f"{type(self).__name__}: PII_ENCRYPTION_KEY not configured")
        self.phone_number_enc = enc
        self.phone_hash = h
    if otp is not None:
        oh = _hash_otp(otp)
        if oh is None:
            raise ValueError(f"{type(self).__name__}: cannot hash empty OTP")
        self.otp_hash = oh


class PasswordResetOTP(Base):
    """Password reset OTP. Email encrypted + hash for lookup; OTP is HMAC-hashed."""
    __tablename__ = "password_reset_otps"

    id = Column(Integer, primary_key=True, index=True)
    email_enc = Column(Text, nullable=False)
    email_hash = Column(String(64), index=True, nullable=False)
    otp_hash = Column(String(64), nullable=False)                  # HMAC-SHA256(otp)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False)

    __init__ = _otp_init
    email = property(_otp_email_property)


class EmailVerificationOTP(Base):
    """Email verification OTP. Email encrypted + hash for lookup; OTP is HMAC-hashed."""
    __tablename__ = "email_verification_otps"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    email_enc = Column(Text, nullable=False)
    email_hash = Column(String(64), index=True, nullable=False)
    otp_hash = Column(String(64), nullable=False)                  # HMAC-SHA256(otp)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False, server_default="false")

    __init__ = _otp_init
    email = property(_otp_email_property)


class PhoneOTP(Base):
    """OTP for phone verification. Phone encrypted + hash for lookup; OTP is HMAC-hashed."""
    __tablename__ = "phone_otps"

    id = Column(Integer, primary_key=True, index=True)
    phone_number_enc = Column(Text, nullable=False)
    phone_hash = Column(String(64), index=True, nullable=False)
    otp_hash = Column(String(64), nullable=False)                  # HMAC-SHA256(otp)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False, server_default="false")

    __init__ = _otp_init
    phone_number = property(_otp_phone_property)


# ---------------------------------------------------------------------------
# Doctor Portal models (Module E)
# ---------------------------------------------------------------------------

class DoctorProfile(Base):
    """Doctor-specific profile data. Linked 1:1 to a User with role=doctor.

    PII (NMC number + contact numbers) is encrypted at rest under
    PII_ENCRYPTION_KEY. Uniqueness of NMC is enforced via `nmc_hash`.
    `specialty`, `clinic_name`, `doctor_code` are business/public data —
    not PII, kept plaintext. Doctor's full name lives on User.full_name_enc.
    """
    __tablename__ = "doctor_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)

    # NMC / State Medical Council registration — PII under DPDPA. Encrypted + blind-index for uniqueness.
    nmc_number_enc = Column(Text, nullable=False)
    nmc_hash = Column(String(64), unique=True, index=True, nullable=False)

    # Doctor contact numbers (new) — needed for Priority Call / WhatsApp flows (see tracker line 213)
    phone_number_enc = Column(Text, nullable=True)
    phone_hash = Column(String(64), index=True, nullable=True)
    whatsapp_number_enc = Column(Text, nullable=True)
    whatsapp_hash = Column(String(64), index=True, nullable=True)

    specialty = Column(String, nullable=True)                       # "General Physician", "Endocrinologist", etc.
    clinic_name = Column(String, nullable=True)
    doctor_code = Column(String(8), unique=True, nullable=False, index=True)  # e.g. "DRRAJ52" — patients use this to link
    is_verified = Column(Boolean, default=False)                    # Admin verifies NMC number
    verified_at = Column(DateTime(timezone=True), nullable=True)
    verified_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    _PLAINTEXT_KWARGS = ("nmc_number", "phone_number", "whatsapp_number")

    def __init__(self, **kwargs):
        plaintexts = {k: kwargs.pop(k) for k in list(kwargs) if k in self._PLAINTEXT_KWARGS}
        super().__init__(**kwargs)
        for k, v in plaintexts.items():
            setattr(self, k, v)

    @property
    def nmc_number(self) -> Optional[str]:
        return decrypt_pii(self.nmc_number_enc)

    @nmc_number.setter
    def nmc_number(self, value: Optional[str]) -> None:
        enc = _enc_str(value)
        if enc is None:
            raise ValueError("DoctorProfile.nmc_number cannot be empty")
        self.nmc_number_enc = enc
        h = hash_nmc(value)
        if h is None:
            raise ValueError("DoctorProfile.nmc_number: PII_ENCRYPTION_KEY not configured")
        self.nmc_hash = h

    @property
    def phone_number(self) -> Optional[str]:
        return decrypt_pii(self.phone_number_enc)

    @phone_number.setter
    def phone_number(self, value: Optional[str]) -> None:
        if value is None or value == "":
            self.phone_number_enc = None
            self.phone_hash = None
            return
        self.phone_number_enc = encrypt_pii(value)
        self.phone_hash = hash_phone(value)

    @property
    def whatsapp_number(self) -> Optional[str]:
        return decrypt_pii(self.whatsapp_number_enc)

    @whatsapp_number.setter
    def whatsapp_number(self, value: Optional[str]) -> None:
        if value is None or value == "":
            self.whatsapp_number_enc = None
            self.whatsapp_hash = None
            return
        self.whatsapp_number_enc = encrypt_pii(value)
        self.whatsapp_hash = hash_phone(value)


class DoctorPatientLink(Base):
    """Consent-based link between a doctor and a patient profile.

    Lifecycle (NMC 2020 Telemedicine Guidelines § 1.4.1, § 3.3):
      1. Patient creates the link via POST /api/doctor/link/{profile_id}.
         Row is inserted with `status='pending_doctor_accept'` and
         `is_active=False` — the doctor CANNOT see patient data yet.
      2. Doctor reviews the pending request via GET /api/doctor/patients/pending
         and either accepts (with a required `examined_on` date and
         `examined_for_condition` attestation) or declines.
      3. On accept, `status='active'`, `is_active=True`, `accepted_at` and
         `accepted_by_doctor_id` stamped. Only now does the doctor get
         read access to the patient's readings.
      4. Either side can transition `active → revoked` at any time via
         DELETE /api/doctor/link/{profile_id}.

    `is_active` is kept for backwards compatibility with pre-Phase-4
    code paths (existing queries across the codebase). Going forward,
    `status` is the source of truth — `is_active` is always
    `status == 'active'`.
    """
    __tablename__ = "doctor_patient_links"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)

    # Consent (patient side)
    consent_granted_at = Column(DateTime(timezone=True), nullable=False)
    consent_granted_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)  # may be family member
    consent_type = Column(String, nullable=False)                   # "in_person_exam" or "video_consult"

    # Lifecycle state — see class docstring.
    status = Column(String, nullable=False, default="pending_doctor_accept", server_default="pending_doctor_accept")
    is_active = Column(Boolean, default=False)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
    revoke_reason = Column(String, nullable=True)

    # Doctor attestation (required at accept time; NMC First Consult evidence)
    accepted_at = Column(DateTime(timezone=True), nullable=True)
    accepted_by_doctor_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    examined_on = Column(Date, nullable=True)                       # doctor's declared exam date
    examined_for_condition = Column(String, nullable=True)          # what the exam covered

    # Doctor code used to establish link
    doctor_code_used = Column(String(8), nullable=True)

    # Cached triage data (updated async on new reading)
    triage_status = Column(String, default="no_data")               # critical / attention / stable / no_data
    triage_updated_at = Column(DateTime(timezone=True), nullable=True)
    last_reading_value = Column(String, nullable=True)              # "175/110" or "245"
    last_reading_type = Column(String, nullable=True)               # "blood_pressure" or "glucose"
    last_reading_at = Column(DateTime(timezone=True), nullable=True)
    compliance_7d = Column(Integer, default=0)                      # readings count in last 7 days
    trend_direction = Column(String, nullable=True)                 # "improving", "worsening", "stable"

    # Primary doctor flag — only one active link per profile can be primary.
    # Tracker line 200: clinical risk if the dashboard routes "message my doctor"
    # to the wrong active link. Partial unique index enforces it at DB level.
    is_primary = Column(Boolean, nullable=False, default=False, server_default="false")

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("doctor_id", "profile_id", name="uq_doctor_patient"),
        Index(
            "uq_primary_doctor_per_profile",
            "profile_id",
            unique=True,
            postgresql_where="is_primary = true AND status = 'active'",
        ),
    )


class DoctorNote(Base):
    """Private clinical note by a doctor on a specific reading."""
    __tablename__ = "doctor_notes"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    reading_id = Column(Integer, ForeignKey("health_readings.id", ondelete="CASCADE"), nullable=True)  # null = general note
    note_text = Column(Text, nullable=False)
    is_shared_with_patient = Column(Boolean, default=False)         # doctor explicitly shares
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class DoctorAccessLog(Base):
    """Audit trail — every time a doctor accesses patient data. DPDPA requirement."""
    __tablename__ = "doctor_access_log"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=True, index=True)  # null for list views
    action = Column(String, nullable=False)                         # "viewed_readings", "added_note", "sent_whatsapp", etc.
    endpoint = Column(String, nullable=True)                        # API endpoint accessed
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_doctor_access_log_doctor_time", "doctor_id", "created_at"),
    )


# ---------------------------------------------------------------------------
# Admin Audit Log (CERT-In 180-day requirement, DPDPA S8(5))
# ---------------------------------------------------------------------------

class AdminAuditLog(Base):
    """Immutable audit trail for every admin action. CERT-In requires 180-day retention."""
    __tablename__ = "admin_audit_log"

    id = Column(Integer, primary_key=True, index=True)
    admin_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    action_type = Column(String(50), nullable=False)                # VIEW_USER_DETAIL, SUSPEND_USER, VERIFY_DOCTOR, etc.
    target_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    target_profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="SET NULL"), nullable=True)
    details = Column(Text, nullable=True)                           # JSON-encoded extra context (reason, old/new values)
    outcome = Column(String(20), nullable=False, default="SUCCESS") # SUCCESS, DENIED, ERROR
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_admin_audit_admin", "admin_user_id"),
        Index("ix_admin_audit_target", "target_user_id"),
        Index("ix_admin_audit_time", "created_at"),
    )

class WhatsAppMessageStatus(str, enum.Enum):
    QUEUED = "queued"
    SENT = "sent"
    DELIVERED = "delivered"
    FAILED = "failed"

class ReportTriggerType(str, enum.Enum):
    SCHEDULED = "scheduled"
    MANUAL = "manual"

class ReportGenerationStatus(str, enum.Enum):
    SUCCESS = "success"
    PARTIAL = "partial"
    FAILED = "failed"

class ReportGenerationLog(Base):
    """Log for the data aggregation phase of a report."""
    __tablename__ = "report_generation_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    trigger_type = Column(Enum(ReportTriggerType), nullable=False)
    report_date = Column(Date, nullable=False, default=func.current_date())
    generated_at = Column(DateTime(timezone=True), server_default=func.now())

    members_requested = Column(JSON, nullable=False)    # List of profile IDs expected
    members_with_data = Column(JSON, nullable=False)     # List of profile IDs found with data
    members_skipped = Column(JSON, nullable=True)       # List of profile IDs with no data
    
    status = Column(Enum(ReportGenerationStatus), nullable=False)
    error_message = Column(Text, nullable=True)

class WhatsAppMessageLog(Base):
    """Log for the actual delivery phase of a WhatsApp message."""
    __tablename__ = "whatsapp_message_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    phone_number = Column(String, nullable=False)
    
    trigger_type = Column(Enum(ReportTriggerType), nullable=False)
    report_date = Column(Date, nullable=False)
    sent_at = Column(DateTime(timezone=True), server_default=func.now())
    
    member_ids_included = Column(JSON, nullable=False)
    reading_ids_included = Column(JSON, nullable=True)
    
    status = Column(Enum(WhatsAppMessageStatus), nullable=False, default=WhatsAppMessageStatus.QUEUED)
    twilio_sid = Column(String, nullable=True, index=True)
    error_message = Column(Text, nullable=True)
    message_snapshot = Column(Text, nullable=True)


# ---------------------------------------------------------------------------
# WhatsApp Inbound — Session State + Audit Log
# ---------------------------------------------------------------------------

class WhatsAppSession(Base):
    """Short-lived (TTL ~10 min) conversation state for inbound WhatsApp photo flow.

    When a user sends a photo and has multiple profiles, we store the
    extracted reading here while we wait for them to reply with a profile
    number. Expired rows are safe to delete by a periodic cleanup job or
    left until next read (expires_at check is done in code).
    """
    __tablename__ = "whatsapp_sessions"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String, nullable=False, index=True)
    state = Column(String, nullable=False)              # 'awaiting_profile'
    pending_reading_json = Column(JSON, nullable=False) # extracted reading data dict
    profile_choices_json = Column(JSON, nullable=False) # [{id, name, relationship}, ...]
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)

    __table_args__ = (
        Index("ix_wa_session_phone", "phone_number"),
    )


class WhatsAppInboundLog(Base):
    """Audit trail for every inbound WhatsApp message (CERT-In 180-day / DPDPA S8(5)).

    One row per inbound message — whether it was a photo, a profile
    selection reply, or an unrecognized message. Does not store the image
    itself, only metadata about what was detected and what action was taken.
    """
    __tablename__ = "whatsapp_inbound_logs"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String, nullable=False)
    message_sid = Column(String, nullable=True)         # Twilio MessageSid
    message_type = Column(String, nullable=False)       # 'image' | 'text'
    ai_detected_type = Column(String, nullable=True)    # 'glucose' | 'blood_pressure' | 'weight' | 'spo2' | None
    profile_id_saved = Column(Integer, ForeignKey("profiles.id", ondelete="SET NULL"), nullable=True)
    reading_id_saved = Column(Integer, ForeignKey("health_readings.id", ondelete="SET NULL"), nullable=True)
    # outcome options: 'reading_saved' | 'awaiting_profile' | 'user_not_found' | 'scan_failed' | 'expired_session' | 'invalid_reply'
    outcome = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    __table_args__ = (
        Index("ix_wa_inbound_phone_time", "phone_number", "created_at"),
    )
