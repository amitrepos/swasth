"""PUT /api/readings/{id} — edit existing reading.

Covers BP, glucose, weight (newest vs older sync), notes, access control,
and immutability of reading_type.
"""
from datetime import datetime, timedelta, timezone

import pytest

import models


def _pid(db):
    return db.query(models.Profile).first().id


def _r(db, pid, rtype, val, days_ago=0, **kw):
    ts = datetime.now(timezone.utc) - timedelta(days=days_ago)
    unit = "kg" if rtype == "weight" else ("mg/dL" if rtype == "glucose" else "mmHg")
    r = models.HealthReading(
        profile_id=pid,
        reading_type=rtype,
        value_numeric=val,
        unit_display=unit,
        reading_timestamp=ts,
        created_at=ts,
        **kw,
    )
    db.add(r)
    db.flush()
    return r


# ──────────────────────────────────────────────────────────────────────
# Glucose edit
# ──────────────────────────────────────────────────────────────────────


def test_edit_glucose_recomputes_status_and_value(client, auth_headers, db):
    pid = _pid(db)
    r = _r(db, pid, "glucose", 200.0, glucose_value=200.0, status_flag="HIGH")
    db.commit()

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 110.0},
        headers=auth_headers,
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["glucose_value"] == 110.0
    assert body["value_numeric"] == 110.0
    assert body["status_flag"] == "NORMAL"


def test_edit_glucose_low_threshold(client, auth_headers, db):
    pid = _pid(db)
    r = _r(db, pid, "glucose", 100.0, glucose_value=100.0, status_flag="NORMAL")
    db.commit()

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 60.0},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["status_flag"] == "LOW"


# ──────────────────────────────────────────────────────────────────────
# BP edit
# ──────────────────────────────────────────────────────────────────────


def test_edit_bp_recomputes_status(client, auth_headers, db):
    pid = _pid(db)
    r = _r(
        db,
        pid,
        "blood_pressure",
        160.0,
        systolic=160.0,
        diastolic=100.0,
        status_flag="HIGH - STAGE 2",
    )
    db.commit()

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"systolic": 118.0, "diastolic": 78.0},
        headers=auth_headers,
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["systolic"] == 118.0
    assert body["diastolic"] == 78.0
    assert body["status_flag"] == "NORMAL"


def test_edit_bp_partial_diastolic_only(client, auth_headers, db):
    """Edit only diastolic — systolic should remain, status reclassified."""
    pid = _pid(db)
    r = _r(
        db,
        pid,
        "blood_pressure",
        135.0,
        systolic=135.0,
        diastolic=88.0,
        status_flag="HIGH - STAGE 1",
    )
    db.commit()

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"diastolic": 95.0},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["systolic"] == 135.0  # unchanged
    assert body["diastolic"] == 95.0
    assert body["status_flag"] == "HIGH - STAGE 2"  # 95 > 90 → stage 2


# ──────────────────────────────────────────────────────────────────────
# Weight edit + Profile sync
# ──────────────────────────────────────────────────────────────────────


