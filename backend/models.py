from sqlalchemy import Column, Integer, String, Float, Text, ARRAY, DateTime, Date, Boolean, ForeignKey, UniqueConstraint, Index
from sqlalchemy.sql import func
from database import Base


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
    timezone = Column(String, default="UTC", nullable=False)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
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
    access_level = Column(String, nullable=False, default="viewer")  # "viewer" or "editor"
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
    """Glucose and blood pressure readings. Belongs to a profile, logged by a user."""
    __tablename__ = "health_readings"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    logged_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    # Reading type: 'glucose' or 'blood_pressure'
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
    notes_enc = Column(Text, nullable=True)

    reading_timestamp = Column(DateTime, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    __table_args__ = (
        Index("ix_readings_profile_time", "profile_id", "reading_timestamp"),
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


class PasswordResetOTP(Base):
    __tablename__ = "password_reset_otps"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, nullable=False)
    otp = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False)
