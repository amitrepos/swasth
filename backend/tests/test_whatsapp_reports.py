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
def test_send_weekly_reports_dispatches_to_normalized_owner_phone(mock_ai, mock_whatsapp, mock_settings, db):
    """Verify that the OWNER's phone is normalized and used for dispatch."""
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
    
    # Profile has same phone as owner to allow dispatch under PHI-compliance
    profile = Profile(name="Self", phone_number="8700151250")
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
    
    # Assert: Twilio should receive +918700151250 (normalized from user.phone_number)
    mock_whatsapp.send_whatsapp_template.assert_called_once()
    args = mock_whatsapp.send_whatsapp_template.call_args[0]
    assert args[0] == "+918700151250"

# 2. Test Consolidated Reports for Multi-Profile Owners
@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_consolidated_messages(mock_ai, mock_whatsapp, mock_settings, db):
    """Verify multiple profiles for the same owner result in ONE consolidated WhatsApp message."""
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
    
    p1 = Profile(name="Deepak", phone_number="9999999999")
    p2 = Profile(name="Papa", phone_number="9999999999")
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
    
    # After consolidation fix (M3), multiple profiles for same owner result in ONE call
    assert mock_whatsapp.send_whatsapp_template.call_count == 1
    
    calls = mock_whatsapp.send_whatsapp_template.call_args_list
    # Check recipients (both should go to owner's phone +919999999999)
    recipients = [c[0][0] for c in calls]
    assert "+919999999999" in recipients
    assert len(recipients) == 1
    
    # Both names should be in the consolidated body (var3 at index 2)
    report_body = calls[0][0][2][2]
    assert "Deepak" in report_body
    assert "Papa" in report_body

# 3. Test 7-Day Window and No Readings
@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_profile_window_logic(mock_ai, mock_whatsapp, mock_settings, db):
    """Verify data window: 2-day-old data is valid (Weekly), 8-day-old is not."""
    mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
    user = User(email="window@test.com", phone_number="+919999999999", password_hash="dummy_hash", full_name="Window User", is_active=True)
    db.add(user)
    db.flush()
    p1 = Profile(name="Profile A", phone_number="9999999999") # Has data from 2d ago (Should send)
    p2 = Profile(name="Profile B", phone_number="9999999999") # Has data from 8d ago (Should skip)
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
    
    # Assert: Should only call Twilio once (for Profile A) to owner's phone
    mock_whatsapp.send_whatsapp_template.assert_called_once()
    args = mock_whatsapp.send_whatsapp_template.call_args[0]
    assert args[0] == "+919999999999"

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

# 5. Regression: Viewers should NOT trigger/receive reports
@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_excludes_viewed_profiles(mock_ai, mock_whatsapp, mock_settings, db):
    """Verify that a user who only has 'viewer' access does not trigger a report for that profile."""
    mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
    
    # User 1 (Owner)
    owner = User(email="owner@test.com", phone_number="+919999999991", password_hash="h", full_name="Owner", is_active=True)
    # User 2 (Viewer)
    viewer = User(email="viewer@test.com", phone_number="+919999999992", password_hash="h", full_name="Viewer", is_active=True)
    db.add_all([owner, viewer])
    db.flush()
    
    profile = Profile(name="Shared Profile", phone_number="919999999991")
    db.add(profile)
    db.flush()
    
    # Access: User 1 is OWNER, User 2 is VIEWER
    db.add(ProfileAccess(user_id=owner.id, profile_id=profile.id, access_level="owner"))
    db.add(ProfileAccess(user_id=viewer.id, profile_id=profile.id, access_level="viewer"))
    
    # Add data
    db.add(HealthReading(profile_id=profile.id, reading_type="glucose", glucose_value=100, value_numeric=100, unit_display="mg/dL", reading_timestamp=datetime.now(pytz.utc)))
    db.commit()
    
    mock_ai.get_weekly_ai_insight.return_value = "Insight"
    mock_whatsapp.send_whatsapp_template.return_value = (True, "SMxxx", None)
    
    send_weekly_reports(db=db)
    
    # Should only be called ONCE (for the owner), not twice.
    # The per-profile iteration finds the profile, finds the owner, and dispatches.
    # A viewer exists but should not double the dispatch.
    assert mock_whatsapp.send_whatsapp_template.call_count == 1
    args = mock_whatsapp.send_whatsapp_template.call_args[0]
    assert args[0] == "+919999999991" # Dispatched to owner, not viewer

# 6. Test WhatsApp Delivery Error Logging
@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_whatsapp_delivery_error_logging(mock_ai, mock_whatsapp, mock_settings, db):
    """Verify that Twilio API failures are logged to WhatsAppMessageLog."""
    mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
    from models import WhatsAppMessageLog, WhatsAppMessageStatus
    
    user = User(email="fail@test.com", phone_number="+919999999993", password_hash="h", full_name="Fail User", is_active=True)
    db.add(user)
    db.flush()
    profile = Profile(name="P1", phone_number="9999999993")
    db.add(profile)
    db.flush()
    db.add(ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))
    db.add(HealthReading(profile_id=profile.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL", reading_timestamp=datetime.now(pytz.utc)))
    db.commit()
    
    mock_ai.get_weekly_ai_insight.return_value = "Ok"
    # Mock Twilio FAILURE
    mock_whatsapp.send_whatsapp_template.return_value = (False, None, "Twilio Error 123")
    
    send_weekly_reports(db=db)
    
    delivery_log = db.query(WhatsAppMessageLog).filter(WhatsAppMessageLog.user_id == user.id).first()
    assert delivery_log is not None
    assert delivery_log.status == WhatsAppMessageStatus.FAILED
    assert delivery_log.error_message == "Twilio Error 123"

# 7. Multi-profile Consolidation (M3)
@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_consolidated_multi_profile_report(mock_ai, mock_whatsapp, mock_settings, db):
    """Verify that multiple profiles for the same owner result in ONE consolidated WhatsApp message."""
    mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
    
    user = User(email="con@test.com", phone_number="+919999999994", password_hash="h", full_name="Consolidator", is_active=True)
    db.add(user)
    db.flush()
    
    # 3 profiles, all owned by the same user
    p1 = Profile(name="Self", phone_number="919999999994")
    p2 = Profile(name="Papa", phone_number="919999999994")
    p3 = Profile(name="Mummy", phone_number="919999999994")
    db.add_all([p1, p2, p3])
    db.flush()
    
    for p in [p1, p2, p3]:
        db.add(ProfileAccess(user_id=user.id, profile_id=p.id, access_level="owner"))
        db.add(HealthReading(profile_id=p.id, reading_type="glucose", glucose_value=110, value_numeric=110, unit_display="mg/dL", reading_timestamp=datetime.now(pytz.utc)))
    
    db.commit()
    
    mock_ai.get_weekly_ai_insight.return_value = "Good"
    mock_whatsapp.send_whatsapp_template.return_value = (True, "SMxxx", None)
    
    send_weekly_reports(db=db)
    
    # CRITICAL: Should only be called ONCE (consolidated)
    assert mock_whatsapp.send_whatsapp_template.call_count == 1
    
    args = mock_whatsapp.send_whatsapp_template.call_args[0]
    assert args[0] == "+919999999994" # Recipient
    # Variable {{3}} should contain all profile names
    report_body = args[2][2]
    assert "Self" in report_body
    assert "Papa" in report_body
    assert "Mummy" in report_body
