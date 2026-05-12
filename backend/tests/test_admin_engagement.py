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


class TestInactiveUsers:
    """Tests for GET /api/admin/inactive-users endpoint."""
    URL = "/api/admin/inactive-users"

    def test_endpoint_exists(self, client, admin_headers):
        """Endpoint should return 200."""
        resp = client.get(self.URL, headers=admin_headers)
        assert resp.status_code == 200

    def test_response_structure(self, client, admin_headers):
        """Response should have inactive_users list."""
        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()
        assert "inactive_users" in body
        assert isinstance(body["inactive_users"], list)

    def test_never_recorded_displays_never(self, client, admin_headers, db):
        """Users who never recorded should display 'Never'."""
        user = models.User(
            email="never@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Never User",
            role=models.UserRole.patient,
        )
        db.add(user)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()
        # Should return success
        assert resp.status_code == 200
        assert "inactive_users" in body

    def test_non_admin_rejected(self, client, db):
        """Non-admin should be rejected."""
        user = models.User(
            email="patient@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Patient",
        )
        db.add(user)
        db.commit()

        headers = {"Authorization": f"Bearer {create_access_token(data={'sub': user.email})}"}
        resp = client.get(self.URL, headers=headers)
        assert resp.status_code == 403

    def test_unauthenticated_rejected(self, client):
        """Unauthenticated should be rejected."""
        resp = client.get(self.URL)
        assert resp.status_code == 401

    def test_new_account_grace_period(self, client, admin_headers, db):
        """Newly signed-up profile (no readings, created <2 days ago) must NOT
        appear in inactive-users — a fresh user shouldn't be spammed on day 1.
        """
        now = datetime.now(timezone.utc)
        user = models.User(
            email="newbie@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Newbie",
            phone_number="9990001234",
            role=models.UserRole.patient,
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Newbie Self")
        profile.created_at = now - timedelta(hours=6)  # fresh signup
        db.add(profile)
        db.flush()

        db.add(models.ProfileAccess(
            user_id=user.id, profile_id=profile.id, access_level="owner"
        ))
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert all(u["profile_id"] != profile.id for u in body["inactive_users"]), (
            "fresh signup must not appear in inactive list"
        )

    def test_old_no_reading_profile_appears(self, client, admin_headers, db):
        """Profile that's old AND has no readings must still appear."""
        now = datetime.now(timezone.utc)
        user = models.User(
            email="old_no_reading@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Old User",
            phone_number="9990005678",
            role=models.UserRole.patient,
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Old Self")
        profile.created_at = now - timedelta(days=10)
        db.add(profile)
        db.flush()

        db.add(models.ProfileAccess(
            user_id=user.id, profile_id=profile.id, access_level="owner"
        ))
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()
        found = [u for u in body["inactive_users"] if u["profile_id"] == profile.id]
        assert len(found) == 1
        # Per-type tracking: with no readings at all, both glucose and BP are
        # missing → template phrase covers both.
        assert found[0]["glucose_missing"] is True
        assert found[0]["bp_missing"] is True
        assert found[0]["missing_types"] == "glucose and blood pressure"
        assert found[0]["missing_types_display"] == "Glucose + BP"
        assert found[0]["days_since_log"] == 10  # since profile.created_at
        assert found[0]["last_message_sent_at"] is None
        assert found[0]["message_count"] == 0

    def test_only_one_type_missing_surfaces_correctly(self, client, admin_headers, db):
        """If only glucose is missing (BP logged today), profile should still
        surface and missing_types should be just 'glucose'.

        This is the core fix for the old aggregate logic: previously any
        reading in the last 2 days masked the profile, even if a critical
        reading type (glucose) had been silent for weeks.
        """
        now = datetime.now(timezone.utc)
        user = models.User(
            email="bp_only@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="BP-Only Logger",
            phone_number="9990007777",
            role=models.UserRole.patient,
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="BP Only")
        profile.created_at = now - timedelta(days=30)
        db.add(profile)
        db.flush()

        db.add(models.ProfileAccess(
            user_id=user.id, profile_id=profile.id, access_level="owner"
        ))

        # Glucose 10 days ago (stale), BP logged today (active)
        db.add(models.HealthReading(
            profile_id=profile.id, logged_by=user.id, reading_type="glucose",
            glucose_value=110.0, unit_display="mg/dL", value_numeric=110.0,
            status_flag="NORMAL",
            reading_timestamp=now - timedelta(days=10),
            created_at=now - timedelta(days=10),
        ))
        db.add(models.HealthReading(
            profile_id=profile.id, logged_by=user.id, reading_type="blood_pressure",
            systolic=120, diastolic=80, unit_display="mmHg", value_numeric=120,
            status_flag="NORMAL",
            reading_timestamp=now, created_at=now,
        ))
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()
        found = [u for u in body["inactive_users"] if u["profile_id"] == profile.id]
        assert len(found) == 1
        assert found[0]["glucose_missing"] is True
        assert found[0]["bp_missing"] is False
        assert found[0]["missing_types"] == "glucose"
        assert found[0]["missing_types_display"] == "Glucose"
        assert found[0]["days_since_log"] == 10

    def test_admin_owner_excluded(self, client, admin_headers, db):
        """Admin accounts (is_admin=True, even with role=patient) must NOT
        appear in the reminders list — they shouldn't be WhatsApp-pinged.
        The legacy admin fixture sets is_admin=True but leaves role at the
        default 'patient', so the role filter alone would let them through.
        """
        now = datetime.now(timezone.utc)
        admin = models.User(
            email="legacy_admin@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Legacy Admin",
            phone_number="9990001111",
            is_admin=True,
            # role defaults to UserRole.patient — the failure mode being tested
        )
        db.add(admin)
        db.flush()

        profile = models.Profile(name="Admin Self")
        profile.created_at = now - timedelta(days=30)
        db.add(profile)
        db.flush()
        db.add(models.ProfileAccess(
            user_id=admin.id, profile_id=profile.id, access_level="owner"
        ))
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()
        assert all(u["profile_id"] != profile.id for u in body["inactive_users"]), (
            "admin-owned profile must not surface in reminders"
        )

    def test_doctor_owner_excluded(self, client, admin_headers, db):
        """role=doctor owners are also excluded."""
        now = datetime.now(timezone.utc)
        doc = models.User(
            email="dr_test@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr Test",
            phone_number="9990002222",
            role=models.UserRole.doctor,
        )
        db.add(doc)
        db.flush()
        profile = models.Profile(name="Doctor Self")
        profile.created_at = now - timedelta(days=30)
        db.add(profile)
        db.flush()
        db.add(models.ProfileAccess(
            user_id=doc.id, profile_id=profile.id, access_level="owner"
        ))
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()
        assert all(u["profile_id"] != profile.id for u in body["inactive_users"])

    def test_last_message_sent_reflects_audit(self, client, admin_headers, db, admin_user):
        """last_message_sent_at + message_count populate from AdminAuditLog."""
        now = datetime.now(timezone.utc)
        user = models.User(
            email="messaged@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Messaged User",
            phone_number="9990009999",
            role=models.UserRole.patient,
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Messaged Self")
        profile.created_at = now - timedelta(days=10)
        db.add(profile)
        db.flush()

        db.add(models.ProfileAccess(
            user_id=user.id, profile_id=profile.id, access_level="owner"
        ))
        # Two prior reminders: one bulk-item, one individual
        db.add(models.AdminAuditLog(
            admin_user_id=admin_user.id,
            action_type="SEND_WHATSAPP_BULK_ITEM",
            target_user_id=user.id,
            target_profile_id=profile.id,
            outcome="SUCCESS",
        ))
        db.add(models.AdminAuditLog(
            admin_user_id=admin_user.id,
            action_type="SEND_WHATSAPP_INDIVIDUAL",
            target_user_id=user.id,
            target_profile_id=profile.id,
            outcome="SUCCESS",
        ))
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()
        found = [u for u in body["inactive_users"] if u["profile_id"] == profile.id]
        assert len(found) == 1
        assert found[0]["last_message_sent_at"] is not None
        assert found[0]["message_count"] == 2
