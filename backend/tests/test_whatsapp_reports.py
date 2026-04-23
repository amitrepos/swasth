import pytest
from unittest.mock import patch, MagicMock, ANY
from datetime import datetime, timedelta
import pytz
from models import User, Profile, HealthReading, ProfileAccess
from report_service import send_weekly_reports

# 1. Test Phone Normalization Logic
@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_profile_phone_normalization(mock_ai, mock_whatsapp, mock_settings, db):
    """Verify that different profile phone formats are normalized to +91 E.164."""
    mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
    user = User(
        email="norm@test.com",
        full_name="Norm Tester",
        password_hash="dummy_hash",
        phone_number="8700151250",
        timezone="Asia/Kolkata",
        is_active=True
    )
    db.add(user)
    db.flush()
    
    mock_whatsapp.send_whatsapp_template.return_value = (True, "SMxxx", None)
    mock_ai.get_weekly_ai_insight.return_value = "Test AI Insight"
    
    # Profile has its own phone number in raw format
    profile = Profile(name="Self", phone_number="9876543210")
    db.add(profile)
    db.flush()
    db.add(ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))
    
    db.add(HealthReading(
        profile_id=profile.id,
        reading_type="glucose",
        glucose_value=120,
        value_numeric=120,
        unit_display="mg/dL",
        reading_timestamp=datetime.now(pytz.utc)
    ))
    db.commit()
    
    send_weekly_reports(db=db)
    
    # Assert: Twilio should receive +919876543210 (normalized from profile.phone_number)
    mock_whatsapp.send_whatsapp_template.assert_called_once()
    args = mock_whatsapp.send_whatsapp_template.call_args[0]
    assert args[0] == "+919876543210"

# 2. Test Individual Profile Reports
@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_separate_messages(mock_ai, mock_whatsapp, mock_settings, db):
    """Verify multiple profiles get separate messages to their own numbers."""
    mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
    user = User(
        email="multi@test.com", 
        full_name="Multi Owner", 
        phone_number="+919999999999",
        password_hash="dummy_hash",
        is_active=True
    )
    db.add(user)
    db.flush()
    
    mock_whatsapp.send_whatsapp_template.return_value = (True, "SMxxx", None)
    mock_ai.get_weekly_ai_insight.return_value = "Keep it up!"
    
    p1 = Profile(name="Deepak", phone_number="9111111111")
    p2 = Profile(name="Papa", phone_number="9222222222")
    db.add_all([p1, p2])
    db.flush()
    
    db.add(ProfileAccess(user_id=user.id, profile_id=p1.id, access_level="owner"))
    db.add(ProfileAccess(user_id=user.id, profile_id=p2.id, access_level="owner"))
    
    now = datetime.now(pytz.utc)
    db.add(HealthReading(
        profile_id=p1.id, reading_type="glucose", glucose_value=110, value_numeric=110, unit_display="mg/dL", reading_timestamp=now
    ))
    db.add(HealthReading(
        profile_id=p2.id, reading_type="glucose", glucose_value=180, value_numeric=180, unit_display="mg/dL", reading_timestamp=now
    ))
    db.commit()
    
    send_weekly_reports(db=db)
    
    # Should be called twice (once for each profile)
    assert mock_whatsapp.send_whatsapp_template.call_count == 2
    
    calls = mock_whatsapp.send_whatsapp_template.call_args_list
    # Check recipients
    recipients = [c[0][0] for c in calls]
    assert "+919111111111" in recipients
    assert "+919222222222" in recipients

# 3. Test 7-Day Window and No Readings
@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_profile_window_logic(mock_ai, mock_whatsapp, mock_settings, db):
    """Verify data window: 2-day-old data is valid (Weekly), 8-day-old is not."""
    mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
    user = User(email="window@test.com", phone_number="+910000000000", password_hash="dummy_hash", full_name="Window User", is_active=True)
    db.add(user)
    db.flush()
    p1 = Profile(name="Profile A", phone_number="9100000001") # Has data from 2d ago (Should send)
    p2 = Profile(name="Profile B", phone_number="9100000002") # Has data from 8d ago (Should skip)
    db.add_all([p1, p2])
    db.flush()
    db.add(ProfileAccess(user_id=user.id, profile_id=p1.id, access_level="owner"))
    db.add(ProfileAccess(user_id=user.id, profile_id=p2.id, access_level="owner"))
    
    now = datetime.now(pytz.utc)
    db.add(HealthReading(
        profile_id=p1.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL",
        reading_timestamp=now - timedelta(days=2)
    ))
    db.add(HealthReading(
        profile_id=p2.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL",
        reading_timestamp=now - timedelta(days=9)
    ))
    db.commit()
    
    mock_whatsapp.send_whatsapp_template.return_value = (True, "SMxxx", None)
    mock_ai.get_weekly_ai_insight.return_value = "Keep it up!"
    
    send_weekly_reports(db=db)
    
    # Assert: Should only call Twilio once (for Profile A)
    mock_whatsapp.send_whatsapp_template.assert_called_once()
    args = mock_whatsapp.send_whatsapp_template.call_args[0]
    assert args[0] == "+919100000001"

# 4. Test Report Generation Error Logging
@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_report_generation_error_logging_profile(mock_ai, mock_whatsapp, mock_settings, db):
    """Verify that exceptions during generation are logged to ReportGenerationLog."""
    mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
    from models import ReportGenerationLog, ReportGenerationStatus
    
    user = User(email="gen_err@test.com", phone_number="+915555555555", password_hash="hash", full_name="Err User", is_active=True)
    db.add(user)
    db.flush()
    profile = Profile(name="Error Profile", phone_number="9155555555")
    db.add(profile)
    db.flush()
    db.add(ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))
    
    # Mock data to trigger logic
    db.add(HealthReading(profile_id=profile.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL", reading_timestamp=datetime.now(pytz.utc)))
    db.commit()

    # FORCE FAILURE: Mock AI service to crash
    mock_ai.get_weekly_ai_insight.side_effect = Exception("AI Engine Down")
    
    send_weekly_reports(db=db)
    
    # Verify Log (linked to owner)
    log = db.query(ReportGenerationLog).filter(ReportGenerationLog.user_id == user.id).first()
    assert log is not None
    assert log.status == ReportGenerationStatus.FAILED
    assert "AI Engine Down" in log.error_message
