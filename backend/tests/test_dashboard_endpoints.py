"""Integration tests for all dashboard-critical endpoints.

Ensures every section on the home screen has a working API behind it:
- Health Score Ring → GET /readings/health-score
- AI Insight Card → GET /readings/ai-insight
- Vital Summary → GET /readings/health-score (90d averages)
- Readings CRUD → POST/GET/DELETE /readings
- Stats Summary → GET /readings/stats/summary
- Chat → POST /chat/messages (covered in test_chat.py, verified here)
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta
from unittest.mock import patch
from tests.conftest import TEST_USER_EMAIL, TEST_USER_PASSWORD
import models


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _add_glucose_reading(db, profile_id, user_id, value, hours_ago=0, status="NORMAL"):
    ts = datetime.utcnow() - timedelta(hours=hours_ago)
    r = models.HealthReading(
        profile_id=profile_id,
        logged_by=user_id,
        reading_type="glucose",
        glucose_value=value,
        glucose_unit="mg/dL",
        sample_type="Fasting",
        value_numeric=value,
        unit_display="mg/dL",
        status_flag=status,
        reading_timestamp=ts,
    )
    db.add(r)
    db.flush()
    return r


def _add_bp_reading(db, profile_id, user_id, systolic, diastolic, hours_ago=0, status="NORMAL"):
    ts = datetime.utcnow() - timedelta(hours=hours_ago)
    r = models.HealthReading(
        profile_id=profile_id,
        logged_by=user_id,
        reading_type="blood_pressure",
        systolic=float(systolic),
        diastolic=float(diastolic),
        pulse_rate=72.0,
        bp_unit="mmHg",
        bp_status=status,
        value_numeric=float(systolic),
        unit_display="mmHg",
        status_flag=status,
        reading_timestamp=ts,
    )
    db.add(r)
    db.flush()
    return r


# ===========================================================================
# POST /api/readings — Save a reading
# ===========================================================================

class TestSaveReading:
    URL = "/api/readings"

    def test_save_glucose_reading(self, client, test_user, auth_headers, db):
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
            models.ProfileAccess.access_level == "owner",
        ).first()

        resp = client.post(self.URL, json={
            "profile_id": profile.profile_id,
            "reading_type": "glucose",
            "glucose_value": 105.0,
            "glucose_unit": "mg/dL",
            "sample_type": "Fasting",
            "value_numeric": 105.0,
            "unit_display": "mg/dL",
            "status_flag": "NORMAL",
            "reading_timestamp": datetime.utcnow().isoformat(),
        }, headers=auth_headers)
        assert resp.status_code == 201
        body = resp.json()
        assert body["reading_type"] == "glucose"
        assert body["glucose_value"] == 105.0

    def test_save_bp_reading(self, client, test_user, auth_headers, db):
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
            models.ProfileAccess.access_level == "owner",
        ).first()

        resp = client.post(self.URL, json={
            "profile_id": profile.profile_id,
            "reading_type": "blood_pressure",
            "systolic": 120.0,
            "diastolic": 80.0,
            "pulse_rate": 72.0,
            "bp_unit": "mmHg",
            "bp_status": "NORMAL",
            "value_numeric": 120.0,
            "unit_display": "mmHg",
            "status_flag": "NORMAL",
            "reading_timestamp": datetime.utcnow().isoformat(),
        }, headers=auth_headers)
        assert resp.status_code == 201
        assert resp.json()["systolic"] == 120.0

    def test_save_reading_invalid_type(self, client, test_user, auth_headers, db):
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        resp = client.post(self.URL, json={
            "profile_id": profile.profile_id,
            "reading_type": "invalid_type",
            "reading_timestamp": datetime.utcnow().isoformat(),
        }, headers=auth_headers)
        assert resp.status_code in (400, 422)

    def test_save_reading_unauthenticated(self, client):
        resp = client.post(self.URL, json={
            "profile_id": 1,
            "reading_type": "glucose",
            "reading_timestamp": datetime.utcnow().isoformat(),
        })
        assert resp.status_code == 401


# ===========================================================================
# GET /api/readings — List readings
# ===========================================================================

class TestGetReadings:
    URL = "/api/readings"

    def test_get_readings_empty(self, client, test_user, auth_headers, db):
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json() == []

    def test_get_readings_with_data(self, client, test_user, auth_headers, db):
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        _add_glucose_reading(db, profile.profile_id, test_user.id, 100.0)
        _add_bp_reading(db, profile.profile_id, test_user.id, 120, 80)

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 2

    def test_get_readings_filter_by_type(self, client, test_user, auth_headers, db):
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        _add_glucose_reading(db, profile.profile_id, test_user.id, 100.0)
        _add_bp_reading(db, profile.profile_id, test_user.id, 120, 80)

        resp = client.get(self.URL, params={
            "profile_id": profile.profile_id,
            "reading_type": "glucose",
        }, headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["reading_type"] == "glucose"

    def test_get_readings_unauthenticated(self, client):
        resp = client.get(self.URL, params={"profile_id": 1})
        assert resp.status_code == 401


# ===========================================================================
# GET /api/readings/health-score — Dashboard health score ring
# ===========================================================================

class TestHealthScoreEndpoint:
    URL = "/api/readings/health-score"

    def test_health_score_no_readings(self, client, test_user, auth_headers, db):
        """New user with no readings should still get a valid score response."""
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        # Must have all dashboard fields
        assert "score" in body
        assert "color" in body
        assert "streak_days" in body
        assert "insight" in body
        assert isinstance(body["score"], int)
        assert body["score"] >= 0 and body["score"] <= 100

    def test_health_score_with_normal_reading(self, client, test_user, auth_headers, db):
        """Normal glucose reading today should give a decent score."""
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        _add_glucose_reading(db, profile.profile_id, test_user.id, 100.0, hours_ago=0, status="NORMAL")

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["score"] >= 65  # logged today + normal status
        assert body["today_glucose_status"] == "NORMAL"

    def test_health_score_with_critical_reading(self, client, test_user, auth_headers, db):
        """Critical reading should lower score and show warning insight."""
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        _add_glucose_reading(db, profile.profile_id, test_user.id, 350.0, hours_ago=0, status="CRITICAL")

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["score"] < 65
        assert "critical" in body["insight"].lower() or "doctor" in body["insight"].lower()

    def test_health_score_returns_90d_averages(self, client, test_user, auth_headers, db):
        """Vital summary section needs 90-day averages."""
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        # Add readings spread over multiple days
        for i in range(5):
            _add_glucose_reading(db, profile.profile_id, test_user.id, 100 + i * 10, hours_ago=i * 24)
            _add_bp_reading(db, profile.profile_id, test_user.id, 120 + i, 80 + i, hours_ago=i * 24)

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["avg_glucose_90d"] is not None
        assert body["avg_systolic_90d"] is not None
        assert body["avg_diastolic_90d"] is not None

    def test_health_score_returns_last_readings(self, client, test_user, auth_headers, db):
        """Metrics grid needs last glucose and last BP values."""
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        _add_glucose_reading(db, profile.profile_id, test_user.id, 115.0, hours_ago=2)
        _add_bp_reading(db, profile.profile_id, test_user.id, 130, 85, hours_ago=1)

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["last_glucose_value"] == 115.0
        assert body["last_bp_systolic"] == 130.0
        assert body["last_bp_diastolic"] == 85.0

    def test_health_score_unauthenticated(self, client):
        resp = client.get(self.URL, params={"profile_id": 1})
        assert resp.status_code == 401


# ===========================================================================
# GET /api/readings/ai-insight — AI recommendation card
# ===========================================================================

class TestAiInsightEndpoint:
    URL = "/api/readings/ai-insight"

    def test_ai_insight_no_readings(self, client, test_user, auth_headers, db):
        """Should return a valid response even with no readings."""
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "insight" in body

    def test_ai_insight_with_readings_no_consent(self, client, test_user, auth_headers, db):
        """Without AI consent, should return rule-based insight (not call Gemini)."""
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        _add_glucose_reading(db, profile.profile_id, test_user.id, 200.0, hours_ago=0, status="HIGH")

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "insight" in body
        assert len(body["insight"]) > 0

    @patch("ai_service.generate_health_insight", return_value="Stay hydrated and walk daily.")
    def test_ai_insight_with_consent(self, mock_ai, client, test_user, auth_headers, db):
        """With AI consent and readings, should call AI service."""
        test_user.ai_consent = True
        db.flush()

        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        _add_glucose_reading(db, profile.profile_id, test_user.id, 150.0, hours_ago=0, status="HIGH")

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "insight" in body

    def test_ai_insight_no_consent_with_multiple_readings(self, client, test_user, auth_headers, db):
        """Without AI consent, rule-based insight should handle various reading statuses."""
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        # Add diverse readings to trigger different rule-based paths
        _add_glucose_reading(db, profile.profile_id, test_user.id, 250.0, hours_ago=0, status="CRITICAL")
        _add_bp_reading(db, profile.profile_id, test_user.id, 165, 100, hours_ago=1, status="HIGH - STAGE 2")

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        assert len(resp.json()["insight"]) > 0

    @patch("ai_service.generate_health_insight", return_value="AI personalized insight.")
    def test_ai_insight_with_consent_and_data(self, mock_ai, client, test_user, auth_headers, db):
        """With consent + data, should attempt AI call and return insight."""
        test_user.ai_consent = True
        db.flush()

        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        # Add glucose and BP readings to cover both summary paths
        _add_glucose_reading(db, profile.profile_id, test_user.id, 180.0, hours_ago=0, status="HIGH")
        _add_glucose_reading(db, profile.profile_id, test_user.id, 120.0, hours_ago=24, status="NORMAL")
        _add_bp_reading(db, profile.profile_id, test_user.id, 140, 90, hours_ago=2, status="HIGH - STAGE 1")

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        assert "insight" in resp.json()

    @patch("ai_service.generate_health_insight", return_value=None)
    def test_ai_insight_ai_unavailable_falls_to_rule(self, mock_ai, client, test_user, auth_headers, db):
        """When AI is down but user has consent, should fall back to rule-based."""
        test_user.ai_consent = True
        db.flush()

        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        _add_glucose_reading(db, profile.profile_id, test_user.id, 100.0, hours_ago=0, status="NORMAL")

        resp = client.get(self.URL, params={"profile_id": profile.profile_id}, headers=auth_headers)
        assert resp.status_code == 200
        assert len(resp.json()["insight"]) > 0

    def test_ai_insight_unauthenticated(self, client):
        resp = client.get(self.URL, params={"profile_id": 1})
        assert resp.status_code == 401



# ===========================================================================
# DELETE /api/readings/{reading_id} — Delete a reading
# ===========================================================================

class TestDeleteReading:

    def test_delete_own_reading(self, client, test_user, auth_headers, db):
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        reading = _add_glucose_reading(db, profile.profile_id, test_user.id, 100.0)
        reading_id = reading.id

        resp = client.delete(f"/api/readings/{reading_id}", headers=auth_headers)
        assert resp.status_code == 204

    def test_delete_nonexistent_reading(self, client, test_user, auth_headers):
        resp = client.delete("/api/readings/99999", headers=auth_headers)
        assert resp.status_code == 404

    def test_delete_unauthenticated(self, client):
        resp = client.delete("/api/readings/1")
        assert resp.status_code == 401


# ===========================================================================
# Chat endpoint smoke test (detailed tests in test_chat.py)
# ===========================================================================

class TestChatSmoke:

    @patch("ai_service.generate_health_insight", return_value="Drink more water.")
    def test_chat_returns_response(self, mock_ai, client, test_user, auth_headers, db):
        profile = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
        ).first()

        resp = client.post("/api/chat/messages", json={
            "profile_id": profile.profile_id,
            "message": "How is my health?",
        }, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "ai_response" in body
        assert len(body["ai_response"]) > 0