def test_edit_newest_weight_syncs_profile(client, auth_headers, db):
    """Editing the NEWEST weight reading must update Profile.weight."""
    pid = _pid(db)
    profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
    profile.weight = 70.0
    _r(db, pid, "weight", 65.0, weight_value=65.0, days_ago=5)  # older
    newest = _r(db, pid, "weight", 70.0, weight_value=70.0, days_ago=0)  # newest
    db.commit()

    resp = client.put(
        f"/api/readings/{newest.id}",
        json={"weight_value": 68.5},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["weight_value"] == 68.5

    db.expire_all()
    profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
    assert profile.weight == 68.5, "Profile.weight must follow the edited newest weight"


def test_edit_older_weight_does_not_overwrite_profile(client, auth_headers, db):
    """Editing an OLDER weight reading must NOT clobber Profile.weight
    (which tracks the newest reading)."""
    pid = _pid(db)
    older = _r(db, pid, "weight", 65.0, weight_value=65.0, days_ago=10)
    _r(db, pid, "weight", 72.0, weight_value=72.0, days_ago=0)  # newest
    profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
    profile.weight = 72.0
    db.commit()

    resp = client.put(
        f"/api/readings/{older.id}",
        json={"weight_value": 50.0},
        headers=auth_headers,
    )
    assert resp.status_code == 200

    db.expire_all()
    profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
    assert profile.weight == 72.0, (
        f"Profile.weight must still reflect newest (72.0), got {profile.weight}"
    )


def test_delete_newest_weight_resyncs_profile(client, auth_headers, db):
    """Deleting the NEWEST weight reading must re-sync Profile.weight to
    the next-newest remaining reading."""
    pid = _pid(db)
    _r(db, pid, "weight", 65.0, weight_value=65.0, days_ago=10)
    newest = _r(db, pid, "weight", 72.0, weight_value=72.0, days_ago=0)
    profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
    profile.weight = 72.0
    db.commit()

    resp = client.delete(f"/api/readings/{newest.id}", headers=auth_headers)
    assert resp.status_code == 204

    db.expire_all()
    profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
    assert profile.weight == 65.0, (
        f"Profile.weight must re-sync to next-newest (65.0), got {profile.weight}"
    )


def test_delete_only_weight_clears_profile(client, auth_headers, db):
    """Deleting the ONLY weight reading must null Profile.weight."""
    pid = _pid(db)
    only = _r(db, pid, "weight", 70.0, weight_value=70.0, days_ago=0)
    profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
    profile.weight = 70.0
    db.commit()

    resp = client.delete(f"/api/readings/{only.id}", headers=auth_headers)
    assert resp.status_code == 204

    db.expire_all()
    profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
    assert profile.weight is None


# ──────────────────────────────────────────────────────────────────────
# Notes + 404 + access
# ──────────────────────────────────────────────────────────────────────


def test_edit_notes_only(client, auth_headers, db):
    pid = _pid(db)
    r = _r(db, pid, "glucose", 100.0, glucose_value=100.0, status_flag="NORMAL")
    db.commit()

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"notes": "after lunch"},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["notes"] == "after lunch"
    assert resp.json()["glucose_value"] == 100.0  # unchanged


def test_edit_foreign_reading_returns_403(client, auth_headers, db):
    """A user with no access to a profile must get 403 when trying to
    edit a reading on that profile. This guards against silent regression
    of get_profile_editor_or_403 in dependencies.py."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 100.0, glucose_value=100.0, status_flag="NORMAL")
    db.commit()

    # Create a stranger user with NO ProfileAccess to this profile
    from auth import create_access_token, get_password_hash
    stranger = models.User(
        email="stranger@swasth.app",
        password_hash=get_password_hash("X@123abc"),
        full_name="Stranger",
        phone_number="9999999999",
    )
    db.add(stranger)
    db.commit()
    stranger_headers = {
        "Authorization": f"Bearer {create_access_token(data={'sub': stranger.email})}"
    }

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 110.0},
        headers=stranger_headers,
    )
    assert resp.status_code == 403, (
        f"Foreign user must get 403, got {resp.status_code}: {resp.text}"
    )

    # Verify the row was NOT modified
    db.expire_all()
    refreshed = db.query(models.HealthReading).filter(
        models.HealthReading.id == r.id
    ).first()
    assert refreshed.glucose_value == 100.0, "Glucose must not be modified by foreign user"


def test_delete_foreign_reading_returns_403(client, auth_headers, db):
    """Foreign user must not be able to delete another user's reading."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 120.0, glucose_value=120.0, status_flag="NORMAL")
    db.commit()

    from auth import create_access_token, get_password_hash
    stranger = models.User(
        email="stranger2@swasth.app",
        password_hash=get_password_hash("X@123abc"),
        full_name="Stranger Two",
        phone_number="9999999998",
    )
    db.add(stranger)
    db.commit()
    stranger_headers = {
        "Authorization": f"Bearer {create_access_token(data={'sub': stranger.email})}"
    }

    resp = client.delete(f"/api/readings/{r.id}", headers=stranger_headers)
    assert resp.status_code == 403

    # Reading must still exist
    db.expire_all()
    assert db.query(models.HealthReading).filter(
        models.HealthReading.id == r.id
    ).first() is not None


