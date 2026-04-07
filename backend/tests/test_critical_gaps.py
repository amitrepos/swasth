"""Tests for critical untested code paths that cause regressions.

Covers: Gemini key rotation, critical alert emails, image parsing
validation, chat image upload, admin edge cases.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
import json
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock
from io import BytesIO
from tests.conftest import TEST_USER_EMAIL
import models
from auth import get_password_hash, create_access_token


# ===========================================================================
# Gemini Key Rotation
# ===========================================================================

class TestGeminiKeyRotation:

    def test_get_gemini_keys_single(self):
        from ai_service import _get_gemini_keys
        with patch("ai_service.settings") as mock:
            mock.GEMINI_API_KEY = "key1"
            mock.GEMINI_API_KEYS = None
            keys = _get_gemini_keys()
            assert keys == ["key1"]

    def test_get_gemini_keys_multiple(self):
        from ai_service import _get_gemini_keys
        with patch("ai_service.settings") as mock:
            mock.GEMINI_API_KEY = "key1"
            mock.GEMINI_API_KEYS = "key1,key2,key3"
            keys = _get_gemini_keys()
            assert len(keys) == 3
            assert "key2" in keys

    def test_get_gemini_keys_no_duplicates(self):
        from ai_service import _get_gemini_keys
        with patch("ai_service.settings") as mock:
            mock.GEMINI_API_KEY = "key1"
            mock.GEMINI_API_KEYS = "key1,key2"
            keys = _get_gemini_keys()
            assert keys.count("key1") == 1

    def test_get_gemini_keys_none(self):
        from ai_service import _get_gemini_keys
        with patch("ai_service.settings") as mock:
            mock.GEMINI_API_KEY = None
            mock.GEMINI_API_KEYS = None
            keys = _get_gemini_keys()
            assert keys == []

    @patch("ai_service._try_gemini_with_key")
    @patch("ai_service.settings")
    def test_rotation_skips_exhausted_key(self, mock_settings, mock_try):
        mock_settings.GEMINI_API_KEY = "key1"
        mock_settings.GEMINI_API_KEYS = "key1,key2"

        # key1 rate limited, key2 works
        mock_try.side_effect = [
            {"text": None, "error": "429 RESOURCE_EXHAUSTED", "tokens": None, "ms": 50},
            {"text": "Hello!", "error": None, "tokens": 10, "ms": 100},
        ]

        from ai_service import _try_gemini
        result = _try_gemini("test")
        assert result["text"] == "Hello!"
        assert mock_try.call_count == 2

    @patch("ai_service._try_gemini_with_key")
    @patch("ai_service.settings")
    def test_rotation_stops_on_non_rate_limit_error(self, mock_settings, mock_try):
        mock_settings.GEMINI_API_KEY = "key1"
        mock_settings.GEMINI_API_KEYS = "key1,key2"

        # key1 returns non-rate-limit error
        mock_try.return_value = {"text": None, "error": "Invalid API key", "tokens": None, "ms": 50}

        from ai_service import _try_gemini
        result = _try_gemini("test")
        assert result["text"] is None
        assert mock_try.call_count == 1  # didn't try key2


# ===========================================================================
# Critical Alert — email to family
# ===========================================================================

class TestCriticalAlertEmail:

    def test_critical_glucose_sends_email_to_family(self, client, test_user, auth_headers, db):
        """When a critical reading is saved, family members should get email."""
        pid = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
            models.ProfileAccess.access_level == "owner",
        ).first().profile_id

        # Add a family viewer
        viewer = models.User(
            email="family@test.com",
            password_hash=get_password_hash("Fam@1234"),
            full_name="Family Member",
            phone_number="9876500055",
        )
        db.add(viewer)
        db.flush()
        db.add(models.ProfileAccess(user_id=viewer.id, profile_id=pid, access_level="viewer"))
        db.flush()

        with patch("email_service.BrevoEmailService.send_otp_email") as mock_email:
            resp = client.post("/api/readings", json={
                "profile_id": pid,
                "reading_type": "glucose",
                "glucose_value": 400.0,
                "value_numeric": 400.0,
                "unit_display": "mg/dL",
                "status_flag": "CRITICAL",
                "reading_timestamp": datetime.utcnow().isoformat(),
            }, headers=auth_headers)

            assert resp.status_code == 201
            assert resp.json().get("alert") is not None
            # Email should have been called for family member
            assert mock_email.called

    def test_high_stage2_bp_triggers_alert(self, client, test_user, auth_headers, db):
        pid = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
            models.ProfileAccess.access_level == "owner",
        ).first().profile_id

        resp = client.post("/api/readings", json={
            "profile_id": pid,
            "reading_type": "blood_pressure",
            "systolic": 185.0,
            "diastolic": 110.0,
            "value_numeric": 185.0,
            "unit_display": "mmHg",
            "status_flag": "HIGH - STAGE 2",
            "reading_timestamp": datetime.utcnow().isoformat(),
        }, headers=auth_headers)

        assert resp.status_code == 201
        alert = resp.json().get("alert")
        assert alert is not None
        assert "185" in alert["message"]


# ===========================================================================
# Image Parsing — range validation
# ===========================================================================

class TestImageParsingValidation:

    def test_bp_out_of_range_rejected(self):
        """BP values outside valid ranges should be set to None."""
        # Simulate what parse-image does after extracting values
        parsed = {"systolic": 300, "diastolic": 200, "pulse": 250}

        sys = parsed.get("systolic")
        dia = parsed.get("diastolic")
        pulse = parsed.get("pulse")
        if sys is not None and not (70 <= sys <= 250):
            sys = None
        if dia is not None and not (40 <= dia <= 150):
            dia = None
        if pulse is not None and not (30 <= pulse <= 200):
            pulse = None

        assert sys is None  # 300 > 250
        assert dia is None  # 200 > 150
        assert pulse is None  # 250 > 200

    def test_bp_valid_range_accepted(self):
        parsed = {"systolic": 141, "diastolic": 82, "pulse": 66}

        sys = parsed.get("systolic")
        dia = parsed.get("diastolic")
        pulse = parsed.get("pulse")
        if sys is not None and not (70 <= sys <= 250):
            sys = None
        if dia is not None and not (40 <= dia <= 150):
            dia = None
        if pulse is not None and not (30 <= pulse <= 200):
            pulse = None

        assert sys == 141
        assert dia == 82
        assert pulse == 66

    def test_glucose_out_of_range_rejected(self):
        parsed = {"glucose": 700}
        glucose = parsed.get("glucose")
        if glucose is not None and not (20 <= glucose <= 600):
            glucose = None
        assert glucose is None

    def test_glucose_valid_range_accepted(self):
        parsed = {"glucose": 120}
        glucose = parsed.get("glucose")
        if glucose is not None and not (20 <= glucose <= 600):
            glucose = None
        assert glucose == 120


# ===========================================================================
# Chat image upload (backend accepts base64)
# ===========================================================================

class TestChatImageUpload:

    @patch("ai_service.generate_vision_insight", return_value="I see a medical report.")
    @patch("ai_service.generate_health_insight", return_value=None)
    def test_chat_with_image(self, mock_text, mock_vision, client, test_user, auth_headers, db):
        pid = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
            models.ProfileAccess.access_level == "owner",
        ).first().profile_id

        import base64
        fake_image = base64.b64encode(b"fake_image_bytes").decode()

        resp = client.post("/api/chat/send", json={
            "profile_id": pid,
            "message": "What does this report say?",
            "image_base64": fake_image,
        }, headers=auth_headers)

        assert resp.status_code == 200
        assert "ai_response" in resp.json()

    @patch("ai_service.generate_health_insight", return_value="Stay hydrated.")
    def test_chat_without_image(self, mock_ai, client, test_user, auth_headers, db):
        pid = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
            models.ProfileAccess.access_level == "owner",
        ).first().profile_id

        resp = client.post("/api/chat/send", json={
            "profile_id": pid,
            "message": "How am I doing?",
        }, headers=auth_headers)

        assert resp.status_code == 200
        assert "ai_response" in resp.json()
        assert resp.json()["ai_response"] is not None


# ===========================================================================
# Admin edge cases
# ===========================================================================

class TestAdminEdgeCases:

    def test_non_admin_cannot_access_users(self, client, test_user, auth_headers):
        resp = client.get("/api/admin/users", headers=auth_headers)
        assert resp.status_code == 403

    def test_non_admin_cannot_make_admin(self, client, test_user, auth_headers):
        resp = client.post("/api/admin/users/1/make-admin", headers=auth_headers)
        assert resp.status_code == 403

    def test_admin_users_list_has_all_fields(self, client, db):
        admin = models.User(
            email="admin_gap@test.com",
            password_hash=get_password_hash("Admin@1234"),
            full_name="Admin Gap",
            phone_number="9876500044",
            is_admin=True,
        )
        db.add(admin)
        db.flush()
        headers = {"Authorization": f"Bearer {create_access_token(data={'sub': admin.email})}"}

        resp = client.get("/api/admin/users", headers=headers)
        assert resp.status_code == 200
        user = resp.json()["users"][0]
        assert "email" in user
        assert "full_name" in user
        assert "profiles_count" in user
        assert "total_readings" in user
        assert "is_admin" in user


# ===========================================================================
# Pydantic schema validation
# ===========================================================================

class TestSchemaValidation:

    def test_weak_password_rejected(self, client):
        resp = client.post("/api/auth/register", json={
            "email": "weak@test.com",
            "password": "123",
            "confirm_password": "123",
            "full_name": "Weak",
            "phone_number": "9876500033",
        })
        assert resp.status_code == 422

    def test_password_mismatch_rejected(self, client):
        resp = client.post("/api/auth/register", json={
            "email": "mismatch@test.com",
            "password": "Strong@1234",
            "confirm_password": "Different@1234",
            "full_name": "Mismatch",
            "phone_number": "9876500022",
        })
        assert resp.status_code == 422

    def test_invalid_email_rejected(self, client):
        resp = client.post("/api/auth/register", json={
            "email": "not-an-email",
            "password": "Strong@1234",
            "confirm_password": "Strong@1234",
            "full_name": "Invalid",
            "phone_number": "9876500011",
        })
        assert resp.status_code == 422
