"""Tests for admin engagement metrics and alert enrichment."""
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


class TestAdminEngagement:
    """Tests for GET /api/admin/engagement endpoint."""
    URL = "/api/admin/engagement"

    def test_engagement_endpoint_exists(self, client, admin_headers):
        """Endpoint should exist and return 200."""
        resp = client.get(self.URL, headers=admin_headers)
        assert resp.status_code == 200

    def test_engagement_response_structure(self, client, admin_headers):
        """Response should have user_consistency, doctor_activity, and summary."""
        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        assert "user_consistency" in body
        assert "doctor_activity" in body
        assert "summary" in body
        assert isinstance(body["user_consistency"], list)
        assert isinstance(body["doctor_activity"], list)

        # Check summary structure
        summary = body["summary"]
        assert "regular_users" in summary
        assert "sporadic_users" in summary
        assert "dormant_users" in summary
        assert "active_doctors" in summary
        assert "low_doctors" in summary
        assert "dormant_doctors" in summary

    def test_user_consistency_fields(self, client, admin_headers, db):
        """User consistency records should have all required fields."""
        # Create a patient with readings
        user = models.User(
            email="patient@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Test Patient",
            phone_number="9876500002",
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Test Profile", phone_number="9876500003")
        db.add(profile)
        db.flush()

        # Add reading logged by this user
        reading = models.HealthReading(
            profile_id=profile.id,
            logged_by=user.id,
            reading_type="glucose",
            glucose_value=120.0,
            unit_display="mg/dL",
            value_numeric=120.0,
            status_flag="NORMAL",
            reading_timestamp=datetime.now(timezone.utc),
        )
        db.add(reading)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        # Find our user
        user_rec = next((u for u in body["user_consistency"] if u["user_id"] == user.id), None)
        assert user_rec is not None
        assert user_rec["full_name"] == "Test Patient"
        assert user_rec["email"] == "patient@test.com"
        assert "readings_7d" in user_rec
        assert "readings_30d" in user_rec
        assert "last_reading_at" in user_rec
        assert "consistency_score" in user_rec
        assert "tier" in user_rec
        assert user_rec["readings_30d"] == 1

    def test_user_tier_regular(self, client, admin_headers, db):
        """User with score >= 0.5 should be 'regular'."""
        user = models.User(
            email="regular_user@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Regular User",
            phone_number="9876500004",
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Regular Profile")
        db.add(profile)
        db.flush()

        # Add 16+ readings in last 30 days (score >= 0.5)
        now = datetime.now(timezone.utc)
        for i in range(16):
            reading = models.HealthReading(
                profile_id=profile.id,
                logged_by=user.id,
                reading_type="glucose",
                glucose_value=120.0,
                unit_display="mg/dL",
                value_numeric=120.0,
                status_flag="NORMAL",
                reading_timestamp=now - timedelta(days=i),
            )
            db.add(reading)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        user_rec = next((u for u in body["user_consistency"] if u["user_id"] == user.id), None)
        assert user_rec["tier"] == "regular"
        assert user_rec["consistency_score"] >= 0.5

    def test_user_tier_sporadic(self, client, admin_headers, db):
        """User with score 0.1-0.5 should be 'sporadic'."""
        user = models.User(
            email="sporadic_user@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Sporadic User",
            phone_number="9876500005",
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Sporadic Profile")
        db.add(profile)
        db.flush()

        # Add 5 readings in last 30 days (score ~0.17)
        now = datetime.now(timezone.utc)
        for i in range(5):
            reading = models.HealthReading(
                profile_id=profile.id,
                logged_by=user.id,
                reading_type="glucose",
                glucose_value=120.0,
                unit_display="mg/dL",
                value_numeric=120.0,
                status_flag="NORMAL",
                reading_timestamp=now - timedelta(days=i*6),
            )
            db.add(reading)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        user_rec = next((u for u in body["user_consistency"] if u["user_id"] == user.id), None)
        assert user_rec["tier"] == "sporadic"

    def test_user_tier_dormant(self, client, admin_headers, db):
        """User with no recent readings should be 'dormant'."""
        user = models.User(
            email="dormant_user@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dormant User",
            phone_number="9876500006",
        )
        db.add(user)
        db.flush()

        profile = models.Profile(name="Dormant Profile")
        db.add(profile)
        db.flush()

        # Add reading > 30 days ago
        old_reading = models.HealthReading(
            profile_id=profile.id,
            logged_by=user.id,
            reading_type="glucose",
            glucose_value=120.0,
            unit_display="mg/dL",
            value_numeric=120.0,
            status_flag="NORMAL",
            reading_timestamp=datetime.now(timezone.utc) - timedelta(days=45),
        )
        db.add(old_reading)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        user_rec = next((u for u in body["user_consistency"] if u["user_id"] == user.id), None)
        assert user_rec["tier"] == "dormant"
        assert user_rec["consistency_score"] < 0.1

    def test_doctor_activity_fields(self, client, admin_headers, db):
        """Doctor activity records should have all required fields."""
        # Create verified doctor
        doctor = models.User(
            email="doctor@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Test",
            phone_number="9876500007",
            role=models.UserRole.doctor,
        )
        db.add(doctor)
        db.flush()

        doc_profile = models.DoctorProfile(
            user_id=doctor.id,
            nmc_number="NMC123456",
            doctor_code="DRTEST01",
            specialty="Cardiology",
            clinic_name="Test Clinic",
            is_verified=True,
        )
        db.add(doc_profile)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        doc_rec = next((d for d in body["doctor_activity"] if d["user_id"] == doctor.id), None)
        assert doc_rec is not None
        assert doc_rec["full_name"] == "Dr. Test"
        assert doc_rec["doctor_code"] == "DRTEST01"
        assert "specialty" in doc_rec
        assert "last_login" in doc_rec
        assert "last_patient_access" in doc_rec
        assert "patients_checked_7d" in doc_rec
        assert "total_active_patients" in doc_rec
        assert "access_events_7d" in doc_rec
        assert "activity_tier" in doc_rec

    def test_doctor_activity_active(self, client, admin_headers, db):
        """Doctor with access in last 7 days should be 'active'."""
        # Create doctor
        doctor = models.User(
            email="active_doc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Active",
            phone_number="9876500008",
            role=models.UserRole.doctor,
        )
        db.add(doctor)
        db.flush()

        doc_profile = models.DoctorProfile(
            user_id=doctor.id,
            nmc_number="NMC654321",
            doctor_code="DRACT01",
            specialty="General",
            clinic_name="Active Clinic",
            is_verified=True,
        )
        db.add(doc_profile)
        db.flush()

        # Create patient and link
        patient = models.User(
            email="patient2@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Patient 2",
        )
        db.add(patient)
        db.flush()

        profile = models.Profile(name="Patient 2 Profile")
        db.add(profile)
        db.flush()

        # Add doctor access log from today
        access_log = models.DoctorAccessLog(
            doctor_id=doctor.id,
            profile_id=profile.id,
            action="viewed_readings",
            endpoint="/api/readings",
            created_at=datetime.now(timezone.utc),
        )
        db.add(access_log)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        doc_rec = next((d for d in body["doctor_activity"] if d["user_id"] == doctor.id), None)
        assert doc_rec["activity_tier"] == "active"
        assert doc_rec["access_events_7d"] == 1

    def test_doctor_activity_dormant(self, client, admin_headers, db):
        """Doctor with no recent access should be 'dormant'."""
        doctor = models.User(
            email="dormant_doc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Dormant",
            phone_number="9876500009",
            role=models.UserRole.doctor,
        )
        db.add(doctor)
        db.flush()

        doc_profile = models.DoctorProfile(
            user_id=doctor.id,
            nmc_number="NMC999999",
            doctor_code="DRDORM01",
            specialty="General",
            clinic_name="Dormant Clinic",
            is_verified=True,
        )
        db.add(doc_profile)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        doc_rec = next((d for d in body["doctor_activity"] if d["user_id"] == doctor.id), None)
        assert doc_rec["activity_tier"] == "dormant"

    def test_non_admin_rejected(self, client, db):
        """Non-admin should be rejected."""
        user = models.User(
            email="user@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Test User",
            phone_number="9876500010",
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

        # Add old critical reading
        old_reading = models.HealthReading(
            profile_id=profile.id,
            reading_type="glucose",
            glucose_value=280.0,
            unit_display="mg/dL",
            value_numeric=280.0,
            status_flag="CRITICAL",
            reading_timestamp=datetime.now(timezone.utc) - timedelta(days=60),
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
        """Alert should list all linked doctors."""
        profile = models.Profile(name="Multi Doctor Profile")
        db.add(profile)
        db.flush()

        # Create two doctors
        doctors = []
        for i in range(2):
            doc = models.User(
                email=f"multidoc{i}@test.com",
                password_hash=get_password_hash("Test@1234"),
                full_name=f"Dr. MultiDoc {i}",
                role=models.UserRole.doctor,
            )
            db.add(doc)
            db.flush()

            doc_profile = models.DoctorProfile(
                user_id=doc.id,
                nmc_number=f"NMC{i}",
                doctor_code=f"DRMULTI{i}",
                specialty="General",
                clinic_name=f"Clinic {i}",
                is_verified=True,
            )
            db.add(doc_profile)
            db.flush()

            link = models.DoctorPatientLink(
                doctor_id=doc.id,
                profile_id=profile.id,
                consent_granted_at=datetime.now(timezone.utc),
                status="active",
            )
            db.add(link)
            doctors.append(doc)

        # Add critical reading >24h ago
        now = datetime.now(timezone.utc)
        reading = models.HealthReading(
            profile_id=profile.id,
            reading_type="glucose",
            glucose_value=340.0,
            unit_display="mg/dL",
            value_numeric=340.0,
            status_flag="CRITICAL",
            reading_timestamp=now - timedelta(days=2),
        )
        db.add(reading)
        db.commit()

        resp = client.get(self.URL, headers=admin_headers)
        body = resp.json()

        alert = next((a for a in body["alerts"] if a["type"] == "CRITICAL_READING_UNADDRESSED"), None)
        assert alert is not None
        assert len(alert["linked_doctors"]) == 2