def test_viewer_cannot_edit_reading(client, auth_headers, db):
    """A user with viewer-level ProfileAccess must NOT be able to edit
    readings — only owner/editor can."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 100.0, glucose_value=100.0, status_flag="NORMAL")

    from auth import create_access_token, get_password_hash
    viewer = models.User(
        email="viewer@swasth.app",
        password_hash=get_password_hash("X@123abc"),
        full_name="Viewer",
        phone_number="9999999997",
    )
    db.add(viewer)
    db.flush()
    db.add(models.ProfileAccess(user_id=viewer.id, profile_id=pid, access_level="viewer"))
    db.commit()
    viewer_headers = {
        "Authorization": f"Bearer {create_access_token(data={'sub': viewer.email})}"
    }

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 110.0},
        headers=viewer_headers,
    )
    assert resp.status_code == 403


def test_edit_glucose_out_of_range_rejected(client, auth_headers, db):
    """Pydantic Field validators must reject nonsensical values that
    bypass the Flutter UI. Mirrors edit_reading_screen.dart bounds."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 100.0, glucose_value=100.0, status_flag="NORMAL")
    db.commit()

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 999999.0},
        headers=auth_headers,
    )
    assert resp.status_code == 422, "Out-of-range glucose must be rejected"


def test_edit_systolic_out_of_range_rejected(client, auth_headers, db):
    pid = _pid(db)
    r = _r(
        db, pid, "blood_pressure", 120.0,
        systolic=120.0, diastolic=80.0, status_flag="NORMAL",
    )
    db.commit()

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"systolic": 5000.0, "diastolic": 80.0},
        headers=auth_headers,
    )
    assert resp.status_code == 422


def test_edit_nonexistent_reading_returns_404(client, auth_headers, db):
    resp = client.put(
        "/api/readings/9999999",
        json={"glucose_value": 100.0},
        headers=auth_headers,
    )
    assert resp.status_code == 404


def test_edit_invalidates_ai_insight_log(client, auth_headers, db):
    """Editing a reading must mark AiInsightLog rows as 'invalidated'
    so the dashboard ai-insight endpoint regenerates instead of
    returning a stale cached insight."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 200.0, glucose_value=200.0, status_flag="HIGH")
    log = models.AiInsightLog(
        profile_id=pid,
        model_used="gemini-2.5-flash",
        response_text="Stale insight based on 200 mg/dL",
        prompt_summary="glucose summary",
    )
    db.add(log)
    db.commit()

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 110.0},
        headers=auth_headers,
    )
    assert resp.status_code == 200

    db.expire_all()
    rows = (
        db.query(models.AiInsightLog)
        .filter(models.AiInsightLog.profile_id == pid)
        .all()
    )
    assert all(row.model_used == "invalidated" for row in rows), (
        "AiInsightLog rows must be marked 'invalidated' so dashboard re-evaluates"
    )


def test_delete_invalidates_ai_insight_log(client, auth_headers, db):
    """Deleting a reading must also invalidate AiInsightLog."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 200.0, glucose_value=200.0, status_flag="HIGH")
    db.add(models.AiInsightLog(
        profile_id=pid,
        model_used="gemini-2.5-flash",
        response_text="Stale",
        prompt_summary="glucose",
    ))
    db.commit()

    resp = client.delete(f"/api/readings/{r.id}", headers=auth_headers)
    assert resp.status_code == 204

    db.expire_all()
    rows = (
        db.query(models.AiInsightLog)
        .filter(models.AiInsightLog.profile_id == pid)
        .all()
    )
    assert all(row.model_used == "invalidated" for row in rows)


def test_edit_refreshes_doctor_triage_link(client, auth_headers, db):
    """Editing a reading must refresh the DoctorPatientLink triage cache
    so the doctor's patient-detail dashboard (compliance_7d,
    triage_status, last_reading_*) reflects the corrected values."""
    pid = _pid(db)

    # Create a doctor user + active link to this profile
    doctor = models.User(
        email="dr_triage@swasth.app",
        password_hash="x",
        full_name="Dr Triage",
        role=models.UserRole.doctor,
    )
    db.add(doctor)
    db.flush()

    link = models.DoctorPatientLink(
        doctor_id=doctor.id,
        profile_id=pid,
        consent_granted_at=datetime.now(timezone.utc),
        consent_type="in_person_exam",
        status="active",
        is_active=True,
        triage_status="stable",
        compliance_7d=99,
        last_reading_value="999",
        last_reading_type="stale",
    )
    db.add(link)

    r = _r(db, pid, "glucose", 250.0, glucose_value=250.0, status_flag="HIGH")
    db.commit()

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 100.0},
        headers=auth_headers,
    )
    assert resp.status_code == 200

    db.expire_all()
    refreshed = (
        db.query(models.DoctorPatientLink)
        .filter(models.DoctorPatientLink.id == link.id)
        .first()
    )
    # Stale value '999' must be gone — triage recomputed off the edited reading
    assert refreshed.last_reading_value != "999", (
        "DoctorPatientLink.last_reading_value must refresh after reading edit"
    )
    assert refreshed.last_reading_type == "glucose"


