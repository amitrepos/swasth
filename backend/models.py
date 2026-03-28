from sqlalchemy import Column, Integer, String, Float, Text, ARRAY, DateTime, Boolean, ForeignKey, UniqueConstraint, Index
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
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class Profile(Base):
    """Health identity for a person. One user can own/access many profiles."""
    __tablename__ = "profiles"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)                        # "My Health", "Papa", "Mummy"
    age = Column(Integer, nullable=True)
    gender = Column(String, nullable=True)                       # Male / Female / Other
    height = Column(Float, nullable=True)                        # cm
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
    status = Column(String, nullable=False, default="pending")   # "pending", "accepted", "rejected"
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)

    __table_args__ = (
        # Prevent duplicate pending invites for the same profile+email
        UniqueConstraint("profile_id", "invited_email", name="uq_profile_invite_email"),
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

    reading_timestamp = Column(DateTime, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    __table_args__ = (
        Index("ix_readings_profile_time", "profile_id", "reading_timestamp"),
    )


class PasswordResetOTP(Base):
    __tablename__ = "password_reset_otps"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, nullable=False)
    otp = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False)
