"""Tests for account deletion (DPDP Act right to erasure)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta
import models


class TestAccountDeletion:
    """DELETE /api/auth/account removes all user data."""

    def test_delete_removes_user_and_profile(self, client, test_user, auth_headers, db):
        resp = client.delete("/api/auth/account", headers=auth_headers)
        assert resp.status_code == 204

        # User gone
        assert db.query(models.User).filter_by(id=test_user.id).first() is None

    def test_delete_removes_health_readings(self, client, test_user, auth_headers, db):
        # Get owned profile
        access = db.query(models.ProfileAccess).filter_by(
            user_id=test_user.id, access_level="owner"
        ).first()

        # Add a reading
        reading = models.HealthReading(
            profile_id=access.profile_id,
            logged_by=test_user.id,
            reading_type="glucose",
            glucose_value=120,
            value_numeric=120,
            unit_display="mg/dL",
            status_flag="NORMAL",
            reading_timestamp=datetime.utcnow(),
        )
        db.add(reading)
        db.flush()

        resp = client.delete("/api/auth/account", headers=auth_headers)
        assert resp.status_code == 204

        # Reading gone
        assert db.query(models.HealthReading).filter_by(profile_id=access.profile_id).first() is None

    def test_delete_removes_ai_logs(self, client, test_user, auth_headers, db):
        access = db.query(models.ProfileAccess).filter_by(
            user_id=test_user.id, access_level="owner"
        ).first()

        log = models.AiInsightLog(
            profile_id=access.profile_id,
            model_used="test",
            response_text="test insight",
        )
        db.add(log)
        db.flush()

        resp = client.delete("/api/auth/account", headers=auth_headers)
        assert resp.status_code == 204
        assert db.query(models.AiInsightLog).filter_by(profile_id=access.profile_id).first() is None

    def test_delete_removes_invites_by_email(self, client, test_user, auth_headers, db):
        # Create another user who sends an invite to test_user
        from auth import get_password_hash
        other_user = models.User(
            email="other@test.com", password_hash=get_password_hash("Test@1234"),
            full_name="Other", phone_number="1234567890",
        )
        db.add(other_user)
        db.flush()

        other_profile = models.Profile(name="Other", phone_number=other_user.phone_number)
        db.add(other_profile)
        db.flush()
        db.add(models.ProfileAccess(user_id=other_user.id, profile_id=other_profile.id, access_level="owner"))
        db.flush()

        invite = models.ProfileInvite(
            profile_id=other_profile.id,
            invited_by_user_id=other_user.id,
            invited_email=test_user.email,
            status="pending",
            expires_at=datetime.utcnow() + timedelta(days=7),
        )
        db.add(invite)
        db.flush()

        resp = client.delete("/api/auth/account", headers=auth_headers)
        assert resp.status_code == 204
        assert db.query(models.ProfileInvite).filter_by(invited_email=test_user.email).first() is None

    def test_delete_nullifies_logged_by_on_others_readings(self, client, test_user, auth_headers, db):
        # Another profile where test_user logged a reading
        other_profile = models.Profile(name="Papa", phone_number="9876543210")
        db.add(other_profile)
        db.flush()

        reading = models.HealthReading(
            profile_id=other_profile.id,
            logged_by=test_user.id,
            reading_type="glucose",
            glucose_value=100,
            value_numeric=100,
            unit_display="mg/dL",
            status_flag="NORMAL",
            reading_timestamp=datetime.utcnow(),
        )
        db.add(reading)
        db.flush()
        reading_id = reading.id

        resp = client.delete("/api/auth/account", headers=auth_headers)
        assert resp.status_code == 204

        # Reading still exists but logged_by is NULL
        r = db.query(models.HealthReading).filter_by(id=reading_id).first()
        assert r is not None
        assert r.logged_by is None

    def test_unauthenticated_delete_rejected(self, client):
        resp = client.delete("/api/auth/account")
        assert resp.status_code in (401, 403)


class TestAiConsent:
    """POST /api/auth/ai-consent grants AI processing consent."""

    def test_grant_consent(self, client, test_user, auth_headers, db):
        resp = client.post("/api/auth/ai-consent", headers=auth_headers)
        assert resp.status_code == 200

        db.refresh(test_user)
        assert test_user.ai_consent is True
        assert test_user.ai_consent_timestamp is not None

    def test_consent_idempotent(self, client, test_user, auth_headers, db):
        client.post("/api/auth/ai-consent", headers=auth_headers)
        client.post("/api/auth/ai-consent", headers=auth_headers)
        db.refresh(test_user)
        assert test_user.ai_consent is True

    def test_unauthenticated_consent_rejected(self, client):
        resp = client.post("/api/auth/ai-consent")
        assert resp.status_code in (401, 403)
