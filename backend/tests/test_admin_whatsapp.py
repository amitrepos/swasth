"""Tests for admin WhatsApp messaging to inactive users."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, MagicMock, PropertyMock
import models
from auth import get_password_hash, create_access_token
from config import settings


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


@pytest.fixture(autouse=True)
def mock_whatsapp_content_sid():
    """Mock the Content SID for all tests."""
    with patch.object(settings, 'WHATSAPP_REMAINDER_CONTENT_SID', 'HXfb6674c084fa42cded754ed2179b54ad'):
        yield


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
        assert "Twilio error" in body["detail"]

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
        # At least the 3 from fixture should be present
        assert body["total_inactive"] >= 3
        assert body["successful"] >= 3
        assert body["failed"] == 0
        assert len(body["results"]) >= 3
        assert mock_send.call_count >= 3

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_bulk_partial_failure(self, mock_send, client, admin_headers, inactive_patients):
        """Should track partial failures in bulk send."""
        # Simulate 3+ users with mixed results
        mock_send.side_effect = [
            (True, "SM_sid1", None),
            (False, None, "Invalid number"),
            (True, "SM_sid3", None),
            (True, "SM_sid4", None),  # Extra in case more users exist
        ]

        resp = client.post(
            self.URL,
            headers=admin_headers,
            json={}
        )

        assert resp.status_code == 200
        body = resp.json()
        # At least 3 inactive users
        assert body["total_inactive"] >= 3
        assert body["successful"] >= 2
        assert body["failed"] >= 1
        assert any(r["success"] is False for r in body["results"])

    @patch("twilio_service.whatsapp_service.send_whatsapp_template")
    def test_bulk_with_active_user(self, mock_send, client, admin_headers, db, inactive_patients):
        """Bulk send should skip active users (only send to inactive)."""
        mock_send.return_value = (True, "SM_test_sid", None)

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

        # Recent reading (< 2 days ago)
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
        # Should still send to the 3+ inactive users, not the active one
        assert body["total_inactive"] >= 3
        assert body["successful"] >= 3
        # The active user should NOT be in results
        active_results = [r for r in body["results"] if r["user_id"] == user.id]
        assert len(active_results) == 0