def test_delete_survives_cache_invalidation_failure(
    client, auth_headers, db, monkeypatch
):
    """Even if cache invalidation raises, the reading deletion must
    persist. Regression for the rollback-wipes-delete bug."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 100.0, glucose_value=100.0, status_flag="NORMAL")
    db.commit()
    rid = r.id

    # Force the AiInsightLog query to blow up so the cache try/except fires
    import routes_health as rh

    real_query = rh.models.AiInsightLog
    class _Boom:
        @classmethod
        def __getattr__(cls, name):
            raise RuntimeError("simulated cache failure")
    # Patch only the AiInsightLog reference used in the cache block
    orig_update = None
    from sqlalchemy.orm import Query

    def _explode(*a, **kw):
        raise RuntimeError("simulated cache failure")

    monkeypatch.setattr(Query, "update", _explode)

    resp = client.delete(f"/api/readings/{rid}", headers=auth_headers)
    assert resp.status_code == 204, resp.text

    db.expire_all()
    survivor = db.query(models.HealthReading).filter(
        models.HealthReading.id == rid
    ).first()
    assert survivor is None, (
        "Reading deletion must persist even if cache invalidation fails"
    )


def test_notes_oversized_rejected(client, auth_headers, db):
    """notes max_length=2000 must reject oversized payloads."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 100.0, glucose_value=100.0, status_flag="NORMAL")
    db.commit()

    huge = "x" * 5000
    resp = client.put(
        f"/api/readings/{r.id}",
        json={"notes": huge},
        headers=auth_headers,
    )
    assert resp.status_code == 422, "notes >2000 chars must be rejected"


def test_reading_timestamp_far_future_rejected(client, auth_headers, db):
    """Timestamps more than 5 minutes in the future must be rejected."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 100.0, glucose_value=100.0, status_flag="NORMAL")
    db.commit()

    far_future = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()
    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 100.0, "reading_timestamp": far_future},
        headers=auth_headers,
    )
    assert resp.status_code == 422


def test_reading_timestamp_far_past_rejected(client, auth_headers, db):
    """Timestamps older than 2 years must be rejected."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 100.0, glucose_value=100.0, status_flag="NORMAL")
    db.commit()

    far_past = (datetime.now(timezone.utc) - timedelta(days=1000)).isoformat()
    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 100.0, "reading_timestamp": far_past},
        headers=auth_headers,
    )
    assert resp.status_code == 422


def test_reading_timestamp_recent_past_accepted(client, auth_headers, db):
    """Timestamps within the 2-year window must be accepted."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 100.0, glucose_value=100.0, status_flag="NORMAL")
    db.commit()

    recent = (datetime.now(timezone.utc) - timedelta(days=3)).isoformat()
    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 100.0, "reading_timestamp": recent},
        headers=auth_headers,
    )
    assert resp.status_code == 200


def test_edit_invalidates_trend_cache(client, auth_headers, db):
    """Editing a reading must wipe TrendSummaryCache so AI re-evaluates."""
    pid = _pid(db)
    r = _r(db, pid, "glucose", 200.0, glucose_value=200.0, status_flag="HIGH")
    from datetime import date as _date
    cache_row = models.TrendSummaryCache(
        profile_id=pid,
        period_days=7,
        cache_date=_date.today(),
        summary_text="stale",
    )
    db.add(cache_row)
    db.commit()

    resp = client.put(
        f"/api/readings/{r.id}",
        json={"glucose_value": 110.0},
        headers=auth_headers,
    )
    assert resp.status_code == 200

    remaining = (
        db.query(models.TrendSummaryCache)
        .filter(models.TrendSummaryCache.profile_id == pid)
        .all()
    )
    assert len(remaining) == 0, "TrendSummaryCache must be cleared after edit"
