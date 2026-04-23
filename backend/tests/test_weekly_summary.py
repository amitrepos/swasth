"""Tests for GET /readings/weekly-summary endpoint."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta
import models


def _add_reading(db, pid, uid, rtype, value, hours_ago=0):
    r = models.HealthReading(
        profile_id=pid, logged_by=uid, reading_type=rtype,
        glucose_value=value if rtype == "glucose" else None,
        systolic=value if rtype == "blood_pressure" else None,
        diastolic=(value - 40) if rtype == "blood_pressure" else None,
        value_numeric=value, unit_display="mg/dL" if rtype == "glucose" else "mmHg",
        status_flag="NORMAL", reading_timestamp=datetime.utcnow() - timedelta(hours=hours_ago),
    )
    db.add(r)
    db.flush()


def _pid(db, uid):
    return db.query(models.ProfileAccess).filter(
        models.ProfileAccess.user_id == uid, models.ProfileAccess.access_level == "owner",
    ).first().profile_id


class TestWeeklySummary:
    URL = "/api/readings/weekly-summary"

    def test_empty_summary(self, client, test_user, auth_headers, db):
        pid = _pid(db, test_user.id)
        resp = client.get(self.URL, params={"profile_id": pid}, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "summary_text" in body
        assert body["total_readings"] == 0
        assert body["days_logged"] == 0

    def test_summary_with_glucose(self, client, test_user, auth_headers, db):
        pid = _pid(db, test_user.id)
        _add_reading(db, pid, test_user.id, "glucose", 120, hours_ago=0)
        _add_reading(db, pid, test_user.id, "glucose", 140, hours_ago=24)

        resp = client.get(self.URL, params={"profile_id": pid}, headers=auth_headers)
        body = resp.json()
        assert body["glucose_count"] == 2
        assert body["glucose_avg"] == 130.0
        assert "Glucose" in body["summary_text"]

    def test_summary_with_bp(self, client, test_user, auth_headers, db):
        pid = _pid(db, test_user.id)
        _add_reading(db, pid, test_user.id, "blood_pressure", 130, hours_ago=0)

        resp = client.get(self.URL, params={"profile_id": pid}, headers=auth_headers)
        body = resp.json()
        assert body["bp_count"] == 1
        assert "Blood Pressure" in body["summary_text"]

    def test_summary_shareable_text(self, client, test_user, auth_headers, db):
        pid = _pid(db, test_user.id)
        _add_reading(db, pid, test_user.id, "glucose", 100, hours_ago=0)

        resp = client.get(self.URL, params={"profile_id": pid}, headers=auth_headers)
        text = resp.json()["summary_text"]
        assert "Weekly Health Summary" in text
        assert "Swasth" in text

    def test_summary_unauthenticated(self, client):
        resp = client.get(self.URL, params={"profile_id": 1})
        assert resp.status_code == 401

    def test_summary_unauthorized_profile(self, client, test_user, auth_headers, db):
        other = models.Profile(name="Secret", phone_number="9876543211")
        db.add(other)
        db.flush()
        resp = client.get(self.URL, params={"profile_id": other.id}, headers=auth_headers)
        assert resp.status_code == 403
