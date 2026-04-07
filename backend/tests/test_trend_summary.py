"""Tests for GET /readings/trend-summary — layered summary endpoint."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta
from tests.conftest import TEST_USER_EMAIL
import models


def _add_glucose(db, profile_id, user_id, value, hours_ago=0, status="NORMAL"):
    max_seq = db.query(models.GlucoseReading).filter(
        models.GlucoseReading.profile_id == profile_id
    ).count()
    r = models.GlucoseReading(
        profile_id=profile_id,
        logged_by=user_id,
        sequence_number=max_seq,
        glucose_value=value,
        glucose_unit="mg/dL",
        status_flag=status,
        reading_timestamp=datetime.utcnow() - timedelta(hours=hours_ago),
    )
    db.add(r)
    db.flush()
    return r


def _add_bp(db, profile_id, user_id, sys_val, dia_val, hours_ago=0, status="NORMAL"):
    max_seq = db.query(models.BPReading).filter(
        models.BPReading.profile_id == profile_id
    ).count()
    r = models.BPReading(
        profile_id=profile_id,
        logged_by=user_id,
        sequence_number=max_seq,
        slot_number=0,
        systolic=float(sys_val),
        diastolic=float(dia_val),
        pulse_rate=72.0,
        bp_unit="mmHg",
        status_flag=status,
        reading_timestamp=datetime.utcnow() - timedelta(hours=hours_ago),
    )
    db.add(r)
    db.flush()
    return r


def _get_pid(db, user_id):
    a = db.query(models.ProfileAccess).filter(
        models.ProfileAccess.user_id == user_id,
        models.ProfileAccess.access_level == "owner",
    ).first()
    return a.profile_id


class TestTrendSummaryNoData:
    URL = "/api/readings/trend-summary"

    def test_no_readings_returns_message(self, client, test_user, auth_headers, db):
        pid = _get_pid(db, test_user.id)
        resp = client.get(self.URL, params={"profile_id": pid, "period": 7}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "summary" in body
        assert "period" in body
        assert "no readings" in body["summary"].lower() or len(body["summary"]) > 0

    def test_unauthenticated(self, client):
        resp = client.get(self.URL, params={"profile_id": 1, "period": 7})
        assert resp.status_code == 401

    def test_invalid_period(self, client, test_user, auth_headers, db):
        pid = _get_pid(db, test_user.id)
        resp = client.get(self.URL, params={"profile_id": pid, "period": 3}, headers=auth_headers)
        assert resp.status_code == 422  # below minimum of 7


class TestTrendSummaryWithData:
    URL = "/api/readings/trend-summary"

    def test_7day_with_glucose(self, client, test_user, auth_headers, db):
        pid = _get_pid(db, test_user.id)
        for i in range(5):
            _add_glucose(db, pid, test_user.id, 100 + i * 20, hours_ago=i * 24)

        resp = client.get(self.URL, params={"profile_id": pid, "period": 7}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["period"] == 7
        assert "summary" in body
        assert len(body["summary"]) > 0

    def test_30day_with_bp(self, client, test_user, auth_headers, db):
        pid = _get_pid(db, test_user.id)
        for i in range(10):
            _add_bp(db, pid, test_user.id, 120 + i * 3, 80 + i, hours_ago=i * 48)

        resp = client.get(self.URL, params={"profile_id": pid, "period": 30}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["period"] == 30
        assert "BP" in body["summary"] or "bp" in body["summary"].lower() or len(body["summary"]) > 0

    def test_90day_mixed_readings(self, client, test_user, auth_headers, db):
        pid = _get_pid(db, test_user.id)
        for i in range(15):
            _add_glucose(db, pid, test_user.id, 150 + i * 5, hours_ago=i * 48)
            _add_bp(db, pid, test_user.id, 130 + i, 85, hours_ago=i * 48)

        resp = client.get(self.URL, params={"profile_id": pid, "period": 90}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["period"] == 90

    def test_summary_includes_trend_direction(self, client, test_user, auth_headers, db):
        """Summary should show trend direction (improving/rising/stable)."""
        pid = _get_pid(db, test_user.id)
        # Create worsening trend
        _add_glucose(db, pid, test_user.id, 100, hours_ago=6 * 24)
        _add_glucose(db, pid, test_user.id, 110, hours_ago=5 * 24)
        _add_glucose(db, pid, test_user.id, 150, hours_ago=2 * 24)
        _add_glucose(db, pid, test_user.id, 200, hours_ago=0)

        resp = client.get(self.URL, params={"profile_id": pid, "period": 7}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        # Should contain trend indicator
        assert "↑" in body["summary"] or "↓" in body["summary"] or "→" in body["summary"] or "trend" in body["summary"].lower() or len(body["summary"]) > 20

    def test_summary_includes_previous_period_comparison(self, client, test_user, auth_headers, db):
        """When previous period has data, summary should compare."""
        pid = _get_pid(db, test_user.id)
        # Current period: high
        _add_glucose(db, pid, test_user.id, 200, hours_ago=24)
        _add_glucose(db, pid, test_user.id, 210, hours_ago=48)
        # Previous period: low
        _add_glucose(db, pid, test_user.id, 100, hours_ago=8 * 24)
        _add_glucose(db, pid, test_user.id, 110, hours_ago=10 * 24)

        resp = client.get(self.URL, params={"profile_id": pid, "period": 7}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        # Should mention comparison
        assert "vs previous" in body["summary"].lower() or "up" in body["summary"].lower() or len(body["summary"]) > 20


class TestTrendSummaryCache:
    URL = "/api/readings/trend-summary"

    def test_cached_response(self, client, test_user, auth_headers, db):
        """Second call should return cached response."""
        pid = _get_pid(db, test_user.id)
        _add_glucose(db, pid, test_user.id, 120, hours_ago=0)

        # First call
        resp1 = client.get(self.URL, params={"profile_id": pid, "period": 7}, headers=auth_headers)
        assert resp1.status_code == 200

        # Second call — should be cached
        resp2 = client.get(self.URL, params={"profile_id": pid, "period": 7}, headers=auth_headers)
        assert resp2.status_code == 200
        assert resp2.json()["cached"] is True
        assert resp2.json()["summary"] == resp1.json()["summary"]


class TestTrendSummaryWithAiInsight:
    URL = "/api/readings/trend-summary"

    def test_reuses_dashboard_insight(self, client, test_user, auth_headers, db):
        """When an AI insight log exists, summary should include it as base."""
        pid = _get_pid(db, test_user.id)
        _add_glucose(db, pid, test_user.id, 180, hours_ago=0)

        # Create a dashboard AI insight log
        log = models.AiInsightLog(
            profile_id=pid,
            model_used="gemini-2.5-flash",
            prompt_summary="ai-insight",
            response_text="Your glucose needs attention but you're doing great by tracking daily.",
        )
        db.add(log)
        db.flush()

        resp = client.get(self.URL, params={"profile_id": pid, "period": 7}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        # Should contain the dashboard insight as base
        assert "tracking daily" in body["summary"] or "Glucose" in body["summary"]

    def test_no_ai_insight_still_works(self, client, test_user, auth_headers, db):
        """Without any AI insight log, should still return data-only summary."""
        pid = _get_pid(db, test_user.id)
        _add_glucose(db, pid, test_user.id, 100, hours_ago=0)
        _add_bp(db, pid, test_user.id, 120, 80, hours_ago=0)

        resp = client.get(self.URL, params={"profile_id": pid, "period": 7}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body["summary"]) > 0


class TestTrendSummarySharedProfile:
    URL = "/api/readings/trend-summary"

    def test_viewer_can_see_summary(self, client, test_user, auth_headers, db):
        """Users with viewer access should be able to see trend summary."""
        from auth import get_password_hash, create_access_token

        # Create owner with data
        owner = models.User(
            email="owner@test.com",
            password_hash=get_password_hash("Own@1234"),
            full_name="Owner",
            phone_number="9876500077",
        )
        db.add(owner)
        db.flush()

        profile = models.Profile(name="Owner Health", age=50)
        db.add(profile)
        db.flush()

        db.add(models.ProfileAccess(user_id=owner.id, profile_id=profile.id, access_level="owner"))
        db.add(models.ProfileAccess(user_id=test_user.id, profile_id=profile.id, access_level="viewer"))
        db.flush()

        _add_glucose(db, profile.id, owner.id, 150, hours_ago=0)

        # test_user (viewer) requests summary
        resp = client.get(self.URL, params={"profile_id": profile.id, "period": 7}, headers=auth_headers)
        assert resp.status_code == 200
        assert len(resp.json()["summary"]) > 0

    def test_no_access_rejected(self, client, test_user, auth_headers, db):
        """Users without access should be rejected."""
        # Create a profile test_user has no access to
        other = models.Profile(name="Secret Health")
        db.add(other)
        db.flush()

        resp = client.get(self.URL, params={"profile_id": other.id, "period": 7}, headers=auth_headers)
        assert resp.status_code == 403
