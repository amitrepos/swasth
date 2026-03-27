from sqlalchemy import Column, Integer, String, Float, Text, ARRAY, DateTime, Boolean, ForeignKey
from sqlalchemy.sql import func
from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    full_name = Column(String, nullable=False)
    phone_number = Column(String, nullable=False)
    age = Column(Integer, nullable=False)
    gender = Column(String, nullable=False)  # Male / Female / Other
    height = Column(Float, nullable=False)  # in cm
    weight = Column(Float, nullable=False)  # in kg
    blood_group = Column(String, nullable=False)  # A+, A-, B+, B-, O+, O-, AB+, AB-
    current_medications = Column(Text)  # comma-separated
    medical_conditions = Column(ARRAY(String))  # List of conditions
    other_medical_condition = Column(Text, nullable=True)  # For "Other" medical condition
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class HealthReading(Base):
    """Store glucose and blood pressure readings for users"""
    __tablename__ = "health_readings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    # Reading type: 'glucose' or 'blood_pressure'
    reading_type = Column(String, nullable=False)
    
    # Glucose specific fields
    glucose_value = Column(Float, nullable=True)  # mg/dL
    glucose_unit = Column(String, nullable=True)  # 'mg/dL'
    sample_type = Column(String, nullable=True)  # 'Capillary whole blood', etc.
    
    # BP specific fields
    systolic = Column(Float, nullable=True)  # mmHg
    diastolic = Column(Float, nullable=True)  # mmHg
    mean_arterial_pressure = Column(Float, nullable=True)  # MAP
    pulse_rate = Column(Float, nullable=True)  # bpm
    bp_unit = Column(String, nullable=True)  # 'mmHg' or 'kPa'
    bp_status = Column(String, nullable=True)  # 'NORMAL', 'ELEVATED', etc.
    
    # Common fields
    value_numeric = Column(Float, nullable=False)  # Primary value for sorting
    unit_display = Column(String, nullable=False)  # Display unit
    status_flag = Column(String, nullable=True)  # Status/category
    notes = Column(Text, nullable=True)  # User notes
    
    # Timestamp from device or server
    reading_timestamp = Column(DateTime, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class PasswordResetOTP(Base):
    __tablename__ = "password_reset_otps"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, nullable=False)
    otp = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False)
