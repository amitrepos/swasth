import pytest
from unittest.mock import patch, MagicMock, ANY
from datetime import datetime, timedelta
import pytz
import json
from models import User, Profile, HealthReading, ProfileAccess
from report_service import send_weekly_reports, format_report_template_variables
from twilio_service import TwilioWhatsAppService

# --- Tests for report_service.py ---

def test_format_report_template_variables_basic():
    """Test formatting template variables with glucose and BP data."""
    profile_data = {
        "glucose": MagicMock(glucose_value=120),
        "bp": MagicMock(systolic=120, diastolic=80),
        "insight": "Test insight"
    }
    vars = format_report_template_variables("Papa", profile_data)
    assert len(vars) == 3
    assert vars[0]  # Start date (e.g., "16 Apr")
    assert vars[1]  # End date (e.g., "22 Apr 2026")
    assert "Papa" in vars[2]
    assert "💓 BP: 120/80 mmHg" in vars[2]
    assert "(Normal) ✅" in vars[2]
    assert "✨ *AI Evaluation:* Test insight" in vars[2]

def test_format_report_template_variables_no_data():
    """Test template variables with no glucose/BP data."""
    profile_data = {
        "glucose": None,
        "bp": None,
        "insight": None
    }
    vars = format_report_template_variables("Self", profile_data)
    assert len(vars) == 3
    assert "Self" in vars[2]
    assert "No checks today" in vars[2]
    assert "\n" in vars[2]  # Should have newlines in the template var

@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_managed_session(mock_ai, mock_whatsapp, mock_settings, db):
    """Test line 61-62, 131: Managed session when db is None."""
    mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
    # This involves patching SessionLocal in report_service
    with patch("report_service.SessionLocal") as mock_session_local:
        mock_session_local.return_value = db
        # We don't need any users/readings, just hitting the initialization/finally blocks
        send_weekly_reports(db=None) 
        mock_session_local.assert_called_once()

@patch("report_service.settings")
@patch("report_service.whatsapp_service")
@patch("report_service.ai_report_service")
def test_send_weekly_reports_phone_formats(mock_ai, mock_whatsapp, mock_settings, db):
    """Test phone number normalization (10-digit, 12-digit with 91, full +91)."""
    mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
    user = User(
        email="phone@test.com",
        full_name="Phone Tester",
        password_hash="pw",
        phone_number="918700151250",
        timezone="UTC",
        is_active=True
    )
    db.add(user)
    db.flush()
    profile = Profile(name="Self", phone_number="9876543210")  # 10-digit format
    db.add(profile)
    db.flush()
    db.add(ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))
    db.add(HealthReading(
        profile_id=profile.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL",
        reading_timestamp=datetime.now(pytz.utc)
    ))
    db.commit()
    
    mock_ai.get_weekly_ai_insight.return_value = "Insight"
    mock_whatsapp.send_whatsapp_template.return_value = (True, "SMxxx", None)
    
    send_weekly_reports(db=db)
    # Should normalize to +91...
    mock_whatsapp.send_whatsapp_template.assert_called_once()
    args = mock_whatsapp.send_whatsapp_template.call_args[0]
    assert args[0] == "+919876543210"  # Normalized phone number

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

def test_twilio_send_whatsapp_template_success():
    """Test send_whatsapp_template with proper JSON formatting."""
    service = TwilioWhatsAppService()
    service.from_number = "+14155238886"
    
    mock_client = MagicMock()
    mock_client.messages.create.return_value = MagicMock(sid="SMyyy")
    
    with patch.object(TwilioWhatsAppService, "client", mock_client):
        variables = ["16 Apr", "22 Apr 2026", "👤 *Deepak*\n🩸 Sugar: 120 mg/dL"]
        result = service.send_whatsapp_template("+919876543210", "HXxxxxx", variables)
        assert result[0] is True
        assert result[1] == "SMyyy"
        
        # Check that the call was made with JSON string content_variables
        call_args = mock_client.messages.create.call_args
        assert call_args[1]["content_sid"] == "HXxxxxx"
        # Verify it's a JSON string with proper key format
        content_vars = json.loads(call_args[1]["content_variables"])
        assert content_vars["1"] == "16 Apr"
        assert content_vars["2"] == "22 Apr 2026"

def test_twilio_send_whatsapp_template_sanitize_newlines():
    """Test that template variables sanitize newlines and extra spaces."""
    service = TwilioWhatsAppService()
    service.from_number = "+14155238886"
    
    mock_client = MagicMock()
    mock_client.messages.create.return_value = MagicMock(sid="SMzzz")
    
    with patch.object(TwilioWhatsAppService, "client", mock_client):
        # Variables with newlines and multiple spaces
        variables = ["16 Apr", "22 Apr 2026", "👤 *Deepak*\n🩸 Sugar:  120  mg/dL\t(High)"]
        result = service.send_whatsapp_template("+919876543210", "HXxxxxx", variables)
        assert result[0] is True
        
        # Check that newlines and extra spaces are removed
        call_args = mock_client.messages.create.call_args
        content_vars = json.loads(call_args[1]["content_variables"])
        # Should not have newlines or tabs
        assert "\n" not in content_vars["3"]
        assert "\t" not in content_vars["3"]
        # Should have single spaces where multiple existed
        assert "  " not in content_vars["3"]

def test_twilio_send_whatsapp_template_not_configured():
    """Test template send fails if client or from_number is missing."""
    service = TwilioWhatsAppService()
    
    with patch.multiple(service, _client=None, from_number=None):
        with patch("twilio_service.settings") as mock_settings:
            mock_settings.TWILIO_ACCOUNT_SID = None
            result = service.send_whatsapp_template("+919876543210", "HXxxxxx", ["1", "2", "3"])
            assert result[0] is False
            assert "not configured" in result[2]

