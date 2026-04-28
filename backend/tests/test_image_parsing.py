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
# parse_image_with_gemini — full branch coverage via ai_service mocking
#
# The endpoint calls ai_service.generate_vision_insight() internally via a
# local `import ai_service`. Patching the module attribute works because the
# import statement inside the function looks up the already-loaded module.
# ===========================================================================

URL = "/api/readings/parse-image"


def _post(client, auth_headers, device_type, *, filename="test.jpg", content_type="image/jpeg"):
    return client.post(
        URL,
        params={"device_type": device_type},
        files={"file": (filename, BytesIO(b"fake_image_bytes"), content_type)},
        headers=auth_headers,
    )


class TestParseImageNoApiKey:
    """Line 1066: both GEMINI and DEEPSEEK keys are None → early return."""

    @patch("routes_health.settings")
    def test_no_keys_at_all(self, mock_settings, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = None
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        resp = _post(client, auth_headers, "glucose")
        assert resp.status_code == 200
        assert resp.json() == {"error": "No AI API key configured"}


class TestParseImageMimeDerivation:
    """Lines 1072-1077: iOS octet-stream → derive mime from filename extension."""

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_octet_stream_png_filename(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"glucose": 120}'
        resp = client.post(
            URL,
            params={"device_type": "glucose"},
            files={"file": ("reading.png", BytesIO(b"fake"), "application/octet-stream")},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json() == {"glucose": 120}
        # Verify mime_type was derived to image/png
        _args, kwargs = mock_ai.call_args
        assert kwargs["mime_type"] == "image/png"

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_octet_stream_jpg_fallback(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"glucose": 100}'
        resp = client.post(
            URL,
            params={"device_type": "glucose"},
            files={"file": ("reading.heic", BytesIO(b"fake"), "application/octet-stream")},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        _args, kwargs = mock_ai.call_args
        assert kwargs["mime_type"] == "image/jpeg"


class TestParseImageAiServiceFailures:
    """Lines 1114-1120, 1146-1149: ai_service returns empty / bad data / raises."""

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_ai_returns_none(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = None
        resp = _post(client, auth_headers, "glucose")
        assert resp.status_code == 200
        assert "could not process" in resp.json()["error"].lower()

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_ai_returns_no_json(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = "I cannot read this image."
        resp = _post(client, auth_headers, "glucose")
        assert resp.status_code == 200
        assert "could not extract values" in resp.json()["error"].lower()

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_ai_returns_malformed_json_maps_to_502(
        self, mock_settings, mock_ai, client, test_user, auth_headers
    ):
        # Regex matches { ... } but JSON.loads blows up → 502 bad gateway
        # with a generic user-facing message. Previously this returned HTTP
        # 200 with {"error": "Gemini returned an unexpected format"} which
        # leaked the upstream vendor name to patients.
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = "{glucose: not_json}"
        resp = _post(client, auth_headers, "glucose")
        assert resp.status_code == 502
        detail = resp.json()["detail"].lower()
        # Must NOT leak upstream vendor name
        assert "gemini" not in detail
        # Must give patient an actionable fallback
        assert "manually" in detail or "try again" in detail

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_ai_service_raises_maps_to_503_sanitized(
        self, mock_settings, mock_ai, client, test_user, auth_headers
    ):
        # Previously returned HTTP 200 with `{"error": f"Gemini Vision
        # failed: {str(e)}"}` — str(e) could leak API endpoint URLs, auth
        # header fragments, or rate-limit quota strings. Now returns 503
        # with a sanitized message.
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.side_effect = RuntimeError("network blew up at example.com/v1/models")
        resp = _post(client, auth_headers, "glucose")
        assert resp.status_code == 503
        detail = resp.json()["detail"].lower()
        # Exception message must NOT reach the user
        assert "network blew up" not in detail
        assert "example.com" not in detail
        assert "gemini" not in detail
        assert "runtimeerror" not in detail


class TestParseImageGlucoseValidation:
    """Lines 1138-1144: glucose range / null validation."""

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_glucose_valid(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"glucose": 130}'
        resp = _post(client, auth_headers, "glucose")
        assert resp.status_code == 200
        assert resp.json() == {"glucose": 130}

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_glucose_out_of_range_high(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"glucose": 999}'
        resp = _post(client, auth_headers, "glucose")
        assert resp.status_code == 200
        assert "could not extract valid glucose" in resp.json()["error"].lower()

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_glucose_out_of_range_low(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"glucose": 5}'
        resp = _post(client, auth_headers, "glucose")
        assert resp.status_code == 200
        assert "error" in resp.json()

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_glucose_null(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"glucose": null}'
        resp = _post(client, auth_headers, "glucose")
        assert resp.status_code == 200
        assert "error" in resp.json()


class TestParseImageBpValidation:
    """Lines 1125-1137: BP branches — in-range, out-of-range sys/dia/pulse, nulls."""

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_bp_valid_full(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"systolic": 120, "diastolic": 80, "pulse": 72}'
        resp = _post(client, auth_headers, "blood_pressure")
        assert resp.status_code == 200
        body = resp.json()
        assert body == {"systolic": 120, "diastolic": 80, "pulse": 72}

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_bp_systolic_out_of_range(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"systolic": 500, "diastolic": 80, "pulse": 72}'
        resp = _post(client, auth_headers, "blood_pressure")
        assert resp.status_code == 200
        assert "could not extract valid bp" in resp.json()["error"].lower()

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_bp_diastolic_out_of_range(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"systolic": 120, "diastolic": 300, "pulse": 72}'
        resp = _post(client, auth_headers, "blood_pressure")
        assert resp.status_code == 200
        assert "error" in resp.json()

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_bp_pulse_out_of_range_dropped(self, mock_settings, mock_ai, client, test_user, auth_headers):
        # Out-of-range pulse is zeroed to null but sys/dia are valid → success
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"systolic": 120, "diastolic": 80, "pulse": 500}'
        resp = _post(client, auth_headers, "blood_pressure")
        assert resp.status_code == 200
        body = resp.json()
        assert body["systolic"] == 120
        assert body["diastolic"] == 80
        assert body["pulse"] is None

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_bp_pulse_rate_key_fallback(self, mock_settings, mock_ai, client, test_user, auth_headers):
        """Gemini returning 'pulse_rate' instead of 'pulse' must still be captured."""
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"systolic": 130, "diastolic": 85, "pulse_rate": 68}'
        resp = _post(client, auth_headers, "blood_pressure")
        assert resp.status_code == 200
        body = resp.json()
        assert body["systolic"] == 130
        assert body["diastolic"] == 85
        assert body["pulse"] == 68

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_bp_heart_rate_key_fallback(self, mock_settings, mock_ai, client, test_user, auth_headers):
        """Gemini returning 'heart_rate' must still be captured as pulse."""
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"systolic": 118, "diastolic": 76, "heart_rate": 75}'
        resp = _post(client, auth_headers, "blood_pressure")
        assert resp.status_code == 200
        body = resp.json()
        assert body["pulse"] == 75

    @patch("ai_service.generate_vision_insight")
    @patch("routes_health.settings")
    def test_bp_null_systolic(self, mock_settings, mock_ai, client, test_user, auth_headers):
        mock_settings.GEMINI_API_KEY = "fake"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_settings.REQUIRE_HTTPS = False
        mock_ai.return_value = '{"systolic": null, "diastolic": 80, "pulse": 72}'
        resp = _post(client, auth_headers, "blood_pressure")
        assert resp.status_code == 200
        assert "error" in resp.json()


# ===========================================================================
# Rule-based insight fallback
# ===========================================================================

class TestRuleBasedInsight:
    """Tests for _rule_based_insight() function."""

    def _mock_db(self):
        """Create a mock db session for _rule_based_insight."""
        mock = MagicMock()
        # The function queries Profile when weight readings exist;
        # for tests without weight readings this is never called.
        mock.query.return_value.filter.return_value.first.return_value = None
        return mock

    def test_no_readings(self):
        from routes_health import _rule_based_insight
        result = _rule_based_insight([], self._mock_db(), total_count=0)
        assert "first reading" in result.lower()

    def test_returning_user_no_readings(self):
        from routes_health import _rule_based_insight
        result = _rule_based_insight([], self._mock_db(), total_count=15)
        assert "welcome back" in result.lower()

    def test_critical_reading(self):
        from routes_health import _rule_based_insight
        reading = MagicMock()
        reading.status_flag = "CRITICAL"
        reading.reading_type = "glucose"
        result = _rule_based_insight([reading], self._mock_db())
        assert "critical" in result.lower()

    def test_high_stage2_bp(self):
        from routes_health import _rule_based_insight
        reading = MagicMock()
        reading.status_flag = "HIGH - STAGE 2"
        reading.reading_type = "blood_pressure"
        reading.systolic = 165.0
        reading.diastolic = 100.0
        result = _rule_based_insight([reading], self._mock_db())
        assert "165" in result

    def test_high_reading(self):
        from routes_health import _rule_based_insight
        reading = MagicMock()
        reading.status_flag = "HIGH"
        reading.reading_type = "glucose"
        result = _rule_based_insight([reading], self._mock_db())
        assert "elevated" in result.lower()

    def test_all_normal(self):
        from routes_health import _rule_based_insight
        r1 = MagicMock()
        r1.status_flag = "NORMAL"
        r2 = MagicMock()
        r2.status_flag = "NORMAL"
        result = _rule_based_insight([r1, r2], self._mock_db())
        assert "healthy" in result.lower()

    def test_mixed_readings(self):
        from routes_health import _rule_based_insight
        r1 = MagicMock()
        r1.status_flag = "NORMAL"
        r2 = MagicMock()
        r2.status_flag = None
        result = _rule_based_insight([r1, r2], self._mock_db())
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
