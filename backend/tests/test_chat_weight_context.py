import pytest
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
import models
from routes_chat import _build_health_summary

def test_build_health_summary_with_weight(db: Session, test_user):
    # 1. Setup profile with height
    profile = models.Profile(
        name="Context Test",
        gender="Male",
        age=30,
        height=180.0, # 1.8m
        weight=80.0,  # profile weight
        phone_number="9876543210",
        medical_conditions=[],
        current_medications="None"
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)

    # 2. Add some weight readings (within 30 days)
    now = datetime.now()
    r1 = models.HealthReading(
        profile_id=profile.id,
        logged_by=test_user.id,
        reading_type="weight",
        weight_value=85.0,
        value_numeric=85.0,
        unit_display="kg",
        reading_timestamp=now - timedelta(days=2)
    )
    r2 = models.HealthReading(
        profile_id=profile.id,
        logged_by=test_user.id,
        reading_type="weight",
        weight_value=83.0,
        value_numeric=83.0,
        unit_display="kg",
        reading_timestamp=now - timedelta(days=1)
    )
    db.add_all([r1, r2])
    db.commit()

    # 3. Build summary
    summary = _build_health_summary(profile.id, db)

    # 4. Assertions
    # BMI should use latest weight (83.0kg), not profile weight (80.0kg)
    # BMI = 83 / (1.8 * 1.8) = 83 / 3.24 = 25.6 (Overweight)
    assert "Current Weight (logged): 83.0kg" in summary
    assert "BMI: 25.6 (Overweight)" in summary
    assert "Weight (30d, 2 readings): avg 84.0 kg" in summary
    assert "Latest: 83.0 kg" in summary

def test_build_health_summary_fallback_to_profile_weight(db: Session, test_user):
    # Setup profile without logged readings
    profile = models.Profile(
        name="Profile Weight Test",
        gender="Female",
        age=25,
        height=160.0, # 1.6m
        weight=50.0,  # profile weight
        phone_number="9876543210",
        medical_conditions=[],
        current_medications="None"
    )
    db.add(profile)
    db.commit()

    summary = _build_health_summary(profile.id, db)

    # BMI = 50 / (1.6 * 1.6) = 50 / 2.56 = 19.5 (Normal)
    assert "Current Weight (profile): 50.0kg" in summary
    assert "BMI: 19.5 (Normal)" in summary
    assert "Weight (30d" not in summary # No trend section since no readings
