"""Tests for admin WhatsApp messaging — PROFILE-centric (not user-centric)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch
import models
from auth import get_password_hash, create_access_token
from config import settings


@pytest.fixture()
def admin_user(db):
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


@pytest.fixture(autouse=True)
def mock_whatsapp_content_sid():
    with patch.object(settings, 'WHATSAPP_REMINDER_CONTENT_SID', 'HXfb6674c084fa42cded754ed2179b54ad'):
        yield


def _make_owner_link(db, user, profile):
    db.add(models.ProfileAccess(
        user_id=user.id, profile_id=profile.id, access_level="owner"
    ))
    db.flush()


def _make_reading(db, user, profile, ts, reading_type="glucose"):
    kwargs = dict(
        profile_id=profile.id,
        logged_by=user.id,
        reading_type=reading_type,
        unit_display="mg/dL",
        value_numeric=120.0,
        status_flag="NORMAL",
        reading_timestamp=ts,
        created_at=ts,
    )
    if reading_type == "glucose":
        kwargs["glucose_value"] = 120.0
    else:
        kwargs["systolic"] = 120
        kwargs["diastolic"] = 80
    db.add(models.HealthReading(**kwargs))
    db.flush()


@pytest.fixture()
def inactive_profiles(db):
    """3 inactive profiles, each with its own owner user."""
    out = []
    now = datetime.now(timezone.utc)
    old_ts = now - timedelta(days=5)

    for i in range(3):
        user = models.User(
            email=f"patient{i}@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name=f"Patient {i}",
            phone_number=f"9876543{i:03d}",
            role=models.UserRole.patient,
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name=f"Profile {i}")
        db.add(profile)
        db.flush()

        _make_owner_link(db, user, profile)
        _make_reading(db, user, profile, old_ts)
        db.commit()

        out.append({"user": user, "profile": profile})

    return out


class TestWhatsAppIndividual:
    URL = "/api/admin/send-whatsapp-individual"

    def test_endpoint_exists(self, client, admin_headers):
        resp = client.post(self.URL, headers=admin_headers, json={"profile_id": 999})
        assert resp.status_code in [200, 400, 404, 500]

    def test_non_admin_rejected(self, client, db):
        user = models.User(
            email="patient@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Patient",
        )
        db.add(user)
        db.commit()
        headers = {"Authorization": f"Bearer {create_access_token(data={'sub': user.email})}"}
        resp = client.post(self.URL, headers=headers, json={"profile_id": 1})
        assert resp.status_code == 403

    def test_unauthenticated_rejected(self, client):
        resp = client.post(self.URL, json={"profile_id": 1})
        assert resp.status_code == 401

    def test_profile_not_found(self, client, admin_headers):
        resp = client.post(self.URL, headers=admin_headers, json={"profile_id": 99999})
        assert resp.status_code == 404

    def test_profile_with_no_owner_rejected(self, client, admin_headers, db):
        profile = models.Profile(name="Orphan")
        db.add(profile)
        db.commit()
        resp = client.post(self.URL, headers=admin_headers, json={"profile_id": profile.id})
        assert resp.status_code == 400
        assert "owner" in resp.json()["detail"].lower()

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_send_to_inactive_profile(self, mock_send, client, admin_headers, inactive_profiles):
        mock_send.return_value = (True, "SM_test_sid", None)

        item = inactive_profiles[0]
        resp = client.post(
            self.URL, headers=admin_headers,
            json={"profile_id": item["profile"].id},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["success"] is True
        assert body["message_sid"] == "SM_test_sid"

        # Verify recipient is OWNER's phone, not profile phone, and template's
        # name slot is the PROFILE name.
        call_args = mock_send.call_args
        assert call_args[0][0] == item["user"].phone_number
        variables = call_args[0][2]
        assert variables[0] == item["profile"].name      # profile, not owner
        assert variables[1] in ("glucose", "blood_pressure")
        assert variables[2] == "5"

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_caregiver_with_dormant_family_profile(self, mock_send, client, admin_headers, db):
        """The bug we're fixing: caregiver logs daily for self, mother is dormant.

        - User 'Rajesh' owns two profiles: 'Self' and 'Mummy'
        - Rajesh logs Self today (active)
        - Mummy has no readings for 7 days
        - Admin sends WhatsApp for Mummy's profile
        - Message goes to Rajesh's phone, names 'Mummy'
        """
        mock_send.return_value = (True, "SM_test_sid", None)
        now = datetime.now(timezone.utc)

        rajesh = models.User(
            email="rajesh@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Rajesh",
            phone_number="9990001111",
            role=models.UserRole.patient,
        )
        db.add(rajesh)
        db.flush()

        self_profile = models.Profile(name="Self")
        mummy_profile = models.Profile(name="Mummy")
        db.add_all([self_profile, mummy_profile])
        db.flush()

        _make_owner_link(db, rajesh, self_profile)
        _make_owner_link(db, rajesh, mummy_profile)

        # Self: recent reading (active)
        _make_reading(db, rajesh, self_profile, now)
        # Mummy: 7-day-old reading (dormant)
        _make_reading(db, rajesh, mummy_profile, now - timedelta(days=7))
        db.commit()

        resp = client.post(
            self.URL, headers=admin_headers,
            json={"profile_id": mummy_profile.id},
        )
        assert resp.status_code == 200
        call_args = mock_send.call_args
        # Recipient is Rajesh
        assert call_args[0][0] == rajesh.phone_number
        # Template names the dormant profile (Mummy), not Rajesh
        assert call_args[0][2][0] == "Mummy"

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_active_profile_rejected(self, mock_send, client, admin_headers, db):
        """If the targeted profile is not actually inactive, reject."""
        mock_send.return_value = (True, "SM", None)
        now = datetime.now(timezone.utc)

        u = models.User(
            email="active_owner@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Active Owner",
            phone_number="9990002222",
            role=models.UserRole.patient,
        )
        db.add(u)
        db.flush()
        p = models.Profile(name="Active P")
        db.add(p)
        db.flush()
        _make_owner_link(db, u, p)
        _make_reading(db, u, p, now)
        db.commit()

        resp = client.post(self.URL, headers=admin_headers, json={"profile_id": p.id})
        assert resp.status_code == 400
        assert "not inactive" in resp.json()["detail"].lower()

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_send_failure_handling(self, mock_send, client, admin_headers, inactive_profiles):
        mock_send.return_value = (False, None, "Twilio error: invalid number")
        item = inactive_profiles[0]
        resp = client.post(
            self.URL, headers=admin_headers,
            json={"profile_id": item["profile"].id},
        )
        assert resp.status_code == 400
        assert "Twilio error" in resp.json()["detail"]

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_audit_log_persisted(self, mock_send, client, admin_headers, inactive_profiles, db, admin_user):
        """Regression: _audit_log only flushes; endpoint must db.commit() so the
        audit row survives the request (CERT-In 180-day requirement)."""
        mock_send.return_value = (True, "SM_test_sid", None)
        item = inactive_profiles[0]
        resp = client.post(
            self.URL, headers=admin_headers,
            json={"profile_id": item["profile"].id},
        )
        assert resp.status_code == 200

        entry = db.query(models.AdminAuditLog).filter(
            models.AdminAuditLog.action_type == "SEND_WHATSAPP_INDIVIDUAL",
            models.AdminAuditLog.target_profile_id == item["profile"].id,
        ).first()
        assert entry is not None, "audit row missing — db.commit() was skipped"
        assert entry.target_user_id == item["user"].id
        assert entry.admin_user_id == admin_user.id


class TestWhatsAppBulk:
    URL = "/api/admin/send-whatsapp-bulk"

    def test_endpoint_exists(self, client, admin_headers):
        resp = client.post(self.URL, headers=admin_headers, json={})
        assert resp.status_code in [200, 400, 500]

    def test_non_admin_rejected(self, client, db):
        user = models.User(
            email="patient@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Patient",
        )
        db.add(user)
        db.commit()
        headers = {"Authorization": f"Bearer {create_access_token(data={'sub': user.email})}"}
        resp = client.post(self.URL, headers=headers, json={})
        assert resp.status_code == 403

    def test_unauthenticated_rejected(self, client):
        resp = client.post(self.URL, json={})
        assert resp.status_code == 401

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_bulk_send_to_all_inactive(self, mock_send, client, admin_headers, inactive_profiles):
        mock_send.return_value = (True, "SM_test_sid", None)
        resp = client.post(self.URL, headers=admin_headers, json={})
        assert resp.status_code == 200
        body = resp.json()
        assert body["total_inactive"] >= 3
        assert body["successful"] >= 3
        assert body["failed"] == 0
        # Each result row has profile_id + owner_user_id
        for r in body["results"]:
            assert "profile_id" in r
            assert "owner_user_id" in r

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_bulk_partial_failure(self, mock_send, client, admin_headers, inactive_profiles):
        mock_send.side_effect = [
            (True, "SM_sid1", None),
            (False, None, "Invalid number"),
            (True, "SM_sid3", None),
            (True, "SM_sid4", None),
        ]
        resp = client.post(self.URL, headers=admin_headers, json={})
        assert resp.status_code == 200
        body = resp.json()
        assert body["total_inactive"] >= 3
        assert body["successful"] >= 2
        assert body["failed"] >= 1

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_bulk_skips_active_profile(self, mock_send, client, admin_headers, db, inactive_profiles):
        mock_send.return_value = (True, "SM_test_sid", None)
        now = datetime.now(timezone.utc)

        u = models.User(
            email="active@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Active Patient",
            phone_number="9876543210",
            role=models.UserRole.patient,
        )
        db.add(u)
        db.flush()
        p = models.Profile(name="Active Profile")
        db.add(p)
        db.flush()
        _make_owner_link(db, u, p)
        _make_reading(db, u, p, now)
        db.commit()

        resp = client.post(self.URL, headers=admin_headers, json={})
        assert resp.status_code == 200
        body = resp.json()
        # Active profile must NOT appear in results
        assert all(r["profile_id"] != p.id for r in body["results"])

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_bulk_audit_log_persisted(self, mock_send, client, admin_headers, inactive_profiles, db, admin_user):
        """Regression: bulk endpoint must db.commit() the SEND_WHATSAPP_BULK audit row."""
        mock_send.return_value = (True, "SM_test_sid", None)
        resp = client.post(self.URL, headers=admin_headers, json={})
        assert resp.status_code == 200

        entry = db.query(models.AdminAuditLog).filter(
            models.AdminAuditLog.action_type == "SEND_WHATSAPP_BULK",
            models.AdminAuditLog.admin_user_id == admin_user.id,
        ).order_by(models.AdminAuditLog.id.desc()).first()
        assert entry is not None, "bulk audit row missing — db.commit() was skipped"

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_bulk_writes_per_profile_audit_rows(self, mock_send, client, admin_headers, inactive_profiles, db):
        """Each bulk recipient must get its own SEND_WHATSAPP_BULK_ITEM audit row.

        Drives the 'Last Message Sent' column on the admin inactive-users tab:
        without per-profile rows, the column wouldn't reflect bulk sends.
        """
        mock_send.return_value = (True, "SM_test_sid", None)
        resp = client.post(self.URL, headers=admin_headers, json={})
        assert resp.status_code == 200

        for item in inactive_profiles:
            row = db.query(models.AdminAuditLog).filter(
                models.AdminAuditLog.action_type == "SEND_WHATSAPP_BULK_ITEM",
                models.AdminAuditLog.target_profile_id == item["profile"].id,
                models.AdminAuditLog.outcome == "SUCCESS",
            ).first()
            assert row is not None, (
                f"per-profile audit row missing for profile {item['profile'].id}"
            )

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_bulk_caregiver_dormant_family_profile(self, mock_send, client, admin_headers, db):
        """Caregiver case: user logs daily for self, has dormant Mummy profile.

        Bulk send must include Mummy with the OWNER's phone — even though the
        owner himself is "active" (logging for self).
        """
        mock_send.return_value = (True, "SM_test_sid", None)
        now = datetime.now(timezone.utc)

        rajesh = models.User(
            email="rajesh_bulk@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Rajesh",
            phone_number="9990003333",
            role=models.UserRole.patient,
        )
        db.add(rajesh)
        db.flush()

        self_p = models.Profile(name="Rajesh-Self")
        mummy_p = models.Profile(name="Mummy")
        db.add_all([self_p, mummy_p])
        db.flush()
        _make_owner_link(db, rajesh, self_p)
        _make_owner_link(db, rajesh, mummy_p)

        _make_reading(db, rajesh, self_p, now)                      # active
        _make_reading(db, rajesh, mummy_p, now - timedelta(days=8)) # dormant
        db.commit()

        resp = client.post(self.URL, headers=admin_headers, json={})
        assert resp.status_code == 200
        body = resp.json()
        mummy_results = [r for r in body["results"] if r["profile_id"] == mummy_p.id]
        assert len(mummy_results) == 1, "Mummy profile must appear in bulk results"
        assert mummy_results[0]["owner_user_id"] == rajesh.id
        # Self profile is active — must NOT appear
        assert all(r["profile_id"] != self_p.id for r in body["results"])
