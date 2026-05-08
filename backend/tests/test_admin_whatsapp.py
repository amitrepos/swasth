"""Tests for admin WhatsApp messaging to inactive users."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, MagicMock
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


@pytest.fixture()
def inactive_patients(db):
    """Create 3 inactive patients (no readings in last 2 days)."""
    patients = []
    now = datetime.now(timezone.utc)
    old_ts = now - timedelta(days=5)  # 5 days ago

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

        # Create profile
        profile = models.Profile(name=f"Profile {i}")
        db.add(profile)
        db.flush()

        # Add old reading (5 days ago)
        reading = models.HealthReading(
            profile_id=profile.id,
            logged_by=user.id,
            reading_type="glucose",
            glucose_value=120.0,
            unit_display="mg/dL",
            value_numeric=120.0,
            status_flag="NORMAL",
            reading_timestamp=old_ts,
            created_at=old_ts,
        )
        db.add(reading)
        db.commit()
        patients.append({"user": user, "profile": profile})

    return patients


class TestWhatsAppIndividual:
    """Tests for POST /api/admin/send-whatsapp-individual"""
    URL = "/api/admin/send-whatsapp-individual"

    def test_endpoint_exists(self, client, admin_headers):
        """Endpoint should exist and require auth."""
        resp = client.post(self.URL, headers=admin_headers, json={"user_id": 999})
        assert resp.status_code in [200, 400, 404, 500]  # Not 401/403

    def test_non_admin_rejected(self, client, db):
        """Non-admin cannot send WhatsApp."""
        user = models.User(
            email="patient@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Patient",
        )
        db.add(user)
        db.commit()

        headers = {"Authorization": f"Bearer {create_access_token(data={'sub': user.email})}"}
        resp = client.post(self.URL, headers=headers, json={"user_id": 1})
        assert resp.status_code == 403

    def test_unauthenticated_rejected(self, client):
        """Unauthenticated request rejected."""
        resp = client.post(self.URL, json={"user_id": 1})
        assert resp.status_code == 401

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_send_to_inactive_patient(self, mock_send, client, admin_headers, inactive_patients, db):
        """Should successfully send WhatsApp template to an inactive patient."""
        mock_send.return_value = (True, "SM_test_sid", None)

        patient = inactive_patients[0]

        resp = client.post(
            self.URL,
            headers=admin_headers,
            json={"user_id": patient["user"].id}
        )

        assert resp.status_code == 200
        body = resp.json()
        assert body["success"] is True
        assert body["message_sid"] == "SM_test_sid"

        # Verify template was called with correct variables
        call_args = mock_send.call_args
        assert patient["user"].phone_number in call_args[0][0]  # phone
        variables = call_args[0][2]  # variables list
        assert "Patient 0" in variables  # name
        assert "glucose" in variables  # reading_type
        assert "5" in variables  # days

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_template_variables(self, mock_send, client, admin_headers, inactive_patients):
        """Template should be called with [name, reading_type, days]."""
        mock_send.return_value = (True, "SM_test_sid", None)

        patient = inactive_patients[0]

        resp = client.post(
            self.URL,
            headers=admin_headers,
            json={"user_id": patient["user"].id}
        )

        assert resp.status_code == 200

        call_args = mock_send.call_args
        phone = call_args[0][0]
        content_sid = call_args[0][1]
        variables = call_args[0][2]

        # Verify structure
        assert phone == patient["user"].phone_number
        assert content_sid is not None
        assert isinstance(variables, list)
        assert len(variables) == 3
        assert variables[0] == patient["user"].full_name
        assert variables[1] in ["glucose", "blood_pressure"]  # reading_type
        assert variables[2] == "5"  # days

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_send_failure_handling(self, mock_send, client, admin_headers, inactive_patients):
        """Should handle WhatsApp send failures gracefully."""
        mock_send.return_value = (False, None, "Twilio error: invalid number")

        patient = inactive_patients[0]
        resp = client.post(
            self.URL,
            headers=admin_headers,
            json={"user_id": patient["user"].id}
        )

        assert resp.status_code == 400
        body = resp.json()
        assert body["success"] is False
        assert "Twilio error" in body["error"]

    def test_user_not_found(self, client, admin_headers):
        """Should return 404 if user not found."""
        resp = client.post(
            self.URL,
            headers=admin_headers,
            json={"user_id": 99999}
        )
        assert resp.status_code == 404


class TestWhatsAppBulk:
    """Tests for POST /api/admin/send-whatsapp-bulk"""
    URL = "/api/admin/send-whatsapp-bulk"

    def test_endpoint_exists(self, client, admin_headers):
        """Endpoint should exist and require auth."""
        resp = client.post(self.URL, headers=admin_headers, json={})
        assert resp.status_code in [200, 400, 500]  # Not 401/403

    def test_non_admin_rejected(self, client, db):
        """Non-admin cannot send bulk WhatsApp."""
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
        """Unauthenticated request rejected."""
        resp = client.post(self.URL, json={})
        assert resp.status_code == 401

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_bulk_send_to_all_inactive(self, mock_send, client, admin_headers, inactive_patients):
        """Should send template to all inactive patients."""
        mock_send.return_value = (True, "SM_test_sid", None)

        resp = client.post(
            self.URL,
            headers=admin_headers,
            json={}
        )

        assert resp.status_code == 200
        body = resp.json()
        assert body["total_inactive"] == 3
        assert body["successful"] == 3
        assert body["failed"] == 0
        assert len(body["results"]) == 3
        assert mock_send.call_count == 3

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_bulk_partial_failure(self, mock_send, client, admin_headers, inactive_patients):
        """Should track partial failures in bulk send."""
        # First succeeds, second fails, third succeeds
        mock_send.side_effect = [
            (True, "SM_sid1", None),
            (False, None, "Invalid number"),
            (True, "SM_sid3", None),
        ]

        resp = client.post(
            self.URL,
            headers=admin_headers,
            json={}
        )

        assert resp.status_code == 200
        body = resp.json()
        assert body["total_inactive"] == 3
        assert body["successful"] == 2
        assert body["failed"] == 1
        assert any(r["success"] is False for r in body["results"])

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_no_inactive_users(self, mock_send, client, admin_headers, db):
        """Should return empty list if no inactive users."""
        # Create active patient (recorded today)
        now = datetime.now(timezone.utc)
        user = models.User(
            email="active@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Active Patient",
            phone_number="9876543210",
            role=models.UserRole.patient,
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Active Profile")
        db.add(profile)
        db.flush()

        # Recent reading
        reading = models.HealthReading(
            profile_id=profile.id,
            logged_by=user.id,
            reading_type="glucose",
            glucose_value=120.0,
            unit_display="mg/dL",
            value_numeric=120.0,
            status_flag="NORMAL",
            reading_timestamp=now,
            created_at=now,
        )
        db.add(reading)
        db.commit()

        resp = client.post(
            self.URL,
            headers=admin_headers,
            json={}
        )

        assert resp.status_code == 200
        body = resp.json()
        assert body["total_inactive"] == 0
        assert mock_send.call_count == 0
