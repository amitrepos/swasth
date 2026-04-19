from sqlalchemy import Column, Integer, String, Float, Text, ARRAY, DateTime, Date, Boolean, ForeignKey, UniqueConstraint, Index, Enum, JSON
from sqlalchemy.sql import func
from database import Base
import enum


class UserRole(str, enum.Enum):
    """User role — determines which dashboard and access level."""
    patient = "patient"
    doctor = "doctor"
    admin = "admin"


class User(Base):
    """Auth identity only. Health data lives in Profile."""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    full_name = Column(String, nullable=False)
    phone_number = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    consent_timestamp = Column(DateTime(timezone=True), nullable=True)
    consent_app_version = Column(String, nullable=True)
    consent_language = Column(String, nullable=True)
    ai_consent = Column(Boolean, default=False)
    ai_consent_timestamp = Column(DateTime(timezone=True), nullable=True)
    is_admin = Column(Boolean, default=False)
    role = Column(Enum(UserRole), default=UserRole.patient, nullable=False)
    timezone = Column(String, default="UTC", server_default="UTC", nullable=False)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    email_verified = Column(Boolean, default=False)
    email_verified_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class Profile(Base):
    """Health identity for a person. One user can own/access many profiles."""
    __tablename__ = "profiles"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)                        # "My Health", "Papa", "Mummy"
    relationship = Column(String, nullable=True)                 # "myself", "father", "mother", etc.
    age = Column(Integer, nullable=True)
    gender = Column(String, nullable=True)                       # Male / Female / Other
    height = Column(Float, nullable=True)                        # cm
    weight = Column(Float, nullable=True)                        # kg
    blood_group = Column(String, nullable=True)
    medical_conditions = Column(ARRAY(String), nullable=True)
    other_medical_condition = Column(Text, nullable=True)
    current_medications = Column(Text, nullable=True)
    doctor_name = Column(String, nullable=True)
    doctor_specialty = Column(String, nullable=True)
    doctor_whatsapp = Column(String, nullable=True)             # full number e.g. +917001234567
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


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
    """Pending invite for a user to gain viewer access to a profile."""
    __tablename__ = "profile_invites"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    invited_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    invited_email = Column(String, nullable=False, index=True)
    invited_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    relationship = Column(String, nullable=True)                 # "father", "mother", etc.
    access_level = Column(String, nullable=False, default="viewer", server_default="viewer")  # "viewer" or "editor"
    status = Column(String, nullable=False, default="pending")   # "pending", "accepted", "rejected"
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)

    __table_args__ = (
        # Partial unique index — only prevent duplicate PENDING invites.
        # Accepted/rejected invites should not block re-inviting.
        Index("uq_profile_invite_email_pending", "profile_id", "invited_email",
              unique=True, postgresql_where="status = 'pending'"),
    )


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

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_meals_profile_time", "profile_id", "timestamp"),
    )


class PasswordResetOTP(Base):
    __tablename__ = "password_reset_otps"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, nullable=False)
    otp = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False)


class EmailVerificationOTP(Base):
    __tablename__ = "email_verification_otps"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    email = Column(String, nullable=False)
    otp = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False)


# ---------------------------------------------------------------------------
# Doctor Portal models (Module E)
# ---------------------------------------------------------------------------

class DoctorProfile(Base):
    """Doctor-specific profile data. Linked 1:1 to a User with role=doctor."""
    __tablename__ = "doctor_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    nmc_number = Column(String, unique=True, nullable=False)       # NMC / State Medical Council registration
    specialty = Column(String, nullable=True)                       # "General Physician", "Endocrinologist", etc.
    clinic_name = Column(String, nullable=True)
    doctor_code = Column(String(8), unique=True, nullable=False, index=True)  # e.g. "DRRAJ52" — patients use this to link
    is_verified = Column(Boolean, default=False)                    # Admin verifies NMC number
    verified_at = Column(DateTime(timezone=True), nullable=True)
    verified_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


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

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("doctor_id", "profile_id", name="uq_doctor_patient"),
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
