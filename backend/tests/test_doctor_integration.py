"""End-to-end integration tests for the doctor workflow.

These exercise the full happy-path and alternate paths as a single
connected workflow — each test drives the app through multiple endpoints
in sequence, the way a real patient + doctor would use the app. This
catches the class of bug where individual endpoint tests pass but the
endpoints fail to compose (e.g. directory returning the wrong schema,
link rejecting a doctor the directory just surfaced, triage still
showing a patient after revocation).

Fixtures (doctor_user, patient_user, patient_headers, doctor_headers,
patient_with_readings) are imported via pytest conftest propagation
from ``test_doctor_routes`` in the same directory.
"""
from datetime import date, timedelta

import pytest

from tests.test_doctor_routes import (  # noqa: F401 — re-used fixtures
    doctor_user,
    doctor_headers,
    patient_user,
    patient_headers,
    patient_with_readings,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _pick_doctor_from_directory(client, patient_headers):
    """Patient-side: fetch directory and pick the verified doctor.

    Asserts the picker response contains the ``is_verified`` flag the
    Flutter preview card relies on — without it, the link UI silently
    aborts on the verified-only guard even though the backend would
    accept the request.
    """
    resp = client.get("/api/doctor/directory", headers=patient_headers)
    assert resp.status_code == 200, resp.text
    rows = resp.json()
    assert len(rows) >= 1, "directory should surface the seeded doctor"
    entry = rows[0]
    assert entry["doctor_code"] == "DRRAJ52"
    assert entry["is_verified"] is True, (
        "directory MUST expose is_verified so the Flutter picker can "
        "mark the selection verified before submitting the link"
    )
    # PII must not leak
    assert "email" not in entry
    assert "phone_number" not in entry
    assert "nmc_number" not in entry
    return entry


def _request_link(client, patient_headers, profile_id, doctor_code="DRRAJ52"):
    resp = client.post(
        f"/api/doctor/link/{profile_id}",
        json={"doctor_code": doctor_code, "consent_type": "in_person_exam"},
        headers=patient_headers,
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["status"] == "pending_doctor_accept"
    return body


def _doctor_accepts(client, doctor_headers, profile_id):
    exam_date = (date.today() - timedelta(days=14)).isoformat()
    resp = client.post(
        f"/api/doctor/patients/{profile_id}/accept",
        headers=doctor_headers,
        json={
            "examined_on": exam_date,
            "examined_for_condition": "Type 2 diabetes follow-up",
        },
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "active"


# ---------------------------------------------------------------------------
# Full workflow integration
# ---------------------------------------------------------------------------


class TestDoctorWorkflowIntegration:
    """Drive the entire doctor workflow end-to-end."""

    def test_happy_path_full_workflow(
        self,
        client,
        doctor_user,
        doctor_headers,
        patient_user,
        patient_headers,
        patient_with_readings,
    ):
        """Full happy path:
        1. Patient opens directory → picks verified doctor
        2. Patient requests link → pending
        3. Doctor sees pending request in queue
        4. Doctor is blocked from reading data while pending
        5. Doctor accepts → status=active
        6. Doctor appears in patient's "my doctors" list
        7. Doctor sees patient on triage board
        8. Doctor reads patient's readings
        9. Doctor adds a clinical note
        10. Patient revokes access → doctor loses triage entry
        """
        _, profile = patient_user

        # 1. Directory pick
        picked = _pick_doctor_from_directory(client, patient_headers)

        # 2. Link request
        _request_link(client, patient_headers, profile.id, picked["doctor_code"])

        # 3. Pending queue shows it
        pending = client.get("/api/doctor/patients/pending", headers=doctor_headers)
        assert pending.status_code == 200
        pending_rows = pending.json()
        assert len(pending_rows) == 1
        assert pending_rows[0]["profile_id"] == profile.id

        # 4. Access blocked while pending
        r = client.get(
            f"/api/doctor/patients/{profile.id}/readings", headers=doctor_headers
        )
        assert r.status_code == 403
        triage_before = client.get("/api/doctor/patients", headers=doctor_headers)
        assert triage_before.status_code == 200
        assert triage_before.json() == []

        # 5. Accept
        _doctor_accepts(client, doctor_headers, profile.id)

        # 6. Patient's linked-doctors list contains the doctor
        mine = client.get(
            f"/api/doctor/link/{profile.id}", headers=patient_headers
        )
        assert mine.status_code == 200
        my_list = mine.json()
        assert len(my_list) == 1
        assert my_list[0]["doctor_code"] == "DRRAJ52"
        assert my_list[0]["status"] == "active"

        # 7. Triage board now contains the patient
        triage_after = client.get("/api/doctor/patients", headers=doctor_headers)
        assert triage_after.status_code == 200
        triage_rows = triage_after.json()
        assert len(triage_rows) == 1
        assert triage_rows[0]["profile_id"] == profile.id

        # 8. Readings visible
        readings = client.get(
            f"/api/doctor/patients/{profile.id}/readings", headers=doctor_headers
        )
        assert readings.status_code == 200
        reading_rows = readings.json()
        assert len(reading_rows) >= 2, "should see the seeded readings"

        # 9. Add a note
        note = client.post(
            f"/api/doctor/patients/{profile.id}/notes",
            headers=doctor_headers,
            json={
                "note_text": "BP elevated. Continue amlodipine, recheck in 2 weeks."
            },
        )
        assert note.status_code == 201, note.text

        # List notes round-trip
        notes = client.get(
            f"/api/doctor/patients/{profile.id}/notes", headers=doctor_headers
        )
        assert notes.status_code == 200
        assert len(notes.json()) == 1

        # 10. Patient revokes
        revoke = client.delete(
            f"/api/doctor/link/{profile.id}?doctor_code=DRRAJ52",
            headers=patient_headers,
        )
        assert revoke.status_code == 200, revoke.text

        # Doctor's triage + readings access should now fail/empty
        triage_final = client.get("/api/doctor/patients", headers=doctor_headers)
        assert triage_final.status_code == 200
        assert triage_final.json() == []

        readings_final = client.get(
            f"/api/doctor/patients/{profile.id}/readings", headers=doctor_headers
        )
        assert readings_final.status_code == 403

    def test_decline_flow_integration(
        self,
        client,
        doctor_user,
        doctor_headers,
        patient_user,
        patient_headers,
    ):
        """Decline path: link → pending → doctor declines → not active."""
        _, profile = patient_user
        _pick_doctor_from_directory(client, patient_headers)
        _request_link(client, patient_headers, profile.id)

        decline = client.post(
            f"/api/doctor/patients/{profile.id}/decline",
            headers=doctor_headers,
            json={"reason": "Cannot confirm recent in-person exam"},
        )
        assert decline.status_code == 200, decline.text

        # Pending queue empty
        pending = client.get("/api/doctor/patients/pending", headers=doctor_headers)
        assert pending.status_code == 200
        assert pending.json() == []

        # Not on triage
        triage = client.get("/api/doctor/patients", headers=doctor_headers)
        assert triage.json() == []

    def test_patient_withdraw_pending_integration(
        self,
        client,
        doctor_user,
        doctor_headers,
        patient_user,
        patient_headers,
    ):
        """Patient can cancel a pending request before the doctor acts."""
        _, profile = patient_user
        _pick_doctor_from_directory(client, patient_headers)
        _request_link(client, patient_headers, profile.id)

        # Withdraw via the same revoke endpoint — pending is a revocable state
        resp = client.delete(
            f"/api/doctor/link/{profile.id}?doctor_code=DRRAJ52",
            headers=patient_headers,
        )
        assert resp.status_code == 200, resp.text

        pending = client.get("/api/doctor/patients/pending", headers=doctor_headers)
        assert pending.json() == []

    def test_directory_filters_unverified_doctors(
        self, client, db, patient_headers
    ):
        """Unverified doctors must not surface in the patient-facing
        directory, even if they exist in the DB. This is the ground
        truth for the Flutter picker — trusting this filter is what
        lets the Flutter client always mark picker selections as
        verified."""
        import models
        from auth import get_password_hash

        unverified = models.User(
            email="dr.unverified@test.com",
            password_hash=get_password_hash("Doctor@123"),
            full_name="Dr. Unverified",
            phone_number="9876500099",
            role=models.UserRole.doctor,
        )
        db.add(unverified)
        db.flush()
        db.add(
            models.DoctorProfile(
                user_id=unverified.id,
                nmc_number="BR-00000",
                specialty="General Physician",
                clinic_name="Nowhere",
                doctor_code="DRNOPE1",
                is_verified=False,
            )
        )
        db.flush()

        resp = client.get("/api/doctor/directory", headers=patient_headers)
        assert resp.status_code == 200
        codes = [d["doctor_code"] for d in resp.json()]
        assert "DRNOPE1" not in codes
