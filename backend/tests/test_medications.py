"""Tests for medication-intake API (NUO-127).

Covers: create, list, update, delete, access control, doctor view.
"""
from datetime import datetime, timezone, timedelta

import pytest

import models
from auth import create_access_token, get_password_hash


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

    db.add(models.Medication(profile_id=pid, name="A", taken_at=now - timedelta(days=2)))
    db.add(models.Medication(profile_id=pid, name="B", taken_at=now - timedelta(hours=1)))
    db.add(models.Medication(profile_id=pid, name="C", taken_at=now - timedelta(days=10)))
    db.commit()

    r = client.get(f"/api/medications?profile_id={pid}&days=30", headers=auth_headers)
    assert r.status_code == 200
    names = [m["name"] for m in r.json()]
    assert names == ["B", "A", "C"]


def test_list_medications_filters_by_days_window(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    now = datetime.now(timezone.utc)

    db.add(models.Medication(profile_id=pid, name="Recent", taken_at=now - timedelta(days=1)))
    db.add(models.Medication(profile_id=pid, name="OldOne", taken_at=now - timedelta(days=20)))
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
    med = models.Medication(profile_id=pid, name="Old", dose="100", taken_at=datetime.now(timezone.utc))
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
    med = models.Medication(profile_id=pid, name="X", taken_at=datetime.now(timezone.utc))
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
    med = models.Medication(profile_id=other.id, name="Z", taken_at=datetime.now(timezone.utc))
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
    med = models.Medication(profile_id=other.id, name="Q", taken_at=datetime.now(timezone.utc))
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
    med = models.Medication(profile_id=pid, name="Old", taken_at=datetime.now(timezone.utc))
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
    med = models.Medication(profile_id=pid, name="X", taken_at=datetime.now(timezone.utc))
    db.add(med)
    db.commit()
    db.refresh(med)
    viewer_headers = _make_viewer(db, pid)
    r = client.delete(f"/api/medications/{med.id}", headers=viewer_headers)
    assert r.status_code == 403


def test_viewer_can_list_medications(client, db, test_user):
    pid = _profile_id_for(test_user, db)
    db.add(models.Medication(profile_id=pid, name="A", taken_at=datetime.now(timezone.utc)))
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
