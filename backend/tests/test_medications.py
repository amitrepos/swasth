"""Tests for medication-intake API (NUO-127).

Covers: create, list, update, delete, access control, doctor view.
"""
from datetime import date, datetime, timezone, timedelta
from io import BytesIO
from pathlib import Path
from unittest.mock import patch

import pytest

import models
from auth import create_access_token, get_password_hash
from models import UserRole

_FAKE_JPEG = b"\xff\xd8\xff" + b"fake-jpeg-bytes"


def _abs_photo_path(relative_path: str) -> Path:
    from medication_photo_storage import _UPLOAD_ROOT

    rel = Path(relative_path)
    parts = rel.parts
    suffix = Path(*parts[parts.index("medication_photos") + 1 :])
    return _UPLOAD_ROOT / suffix


@pytest.fixture(autouse=True)
def isolated_medication_photo_uploads(tmp_path, monkeypatch):
    """Keep encrypted photo files off the shared backend/uploads tree in CI."""
    upload_root = tmp_path / "medication_photos"
    monkeypatch.setattr("medication_photo_storage._UPLOAD_ROOT", upload_root)
    yield


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _profile_id_for(user, db):
    access = (
        db.query(models.ProfileAccess)
        .filter(models.ProfileAccess.user_id == user.id)
        .first()
    )
    return access.profile_id


def _post_medication(client, headers, profile_id, **overrides):
    payload = {
        "profile_id": profile_id,
        "name": "Metformin",
        "dose": "500 mg",
        "frequency": "Twice daily",
        "intake_period": "MORNING",
        "taken_at": datetime.now(timezone.utc).isoformat(),
        "notes": None,
    }
    payload.update(overrides)
    return client.post("/api/medications", json=payload, headers=headers)


def _post_medication_with_photo(client, headers, profile_id, **overrides):
    fields = {
        "profile_id": str(profile_id),
        "name": "Metformin",
        "dose": "500 mg",
        "frequency": "Twice daily",
        "intake_period": "MORNING",
        "taken_at": datetime.now(timezone.utc).isoformat(),
        "notes": "",
    }
    fields.update({k: str(v) for k, v in overrides.items() if v is not None})
    files = {"photo": ("strip.jpg", BytesIO(_FAKE_JPEG), "image/jpeg")}
    return client.post("/api/medications", data=fields, files=files, headers=headers)


# ---------------------------------------------------------------------------
# Create
# ---------------------------------------------------------------------------

