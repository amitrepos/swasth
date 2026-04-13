import pytest
from unittest.mock import patch, MagicMock, ANY
from datetime import datetime, timedelta
import pytz
from models import User, Profile, HealthReading, ProfileAccess
from report_service import send_weekly_reports

# 1. Test Phone Normalization Logic
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_phone_normalization(mock_ai, mock_whatsapp, db):
    """Verify that different phone formats are normalized to +91 E.164."""
    user = User(
        email="norm@test.com",
        full_name="Norm Tester",
        password_hash="dummy_hash",
        phone_number="8700151250",  # Raw 10 digits
        timezone="Asia/Kolkata",
        is_active=True
    )
    db.add(user)
    db.flush()
    
    mock_whatsapp.send_whatsapp.return_value = (True, "SMxxx", None)
    mock_ai.get_weekly_ai_insight.return_value = "Test AI Insight"
    
    profile = Profile(name="Self")
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
    
    # Execute passing the test DB session
    send_weekly_reports(db=db)
    
    # Assert: Twilio should receive +918700151250
    mock_whatsapp.send_whatsapp.assert_called_with("+918700151250", ANY)

# 2. Test Multi-Profile Aggregation
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_multi_profile(mock_ai, mock_whatsapp, db):
    """Verify multiple profiles with AI insights are combined into one message."""
    user = User(
        email="multi@test.com", 
        full_name="Multi Owner", 
        phone_number="+919999999999",
        password_hash="dummy_hash",
        is_active=True
    )
    db.add(user)
    db.flush()
    
    mock_whatsapp.send_whatsapp.return_value = (True, "SMxxx", None)
    mock_ai.get_weekly_ai_insight.return_value = "Keep it up!"
    
    p1 = Profile(name="Deepak")
    p2 = Profile(name="Papa")
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
    
    args, kwargs = mock_whatsapp.send_whatsapp.call_args
    message = args[1]
    assert "Weekly Health Report" in message
    assert "Deepak" in message
    assert "Papa" in message
    assert "110 mg/dL" in message
    assert "180 mg/dL" in message
    assert "*AI Evaluation:* Keep it up!" in message

# 3. Test Shared Access Scoping
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_excludes_viewed_profiles(mock_ai, mock_whatsapp, db):
    """Verify reports only include profiles where user is 'owner', not just 'viewer'."""
    user_a = User(email="owner@test.com", phone_number="+911111111111", password_hash="hash_a", full_name="Owner A", is_active=True)
    user_b = User(email="viewer@test.com", phone_number="+912222222222", password_hash="hash_b", full_name="Viewer B", is_active=True)
    db.add_all([user_a, user_b])
    db.flush()
    
    mock_whatsapp.send_whatsapp.return_value = (True, "SMxxx", None)
    mock_ai.get_weekly_ai_insight.return_value = "Ok"
    
    shared_profile = Profile(name="Shared Profile")
    db.add(shared_profile)
    db.flush()
    
    db.add(ProfileAccess(user_id=user_a.id, profile_id=shared_profile.id, access_level="owner"))
    db.add(ProfileAccess(user_id=user_b.id, profile_id=shared_profile.id, access_level="viewer"))
    
    db.add(HealthReading(
        profile_id=shared_profile.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL", reading_timestamp=datetime.now(pytz.utc)
    ))
    db.commit()
    
    send_weekly_reports(db=db)
    
    calls = mock_whatsapp.send_whatsapp.call_args_list
    recipient_numbers = [call[0][0] for call in calls]
    
    assert "+911111111111" in recipient_numbers
    assert "+912222222222" not in recipient_numbers

# 4. Test 7-Day Window and No Readings
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_window_logic(mock_ai, mock_whatsapp, db):
    """Verify data window: 2-day-old data is valid (Weekly), 8-day-old is not."""
    user = User(email="window@test.com", phone_number="+910000000000", password_hash="dummy_hash", full_name="Window User", is_active=True)
    db.add(user)
    db.flush()
    p1 = Profile(name="Profile A") # Has data from 2d ago (Should send)
    p2 = Profile(name="Profile B") # Has data from 8d ago (Should skip)
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
    
    send_weekly_reports(db=db)
    
    # Assert: Should only call Twilio once, message should contain A but not B
    mock_whatsapp.send_whatsapp.assert_called_once()
    args, _ = mock_whatsapp.send_whatsapp.call_args
    message = args[1]
    assert "Profile A" in message
    assert "Profile B" not in message

# 5. Test Report Generation Error Logging
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_report_generation_error_logging(mock_ai, mock_whatsapp, db):
    """Verify that exceptions during generation are logged to ReportGenerationLog."""
    from models import ReportGenerationLog, ReportGenerationStatus
    
    user = User(email="gen_err@test.com", phone_number="+915555555555", password_hash="hash", full_name="Err User", is_active=True)
    db.add(user)
    db.flush()
    profile = Profile(name="Error Profile")
    db.add(profile)
    db.flush()
    db.add(ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))
    
    # Mock data to trigger logic
    db.add(HealthReading(profile_id=profile.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL", reading_timestamp=datetime.now(pytz.utc)))
    db.commit()

    # FORCE FAILURE: Mock AI service to crash
    mock_ai.get_weekly_ai_insight.side_effect = Exception("AI Engine Down")
    
    send_weekly_reports(db=db)
    
    # Verify Log
    log = db.query(ReportGenerationLog).filter(ReportGenerationLog.user_id == user.id).first()
    assert log is not None
    assert log.status == ReportGenerationStatus.FAILED
    assert "AI Engine Down" in log.error_message

# 6. Test WhatsApp Delivery Error Logging
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_whatsapp_delivery_error_logging(mock_ai, mock_whatsapp, db):
    """Verify that Twilio failures are logged to WhatsAppMessageLog."""
    from models import WhatsAppMessageLog, WhatsAppMessageStatus
    
    user = User(email="del_err@test.com", phone_number="+916666666666", password_hash="hash", full_name="Del User", is_active=True)
    db.add(user)
    db.flush()
    profile = Profile(name="Del Profile")
    db.add(profile)
    db.flush()
    db.add(ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))
    db.add(HealthReading(profile_id=profile.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL", reading_timestamp=datetime.now(pytz.utc)))
    db.commit()

    mock_ai.get_weekly_ai_insight.return_value = "Insight"
    
    # FORCE FAILURE: Mock WhatsApp service to return failure
    mock_whatsapp.send_whatsapp.return_value = (False, "ERR123", "Simulated Twilio Failure")
    
    send_weekly_reports(db=db)
    
    # Verify Log
    log = db.query(WhatsAppMessageLog).filter(WhatsAppMessageLog.user_id == user.id).first()
    assert log is not None
    assert log.status == WhatsAppMessageStatus.FAILED
    assert log.twilio_sid == "ERR123"
    assert "Simulated Twilio Failure" in log.error_message
