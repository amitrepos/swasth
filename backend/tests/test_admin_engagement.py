"""Tests for admin alert enrichment with patient names and doctor details."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta, timezone
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


class TestAlertEnrichment:
    """Tests for alert enrichment with patient_name and linked_doctors."""
    URL = "/api/admin/alerts"

    def test_critical_reading_alert_has_patient_name(self, client, admin_headers, db):
        """Critical reading alerts should include patient_name."""
        # Create patient and profile
        user = models.User(
            email="alert_user@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Alert Patient",
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Alert Profile")
        db.add(profile)
        db.flush()

        # Add critical reading >24h ago
        now = datetime.now(timezone.utc)
        reading = models.HealthReading(
            profile_id=profile.id,
            reading_type="glucose",
            glucose_value=300.0,
            unit_display="mg/dL",
            value_numeric=300.0,
            status_flag="CRITICAL",
            reading_timestamp=now - timedelta(days=2),
        )
        db.add(reading)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        # Find the critical reading alert
        alert = next((a for a in body["alerts"] if a["type"] == "CRITICAL_READING_UNADDRESSED"), None)
        assert alert is not None
        assert "patient_name" in alert
        assert alert["patient_name"] == "Alert Profile"

    def test_critical_reading_alert_has_linked_doctors(self, client, admin_headers, db):
        """Critical reading alerts should include linked_doctors array."""
        # Create patient and profile
        user = models.User(
            email="alert_user2@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Alert Patient 2",
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Alert Profile 2")
        db.add(profile)
        db.flush()

        # Create doctor
        doctor = models.User(
            email="alert_doc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Alert",
            role=models.UserRole.doctor,
        )
        db.add(doctor)
        db.flush()

        doc_profile = models.DoctorProfile(
            user_id=doctor.id,
            nmc_number="NMC123",
            doctor_code="DRALERT",
            specialty="General",
            clinic_name="Alert Clinic",
            is_verified=True,
        )
        db.add(doc_profile)
        db.flush()

        # Link doctor to patient
        link = models.DoctorPatientLink(
            doctor_id=doctor.id,
            profile_id=profile.id,
            consent_granted_at=datetime.now(timezone.utc),
            consent_type="explicit",
            status="active",
        )
        db.add(link)
        db.flush()

        # Add critical reading >24h ago
        now = datetime.now(timezone.utc)
        reading = models.HealthReading(
            profile_id=profile.id,
            reading_type="glucose",
            glucose_value=350.0,
            unit_display="mg/dL",
            value_numeric=350.0,
            status_flag="CRITICAL",
            reading_timestamp=now - timedelta(days=2),
        )
        db.add(reading)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        alert = next((a for a in body["alerts"] if a["type"] == "CRITICAL_READING_UNADDRESSED"), None)
        assert alert is not None
        assert "linked_doctors" in alert
        assert isinstance(alert["linked_doctors"], list)
        assert len(alert["linked_doctors"]) == 1
        assert alert["linked_doctors"][0]["name"] == "Dr. Alert"
        assert alert["linked_doctors"][0]["doctor_code"] == "DRALERT"

    def test_inactive_patient_alert_has_patient_name(self, client, admin_headers, db):
        """Inactive patient alerts should include patient_name."""
        profile = models.Profile(name="Inactive Profile")
        db.add(profile)
        db.flush()

        # Add old critical reading (60+ days ago)
        old_reading = models.HealthReading(
            profile_id=profile.id,
            reading_type="glucose",
            glucose_value=280.0,
            unit_display="mg/dL",
            value_numeric=280.0,
            status_flag="CRITICAL",
            reading_timestamp=datetime.now(timezone.utc) - timedelta(days=60),
            created_at=datetime.now(timezone.utc) - timedelta(days=60),
        )
        db.add(old_reading)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        alert = next((a for a in body["alerts"] if a["type"] == "PATIENT_INACTIVE_HIGH_RISK"), None)
        assert alert is not None
        assert "patient_name" in alert
        assert alert["patient_name"] == "Inactive Profile"

    def test_alert_with_no_linked_doctors(self, client, admin_headers, db):
        """Alert should show empty list when no linked doctors."""
        profile = models.Profile(name="No Doctor Profile")
        db.add(profile)
        db.flush()

        # Add critical reading >24h ago with no doctor link
        now = datetime.now(timezone.utc)
        reading = models.HealthReading(
            profile_id=profile.id,
            reading_type="glucose",
            glucose_value=320.0,
            unit_display="mg/dL",
            value_numeric=320.0,
            status_flag="CRITICAL",
            reading_timestamp=now - timedelta(days=2),
        )
        db.add(reading)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        alert = next((a for a in body["alerts"] if a["type"] == "CRITICAL_READING_UNADDRESSED"), None)
        assert alert is not None
        assert "linked_doctors" in alert
        assert isinstance(alert["linked_doctors"], list)
        assert len(alert["linked_doctors"]) == 0

    def test_alert_with_multiple_linked_doctors(self, client, admin_headers, db):
        """Alert should list doctor links correctly."""
        profile = models.Profile(name="Multi Doctor Profile")
        db.add(profile)
        db.flush()

        # Create one doctor and link to profile
        doc = models.User(
            email="multidoc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. MultiDoc",
            role=models.UserRole.doctor,
        )
        db.add(doc)
        db.flush()

        doc_profile = models.DoctorProfile(
            user_id=doc.id,
            nmc_number="NMC999",
            doctor_code="DRMULTI99",
            specialty="General",
            clinic_name="Multi Clinic",
            is_verified=True,
        )
        db.add(doc_profile)
        db.flush()

        link = models.DoctorPatientLink(
            doctor_id=doc.id,
            profile_id=profile.id,
            consent_granted_at=datetime.now(timezone.utc),
            consent_type="explicit",
            status="active",
        )
        db.add(link)
        db.flush()

        # Add critical reading >24h ago (now uses immediate alerts)
        now = datetime.now(timezone.utc)
        reading = models.HealthReading(
            profile_id=profile.id,
            reading_type="glucose",
            glucose_value=340.0,
            unit_display="mg/dL",
            value_numeric=340.0,
            status_flag="CRITICAL",
            reading_timestamp=now,
        )
        db.add(reading)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        alert = next((a for a in body["alerts"] if a["type"] == "CRITICAL_READING_UNADDRESSED"), None)
        assert alert is not None
        assert len(alert["linked_doctors"]) == 1
        assert alert["linked_doctors"][0]["doctor_code"] == "DRMULTI99"
