import pytest
from unittest.mock import patch, MagicMock
from datetime import datetime, timedelta, date
from models import User, Profile, HealthReading, ProfileAccess
from ai_report_service import get_weekly_ai_insight, _get_weekly_rule_based_fallback

def test_ai_insight_no_consent(db):
    """Verify fallback to rule-based when ai_consent is False."""
    user = User(
        email="noconsent@test.com", 
        full_name="No Consent", 
        phone_number="+911111111111",
        password_hash="hash",
        ai_consent=False, 
        email_verified=False
    )
    db.add(user)
    db.flush()
    profile = Profile(name="Tester")
    db.add(profile)
    db.flush()
    
    # No readings - Should return the generic encouragement string from rule-based fallback
    insight = get_weekly_ai_insight(db, profile.id, user)
    assert "Keep tracking your sugar and BP daily" in insight

def test_ai_insight_no_data(db):
    """Verify response when there is no health data for the week."""
    user = User(
        email="nodata@test.com", 
        full_name="Has Consent", 
        phone_number="+912222222222",
        password_hash="hash",
        ai_consent=True, 
        email_verified=False
    )
    db.add(user)
    db.flush()
    profile = Profile(name="Tester")
    db.add(profile)
    db.flush()
    
    insight = get_weekly_ai_insight(db, profile.id, user)
    assert "Not enough readings logged this week" in insight

@patch("ai_report_service.ai_service.generate_health_insight")
def test_ai_insight_generation_success(mock_gen, db):
    """Verify successful AI generation when data is present."""
    user = User(
        email="success@test.com", 
        full_name="Has Consent", 
        phone_number="+913333333333",
        password_hash="hash",
        ai_consent=True, 
        email_verified=False
    )
    db.add(user)
    db.flush()
    profile = Profile(name="Tester", age=45, medical_conditions=["Hypertension"])
    db.add(profile)
    db.flush()
    
    # Add a reading from 2 days ago
    db.add(HealthReading(
        profile_id=profile.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL",
        reading_timestamp=datetime.now() - timedelta(days=2)
    ))
    db.commit()
    
    mock_gen.return_value = "AI Generated Insight: You are doing great."
    
    insight = get_weekly_ai_insight(db, profile.id, user)
    assert "AI Generated Insight" in insight
    mock_gen.assert_called_once()

def test_rule_based_fallback_critical(db):
    """Verify rule-based logic identifies critical readings."""
    profile = Profile(name="Tester")
    db.add(profile)
    db.flush()
    
    # Add a critical reading
    db.add(HealthReading(
        profile_id=profile.id, reading_type="glucose", status_flag="CRITICAL", value_numeric=120, unit_display="mg/dL",
        reading_timestamp=datetime.now() - timedelta(days=1)
    ))
    db.commit()
    
    insight = _get_weekly_rule_based_fallback(db, profile.id)
    assert "Multiple readings were critical" in insight

def test_rule_based_fallback_high(db):
    """Verify rule-based logic identifies high readings."""
    profile = Profile(name="Tester")
    db.add(profile)
    db.flush()
    
    # Add a high reading
    db.add(HealthReading(
        profile_id=profile.id, reading_type="glucose", status_flag="HIGH", value_numeric=120, unit_display="mg/dL",
        reading_timestamp=datetime.now() - timedelta(days=1)
    ))
    db.commit()
    
    insight = _get_weekly_rule_based_fallback(db, profile.id)
    assert "Some readings were elevated" in insight

def test_rule_based_fallback_normal(db):
    """Verify rule-based logic returns normal message when all readings are fine."""
    profile = Profile(name="Tester")
    db.add(profile)
    db.flush()
    
    # Add a normal reading
    db.add(HealthReading(
        profile_id=profile.id, reading_type="glucose", status_flag="NORMAL", value_numeric=120, unit_display="mg/dL",
        reading_timestamp=datetime.now() - timedelta(days=1)
    ))
    db.commit()
    
    insight = _get_weekly_rule_based_fallback(db, profile.id)
    assert "All readings were normal" in insight
