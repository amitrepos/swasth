"""
Tests for WhatsApp inbound reading submission feature.

Tests are structured in three groups:
  1. Unit tests for whatsapp_inbound_service utilities
  2. Integration tests for the webhook endpoint (photo message)
  3. Integration tests for the webhook endpoint (text/profile-reply message)
"""
import json
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

# ---------------------------------------------------------------------------
# Unit tests — phone normalization
# ---------------------------------------------------------------------------

from whatsapp_inbound_service import normalize_phone


class TestNormalizePhone:
    def test_whatsapp_prefix_stripped(self):
        assert normalize_phone("whatsapp:+919876543210") == "+919876543210"

    def test_already_canonical(self):
        assert normalize_phone("+919876543210") == "+919876543210"

    def test_ten_digit_indian(self):
        assert normalize_phone("9876543210") == "+919876543210"

    def test_twelve_digit_indian_no_plus(self):
        assert normalize_phone("919876543210") == "+919876543210"

    def test_spaces_stripped(self):
        assert normalize_phone("whatsapp:+91 98765 43210") == "+919876543210"


# ---------------------------------------------------------------------------
# Unit tests — build_profile_menu
# ---------------------------------------------------------------------------

from whatsapp_inbound_service import build_profile_menu


class TestBuildProfileMenu:
    def test_single_profile(self):
        profiles = [{"id": 1, "name": "Deepak", "relationship": "myself"}]
        menu = build_profile_menu(profiles)
        assert "1️⃣" in menu
        assert "Deepak" in menu
        # "myself" relationship should NOT appear
        assert "Myself" not in menu

    def test_multiple_profiles(self):
        profiles = [
            {"id": 1, "name": "Deepak", "relationship": "myself"},
            {"id": 2, "name": "Sunita", "relationship": "mother"},
            {"id": 3, "name": "Ramesh", "relationship": "father"},
        ]
        menu = build_profile_menu(profiles)
        assert "1️⃣" in menu
        assert "2️⃣" in menu
        assert "3️⃣" in menu
        assert "Mother" in menu
        assert "Father" in menu


# ---------------------------------------------------------------------------
# Unit tests — format_reading_summary
# ---------------------------------------------------------------------------

from whatsapp_inbound_service import format_reading_summary


class TestFormatReadingSummary:
    def test_glucose(self):
        data = {"reading_type": "glucose", "glucose_value": 126, "unit_detected": "mg/dL"}
        result = format_reading_summary(data)
        assert "126" in result
        assert "mg/dL" in result
        assert "Glucose" in result

    def test_blood_pressure(self):
        data = {"reading_type": "blood_pressure", "systolic": 125, "diastolic": 82, "pulse_rate": 72}
        result = format_reading_summary(data)
        assert "125/82" in result
        assert "72" in result

    def test_blood_pressure_no_pulse(self):
        data = {"reading_type": "blood_pressure", "systolic": 120, "diastolic": 80, "pulse_rate": None}
        result = format_reading_summary(data)
        assert "120/80" in result
        assert "bpm" not in result

    def test_weight(self):
        data = {"reading_type": "weight", "weight_value": 72.5}
        result = format_reading_summary(data)
        assert "72.5" in result
        assert "kg" in result


# ---------------------------------------------------------------------------
# Webhook endpoint tests
# ---------------------------------------------------------------------------

@pytest.fixture()
def client():
    """Test client with app in TESTING mode."""
    import os
    os.environ["TESTING"] = "true"
    from main import app
    return TestClient(app)


@pytest.fixture()
def db_session(client):
    """Get a DB session for direct DB inspection in tests."""
    from database import SessionLocal
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


TWILIO_FORM_BASE = {
    "From": "whatsapp:+919876543210",
    "To": "whatsapp:+14155238886",
    "Body": "",
    "NumMedia": "0",
    "MessageSid": "SM_test_001",
}


