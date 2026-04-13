import pytest
from unittest.mock import patch, MagicMock, ANY
from datetime import datetime, timedelta
import pytz
from models import User, Profile, HealthReading, ProfileAccess
from report_service import send_weekly_reports, format_report_message
from twilio_service import TwilioWhatsAppService

# --- Tests for report_service.py ---

def test_format_report_message_invalid_timezone():
    """Test line 16-17: Fallback when user has an invalid timezone string."""
    user = User(full_name="Test User", timezone="Invalid/Zone")
    # Should fallback to Asia/Kolkata
    msg = format_report_message(user, [])
    assert "Weekly Health Report" in msg

def test_format_report_message_with_bp_data():
    """Test line 46-50: Rendering Blood Pressure data correctly."""
    user = User(full_name="Test User", timezone="UTC")
    p_data = [{
        "name": "Papa",
        "glucose": None,
        "bp": MagicMock(systolic=120, diastolic=80),
        "insight": "Test insight"
    }]
    msg = format_report_message(user, p_data)
    assert "💓 BP: 120/80 mmHg" in msg
    assert "(Normal) ✅" in msg
    assert "✨ *AI Evaluation:* Test insight" in msg

@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_managed_session(mock_ai, mock_whatsapp, db):
    """Test line 61-62, 131: Managed session when db is None."""
    # This involves patching SessionLocal in report_service
    with patch("report_service.SessionLocal") as mock_session_local:
        mock_session_local.return_value = db
        # We don't need any users/readings, just hitting the initialization/finally blocks
        send_weekly_reports(db=None) 
        mock_session_local.assert_called_once()

@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_phone_formats(mock_ai, mock_whatsapp, db):
    """Test line 80-84: Phone number starting with 91 but no +."""
    user = User(
        email="phone@test.com",
        full_name="Phone Tester",
        password_hash="pw",
        phone_number="918700151250", # 12 digits starting with 91
        timezone="UTC",
        is_active=True
    )
    db.add(user)
    db.flush()
    profile = Profile(name="Self")
    db.add(profile)
    db.flush()
    db.add(ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))
    db.add(HealthReading(
        profile_id=profile.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL",
        reading_timestamp=datetime.now(pytz.utc)
    ))
    db.commit()
    
    mock_ai.get_weekly_ai_insight.return_value = "Insight"
    
    send_weekly_reports(db=db)
    # Should normalize to +91...
    mock_whatsapp.send_whatsapp.assert_called_with("+918700151250", ANY)

# --- Tests for twilio_service.py ---

def test_twilio_client_initialization_error():
    """Test line 18-23: Handle client initialization failure."""
    with patch("twilio_service.settings") as mock_settings:
        mock_settings.TWILIO_ACCOUNT_SID = "ACxxx"
        mock_settings.TWILIO_AUTH_TOKEN = "token"
        
        service = TwilioWhatsAppService()
        with patch("twilio_service.Client", side_effect=Exception("Initialization failed")):
            client = service.client
            assert client is None

def test_twilio_send_whatsapp_not_configured():
    """Test line 36-38: Send fails if client or from_number is missing."""
    service = TwilioWhatsAppService()
    # Mock client and from_number as None
    with patch.multiple(service, _client=None, from_number=None):
        with patch("twilio_service.settings") as mock_settings:
            mock_settings.TWILIO_ACCOUNT_SID = None
            result = service.send_whatsapp("+918700151250", "hello")
            assert result[0] is False

def test_twilio_send_whatsapp_success():
    """Test line 41-50: Successful message creation."""
    service = TwilioWhatsAppService()
    service.from_number = "+14155238886"
    
    mock_client = MagicMock()
    mock_client.messages.create.return_value = MagicMock(sid="SMxxx")
    
    with patch.object(TwilioWhatsAppService, "client", mock_client):
        result = service.send_whatsapp("8700151250", "hello")
        assert result[0] is True
        assert result[1] == "SMxxx"
        mock_client.messages.create.assert_called_once_with(
            body="hello",
            from_="whatsapp:+14155238886",
            to="whatsapp:8700151250"
        )

def test_twilio_send_whatsapp_api_error():
    """Test line 51-54: Handle API errors."""
    service = TwilioWhatsAppService()
    service.from_number = "+14155238886"
    
    mock_client = MagicMock()
    mock_client.messages.create.side_effect = Exception("API error")
    
    with patch.object(TwilioWhatsAppService, "client", mock_client):
        result = service.send_whatsapp("8700151250", "hello")
        assert result[0] is False
        assert result[2] == "API error"
