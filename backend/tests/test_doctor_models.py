"""Tests for Doctor Portal models, schemas, and dependencies (E1/E10/E3)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timezone
from tests.conftest import (
    TEST_USER_EMAIL,
    TEST_USER_PASSWORD,
    TEST_USER_NAME,
    TEST_USER_PHONE,
)
from auth import get_password_hash, create_access_token
import models
from models import UserRole


# ---------------------------------------------------------------------------
# UserRole enum
# ---------------------------------------------------------------------------

class TestUserRole:
    def test_default_role_is_patient(self, db):
        user = models.User(
            email="patient@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Patient User",
            phone_number="9000000001",
        )
        db.add(user)
        db.flush()
        assert user.role == UserRole.patient

    def test_doctor_role(self, db):
        user = models.User(
            email="doc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Rajesh",
            phone_number="9000000002",
            role=UserRole.doctor,
        )
        db.add(user)
        db.flush()
        assert user.role == UserRole.doctor

    def test_admin_role(self, db):
        user = models.User(
            email="admin@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Admin",
            phone_number="9000000003",
            role=UserRole.admin,
        )
        db.add(user)
        db.flush()
        assert user.role == UserRole.admin

    def test_role_enum_values(self):
        assert UserRole.patient.value == "patient"
        assert UserRole.doctor.value == "doctor"
        assert UserRole.admin.value == "admin"


# ---------------------------------------------------------------------------
# DoctorProfile model
# ---------------------------------------------------------------------------

class TestDoctorProfile:
    def _make_doctor_user(self, db, email="doctor@test.com"):
        user = models.User(
            email=email,
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Rajesh Verma",
            phone_number="9000000010",
            role=UserRole.doctor,
        )
        db.add(user)
        db.flush()
        return user

    def test_create_doctor_profile(self, db):
        user = self._make_doctor_user(db)
        dp = models.DoctorProfile(
            user_id=user.id,
            nmc_number="BR-12345",
            specialty="General Physician",
            clinic_name="Verma Clinic",
            doctor_code="DRRAJ52",
        )
        db.add(dp)
        db.flush()
        assert dp.id is not None
        assert dp.doctor_code == "DRRAJ52"
        assert dp.is_verified is False
        assert dp.nmc_number == "BR-12345"

    def test_doctor_code_unique(self, db):
        u1 = self._make_doctor_user(db, "doc1@test.com")
        u2 = self._make_doctor_user(db, "doc2@test.com")
        dp1 = models.DoctorProfile(
            user_id=u1.id, nmc_number="NMC-001",
            doctor_code="DRABC12",
        )
        dp2 = models.DoctorProfile(
            user_id=u2.id, nmc_number="NMC-002",
            doctor_code="DRABC12",  # duplicate
        )
        db.add(dp1)
        db.flush()
        db.add(dp2)
        with pytest.raises(Exception):  # IntegrityError
            db.flush()

    def test_nmc_number_unique(self, db):
        u1 = self._make_doctor_user(db, "doc3@test.com")
        u2 = self._make_doctor_user(db, "doc4@test.com")
        dp1 = models.DoctorProfile(
            user_id=u1.id, nmc_number="NMC-SAME",
            doctor_code="DRXYZ01",
        )
        dp2 = models.DoctorProfile(
            user_id=u2.id, nmc_number="NMC-SAME",  # duplicate NMC
            doctor_code="DRXYZ02",
        )
        db.add(dp1)
        db.flush()
        db.add(dp2)
        with pytest.raises(Exception):
            db.flush()

    def test_user_id_unique(self, db):
        user = self._make_doctor_user(db, "doc5@test.com")
        dp1 = models.DoctorProfile(
            user_id=user.id, nmc_number="NMC-A",
            doctor_code="DRAAA01",
        )
        dp2 = models.DoctorProfile(
            user_id=user.id, nmc_number="NMC-B",
            doctor_code="DRAAA02",
        )
        db.add(dp1)
        db.flush()
        db.add(dp2)
        with pytest.raises(Exception):
            db.flush()

    def test_verification_fields(self, db):
        user = self._make_doctor_user(db, "doc6@test.com")
        admin = models.User(
            email="verifyadmin@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Admin",
            phone_number="9000000099",
            role=UserRole.admin,
        )
        db.add(admin)
        db.flush()

        dp = models.DoctorProfile(
            user_id=user.id, nmc_number="NMC-VERIFY",
            doctor_code="DRVER01",
            is_verified=True,
            verified_at=datetime.now(timezone.utc),
            verified_by=admin.id,
        )
        db.add(dp)
        db.flush()
        assert dp.is_verified is True
        assert dp.verified_by == admin.id


# ---------------------------------------------------------------------------
# DoctorPatientLink model
# ---------------------------------------------------------------------------

class TestDoctorPatientLink:
    def _setup(self, db):
        doctor = models.User(
            email="linkdoc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Link",
            phone_number="9000000020",
            role=UserRole.doctor,
        )
        patient = models.User(
            email="linkpat@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Patient Link",
            phone_number="9000000021",
        )
        db.add_all([doctor, patient])
        db.flush()

        profile = models.Profile(name="Patient Profile")
        db.add(profile)
        db.flush()

        access = models.ProfileAccess(
            user_id=patient.id, profile_id=profile.id, access_level="owner",
        )
        db.add(access)
        db.flush()

        return doctor, patient, profile

    def test_create_link(self, db):
        doctor, patient, profile = self._setup(db)
        link = models.DoctorPatientLink(
            doctor_id=doctor.id,
            profile_id=profile.id,
            consent_granted_at=datetime.now(timezone.utc),
            consent_granted_by=patient.id,
            consent_type="in_person_exam",
            doctor_code_used="DRLIN01",
        )
        db.add(link)
        db.flush()
        assert link.id is not None
        assert link.is_active is True
        assert link.triage_status == "no_data"
        assert link.compliance_7d == 0

    def test_unique_doctor_patient(self, db):
        doctor, patient, profile = self._setup(db)
        link1 = models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=profile.id,
            consent_granted_at=datetime.now(timezone.utc),
            consent_granted_by=patient.id,
            consent_type="in_person_exam",
        )
        link2 = models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=profile.id,  # duplicate
            consent_granted_at=datetime.now(timezone.utc),
            consent_granted_by=patient.id,
            consent_type="video_consult",
        )
        db.add(link1)
        db.flush()
        db.add(link2)
        with pytest.raises(Exception):
            db.flush()

    def test_revoke_link(self, db):
        doctor, patient, profile = self._setup(db)
        link = models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=profile.id,
            consent_granted_at=datetime.now(timezone.utc),
            consent_granted_by=patient.id,
            consent_type="in_person_exam",
        )
        db.add(link)
        db.flush()

        link.is_active = False
        link.revoked_at = datetime.now(timezone.utc)
        db.flush()
        assert link.is_active is False
        assert link.revoked_at is not None

    def test_triage_cache_fields(self, db):
        doctor, patient, profile = self._setup(db)
        link = models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=profile.id,
            consent_granted_at=datetime.now(timezone.utc),
            consent_granted_by=patient.id,
            consent_type="in_person_exam",
            triage_status="critical",
            last_reading_value="182/115",
            last_reading_type="blood_pressure",
            last_reading_at=datetime.now(timezone.utc),
            compliance_7d=5,
            trend_direction="worsening",
        )
        db.add(link)
        db.flush()
        assert link.triage_status == "critical"
        assert link.last_reading_value == "182/115"
        assert link.compliance_7d == 5
        assert link.trend_direction == "worsening"


# ---------------------------------------------------------------------------
# DoctorNote model
# ---------------------------------------------------------------------------

class TestDoctorNote:
    def test_create_note(self, db):
        doctor = models.User(
            email="notedoc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Notes",
            phone_number="9000000030",
            role=UserRole.doctor,
        )
        db.add(doctor)
        db.flush()

        profile = models.Profile(name="Note Patient")
        db.add(profile)
        db.flush()

        note = models.DoctorNote(
            doctor_id=doctor.id,
            profile_id=profile.id,
            reading_id=None,  # general note
            note_text="Patient compliance improving. Continue current medication.",
            is_shared_with_patient=False,
        )
        db.add(note)
        db.flush()
        assert note.id is not None
        assert note.is_shared_with_patient is False

    def test_note_shared_with_patient(self, db):
        doctor = models.User(
            email="sharedoc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Share",
            phone_number="9000000031",
            role=UserRole.doctor,
        )
        db.add(doctor)
        db.flush()

        profile = models.Profile(name="Share Patient")
        db.add(profile)
        db.flush()

        note = models.DoctorNote(
            doctor_id=doctor.id,
            profile_id=profile.id,
            note_text="Reduce salt intake. Walk 30 min daily.",
            is_shared_with_patient=True,
        )
        db.add(note)
        db.flush()
        assert note.is_shared_with_patient is True


# ---------------------------------------------------------------------------
# DoctorAccessLog model
# ---------------------------------------------------------------------------

class TestDoctorAccessLog:
    def test_create_log(self, db):
        doctor = models.User(
            email="logdoc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Logger",
            phone_number="9000000040",
            role=UserRole.doctor,
        )
        db.add(doctor)
        db.flush()

        profile = models.Profile(name="Log Patient")
        db.add(profile)
        db.flush()

        log = models.DoctorAccessLog(
            doctor_id=doctor.id,
            profile_id=profile.id,
            action="viewed_readings",
            endpoint="/api/doctor/patients/1/readings",
        )
        db.add(log)
        db.flush()
        assert log.id is not None
        assert log.action == "viewed_readings"

    def test_multiple_logs(self, db):
        doctor = models.User(
            email="multilog@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. MultiLog",
            phone_number="9000000041",
            role=UserRole.doctor,
        )
        db.add(doctor)
        db.flush()

        profile = models.Profile(name="MultiLog Patient")
        db.add(profile)
        db.flush()

        actions = ["viewed_readings", "added_note", "viewed_trends"]
        for action in actions:
            db.add(models.DoctorAccessLog(
                doctor_id=doctor.id,
                profile_id=profile.id,
                action=action,
            ))
        db.flush()

        logs = db.query(models.DoctorAccessLog).filter(
            models.DoctorAccessLog.doctor_id == doctor.id,
        ).all()
        assert len(logs) == 3


# ---------------------------------------------------------------------------
# Schema validation tests
# ---------------------------------------------------------------------------

class TestDoctorSchemas:
    def test_doctor_register_valid(self):
        from schemas import DoctorRegister
        data = DoctorRegister(
            email="dr@test.com",
            password="Doctor@123",
            confirm_password="Doctor@123",
            full_name="Dr. Test",
            phone_number="9876543210",
            nmc_number="BR-12345",
            specialty="General Physician",
            clinic_name="Test Clinic",
        )
        assert data.nmc_number == "BR-12345"
        assert data.timezone == "Asia/Kolkata"

    def test_doctor_register_bad_specialty(self):
        from schemas import DoctorRegister
        with pytest.raises(Exception):
            DoctorRegister(
                email="dr@test.com",
                password="Doctor@123",
                confirm_password="Doctor@123",
                full_name="Dr. Test",
                phone_number="9876543210",
                nmc_number="BR-12345",
                specialty="Wizard",  # invalid
            )

    def test_doctor_register_password_mismatch(self):
        from schemas import DoctorRegister
        with pytest.raises(Exception):
            DoctorRegister(
                email="dr@test.com",
                password="Doctor@123",
                confirm_password="Different@123",
                full_name="Dr. Test",
                phone_number="9876543210",
                nmc_number="BR-12345",
            )

    def test_doctor_patient_link_request_valid(self):
        from schemas import DoctorPatientLinkRequest
        req = DoctorPatientLinkRequest(
            doctor_code="DRRAJ52",
            consent_type="in_person_exam",
        )
        assert req.doctor_code == "DRRAJ52"

    def test_doctor_patient_link_request_bad_consent(self):
        from schemas import DoctorPatientLinkRequest
        with pytest.raises(Exception):
            DoctorPatientLinkRequest(
                doctor_code="DRRAJ52",
                consent_type="phone_call",  # invalid
            )

    def test_doctor_note_create_valid(self):
        from schemas import DoctorNoteCreate
        note = DoctorNoteCreate(
            note_text="Increase Amlodipine to 10mg",
            reading_id=42,
        )
        assert note.is_shared_with_patient is False

    def test_doctor_note_create_empty_text(self):
        from schemas import DoctorNoteCreate
        with pytest.raises(Exception):
            DoctorNoteCreate(note_text="")  # min_length=1

    def test_triage_patient_card(self):
        from schemas import TriagePatientCard
        card = TriagePatientCard(
            profile_id=1,
            profile_name="Ramesh Kumar",
            age=62,
            gender="Male",
            medical_conditions=["Diabetes T2", "Hypertension"],
            triage_status="critical",
            last_reading_value="182/115",
            last_reading_type="blood_pressure",
            compliance_7d=5,
            trend_direction="worsening",
            link_id=10,
        )
        assert card.triage_status == "critical"

    def test_user_response_includes_role(self):
        from schemas import UserResponse
        resp = UserResponse(
            id=1, email="test@test.com", full_name="Test",
            phone_number="1234567890", is_active=True,
            role="doctor", timezone="UTC",
            created_at=datetime.now(),
        )
        assert resp.role == "doctor"


# ---------------------------------------------------------------------------
# Dependency tests
# ---------------------------------------------------------------------------

class TestDoctorDependencies:
    def _make_doctor_with_link(self, db):
        doctor = models.User(
            email="depdoc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. Dep",
            phone_number="9000000050",
            role=UserRole.doctor,
        )
        db.add(doctor)
        db.flush()

        profile = models.Profile(name="Dep Patient")
        db.add(profile)
        db.flush()

        link = models.DoctorPatientLink(
            doctor_id=doctor.id,
            profile_id=profile.id,
            consent_granted_at=datetime.now(timezone.utc),
            consent_granted_by=doctor.id,
            consent_type="in_person_exam",
        )
        db.add(link)
        db.flush()

        return doctor, profile, link

    def test_doctor_access_success(self, db):
        from dependencies import get_doctor_patient_access
        doctor, profile, link = self._make_doctor_with_link(db)
        result = get_doctor_patient_access(profile.id, doctor, db)
        assert result.id == link.id

    def test_doctor_access_not_a_doctor(self, db):
        from dependencies import get_doctor_patient_access
        from fastapi import HTTPException
        patient = models.User(
            email="notdoc@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Not Doctor",
            phone_number="9000000051",
            role=UserRole.patient,
        )
        db.add(patient)
        db.flush()

        with pytest.raises(HTTPException) as exc:
            get_doctor_patient_access(999, patient, db)
        assert exc.value.status_code == 403
        assert "Only doctors" in exc.value.detail

    def test_doctor_access_no_link(self, db):
        from dependencies import get_doctor_patient_access
        from fastapi import HTTPException
        doctor = models.User(
            email="nolink@test.com",
            password_hash=get_password_hash("Test@1234"),
            full_name="Dr. NoLink",
            phone_number="9000000052",
            role=UserRole.doctor,
        )
        db.add(doctor)
        db.flush()

        profile = models.Profile(name="Unlinked Patient")
        db.add(profile)
        db.flush()

        with pytest.raises(HTTPException) as exc:
            get_doctor_patient_access(profile.id, doctor, db)
        assert exc.value.status_code == 403
        assert "No active access" in exc.value.detail

    def test_doctor_access_revoked_link(self, db):
        from dependencies import get_doctor_patient_access
        from fastapi import HTTPException
        doctor, profile, link = self._make_doctor_with_link(db)
        link.is_active = False
        link.revoked_at = datetime.now(timezone.utc)
        db.flush()

        with pytest.raises(HTTPException) as exc:
            get_doctor_patient_access(profile.id, doctor, db)
        assert exc.value.status_code == 403