def test_create_medication_returns_201_and_persists(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    r = _post_medication(client, auth_headers, pid, notes="Felt fine")
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["name"] == "Metformin"
    assert body["dose"] == "500 mg"
    assert body["notes"] == "Felt fine"
    assert body["intake_period"] == "MORNING"
    assert body["profile_id"] == pid

    rows = db.query(models.Medication).filter(models.Medication.profile_id == pid).all()
    assert len(rows) == 1
    assert rows[0].logged_by == test_user.id
    assert rows[0].name == "Metformin"
    # PHI must be encrypted at rest (C2), not stored as plaintext.
    assert rows[0].name_enc is not None
    assert rows[0].name_enc != "Metformin"


def test_create_medication_rejects_empty_name(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    r = _post_medication(client, auth_headers, pid, name="")
    assert r.status_code == 422


def test_create_medication_rejects_invalid_intake_period(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    r = _post_medication(client, auth_headers, pid, intake_period="NOON")
    assert r.status_code == 422


@pytest.mark.parametrize("period", ["MORNING", "AFTERNOON", "EVENING", "NIGHT"])
def test_create_medication_all_intake_periods(
    client, db, test_user, auth_headers, period
):
    pid = _profile_id_for(test_user, db)
    r = _post_medication(client, auth_headers, pid, intake_period=period)
    assert r.status_code == 201, r.text
    assert r.json()["intake_period"] == period
    row = (
        db.query(models.Medication)
        .filter(models.Medication.profile_id == pid)
        .order_by(models.Medication.id.desc())
        .first()
    )
    assert row.intake_period == period


def test_update_medication_intake_period(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    r = _post_medication(client, auth_headers, pid, intake_period="MORNING")
    assert r.status_code == 201, r.text
    med_id = r.json()["id"]

    r2 = client.patch(
        f"/api/medications/{med_id}",
        json={"intake_period": "NIGHT"},
        headers=auth_headers,
    )
    assert r2.status_code == 200, r2.text
    assert r2.json()["intake_period"] == "NIGHT"

    row = db.query(models.Medication).filter_by(id=med_id).first()
    assert row.intake_period == "NIGHT"


def test_update_medication_rejects_invalid_intake_period(
    client, db, test_user, auth_headers
):
    pid = _profile_id_for(test_user, db)
    r = _post_medication(client, auth_headers, pid, intake_period="MORNING")
    assert r.status_code == 201, r.text
    med_id = r.json()["id"]

    r2 = client.patch(
        f"/api/medications/{med_id}",
        json={"intake_period": "NOON"},
        headers=auth_headers,
    )
    assert r2.status_code == 422


def test_update_medication_preserves_period_when_omitted(
    client, db, test_user, auth_headers
):
    """PATCHing only dose must not change an existing intake_period."""
    pid = _profile_id_for(test_user, db)
    r = _post_medication(client, auth_headers, pid, intake_period="EVENING")
    assert r.status_code == 201, r.text
    med_id = r.json()["id"]

    r2 = client.patch(
        f"/api/medications/{med_id}",
        json={"dose": "750 mg"},
        headers=auth_headers,
    )
    assert r2.status_code == 200, r2.text
    assert r2.json()["intake_period"] == "EVENING"
    row = db.query(models.Medication).filter_by(id=med_id).first()
    assert row.intake_period == "EVENING"


def test_create_medication_rejects_future_taken_at(client, db, test_user, auth_headers):
    """taken_at well in the future would never appear in the report window."""
    pid = _profile_id_for(test_user, db)
    future = (datetime.now(timezone.utc) + timedelta(hours=2)).isoformat()
    r = _post_medication(client, auth_headers, pid, taken_at=future)
    assert r.status_code == 422


def test_create_medication_allows_small_clock_skew(client, db, test_user, auth_headers):
    """A minute of client clock-skew is tolerated (not rejected)."""
    pid = _profile_id_for(test_user, db)
    near = (datetime.now(timezone.utc) + timedelta(minutes=1)).isoformat()
    r = _post_medication(client, auth_headers, pid, taken_at=near)
    assert r.status_code == 201, r.text


def test_create_medication_night_period_same_day_clamped_not_rejected(
    client, db, test_user, auth_headers
):
    """Flutter clamps same-day future anchors to now — backend must accept NIGHT."""
    pid = _profile_id_for(test_user, db)
    now = datetime.now(timezone.utc)
    r = _post_medication(
        client,
        auth_headers,
        pid,
        intake_period="NIGHT",
        taken_at=now.isoformat(),
    )
    assert r.status_code == 201, r.text
    assert r.json()["intake_period"] == "NIGHT"


def test_create_medication_rejects_night_anchor_beyond_skew_window(
    client, db, test_user, auth_headers
):
    """Unclamped 22:00 anchor sent 2h ahead of now exceeds the 5-minute skew window."""
    pid = _profile_id_for(test_user, db)
    future = (datetime.now(timezone.utc) + timedelta(hours=2)).isoformat()
    r = _post_medication(
        client,
        auth_headers,
        pid,
        intake_period="NIGHT",
        taken_at=future,
    )
    assert r.status_code == 422


def test_create_medication_strips_whitespace(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    r = _post_medication(client, auth_headers, pid, name="  Aspirin  ", dose="  ")
    assert r.status_code == 201
    body = r.json()
    assert body["name"] == "Aspirin"
    assert body["dose"] is None  # blank-only collapses to null


def test_create_medication_requires_auth(client, test_user, db):
    pid = _profile_id_for(test_user, db)
    r = _post_medication(client, headers={}, profile_id=pid)
    assert r.status_code == 401


def test_create_medication_with_photo_sets_has_photo(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    r = _post_medication_with_photo(client, auth_headers, pid)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["has_photo"] is True

    row = db.query(models.Medication).filter_by(id=body["id"]).first()
    assert row is not None
    assert row.has_photo is True
    assert row.photo_path is not None


def test_get_medication_photo_returns_bytes(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    create = _post_medication_with_photo(client, auth_headers, pid)
    assert create.status_code == 201, create.text
    med_id = create.json()["id"]

    photo = client.get(f"/api/medications/{med_id}/photo", headers=auth_headers)
    assert photo.status_code == 200
    assert photo.content == _FAKE_JPEG
    assert photo.headers["content-type"].startswith("image/jpeg")


def test_get_medication_photo_404_when_missing(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    created = _post_medication(client, auth_headers, pid)
    assert created.status_code == 201, created.text
    med_id = created.json()["id"]

    photo = client.get(f"/api/medications/{med_id}/photo", headers=auth_headers)
    assert photo.status_code == 404


def test_get_medication_photo_requires_auth(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    created = _post_medication_with_photo(client, auth_headers, pid)
    med_id = created.json()["id"]
    photo = client.get(f"/api/medications/{med_id}/photo")
    assert photo.status_code == 401


def test_get_medication_photo_denies_unrelated_patient(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    created = _post_medication_with_photo(client, auth_headers, pid)
    med_id = created.json()["id"]

    other = models.User(
        email="other-patient@test.com",
        password_hash=get_password_hash("Other@123"),
        full_name="Other Patient",
        phone_number="9876500099",
    )
    db.add(other)
    db.flush()
    other_profile = models.Profile(name="Other Health", phone_number="9876500098")
    db.add(other_profile)
    db.flush()
    db.add(
        models.ProfileAccess(
            user_id=other.id,
            profile_id=other_profile.id,
            access_level="owner",
        )
    )
    db.commit()
    other_headers = {
        "Authorization": f"Bearer {create_access_token(data={'sub': other.email})}"
    }

    photo = client.get(f"/api/medications/{med_id}/photo", headers=other_headers)
    assert photo.status_code == 403


def test_get_medication_photo_denies_unlinked_doctor(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    created = _post_medication_with_photo(client, auth_headers, pid)
    med_id = created.json()["id"]

    doctor = models.User(
        email="unlinked-dr@test.com",
        password_hash=get_password_hash("Doctor@123"),
        full_name="Dr Unlinked",
        phone_number="9876500088",
        role=UserRole.doctor,
    )
    db.add(doctor)
    db.flush()
    db.add(
        models.DoctorProfile(
            user_id=doctor.id,
            nmc_number="BR-88888",
            specialty="General Physician",
            clinic_name="Test Clinic",
            doctor_code="DRUNLK88",
            is_verified=True,
            verified_at=datetime.now(timezone.utc),
        )
    )
    db.commit()
    doctor_headers = {
        "Authorization": f"Bearer {create_access_token(data={'sub': doctor.email})}"
    }

    photo = client.get(f"/api/medications/{med_id}/photo", headers=doctor_headers)
    assert photo.status_code == 403


def test_get_medication_photo_allows_linked_doctor(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    created = _post_medication_with_photo(client, auth_headers, pid)
    med_id = created.json()["id"]

    doctor = models.User(
        email="linked-dr@test.com",
        password_hash=get_password_hash("Doctor@123"),
        full_name="Dr Linked",
        phone_number="9876500077",
        role=UserRole.doctor,
    )
    db.add(doctor)
    db.flush()
    db.add(
        models.DoctorProfile(
            user_id=doctor.id,
            nmc_number="BR-77777",
            specialty="General Physician",
            clinic_name="Linked Clinic",
            doctor_code="DRLNK777",
            is_verified=True,
            verified_at=datetime.now(timezone.utc),
        )
    )
    db.flush()
    now = datetime.now(timezone.utc)
    db.add(
        models.DoctorPatientLink(
            doctor_id=doctor.id,
            profile_id=pid,
            consent_granted_at=now,
            consent_granted_by=test_user.id,
            consent_type="in_person_exam",
            doctor_code_used="DRLNK777",
            status="active",
            is_active=True,
            accepted_at=now,
            accepted_by_doctor_id=doctor.id,
            examined_on=date.today() - timedelta(days=1),
            examined_for_condition="Diabetes follow-up",
            triage_status="stable",
            compliance_7d=5,
        )
    )
    db.commit()
    doctor_headers = {
        "Authorization": f"Bearer {create_access_token(data={'sub': doctor.email})}"
    }

    photo = client.get(f"/api/medications/{med_id}/photo", headers=doctor_headers)
    assert photo.status_code == 200
    assert photo.content == _FAKE_JPEG


def test_create_medication_rejects_invalid_photo_mime(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    fields = {
        "profile_id": str(pid),
        "name": "Metformin",
        "intake_period": "MORNING",
        "taken_at": datetime.now(timezone.utc).isoformat(),
    }
    files = {"photo": ("bad.gif", BytesIO(b"x"), "image/gif")}
    r = client.post("/api/medications", data=fields, files=files, headers=auth_headers)
    assert r.status_code == 422


def test_create_medication_rejects_oversized_photo(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    fields = {
        "profile_id": str(pid),
        "name": "Metformin",
        "intake_period": "MORNING",
        "taken_at": datetime.now(timezone.utc).isoformat(),
    }
    files = {"photo": ("big.jpg", BytesIO(b"\xff\xd8\xff" + b"x" * 200), "image/jpeg")}
    with patch("routes_medications.settings.MAX_UPLOAD_SIZE_BYTES", 50):
        r = client.post("/api/medications", data=fields, files=files, headers=auth_headers)
    assert r.status_code == 422


def test_delete_medication_removes_photo_file(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    created = _post_medication_with_photo(client, auth_headers, pid)
    med_id = created.json()["id"]
    row = db.query(models.Medication).filter_by(id=med_id).first()
    abs_path = _abs_photo_path(row.photo_path)
    assert abs_path.is_file()

    deleted = client.delete(f"/api/medications/{med_id}", headers=auth_headers)
    assert deleted.status_code == 204
    assert not abs_path.exists()


def test_get_medication_photo_500_on_corrupt_file(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    created = _post_medication_with_photo(client, auth_headers, pid)
    med_id = created.json()["id"]
    row = db.query(models.Medication).filter_by(id=med_id).first()
    abs_path = _abs_photo_path(row.photo_path)
    abs_path.write_bytes(b"corrupt")

    photo = client.get(f"/api/medications/{med_id}/photo", headers=auth_headers)
    assert photo.status_code == 500


def test_create_medication_photo_cleaned_up_on_commit_failure(
    client, db, test_user, auth_headers, monkeypatch
):
    pid = _profile_id_for(test_user, db)

    def boom():
        raise Exception("simulated DB error")

    monkeypatch.setattr(db, "commit", boom)

    with pytest.raises(Exception, match="simulated DB error"):
        _post_medication_with_photo(client, auth_headers, pid)

    from medication_photo_storage import _UPLOAD_ROOT

    profile_dir = _UPLOAD_ROOT / str(pid)
    if profile_dir.exists():
        assert list(profile_dir.glob("*.enc")) == []


def test_get_medication_photo_404_when_has_photo_true_but_path_none(
    client, db, test_user, auth_headers
):
    pid = _profile_id_for(test_user, db)
    created = _post_medication(client, auth_headers, pid)
    med_id = created.json()["id"]
    row = db.query(models.Medication).filter_by(id=med_id).first()
    row.has_photo = True
    row.photo_path = None
    db.commit()

    photo = client.get(f"/api/medications/{med_id}/photo", headers=auth_headers)
    assert photo.status_code == 404


def test_create_medication_with_photo_denies_unrelated_profile(
    client, db, test_user, auth_headers
):
    other = models.Profile(name="Stranger")
    db.add(other)
    db.flush()
    r = _post_medication_with_photo(client, auth_headers, other.id)
    assert r.status_code == 403


def test_create_medication_rejects_photo_with_spoofed_mime(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    fields = {
        "profile_id": str(pid),
        "name": "Metformin",
        "intake_period": "MORNING",
        "taken_at": datetime.now(timezone.utc).isoformat(),
    }
    files = {"photo": ("fake.jpg", BytesIO(b"not-a-jpeg"), "image/jpeg")}
    r = client.post("/api/medications", data=fields, files=files, headers=auth_headers)
    assert r.status_code == 422


def test_create_medication_rejects_photo_unsupported_content_type(
    client, db, test_user, auth_headers
):
    pid = _profile_id_for(test_user, db)
    fields = {
        "profile_id": str(pid),
        "name": "Metformin",
        "intake_period": "MORNING",
        "taken_at": datetime.now(timezone.utc).isoformat(),
    }
    files = {
        "photo": ("strip.bin", BytesIO(_FAKE_JPEG), "application/octet-stream"),
    }
    r = client.post("/api/medications", data=fields, files=files, headers=auth_headers)
    assert r.status_code == 422


def test_create_medication_with_photo_rejects_profile_limit(
    client, db, test_user, auth_headers, monkeypatch
):
    monkeypatch.setattr("medication_photo_storage._MAX_PHOTOS_PER_PROFILE", 1)
    pid = _profile_id_for(test_user, db)
    first = _post_medication_with_photo(client, auth_headers, pid, name="First")
    assert first.status_code == 201, first.text
    second = _post_medication_with_photo(client, auth_headers, pid, name="Second")
    assert second.status_code == 422


def test_create_medication_hides_encryption_config_errors(
    client, db, test_user, auth_headers, monkeypatch
):
    pid = _profile_id_for(test_user, db)

    def _boom(**_kwargs):
        raise ValueError("ENCRYPTION_KEY is required for medication photo encryption")

    monkeypatch.setattr("routes_medications.save_medication_photo", _boom)
    r = _post_medication_with_photo(client, auth_headers, pid)
    assert r.status_code == 500
    assert "ENCRYPTION_KEY" not in r.text


def test_create_medication_rejects_riff_non_webp(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    fields = {
        "profile_id": str(pid),
        "name": "Metformin",
        "intake_period": "MORNING",
        "taken_at": datetime.now(timezone.utc).isoformat(),
    }
    riff_avi = b"RIFF" + b"\x00\x00\x00\x00" + b"AVI " + b"data"
    files = {"photo": ("clip.webp", BytesIO(riff_avi), "image/webp")}
    r = client.post("/api/medications", data=fields, files=files, headers=auth_headers)
    assert r.status_code == 422


def test_patch_medication_preserves_has_photo(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    created = _post_medication_with_photo(client, auth_headers, pid)
    med_id = created.json()["id"]
    patched = client.patch(
        f"/api/medications/{med_id}",
        json={"dose": "250 mg"},
        headers=auth_headers,
    )
    assert patched.status_code == 200
    assert patched.json()["has_photo"] is True


def test_create_medication_denies_unrelated_profile(client, db, test_user, auth_headers):
    # Create a second profile the test_user has NO access to
    other = models.Profile(name="Stranger")
    db.add(other)
    db.flush()
    r = _post_medication(client, auth_headers, other.id)
    assert r.status_code == 403


# ---------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------

def test_list_medications_returns_recent_descending(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    now = datetime.now(timezone.utc)

    db.add(models.Medication(profile_id=pid, name="A", intake_period="MORNING", taken_at=now - timedelta(days=2)))
    db.add(models.Medication(profile_id=pid, name="B", intake_period="MORNING", taken_at=now - timedelta(hours=1)))
    db.add(models.Medication(profile_id=pid, name="C", intake_period="MORNING", taken_at=now - timedelta(days=10)))
    db.commit()

    r = client.get(f"/api/medications?profile_id={pid}&days=30", headers=auth_headers)
    assert r.status_code == 200
    names = [m["name"] for m in r.json()]
    assert names == ["B", "A", "C"]


def test_list_medications_filters_by_days_window(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    now = datetime.now(timezone.utc)

    db.add(models.Medication(profile_id=pid, name="Recent", intake_period="MORNING", taken_at=now - timedelta(days=1)))
    db.add(models.Medication(profile_id=pid, name="OldOne", intake_period="MORNING", taken_at=now - timedelta(days=20)))
    db.commit()

    r = client.get(f"/api/medications?profile_id={pid}&days=7", headers=auth_headers)
    names = [m["name"] for m in r.json()]
    assert "Recent" in names
    assert "OldOne" not in names


# ---------------------------------------------------------------------------
# Update / Delete
# ---------------------------------------------------------------------------

def test_update_medication_changes_fields(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    med = models.Medication(profile_id=pid, name="Old", dose="100", intake_period="MORNING", taken_at=datetime.now(timezone.utc))
    db.add(med)
    db.commit()
    db.refresh(med)

    r = client.patch(
        f"/api/medications/{med.id}",
        json={"name": "New", "notes": "noted"},
        headers=auth_headers,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["name"] == "New"
    assert body["dose"] == "100"  # untouched
    assert body["notes"] == "noted"


def test_delete_medication_removes_row(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    med = models.Medication(profile_id=pid, name="X", intake_period="MORNING", taken_at=datetime.now(timezone.utc))
    db.add(med)
    db.commit()
    db.refresh(med)

    r = client.delete(f"/api/medications/{med.id}", headers=auth_headers)
    assert r.status_code == 204
    assert db.query(models.Medication).filter(models.Medication.id == med.id).first() is None


def test_delete_unknown_medication_404(client, auth_headers):
    r = client.delete("/api/medications/99999", headers=auth_headers)
    assert r.status_code == 404


def test_patch_unknown_medication_404(client, auth_headers):
    r = client.patch("/api/medications/99999", json={"name": "X"}, headers=auth_headers)
    assert r.status_code == 404


def test_patch_medication_updates_dose_frequency_taken_at(client, db, test_user, auth_headers):
    """Cover PATCH branches that update dose, frequency, and taken_at."""
    pid = _profile_id_for(test_user, db)
    med = models.Medication(
        profile_id=pid,
        name="Aspirin",
        dose="75 mg",
        frequency="Once daily",
        intake_period="MORNING",
        taken_at=datetime.now(timezone.utc) - timedelta(days=1),
    )
    db.add(med)
    db.commit()
    db.refresh(med)

    new_ts = datetime.now(timezone.utc)
    r = client.patch(
        f"/api/medications/{med.id}",
        json={
            "dose": "150 mg",
            "frequency": "Twice daily",
            "taken_at": new_ts.isoformat(),
            "notes": "   ",  # blank-only → null
        },
        headers=auth_headers,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["dose"] == "150 mg"
    assert body["frequency"] == "Twice daily"
    assert body["notes"] is None  # blank stripped


def test_patch_medication_denies_unrelated_profile(client, db, test_user, auth_headers):
    """A patient who owns nothing about this med cannot edit it."""
    # Create a med on a profile the user does NOT own
    other = models.Profile(name="Stranger")
    db.add(other)
    db.flush()
    med = models.Medication(profile_id=other.id, name="Z", intake_period="MORNING", taken_at=datetime.now(timezone.utc))
    db.add(med)
    db.commit()
    db.refresh(med)

    # IDOR hardening: the caller has no access to this profile, so existence
    # is hidden behind a 404 (not 403) to prevent med-ID enumeration.
    r = client.patch(f"/api/medications/{med.id}", json={"name": "Hack"}, headers=auth_headers)
    assert r.status_code == 404


def test_delete_medication_denies_unrelated_profile(client, db, test_user, auth_headers):
    other = models.Profile(name="Stranger2")
    db.add(other)
    db.flush()
    med = models.Medication(profile_id=other.id, name="Q", intake_period="MORNING", taken_at=datetime.now(timezone.utc))
    db.add(med)
    db.commit()
    db.refresh(med)

    # IDOR hardening: no access to this profile → 404 (hide existence), not 403.
    r = client.delete(f"/api/medications/{med.id}", headers=auth_headers)
    assert r.status_code == 404


def test_list_medications_denies_unrelated_profile(client, db, auth_headers):
    other = models.Profile(name="Stranger3")
    db.add(other)
    db.commit()
    db.refresh(other)
    r = client.get(f"/api/medications?profile_id={other.id}&days=30", headers=auth_headers)
    assert r.status_code == 403


# ---------------------------------------------------------------------------
# Viewer-role access control (m1) — a user with viewer access on the profile
# can READ medications but must be denied every write (get_profile_editor_or_403).
# ---------------------------------------------------------------------------

def _make_viewer(db, profile_id, email="viewer@swasth.app") -> dict:
    """Create a second user with VIEWER access to `profile_id`; return auth headers."""
    viewer = models.User(
        email=email,
        password_hash=get_password_hash("Test@1234"),
        full_name="Viewer User",
    )
    db.add(viewer)
    db.flush()
    db.add(
        models.ProfileAccess(
            user_id=viewer.id,
            profile_id=profile_id,
            access_level="viewer",
        )
    )
    db.flush()
    token = create_access_token(data={"sub": viewer.email})
    return {"Authorization": f"Bearer {token}"}


def test_viewer_cannot_create_medication(client, db, test_user):
    pid = _profile_id_for(test_user, db)
    viewer_headers = _make_viewer(db, pid)
    r = _post_medication(client, viewer_headers, pid)
    assert r.status_code == 403


def test_viewer_cannot_update_medication(client, db, test_user):
    pid = _profile_id_for(test_user, db)
    med = models.Medication(profile_id=pid, name="Old", intake_period="MORNING", taken_at=datetime.now(timezone.utc))
    db.add(med)
    db.commit()
    db.refresh(med)
    viewer_headers = _make_viewer(db, pid)
    r = client.patch(
        f"/api/medications/{med.id}", json={"name": "New"}, headers=viewer_headers
    )
    assert r.status_code == 403


def test_viewer_cannot_delete_medication(client, db, test_user):
    pid = _profile_id_for(test_user, db)
    med = models.Medication(profile_id=pid, name="X", intake_period="MORNING", taken_at=datetime.now(timezone.utc))
    db.add(med)
    db.commit()
    db.refresh(med)
    viewer_headers = _make_viewer(db, pid)
    r = client.delete(f"/api/medications/{med.id}", headers=viewer_headers)
    assert r.status_code == 403


def test_viewer_can_list_medications(client, db, test_user):
    pid = _profile_id_for(test_user, db)
    db.add(models.Medication(profile_id=pid, name="A", intake_period="MORNING", taken_at=datetime.now(timezone.utc)))
    db.commit()
    viewer_headers = _make_viewer(db, pid)
    r = client.get(f"/api/medications?profile_id={pid}&days=30", headers=viewer_headers)
    assert r.status_code == 200
    assert len(r.json()) >= 1


# ---------------------------------------------------------------------------
# Doctor view + report integration
# ---------------------------------------------------------------------------

def test_report_service_includes_medications_in_snippet(db, test_user):
    """Weekly WhatsApp report snippet should mention the patient's logged meds."""
    pid = _profile_id_for(test_user, db)
    now = datetime.now(timezone.utc)

    # Need at least one reading in 7-day window so report doesn't short-circuit
    db.add(models.HealthReading(
        profile_id=pid,
        reading_type="glucose",
        glucose_value=120,
        glucose_unit="mg/dL",
        value_numeric=120,
        unit_display="mg/dL",
        reading_timestamp=now - timedelta(hours=2),
    ))
    db.add(models.Medication(profile_id=pid, name="Metformin", dose="500 mg", intake_period="MORNING", taken_at=now - timedelta(hours=1)))
    db.add(models.Medication(profile_id=pid, name="Aspirin", intake_period="EVENING", taken_at=now - timedelta(days=2)))
    # Duplicate by name (case-insensitive) — should be deduped
    db.add(models.Medication(profile_id=pid, name="metformin", dose="500 mg", intake_period="AFTERNOON", taken_at=now - timedelta(hours=3)))
    db.commit()

    profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
    # Owner must have a phone number for the report to build — test_user has one
    profile.phone_number = test_user.phone_number
    db.commit()

    import report_service
    out = report_service.trigger_single_profile_report(db, profile, owner=test_user)
    assert out is not None, "Expected report payload, got None"
    snippet = out["snippet"]
    assert "💊 Meds:" in snippet
    assert "Metformin" in snippet
    assert "Aspirin" in snippet
    assert "(Morning)" in snippet
    assert "(Evening)" in snippet
    # Same name, different period — both appear; same name+period deduped
    assert snippet.lower().count("metformin") == 2


def test_report_snippet_keeps_same_drug_different_periods(db, test_user):
    """Same drug logged morning + evening → both appear in WhatsApp snippet."""
    pid = _profile_id_for(test_user, db)
    now = datetime.now(timezone.utc)

    db.add(
        models.HealthReading(
            profile_id=pid,
            reading_type="glucose",
            glucose_value=120,
            glucose_unit="mg/dL",
            value_numeric=120,
            unit_display="mg/dL",
            reading_timestamp=now - timedelta(hours=2),
        )
    )
    db.add(
        models.Medication(
            profile_id=pid,
            name="Metformin",
            dose="500 mg",
            intake_period="MORNING",
            taken_at=now - timedelta(hours=4),
        )
    )
    db.add(
        models.Medication(
            profile_id=pid,
            name="Metformin",
            dose="500 mg",
            intake_period="EVENING",
            taken_at=now - timedelta(hours=1),
        )
    )
    db.commit()

    profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
    profile.phone_number = test_user.phone_number
    db.commit()

    import report_service

    out = report_service.trigger_single_profile_report(db, profile, owner=test_user)
    snippet = out["snippet"]
    assert "(Morning)" in snippet
    assert "(Evening)" in snippet
    assert snippet.count("Metformin") == 2
