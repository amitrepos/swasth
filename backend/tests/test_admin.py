"""Tests for /api/admin/* endpoints — metrics, user management."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta
from tests.conftest import TEST_USER_EMAIL, TEST_USER_PASSWORD
import models
from auth import get_password_hash, create_access_token


@pytest.fixture()
def admin_user(db):
    """Create an admin user."""
    user = models.User(
        email="admin@swasth.app",
        password_hash=get_password_hash("Admin@1234"),
        full_name="Admin User",
        phone_number="9876500001",
        is_admin=True,
    )
    db.add(user)
    db.flush()
    return user


@pytest.fixture()
def admin_headers(admin_user):
    return {"Authorization": f"Bearer {create_access_token(data={'sub': admin_user.email})}"}


class TestAdminMetrics:
    URL = "/api/admin/metrics"

    def test_admin_can_view_metrics(self, client, admin_user, admin_headers, db):
        resp = client.get(self.URL, headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()

        # Check all metric categories exist
        assert "total_users" in body
        assert "total_profiles" in body
        assert "total_readings" in body
        assert "dau" in body
        assert "mau" in body
        assert "stickiness_pct" in body
        assert "d1_retention_pct" in body
        assert "streak_distribution" in body
        assert "chat_adoption_pct" in body
        assert "ai_fallback_rate_pct" in body
        assert "signups_by_day" in body
        assert "readings_by_day" in body

    def test_non_admin_rejected(self, client, test_user, auth_headers):
        resp = client.get(self.URL, headers=auth_headers)
        assert resp.status_code == 403

    def test_unauthenticated_rejected(self, client):
        resp = client.get(self.URL)
        assert resp.status_code == 401

    def test_metrics_with_data(self, client, admin_user, admin_headers, db):
        """Metrics should reflect actual data."""
        # Create a regular user with readings
        user = models.User(
            email="metrics_user@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Metrics User",
            phone_number="9876500002",
            last_login_at=datetime.utcnow(),
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Metrics Profile", phone_number="9876500002")
        db.add(profile)
        db.flush()

        db.add(models.ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))

        reading = models.HealthReading(
            profile_id=profile.id,
            logged_by=user.id,
            reading_type="glucose",
            glucose_value=120.0,
            value_numeric=120.0,
            unit_display="mg/dL",
            status_flag="NORMAL",
            reading_timestamp=datetime.utcnow(),
        )
        db.add(reading)
        db.flush()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()
        assert body["total_users"] >= 2  # admin + metrics_user
        assert body["total_readings"] >= 1
        assert body["dau"] >= 1  # metrics_user logged in today

    def test_signups_by_day_has_30_entries(self, client, admin_user, admin_headers):
        resp = client.get(self.URL, headers=admin_headers)
        assert len(resp.json()["signups_by_day"]) == 30

    def test_readings_by_day_has_30_entries(self, client, admin_user, admin_headers):
        resp = client.get(self.URL, headers=admin_headers)
        assert len(resp.json()["readings_by_day"]) == 30


class TestAdminUsers:
    URL = "/api/admin/users"

    def test_list_users(self, client, admin_user, admin_headers, db):
        resp = client.get(self.URL, headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "users" in body
        assert "total" in body
        assert body["total"] >= 1

    def test_user_has_activity_stats(self, client, admin_user, admin_headers, db):
        resp = client.get(self.URL, headers=admin_headers)
        user = resp.json()["users"][0]
        assert "email" in user
        assert "profiles_count" in user
        assert "total_readings" in user
        assert "last_login" in user

    def test_non_admin_rejected(self, client, test_user, auth_headers):
        resp = client.get(self.URL, headers=auth_headers)
        assert resp.status_code == 403


class TestAdminStatus:

    def test_grant_admin(self, client, admin_user, admin_headers, db, test_user):
        resp = client.patch(f"/api/admin/users/{test_user.id}", json={"is_admin": True}, headers=admin_headers)
        assert resp.status_code == 200
        assert "admin" in resp.json()["message"].lower()

    def test_revoke_admin(self, client, admin_user, admin_headers, db):
        # Create another admin
        other = models.User(
            email="other_admin@test.com",
            password_hash=get_password_hash("Admin@1234"),
            full_name="Other Admin",
            phone_number="9876500003",
            is_admin=True,
        )
        db.add(other)
        db.flush()

        resp = client.patch(f"/api/admin/users/{other.id}", json={"is_admin": False}, headers=admin_headers)
        assert resp.status_code == 200

    def test_cannot_remove_own_admin(self, client, admin_user, admin_headers):
        resp = client.patch(f"/api/admin/users/{admin_user.id}", json={"is_admin": False}, headers=admin_headers)
        assert resp.status_code == 400

    def test_nonexistent_user(self, client, admin_user, admin_headers):
        resp = client.patch("/api/admin/users/99999", json={"is_admin": True}, headers=admin_headers)
        assert resp.status_code == 404
