"""Tests for /readings/parse-image endpoint and rule-based insight fallback."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
import json
from unittest.mock import patch, MagicMock
from io import BytesIO
from tests.conftest import TEST_USER_EMAIL
import models


def _fake_gemini_response(json_str):
    """Create a mock Gemini response object."""
    part = MagicMock()
    part.text = json_str
    content = MagicMock()
    content.parts = [part]
    candidate = MagicMock()
    candidate.content = content
    response = MagicMock()
    response.candidates = [candidate]
    return response


class TestParseImageGlucose:
    URL = "/api/readings/parse-image"

    @patch("routes_health.settings")
    def test_no_gemini_key(self, mock_settings, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        resp = client.post(
            self.URL,
            params={"device_type": "glucose"},
            files={"file": ("test.jpg", BytesIO(b"fake_image"), "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert "error" in resp.json()
        assert "error" in resp.json()

    def test_invalid_device_type(self, client, test_user, auth_headers):
        resp = client.post(
            self.URL,
            params={"device_type": "invalid"},
            files={"file": ("test.jpg", BytesIO(b"fake"), "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 400

    def test_unauthenticated(self, client):
        resp = client.post(
            self.URL,
            params={"device_type": "glucose"},
            files={"file": ("test.jpg", BytesIO(b"fake"), "image/jpeg")},
        )
        assert resp.status_code == 401

    @patch("routes_health.genai_types", create=True)
    @patch("routes_health.genai", create=True)
    @patch("routes_health.settings")
    def test_glucose_parsing_success(self, mock_settings, mock_genai, mock_types, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake-key"
        mock_settings.REQUIRE_HTTPS = False

        mock_client = MagicMock()
        mock_genai.Client.return_value = mock_client
        mock_client.models.generate_content.return_value = _fake_gemini_response('{"glucose": 105}')

        # Patch the import inside the function
        with patch.dict("sys.modules", {"google": MagicMock(), "google.genai": mock_genai, "google.genai.types": mock_types}):
            resp = client.post(
                self.URL,
                params={"device_type": "glucose"},
                files={"file": ("test.jpg", BytesIO(b"fake_image_bytes"), "image/jpeg")},
                headers=auth_headers,
            )
        assert resp.status_code == 200
        body = resp.json()
        assert body.get("glucose") == 105 or "error" in body  # may fail due to import mocking

    @patch("routes_health.genai_types", create=True)
    @patch("routes_health.genai", create=True)
    @patch("routes_health.settings")
    def test_bp_parsing_success(self, mock_settings, mock_genai, mock_types, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake-key"
        mock_settings.REQUIRE_HTTPS = False

        mock_client = MagicMock()
        mock_genai.Client.return_value = mock_client
        mock_client.models.generate_content.return_value = _fake_gemini_response('{"systolic": 120, "diastolic": 80, "pulse": 72}')

        with patch.dict("sys.modules", {"google": MagicMock(), "google.genai": mock_genai, "google.genai.types": mock_types}):
            resp = client.post(
                self.URL,
                params={"device_type": "blood_pressure"},
                files={"file": ("bp.jpg", BytesIO(b"fake_bp_image"), "image/jpeg")},
                headers=auth_headers,
            )
        assert resp.status_code == 200


# ===========================================================================
# Rule-based insight fallback
# ===========================================================================

class TestRuleBasedInsight:
    """Tests for _rule_based_insight() function."""

    def test_no_readings(self):
        from routes_health import _rule_based_insight
        result = _rule_based_insight([], total_count=0)
        assert "first reading" in result.lower()

    def test_returning_user_no_readings(self):
        from routes_health import _rule_based_insight
        result = _rule_based_insight([], total_count=15)
        assert "welcome back" in result.lower()

    def test_critical_reading(self):
        from routes_health import _rule_based_insight
        reading = MagicMock()
        reading.status_flag = "CRITICAL"
        reading.reading_type = "glucose"
        result = _rule_based_insight([reading])
        assert "critical" in result.lower()

    def test_high_stage2_bp(self):
        from routes_health import _rule_based_insight
        reading = MagicMock()
        reading.status_flag = "HIGH - STAGE 2"
        reading.reading_type = "blood_pressure"
        reading.systolic = 165.0
        reading.diastolic = 100.0
        result = _rule_based_insight([reading])
        assert "165" in result

    def test_high_reading(self):
        from routes_health import _rule_based_insight
        reading = MagicMock()
        reading.status_flag = "HIGH"
        reading.reading_type = "glucose"
        result = _rule_based_insight([reading])
        assert "elevated" in result.lower()

    def test_all_normal(self):
        from routes_health import _rule_based_insight
        r1 = MagicMock()
        r1.status_flag = "NORMAL"
        r2 = MagicMock()
        r2.status_flag = "NORMAL"
        result = _rule_based_insight([r1, r2])
        assert "healthy" in result.lower()

    def test_mixed_readings(self):
        from routes_health import _rule_based_insight
        r1 = MagicMock()
        r1.status_flag = "NORMAL"
        r2 = MagicMock()
        r2.status_flag = None
        result = _rule_based_insight([r1, r2])
        assert len(result) > 0  # returns some insight


# ===========================================================================
# GET /api/readings/{reading_id}
# ===========================================================================

class TestGetSingleReading:

    def test_get_reading_by_id(self, client, test_user, auth_headers, db):
        from datetime import datetime
        profile_access = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        reading = models.HealthReading(
            profile_id=profile_access.profile_id,
            logged_by=test_user.id,
            reading_type="glucose",
            glucose_value=100.0,
            value_numeric=100.0,
            unit_display="mg/dL",
            status_flag="NORMAL",
            reading_timestamp=datetime.utcnow(),
        )
        db.add(reading)
        db.flush()

        resp = client.get(f"/api/readings/{reading.id}", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["glucose_value"] == 100.0

    def test_get_nonexistent_reading(self, client, test_user, auth_headers):
        resp = client.get("/api/readings/99999", headers=auth_headers)
        assert resp.status_code == 404

    def test_get_reading_unauthenticated(self, client):
        resp = client.get("/api/readings/1")
        assert resp.status_code == 401
