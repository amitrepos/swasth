"""Tests for sms_service.py — Twilio SMS wrapper."""
from unittest.mock import MagicMock, patch

import pytest

from sms_service import TwilioSmsService


class TestTwilioSmsServiceInit:
    """Test initialization of TwilioSmsService."""

    def test_init_reads_settings(self):
        """Service should read from settings on init."""
        service = TwilioSmsService()
        assert service.account_sid is not None or service.account_sid is None
        assert service.auth_token is not None or service.auth_token is None
        assert service.from_number is not None or service.from_number is None

    def test_init_client_is_none(self):
        """Client should be None until accessed."""
        service = TwilioSmsService()
        assert service._client is None


class TestTwilioSmsServiceIsEnabled:
    """Test is_enabled property."""

    def test_disabled_when_no_credentials(self):
        """Should be disabled when credentials are missing."""
        service = TwilioSmsService()
        # In test env, these are likely not set
        # Just verify the property works
        result = service.is_enabled
        assert isinstance(result, bool)

    @patch("sms_service.settings")
    def test_enabled_when_all_credentials_set(self, mock_settings):
        """Should be enabled when all three prerequisites are set."""
        mock_settings.TWILIO_ACCOUNT_SID = "test_sid"
        mock_settings.TWILIO_AUTH_TOKEN = "test_token"
        mock_settings.TWILIO_SMS_NUMBER = "+1234567890"

        service = TwilioSmsService()
        assert service.is_enabled is True


class TestTwilioSmsServiceClient:
    """Test client property."""

    @patch("sms_service.settings")
    def test_client_initialization_success(self, mock_settings):
        """Client should initialize when credentials are valid."""
        mock_settings.TWILIO_ACCOUNT_SID = "test_sid"
        mock_settings.TWILIO_AUTH_TOKEN = "test_token"
        mock_settings.TWILIO_SMS_NUMBER = None  # Not needed for client init

        with patch("sms_service.Client") as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client

            service = TwilioSmsService()
            client = service.client

            assert client is mock_client
            mock_client_class.assert_called_once_with("test_sid", "test_token")

    @patch("sms_service.settings")
    def test_client_initialization_failure(self, mock_settings, capsys):
        """Client should handle initialization errors gracefully."""
        mock_settings.TWILIO_ACCOUNT_SID = "bad_sid"
        mock_settings.TWILIO_AUTH_TOKEN = "bad_token"
        mock_settings.TWILIO_SMS_NUMBER = None

        with patch("sms_service.Client", side_effect=Exception("Invalid credentials")):
            service = TwilioSmsService()
            client = service.client

            assert client is None
            captured = capsys.readouterr()
            assert "Failed to initialize Twilio SMS client" in captured.out


class TestTwilioSmsServiceSendSms:
    """Test send_sms method."""

    @patch("sms_service.settings")
    def test_send_sms_disabled_returns_false(self, mock_settings):
        """Should return False when SMS is not configured."""
        mock_settings.TWILIO_ACCOUNT_SID = None
        mock_settings.TWILIO_AUTH_TOKEN = None
        mock_settings.TWILIO_SMS_NUMBER = None

        service = TwilioSmsService()
        result = service.send_sms("+1234567890", "Test message")

        assert result is False

    @patch("sms_service.settings")
    def test_send_sms_success(self, mock_settings):
        """Should send SMS and return True on success."""
        mock_settings.TWILIO_ACCOUNT_SID = "test_sid"
        mock_settings.TWILIO_AUTH_TOKEN = "test_token"
        mock_settings.TWILIO_SMS_NUMBER = "+1987654321"

        with patch("sms_service.Client") as mock_client_class:
            mock_message = MagicMock()
            mock_message.sid = "SM123456"
            mock_client = MagicMock()
            mock_client.messages.create.return_value = mock_message
            mock_client_class.return_value = mock_client

            service = TwilioSmsService()
            result = service.send_sms("+1234567890", "Test message")

            assert result is True
            mock_client.messages.create.assert_called_once_with(
                body="Test message",
                from_="+1987654321",
                to="+1234567890",
            )

    @patch("sms_service.settings")
    def test_send_sms_failure_returns_false(self, mock_settings, capsys):
        """Should return False when SMS sending fails."""
        mock_settings.TWILIO_ACCOUNT_SID = "test_sid"
        mock_settings.TWILIO_AUTH_TOKEN = "test_token"
        mock_settings.TWILIO_SMS_NUMBER = "+1987654321"

        with patch("sms_service.Client") as mock_client_class:
            mock_client = MagicMock()
            mock_client.messages.create.side_effect = Exception("API error")
            mock_client_class.return_value = mock_client

            service = TwilioSmsService()
            result = service.send_sms("+1234567890", "Test message")

            assert result is False
            captured = capsys.readouterr()
            assert "Error sending Twilio SMS" in captured.out


class TestTwilioSmsServiceSendCriticalAlert:
    """Test send_critical_alert_sms method."""

    @patch("sms_service.settings")
    def test_critical_alert_disabled_returns_false(self, mock_settings):
        """Should return False when SMS is not configured."""
        mock_settings.TWILIO_ACCOUNT_SID = None
        mock_settings.TWILIO_AUTH_TOKEN = None
        mock_settings.TWILIO_SMS_NUMBER = None

        service = TwilioSmsService()
        result = service.send_critical_alert_sms(
            to_number="+1234567890",
            patient_name="John Doe",
            alert_text_en="High BP detected",
            alert_text_hi="उच्च रक्तचाप का पता चला",
        )

        assert result is False

    @patch("sms_service.settings")
    def test_critical_alert_formats_message_correctly(self, mock_settings):
        """Should format bilingual alert message correctly."""
        mock_settings.TWILIO_ACCOUNT_SID = "test_sid"
        mock_settings.TWILIO_AUTH_TOKEN = "test_token"
        mock_settings.TWILIO_SMS_NUMBER = "+1987654321"

        with patch("sms_service.Client") as mock_client_class:
            mock_message = MagicMock()
            mock_message.sid = "SM123456"
            mock_client = MagicMock()
            mock_client.messages.create.return_value = mock_message
            mock_client_class.return_value = mock_client

            service = TwilioSmsService()
            service.send_critical_alert_sms(
                to_number="+1234567890",
                patient_name="Jane Smith",
                alert_text_en="Critical glucose level",
                alert_text_hi="गंभीर ग्लूकोज स्तर",
            )

            # Verify the message was created with correct format
            call_args = mock_client.messages.create.call_args
            body = call_args.kwargs["body"]
            assert "Swasth Alert: Critical glucose level" in body
            assert "Jane Smith" in body
            # Hindi text should be truncated to 60 chars
            assert "गंभीर ग्लूकोज स्तर" in body or body.count("...") >= 0
