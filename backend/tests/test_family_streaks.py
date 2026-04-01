"""Tests for GET /readings/family-streaks — leaderboard + weekly calendar."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta
from tests.conftest import TEST_USER_EMAIL
import models
from auth import get_password_hash, create_access_token


def _add_reading(db, profile_id, user_id, hours_ago=0):
    r = models.HealthReading(
        profile_id=profile_id,
        logged_by=user_id,
        reading_type="glucose",
        glucose_value=100.0,
        value_numeric=100.0,
        unit_display="mg/dL",
        status_flag="NORMAL",
        reading_timestamp=datetime.utcnow() - timedelta(hours=hours_ago),
    )
    db.add(r)
    db.flush()


def _get_pid(db, user_id):
    a = db.query(models.ProfileAccess).filter(
        models.ProfileAccess.user_id == user_id,
        models.ProfileAccess.access_level == "owner",
    ).first()
    return a.profile_id


class TestFamilyStreaks:
    URL = "/api/readings/family-streaks"

    def test_returns_leaderboard(self, client, test_user, auth_headers, db):
        resp = client.get(self.URL, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "leaderboard" in body
        assert len(body["leaderboard"]) >= 1

    def test_own_profile_in_board(self, client, test_user, auth_headers, db):
        pid = _get_pid(db, test_user.id)
        resp = client.get(self.URL, headers=auth_headers)
        profiles = [e["profile_id"] for e in resp.json()["leaderboard"]]
        assert pid in profiles

    def test_streak_calculated(self, client, test_user, auth_headers, db):
        pid = _get_pid(db, test_user.id)
        # Add readings for today and yesterday
        _add_reading(db, pid, test_user.id, hours_ago=0)
        _add_reading(db, pid, test_user.id, hours_ago=24)

        resp = client.get(self.URL, headers=auth_headers)
        entry = next(e for e in resp.json()["leaderboard"] if e["profile_id"] == pid)
        assert entry["streak_days"] >= 2

    def test_points_cumulative(self, client, test_user, auth_headers, db):
        pid = _get_pid(db, test_user.id)
        _add_reading(db, pid, test_user.id, hours_ago=0)

        resp = client.get(self.URL, headers=auth_headers)
        entry = next(e for e in resp.json()["leaderboard"] if e["profile_id"] == pid)
        assert entry["points"] >= 10  # at least 10 pts per reading

    def test_week_activity_7_days(self, client, test_user, auth_headers, db):
        resp = client.get(self.URL, headers=auth_headers)
        entry = resp.json()["leaderboard"][0]
        assert len(entry["week_activity"]) == 7
        assert "date" in entry["week_activity"][0]
        assert "weekday" in entry["week_activity"][0]
        assert "has_reading" in entry["week_activity"][0]

    def test_shared_profiles_included(self, client, test_user, auth_headers, db):
        """Profiles shared with the user should appear in the leaderboard."""
        other_user = models.User(
            email="streakowner@test.com",
            password_hash=get_password_hash("Own@1234"),
            full_name="Streak Owner",
            phone_number="9876500066",
        )
        db.add(other_user)
        db.flush()

        other_profile = models.Profile(name="Other Health", age=40)
        db.add(other_profile)
        db.flush()

        db.add(models.ProfileAccess(user_id=other_user.id, profile_id=other_profile.id, access_level="owner"))
        db.add(models.ProfileAccess(user_id=test_user.id, profile_id=other_profile.id, access_level="viewer"))
        db.flush()

        resp = client.get(self.URL, headers=auth_headers)
        profiles = [e["profile_name"] for e in resp.json()["leaderboard"]]
        assert "Other Health" in profiles

    def test_sorted_by_streak(self, client, test_user, auth_headers, db):
        pid = _get_pid(db, test_user.id)
        # Add 3 consecutive days of readings for a good streak
        for i in range(3):
            _add_reading(db, pid, test_user.id, hours_ago=i * 24)

        resp = client.get(self.URL, headers=auth_headers)
        board = resp.json()["leaderboard"]
        # Should be sorted by streak desc
        streaks = [e["streak_days"] for e in board]
        assert streaks == sorted(streaks, reverse=True)

    def test_unauthenticated(self, client):
        resp = client.get(self.URL)
        assert resp.status_code == 401