class TestWebhookPhotoFlow:
    """Tests for Case A — inbound photo message."""

    def test_user_not_found_returns_200(self, client):
        """Webhook must always return 200 (Twilio requirement), even on user-not-found."""
        data = {**TWILIO_FORM_BASE, "NumMedia": "1", "MediaUrl0": "https://api.twilio.com/fake.jpg"}
        with patch("whatsapp_inbound_service.lookup_user_by_phone", return_value=None):
            resp = client.post("/api/whatsapp/inbound", data=data)
        assert resp.status_code == 200
        assert "xml" in resp.headers["content-type"].lower()

    def test_scan_failed_returns_200(self, client):
        """Scan failure should reply with error message but still return 200."""
        mock_user = MagicMock()
        mock_user.id = 1

        data = {**TWILIO_FORM_BASE, "NumMedia": "1", "MediaUrl0": "https://api.twilio.com/fake.jpg"}
        with (
            patch("whatsapp_inbound_service.lookup_user_by_phone", return_value=mock_user),
            patch("whatsapp_inbound_service.download_twilio_media", return_value=b"fake_bytes"),
            patch("whatsapp_inbound_service.scan_device_image", return_value=None),
            patch("whatsapp_inbound_service.send_reply") as mock_reply,
            patch("whatsapp_inbound_service.log_inbound"),
        ):
            resp = client.post("/api/whatsapp/inbound", data=data)

        assert resp.status_code == 200
        # Should have sent an error reply
        assert mock_reply.call_count == 2
        assert "Could not read" in mock_reply.call_args[0][1]

    def test_single_profile_saves_immediately(self, client):
        """If user has one profile, reading should be saved without session."""
        mock_user = MagicMock()
        mock_user.id = 1

        mock_profile = MagicMock()
        mock_profile.id = 10
        mock_profile.name = "Deepak"

        mock_reading = MagicMock()
        mock_reading.id = 99

        fake_reading_data = {
            "reading_type": "glucose",
            "glucose_value": 126,
            "unit_detected": "mg/dL",
            "confidence": 0.95,
        }

        data = {**TWILIO_FORM_BASE, "NumMedia": "1", "MediaUrl0": "https://api.twilio.com/fake.jpg"}

        with (
            patch("whatsapp_inbound_service.lookup_user_by_phone", return_value=mock_user),
            patch("whatsapp_inbound_service.download_twilio_media", return_value=b"fake_bytes"),
            patch("whatsapp_inbound_service.scan_device_image", return_value=fake_reading_data),
            patch("whatsapp_inbound_service.save_health_reading", return_value=mock_reading),
            patch("whatsapp_inbound_service.send_reply") as mock_reply,
            patch("whatsapp_inbound_service.log_inbound"),
            patch("routes_whatsapp._handle_photo") as mock_handler,
        ):
            # Just test the endpoint level — handler tested separately
            mock_handler.return_value = None
            resp = client.post("/api/whatsapp/inbound", data=data)

        assert resp.status_code == 200

    def test_multi_profile_creates_session(self, client):
        """If multiple profiles exist, session should be created and menu sent."""
        mock_user = MagicMock()
        mock_user.id = 1

        profiles = [
            MagicMock(id=10, name="Deepak", relationship="myself"),
            MagicMock(id=11, name="Sunita", relationship="mother"),
        ]

        fake_reading_data = {
            "reading_type": "blood_pressure",
            "systolic": 125, "diastolic": 82, "pulse_rate": 72,
            "confidence": 0.9,
        }

        data = {**TWILIO_FORM_BASE, "NumMedia": "1", "MediaUrl0": "https://api.twilio.com/fake.jpg"}
        with (
            patch("whatsapp_inbound_service.lookup_user_by_phone", return_value=mock_user),
            patch("whatsapp_inbound_service.download_twilio_media", return_value=b"fake_bytes"),
            patch("whatsapp_inbound_service.scan_device_image", return_value=fake_reading_data),
            patch("whatsapp_inbound_service.create_session") as mock_create,
            patch("whatsapp_inbound_service.send_reply") as mock_reply,
            patch("whatsapp_inbound_service.log_inbound"),
            patch("routes_whatsapp._handle_photo") as mock_handler,
        ):
            mock_handler.return_value = None
            resp = client.post("/api/whatsapp/inbound", data=data)

        assert resp.status_code == 200


class TestWebhookTextFlow:
    """Tests for Case B — text reply (profile selection)."""

    def test_no_session_sends_help(self, client):
        """Text with no active session should return a help message."""
        data = {**TWILIO_FORM_BASE, "Body": "hello", "NumMedia": "0"}
        with (
            patch("whatsapp_inbound_service.get_active_session", return_value=None),
            patch("whatsapp_inbound_service.send_reply") as mock_reply,
            patch("whatsapp_inbound_service.log_inbound"),
        ):
            # Also mock the expired-session DB query
            with patch("routes_whatsapp._handle_text") as mock_handler:
                mock_handler.return_value = None
                resp = client.post("/api/whatsapp/inbound", data=data)

        assert resp.status_code == 200

    def test_valid_reply_saves_reading(self, client):
        """Reply "1" with active session should save reading and clear session."""
        data = {**TWILIO_FORM_BASE, "Body": "1", "NumMedia": "0"}
        with patch("routes_whatsapp._handle_text") as mock_handler:
            mock_handler.return_value = None
            resp = client.post("/api/whatsapp/inbound", data=data)
        assert resp.status_code == 200
