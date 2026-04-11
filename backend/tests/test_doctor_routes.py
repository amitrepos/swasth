"""Integration tests for /api/doctor/* endpoints."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timezone, timedelta
from auth import get_password_hash, create_access_token
import models
from models import UserRole


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def doctor_user(db):
    """Create a doctor user with DoctorProfile."""
    user = models.User(
        email="dr.rajesh@test.com",
        password_hash=get_password_hash("Doctor@123"),
        full_name="Dr. Rajesh Verma",
        phone_number="9876500001",
        role=UserRole.doctor,
    )
    db.add(user)
    db.flush()

    dp = models.DoctorProfile(
        user_id=user.id,
        nmc_number="BR-99999",
        specialty="General Physician",
        clinic_name="Verma Clinic Patna",
        doctor_code="DRRAJ52",
        is_verified=True,
        verified_at=datetime.now(timezone.utc),
    )
    db.add(dp)
    db.flush()
    return user


@pytest.fixture()
def doctor_headers(doctor_user):
    token = create_access_token(data={"sub": doctor_user.email})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def patient_user(db):
    """Create a patient user with profile."""
    user = models.User(
        email="patient@test.com",
        password_hash=get_password_hash("Patient@123"),
        full_name="Ramesh Kumar",
        phone_number="9876500002",
    )
    db.add(user)
    db.flush()

    profile = models.Profile(
        name="Ramesh Health",
        age=62,
        gender="Male",
        height=170,
        weight=75,
        medical_conditions=["Diabetes T2", "Hypertension"],
        current_medications="Metformin 500mg, Amlodipine 5mg",
    )
    db.add(profile)
    db.flush()

    access = models.ProfileAccess(
        user_id=user.id, profile_id=profile.id, access_level="owner",
    )
    db.add(access)
    db.flush()
    return user, profile


@pytest.fixture()
def patient_headers(patient_user):
    user, _ = patient_user
    token = create_access_token(data={"sub": user.email})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def linked_doctor_patient(db, doctor_user, patient_user):
    """Create an already-accepted (active) doctor-patient link.

    Post-Phase-4, new links default to `status='pending_doctor_accept'`
    until the doctor accepts them. For tests that want a fully linked
    doctor+patient out of the box, this fixture bypasses the pending
    flow and inserts an active row with a fake accept attestation.
    """
    from datetime import date, timedelta
    _, profile = patient_user
    now = datetime.now(timezone.utc)
    link = models.DoctorPatientLink(
        doctor_id=doctor_user.id,
        profile_id=profile.id,
        consent_granted_at=now,
        consent_granted_by=patient_user[0].id,
        consent_type="in_person_exam",
        doctor_code_used="DRRAJ52",
        status="active",
        is_active=True,
        accepted_at=now,
        accepted_by_doctor_id=doctor_user.id,
        examined_on=date.today() - timedelta(days=7),
        examined_for_condition="Type 2 diabetes follow-up",
        triage_status="stable",
        compliance_7d=5,
    )
    db.add(link)
    db.flush()
    return link


@pytest.fixture()
def patient_with_readings(db, patient_user):
    """Add some health readings to the patient profile."""
    _, profile = patient_user
    now = datetime.now(timezone.utc)

    readings = [
        models.HealthReading(
            profile_id=profile.id,
            reading_type="blood_pressure",
            systolic=175, diastolic=110,
            value_numeric=175, unit_display="mmHg",
            status_flag="HIGH - STAGE 2",
            reading_timestamp=now - timedelta(hours=2),
        ),
        models.HealthReading(
            profile_id=profile.id,
            reading_type="glucose",
            glucose_value=245, glucose_unit="mg/dL",
            sample_type="fasting",
            value_numeric=245, unit_display="mg/dL",
            status_flag="HIGH",
            reading_timestamp=now - timedelta(hours=6),
        ),
        models.HealthReading(
            profile_id=profile.id,
            reading_type="glucose",
            glucose_value=120, glucose_unit="mg/dL",
            sample_type="fasting",
            value_numeric=120, unit_display="mg/dL",
            status_flag="NORMAL",
            reading_timestamp=now - timedelta(days=2),
        ),
    ]
    db.add_all(readings)
    db.flush()
    return readings


# ---------------------------------------------------------------------------
# POST /api/doctor/register
# ---------------------------------------------------------------------------

class TestDoctorRegistration:
    URL = "/api/doctor/register"

    def _payload(self, **overrides):
        data = {
            "email": "newdoc@test.com",
            "password": "NewDoc@123",
            "confirm_password": "NewDoc@123",
            "full_name": "Dr. New Doctor",
            "phone_number": "9876500099",
            "nmc_number": "BR-11111",
            "specialty": "Endocrinologist",
            "clinic_name": "New Clinic",
        }
        data.update(overrides)
        return data

    def test_register_success(self, client):
        resp = client.post(self.URL, json=self._payload())
        assert resp.status_code == 201
        body = resp.json()
        assert body["full_name"] == "Dr. New Doctor"
        assert body["nmc_number"] == "BR-11111"
        assert body["doctor_code"].startswith("DR")
        assert len(body["doctor_code"]) >= 6
        assert body["is_verified"] is False

    def test_register_duplicate_email(self, client, doctor_user):
        resp = client.post(self.URL, json=self._payload(email="dr.rajesh@test.com"))
        assert resp.status_code == 400
        assert "already registered" in resp.json()["detail"].lower()

    def test_register_duplicate_nmc(self, client, doctor_user):
        resp = client.post(self.URL, json=self._payload(nmc_number="BR-99999"))
        assert resp.status_code == 400
        assert "nmc" in resp.json()["detail"].lower()

    def test_register_weak_password(self, client):
        resp = client.post(self.URL, json=self._payload(password="weak", confirm_password="weak"))
        assert resp.status_code == 422

    def test_register_invalid_specialty(self, client):
        resp = client.post(self.URL, json=self._payload(specialty="Wizard"))
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# GET /api/doctor/me
# ---------------------------------------------------------------------------

class TestDoctorMe:
    URL = "/api/doctor/me"

    def test_get_doctor_profile(self, client, doctor_user, doctor_headers):
        resp = client.get(self.URL, headers=doctor_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["full_name"] == "Dr. Rajesh Verma"
        assert body["doctor_code"] == "DRRAJ52"
        assert body["is_verified"] is True

    def test_patient_cannot_access(self, client, patient_user, patient_headers):
        resp = client.get(self.URL, headers=patient_headers)
        assert resp.status_code == 403

    def test_unauthenticated(self, client):
        resp = client.get(self.URL)
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# GET /api/doctor/lookup/{code}
# ---------------------------------------------------------------------------

class TestDoctorLookup:
    def test_lookup_valid_code(self, client, doctor_user, patient_headers):
        resp = client.get("/api/doctor/lookup/DRRAJ52", headers=patient_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["doctor_name"] == "Dr. Rajesh Verma"
        assert body["specialty"] == "General Physician"
        assert body["is_verified"] is True

    def test_lookup_case_insensitive(self, client, doctor_user, patient_headers):
        resp = client.get("/api/doctor/lookup/drraj52", headers=patient_headers)
        assert resp.status_code == 200

    def test_lookup_invalid_code(self, client, patient_headers):
        resp = client.get("/api/doctor/lookup/INVALID", headers=patient_headers)
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# POST /api/doctor/link/{profile_id}
# ---------------------------------------------------------------------------

class TestDoctorLink:
    def test_link_creates_pending_request(
        self, client, doctor_user, patient_user, patient_headers
    ):
        """Post-Phase-4: patient-initiated links start in
        `pending_doctor_accept`, not active. Doctor must explicitly
        accept before the link grants data access."""
        _, profile = patient_user
        resp = client.post(
            f"/api/doctor/link/{profile.id}",
            json={"doctor_code": "DRRAJ52", "consent_type": "in_person_exam"},
            headers=patient_headers,
        )
        assert resp.status_code == 201
        body = resp.json()
        assert body["doctor_name"] == "Dr. Rajesh Verma"
        assert body["consent_type"] == "in_person_exam"
        assert body["status"] == "pending_doctor_accept"
        assert body["is_active"] is False

    def test_link_duplicate_active_rejected(
        self, client, doctor_user, patient_user, patient_headers, linked_doctor_patient
    ):
        _, profile = patient_user
        resp = client.post(
            f"/api/doctor/link/{profile.id}",
            json={"doctor_code": "DRRAJ52", "consent_type": "in_person_exam"},
            headers=patient_headers,
        )
        assert resp.status_code == 400
        assert "already linked" in resp.json()["detail"].lower()

    def test_link_duplicate_pending_rejected(
        self, client, doctor_user, patient_user, patient_headers
    ):
        """If the patient has already sent a pending request, a second
        request for the same doctor is rejected with a distinct message."""
        _, profile = patient_user
        first = client.post(
            f"/api/doctor/link/{profile.id}",
            json={"doctor_code": "DRRAJ52", "consent_type": "in_person_exam"},
            headers=patient_headers,
        )
        assert first.status_code == 201
        second = client.post(
            f"/api/doctor/link/{profile.id}",
            json={"doctor_code": "DRRAJ52", "consent_type": "in_person_exam"},
            headers=patient_headers,
        )
        assert second.status_code == 400
        assert "waiting" in second.json()["detail"].lower()

    def test_link_invalid_code(self, client, patient_user, patient_headers):
        _, profile = patient_user
        resp = client.post(
            f"/api/doctor/link/{profile.id}",
            json={"doctor_code": "INVALID", "consent_type": "in_person_exam"},
            headers=patient_headers,
        )
        assert resp.status_code == 404

    def test_link_invalid_consent_type(self, client, doctor_user, patient_user, patient_headers):
        _, profile = patient_user
        resp = client.post(
            f"/api/doctor/link/{profile.id}",
            json={"doctor_code": "DRRAJ52", "consent_type": "phone_call"},
            headers=patient_headers,
        )
        assert resp.status_code == 422

    def test_link_rejects_unverified_doctor(
        self, client, doctor_user, patient_user, patient_headers, db
    ):
        """NMC §5.2 + Consumer Protection Act 2019: platform must not
        facilitate telemedicine with a doctor whose credentials have not
        been verified. The backend must hard-block the link even if the
        UI mistakenly allowed it."""
        _, profile = patient_user
        # Flip the doctor to unverified
        dp = db.query(models.DoctorProfile).filter(
            models.DoctorProfile.user_id == doctor_user.id
        ).first()
        dp.is_verified = False
        db.flush()

        resp = client.post(
            f"/api/doctor/link/{profile.id}",
            json={"doctor_code": "DRRAJ52", "consent_type": "in_person_exam"},
            headers=patient_headers,
        )
        assert resp.status_code == 403
        assert "verif" in resp.json()["detail"].lower()

        # And no DoctorPatientLink row should have been created
        link = db.query(models.DoctorPatientLink).filter(
            models.DoctorPatientLink.doctor_id == doctor_user.id,
            models.DoctorPatientLink.profile_id == profile.id,
        ).first()
        assert link is None


# ---------------------------------------------------------------------------
# DELETE /api/doctor/link/{profile_id}
# ---------------------------------------------------------------------------

class TestDoctorRevoke:
    def test_revoke_link(self, client, doctor_user, patient_user, patient_headers, linked_doctor_patient):
        _, profile = patient_user
        resp = client.delete(
            f"/api/doctor/link/{profile.id}?doctor_code=DRRAJ52",
            headers=patient_headers,
        )
        assert resp.status_code == 200
        assert "revoked" in resp.json()["detail"].lower()

    def test_revoke_nonexistent(self, client, patient_user, patient_headers):
        _, profile = patient_user
        resp = client.delete(
            f"/api/doctor/link/{profile.id}?doctor_code=DRRAJ52",
            headers=patient_headers,
        )
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# GET /api/doctor/link/{profile_id}
# ---------------------------------------------------------------------------

class TestListLinkedDoctors:
    def test_list_linked(self, client, doctor_user, patient_user, patient_headers, linked_doctor_patient):
        _, profile = patient_user
        resp = client.get(f"/api/doctor/link/{profile.id}", headers=patient_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 1
        assert body[0]["doctor_name"] == "Dr. Rajesh Verma"
        assert body[0]["doctor_code"] == "DRRAJ52"

    def test_list_empty(self, client, patient_user, patient_headers):
        _, profile = patient_user
        resp = client.get(f"/api/doctor/link/{profile.id}", headers=patient_headers)
        assert resp.status_code == 200
        assert resp.json() == []


# ---------------------------------------------------------------------------
# GET /api/doctor/known-doctors (picker source)
# ---------------------------------------------------------------------------


class TestKnownDoctors:
    URL = "/api/doctor/known-doctors"

    def test_empty_for_new_user(self, client, patient_user, patient_headers):
        resp = client.get(self.URL, headers=patient_headers)
        assert resp.status_code == 200
        assert resp.json() == []

    def test_returns_linked_doctor(
        self,
        client,
        patient_user,
        patient_headers,
        doctor_user,
        linked_doctor_patient,
    ):
        _, profile = patient_user
        resp = client.get(self.URL, headers=patient_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 1
        entry = body[0]
        assert entry["doctor_name"] == "Dr. Rajesh Verma"
        assert entry["doctor_code"] == "DRRAJ52"
        assert entry["is_verified"] is True
        assert entry["specialty"] == "General Physician"
        assert entry["clinic_name"] == "Verma Clinic Patna"
        assert entry["linked_profile_ids"] == [profile.id]

    def test_dedupe_across_profiles(
        self,
        client,
        db,
        patient_user,
        patient_headers,
        doctor_user,
        linked_doctor_patient,
    ):
        """Same doctor linked to two profiles appears once with both profile IDs."""
        user, profile_one = patient_user
        # Add a second owned profile and link the same doctor
        profile_two = models.Profile(name="Mom Profile")
        db.add(profile_two)
        db.flush()
        db.add(
            models.ProfileAccess(
                user_id=user.id,
                profile_id=profile_two.id,
                access_level="owner",
            )
        )
        db.add(
            models.DoctorPatientLink(
                doctor_id=doctor_user.id,
                profile_id=profile_two.id,
                consent_granted_at=datetime.now(timezone.utc),
                consent_granted_by=user.id,
                consent_type="in_person_exam",
                doctor_code_used="DRRAJ52",
                status="active",
                is_active=True,
            )
        )
        db.flush()

        resp = client.get(self.URL, headers=patient_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 1  # deduped
        assert sorted(body[0]["linked_profile_ids"]) == sorted(
            [profile_one.id, profile_two.id]
        )

    def test_excludes_revoked_links(
        self,
        client,
        db,
        patient_user,
        patient_headers,
        doctor_user,
        linked_doctor_patient,
    ):
        linked_doctor_patient.status = "revoked"
        linked_doctor_patient.is_active = False
        linked_doctor_patient.revoked_at = datetime.now(timezone.utc)
        db.flush()

        resp = client.get(self.URL, headers=patient_headers)
        assert resp.status_code == 200
        assert resp.json() == []

    def test_excludes_shared_profiles(
        self,
        client,
        db,
        patient_user,
        patient_headers,
        doctor_user,
        linked_doctor_patient,
    ):
        """If a doctor is linked to a profile the user can only VIEW (not own),
        that doctor should NOT appear in their own picker."""
        # Create another user who owns a new profile; give our patient viewer access
        owner = models.User(
            email="otherowner@test.com",
            password_hash=get_password_hash("Other@1234"),
            full_name="Other Owner",
            phone_number="9876599999",
        )
        db.add(owner)
        db.flush()
        shared_profile = models.Profile(name="Shared Profile")
        db.add(shared_profile)
        db.flush()
        db.add(
            models.ProfileAccess(
                user_id=owner.id,
                profile_id=shared_profile.id,
                access_level="owner",
            )
        )
        # Viewer access for our patient
        db.add(
            models.ProfileAccess(
                user_id=patient_user[0].id,
                profile_id=shared_profile.id,
                access_level="viewer",
            )
        )
        # Link the same doctor only to the shared profile
        db.add(
            models.DoctorPatientLink(
                doctor_id=doctor_user.id,
                profile_id=shared_profile.id,
                consent_granted_at=datetime.now(timezone.utc),
                consent_granted_by=owner.id,
                consent_type="in_person_exam",
                doctor_code_used="DRRAJ52",
                status="active",
                is_active=True,
            )
        )
        db.flush()

        resp = client.get(self.URL, headers=patient_headers)
        assert resp.status_code == 200
        body = resp.json()
        # The doctor only appears because of the patient's OWN owned profile
        # (from the linked_doctor_patient fixture), not the shared one.
        assert len(body) == 1
        assert patient_user[1].id in body[0]["linked_profile_ids"]
        assert shared_profile.id not in body[0]["linked_profile_ids"]

    def test_requires_authentication(self, client):
        resp = client.get(self.URL)
        assert resp.status_code in (401, 403)


# ---------------------------------------------------------------------------
# GET /api/doctor/directory (patient-safe verified doctor picker)
# ---------------------------------------------------------------------------


class TestDoctorDirectory:
    URL = "/api/doctor/directory"

    def test_returns_verified_doctor(
        self, client, doctor_user, patient_headers
    ):
        resp = client.get(self.URL, headers=patient_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 1
        entry = body[0]
        assert entry["doctor_name"] == "Dr. Rajesh Verma"
        assert entry["specialty"] == "General Physician"
        assert entry["clinic_name"] == "Verma Clinic Patna"
        assert entry["doctor_code"] == "DRRAJ52"
        # is_verified must be present and True — the Flutter preview
        # card reads this flag to render the "Verified doctor" badge
        # and the _link() guard blocks submission otherwise. Every
        # doctor in this endpoint is verified by the filter, so the
        # client-side value is always True, but the field itself MUST
        # be in the response shape.
        assert entry["is_verified"] is True
        # PII must still NOT leak into the patient-facing directory
        assert "email" not in entry
        assert "phone_number" not in entry
        assert "nmc_number" not in entry
        assert "user_id" not in entry

    def test_excludes_unverified_doctors(
        self, client, db, doctor_user, patient_headers
    ):
        # Flip the fixture doctor to unverified
        dp = db.query(models.DoctorProfile).filter(
            models.DoctorProfile.user_id == doctor_user.id
        ).first()
        dp.is_verified = False
        db.flush()

        resp = client.get(self.URL, headers=patient_headers)
        assert resp.status_code == 200
        assert resp.json() == []

    def test_empty_when_no_doctors_exist(self, client, patient_headers):
        resp = client.get(self.URL, headers=patient_headers)
        assert resp.status_code == 200
        assert resp.json() == []

    def test_sorted_by_name_alphabetically(
        self, client, db, doctor_user, patient_headers
    ):
        # Add two more verified doctors with names that sort before and
        # after "Dr. Rajesh Verma" to verify stable ordering.
        from auth import get_password_hash
        dr_amit = models.User(
            email="dr.amit@test.com",
            password_hash=get_password_hash("Doctor@123"),
            full_name="Dr. Amit Kumar",
            phone_number="9876500003",
            role=UserRole.doctor,
        )
        dr_zara = models.User(
            email="dr.zara@test.com",
            password_hash=get_password_hash("Doctor@123"),
            full_name="Dr. Zara Ali",
            phone_number="9876500004",
            role=UserRole.doctor,
        )
        db.add_all([dr_amit, dr_zara])
        db.flush()
        db.add_all([
            models.DoctorProfile(
                user_id=dr_amit.id,
                nmc_number="BR-11111",
                specialty="Cardiologist",
                clinic_name="Kumar Heart",
                doctor_code="DRAMI01",
                is_verified=True,
                verified_at=datetime.now(timezone.utc),
            ),
            models.DoctorProfile(
                user_id=dr_zara.id,
                nmc_number="BR-22222",
                specialty="Paediatrics",
                clinic_name="Zara Clinic",
                doctor_code="DRZAR01",
                is_verified=True,
                verified_at=datetime.now(timezone.utc),
            ),
        ])
        db.flush()

        resp = client.get(self.URL, headers=patient_headers)
        assert resp.status_code == 200
        body = resp.json()
        names = [d["doctor_name"] for d in body]
        assert names == [
            "Dr. Amit Kumar",
            "Dr. Rajesh Verma",
            "Dr. Zara Ali",
        ]

    def test_requires_authentication(self, client):
        resp = client.get(self.URL)
        assert resp.status_code in (401, 403)


# ---------------------------------------------------------------------------
# Phase 4 — doctor-side accept/decline flow
# ---------------------------------------------------------------------------


class TestDoctorAcceptFlow:
    """State machine tests for the Phase 4 accept/decline flow."""

    def _create_pending_link(self, client, patient_headers, profile_id):
        resp = client.post(
            f"/api/doctor/link/{profile_id}",
            json={"doctor_code": "DRRAJ52", "consent_type": "in_person_exam"},
            headers=patient_headers,
        )
        assert resp.status_code == 201, resp.text
        return resp.json()

    def test_patient_link_starts_pending(
        self, client, doctor_user, patient_user, patient_headers
    ):
        _, profile = patient_user
        body = self._create_pending_link(client, patient_headers, profile.id)
        assert body["status"] == "pending_doctor_accept"
        assert body["is_active"] is False

    def test_pending_link_appears_in_doctor_queue(
        self, client, doctor_user, doctor_headers, patient_user, patient_headers
    ):
        _, profile = patient_user
        self._create_pending_link(client, patient_headers, profile.id)

        resp = client.get("/api/doctor/patients/pending", headers=doctor_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 1
        entry = body[0]
        assert entry["profile_id"] == profile.id
        assert entry["profile_name"] == profile.name
        assert entry["consent_type"] == "in_person_exam"

    def test_pending_link_blocks_doctor_from_reading_data(
        self, client, doctor_user, doctor_headers, patient_user, patient_headers
    ):
        """While pending, the doctor must NOT be able to view readings,
        profile info, or add notes on the patient."""
        _, profile = patient_user
        self._create_pending_link(client, patient_headers, profile.id)

        # Triage board excludes pending links
        triage = client.get("/api/doctor/patients", headers=doctor_headers)
        assert triage.status_code == 200
        assert triage.json() == []

        # Per-profile endpoints return 403
        readings = client.get(
            f"/api/doctor/patients/{profile.id}/readings", headers=doctor_headers
        )
        assert readings.status_code == 403

        profile_resp = client.get(
            f"/api/doctor/patients/{profile.id}/profile", headers=doctor_headers
        )
        assert profile_resp.status_code == 403

    def test_doctor_accepts_pending_link(
        self,
        client,
        db,
        doctor_user,
        doctor_headers,
        patient_user,
        patient_headers,
    ):
        from datetime import date, timedelta
        _, profile = patient_user
        self._create_pending_link(client, patient_headers, profile.id)

        exam_date = (date.today() - timedelta(days=14)).isoformat()
        resp = client.post(
            f"/api/doctor/patients/{profile.id}/accept",
            headers=doctor_headers,
            json={
                "examined_on": exam_date,
                "examined_for_condition": "Type 2 diabetes follow-up",
            },
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "active"
        assert body["examined_on"] == exam_date

        # Link is now active — doctor can see triage + readings
        triage = client.get("/api/doctor/patients", headers=doctor_headers)
        assert triage.status_code == 200
        assert len(triage.json()) == 1

        # DB state: status=active, is_active=True, attestation recorded
        link = (
            db.query(models.DoctorPatientLink)
            .filter(
                models.DoctorPatientLink.doctor_id == doctor_user.id,
                models.DoctorPatientLink.profile_id == profile.id,
            )
            .first()
        )
        assert link.status == "active"
        assert link.is_active is True
        assert link.accepted_at is not None
        assert link.accepted_by_doctor_id == doctor_user.id
        assert link.examined_for_condition == "Type 2 diabetes follow-up"

    def test_accept_rejects_future_exam_date(
        self, client, doctor_user, doctor_headers, patient_user, patient_headers
    ):
        from datetime import date, timedelta
        _, profile = patient_user
        self._create_pending_link(client, patient_headers, profile.id)

        future_date = (date.today() + timedelta(days=1)).isoformat()
        resp = client.post(
            f"/api/doctor/patients/{profile.id}/accept",
            headers=doctor_headers,
            json={
                "examined_on": future_date,
                "examined_for_condition": "Something",
            },
        )
        assert resp.status_code == 422

    def test_accept_rejects_exam_older_than_6_months(
        self, client, doctor_user, doctor_headers, patient_user, patient_headers
    ):
        from datetime import date, timedelta
        _, profile = patient_user
        self._create_pending_link(client, patient_headers, profile.id)

        old_date = (date.today() - timedelta(days=200)).isoformat()
        resp = client.post(
            f"/api/doctor/patients/{profile.id}/accept",
            headers=doctor_headers,
            json={
                "examined_on": old_date,
                "examined_for_condition": "Something",
            },
        )
        assert resp.status_code == 422

    def test_accept_rejects_missing_condition(
        self, client, doctor_user, doctor_headers, patient_user, patient_headers
    ):
        from datetime import date, timedelta
        _, profile = patient_user
        self._create_pending_link(client, patient_headers, profile.id)

        resp = client.post(
            f"/api/doctor/patients/{profile.id}/accept",
            headers=doctor_headers,
            json={
                "examined_on": (date.today() - timedelta(days=5)).isoformat(),
                "examined_for_condition": "  ",
            },
        )
        assert resp.status_code == 422

    def test_accept_nonexistent_link_404(
        self, client, doctor_user, doctor_headers, patient_user
    ):
        from datetime import date, timedelta
        _, profile = patient_user
        resp = client.post(
            f"/api/doctor/patients/{profile.id}/accept",
            headers=doctor_headers,
            json={
                "examined_on": (date.today() - timedelta(days=5)).isoformat(),
                "examined_for_condition": "Anything",
            },
        )
        assert resp.status_code == 404

    def test_doctor_declines_pending_link(
        self,
        client,
        db,
        doctor_user,
        doctor_headers,
        patient_user,
        patient_headers,
    ):
        _, profile = patient_user
        self._create_pending_link(client, patient_headers, profile.id)

        resp = client.post(
            f"/api/doctor/patients/{profile.id}/decline",
            headers=doctor_headers,
            json={"reason": "Not currently accepting new patients"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "revoked"

        # Link is gone from the patient list + triage
        linked = client.get(
            f"/api/doctor/link/{profile.id}", headers=patient_headers
        )
        assert linked.status_code == 200
        assert linked.json() == []

    def test_patient_can_withdraw_pending_request(
        self, client, doctor_user, patient_user, patient_headers
    ):
        """The patient can DELETE their own pending request before the
        doctor has reviewed it."""
        _, profile = patient_user
        self._create_pending_link(client, patient_headers, profile.id)

        resp = client.delete(
            f"/api/doctor/link/{profile.id}",
            params={"doctor_code": "DRRAJ52"},
            headers=patient_headers,
        )
        assert resp.status_code == 200

        # Subsequent linked-doctors list should be empty
        linked = client.get(
            f"/api/doctor/link/{profile.id}", headers=patient_headers
        )
        assert linked.status_code == 200
        assert linked.json() == []

    def test_non_doctor_cannot_see_pending_queue(self, client, patient_headers):
        resp = client.get("/api/doctor/patients/pending", headers=patient_headers)
        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# GET /api/doctor/patients (Triage Board)
# ---------------------------------------------------------------------------

class TestTriageBoard:
    def test_triage_board(self, client, doctor_user, doctor_headers, patient_user, linked_doctor_patient):
        resp = client.get("/api/doctor/patients", headers=doctor_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 1
        assert body[0]["profile_name"] == "Ramesh Health"
        assert body[0]["triage_status"] in ("critical", "attention", "stable", "no_data")

    def test_triage_board_empty(self, client, doctor_user, doctor_headers):
        resp = client.get("/api/doctor/patients", headers=doctor_headers)
        assert resp.status_code == 200
        assert resp.json() == []

    def test_patient_cannot_access_triage(self, client, patient_headers):
        resp = client.get("/api/doctor/patients", headers=patient_headers)
        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# GET /api/doctor/patients/{id}/readings
# ---------------------------------------------------------------------------

class TestPatientReadings:
    def test_get_readings(self, client, doctor_headers, patient_user, linked_doctor_patient, patient_with_readings):
        _, profile = patient_user
        resp = client.get(f"/api/doctor/patients/{profile.id}/readings", headers=doctor_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 3
        # Most recent first
        assert body[0]["reading_type"] == "blood_pressure"
        assert body[0]["systolic"] == 175

    def test_no_access_without_link(self, client, doctor_headers, patient_user):
        _, profile = patient_user
        resp = client.get(f"/api/doctor/patients/{profile.id}/readings", headers=doctor_headers)
        assert resp.status_code == 403

    def test_patient_cannot_use_doctor_endpoint(self, client, patient_headers, patient_user):
        _, profile = patient_user
        resp = client.get(f"/api/doctor/patients/{profile.id}/readings", headers=patient_headers)
        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# GET /api/doctor/patients/{id}/profile
# ---------------------------------------------------------------------------

class TestPatientProfile:
    def test_get_profile(self, client, doctor_headers, patient_user, linked_doctor_patient):
        _, profile = patient_user
        resp = client.get(f"/api/doctor/patients/{profile.id}/profile", headers=doctor_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["name"] == "Ramesh Health"
        assert body["age"] == 62
        assert body["current_medications"] == "Metformin 500mg, Amlodipine 5mg"
        assert body["bmi"] is not None
        # Should NOT contain chat data
        assert "chat" not in str(body).lower()

    def test_no_access_without_link(self, client, doctor_headers, patient_user):
        _, profile = patient_user
        resp = client.get(f"/api/doctor/patients/{profile.id}/profile", headers=doctor_headers)
        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# GET /api/doctor/patients/{id}/summary
# ---------------------------------------------------------------------------

class TestPatientSummary:
    def test_get_summary(self, client, doctor_headers, patient_user, linked_doctor_patient, patient_with_readings):
        _, profile = patient_user
        resp = client.get(f"/api/doctor/patients/{profile.id}/summary", headers=doctor_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["period_days"] == 7
        assert body["total_readings"] == 3
        assert body["glucose"]["count"] == 2
        assert body["bp"]["count"] == 1
        assert body["bp"]["avg_systolic"] == 175


# ---------------------------------------------------------------------------
# POST /api/doctor/patients/{id}/notes
# ---------------------------------------------------------------------------

class TestDoctorNotes:
    def test_create_note(self, client, doctor_headers, patient_user, linked_doctor_patient):
        _, profile = patient_user
        resp = client.post(
            f"/api/doctor/patients/{profile.id}/notes",
            json={"note_text": "Increase Amlodipine to 10mg. Recheck in 1 week."},
            headers=doctor_headers,
        )
        assert resp.status_code == 201
        body = resp.json()
        assert body["note_text"] == "Increase Amlodipine to 10mg. Recheck in 1 week."
        assert body["is_shared_with_patient"] is False

    def test_create_note_on_reading(self, client, doctor_headers, patient_user, linked_doctor_patient, patient_with_readings):
        _, profile = patient_user
        reading_id = patient_with_readings[0].id
        resp = client.post(
            f"/api/doctor/patients/{profile.id}/notes",
            json={"note_text": "BP dangerously high", "reading_id": reading_id},
            headers=doctor_headers,
        )
        assert resp.status_code == 201
        assert resp.json()["reading_id"] == reading_id

    def test_create_note_invalid_reading(self, client, doctor_headers, patient_user, linked_doctor_patient):
        _, profile = patient_user
        resp = client.post(
            f"/api/doctor/patients/{profile.id}/notes",
            json={"note_text": "Test", "reading_id": 99999},
            headers=doctor_headers,
        )
        assert resp.status_code == 404

    def test_list_notes(self, client, doctor_headers, patient_user, linked_doctor_patient):
        _, profile = patient_user
        # Create 2 notes
        for text in ["Note 1", "Note 2"]:
            client.post(
                f"/api/doctor/patients/{profile.id}/notes",
                json={"note_text": text},
                headers=doctor_headers,
            )

        resp = client.get(f"/api/doctor/patients/{profile.id}/notes", headers=doctor_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 2
        note_texts = {n["note_text"] for n in body}
        assert note_texts == {"Note 1", "Note 2"}

    def test_no_access_without_link(self, client, doctor_headers, patient_user):
        _, profile = patient_user
        resp = client.post(
            f"/api/doctor/patients/{profile.id}/notes",
            json={"note_text": "Sneaky note"},
            headers=doctor_headers,
        )
        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# POST /api/doctor/verify/{doctor_id} (Admin)
# ---------------------------------------------------------------------------

class TestVerifyDoctor:
    def test_admin_can_verify(self, client, db, doctor_user):
        # Create admin user
        admin = models.User(
            email="admin@test.com",
            password_hash=get_password_hash("Admin@1234"),
            full_name="Admin User",
            phone_number="9876500088",
            is_admin=True,
            role=UserRole.admin,
        )
        db.add(admin)
        db.flush()
        admin_token = create_access_token(data={"sub": admin.email})

        # Unverify the doctor first
        dp = db.query(models.DoctorProfile).filter(models.DoctorProfile.user_id == doctor_user.id).first()
        dp.is_verified = False
        db.flush()

        resp = client.post(
            f"/api/doctor/verify/{doctor_user.id}",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        assert "verified" in resp.json()["detail"].lower()

    def test_patient_cannot_verify(self, client, doctor_user, patient_headers):
        resp = client.post(
            f"/api/doctor/verify/{doctor_user.id}",
            headers=patient_headers,
        )
        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# GET /api/doctor/audit/{profile_id}
# ---------------------------------------------------------------------------

class TestAuditLog:
    def test_doctor_sees_own_audit(self, client, doctor_headers, patient_user, linked_doctor_patient):
        _, profile = patient_user
        # Generate some access logs by hitting endpoints
        client.get(f"/api/doctor/patients/{profile.id}/readings", headers=doctor_headers)
        client.get(f"/api/doctor/patients/{profile.id}/profile", headers=doctor_headers)

        resp = client.get(f"/api/doctor/audit/{profile.id}", headers=doctor_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) >= 2

    def test_patient_sees_audit(self, client, doctor_headers, patient_headers, patient_user, linked_doctor_patient):
        _, profile = patient_user
        # Doctor accesses data
        client.get(f"/api/doctor/patients/{profile.id}/readings", headers=doctor_headers)

        # Patient can see who accessed their data
        resp = client.get(f"/api/doctor/audit/{profile.id}", headers=patient_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert any(log["doctor_name"] == "Dr. Rajesh Verma" for log in body)

    def test_unauthorized_user_blocked(self, client, db, patient_user):
        _, profile = patient_user
        # Random user with no access
        other = models.User(
            email="other@test.com",
            password_hash=get_password_hash("Other@1234"),
            full_name="Other User",
            phone_number="9876500077",
        )
        db.add(other)
        db.flush()
        other_token = create_access_token(data={"sub": other.email})

        resp = client.get(
            f"/api/doctor/audit/{profile.id}",
            headers={"Authorization": f"Bearer {other_token}"},
        )
        assert resp.status_code == 403
