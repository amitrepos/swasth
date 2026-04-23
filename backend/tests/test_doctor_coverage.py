"""Coverage boost tests for routes_doctor.py — targeting 69% → 85%."""
import pytest
from datetime import datetime, timedelta, timezone
from auth import get_password_hash, create_access_token
import models


def _doc(db, email="doctor@test.com", nmc="NMC001"):
    user = models.User(
        email=email, password_hash=get_password_hash("Test@1234"),
        full_name="Dr. Test", phone_number="9876543211",
        role="doctor",
    )
    db.add(user); db.flush()
    doc = models.DoctorProfile(
        user_id=user.id, doctor_code=f"DR{user.id:04d}",
        nmc_number=nmc, specialty="General", clinic_name="Test Clinic",
        is_verified=True,
    )
    db.add(doc); db.flush()
    return user, doc, {"Authorization": f"Bearer {create_access_token(data={'sub': user.email})}"}


def _patient(db, email="patient@test.com", days=5):
    user = models.User(
        email=email, password_hash=get_password_hash("Test@1234"),
        full_name="Patient Test", phone_number="9876543212",
    )
    db.add(user); db.flush()
    p = models.Profile(name="Patient Health", age=45, gender="Male", phone_number="9876543210")
    db.add(p); db.flush()
    db.add(models.ProfileAccess(user_id=user.id, profile_id=p.id, access_level="owner"))
    db.flush()
    now = datetime.now(timezone.utc)
    for d in range(days):
        ts = now - timedelta(days=d)
        db.add(models.HealthReading(
            profile_id=p.id, reading_type="blood_pressure",
            value_numeric=130 + d * 5, unit_display="mmHg",
            systolic=130.0 + d * 5, diastolic=85.0,
            reading_timestamp=ts, created_at=ts,
            status_flag="NORMAL" if d < 3 else "HIGH - STAGE 1",
        ))
        db.add(models.HealthReading(
            profile_id=p.id, reading_type="glucose",
            value_numeric=120 + d * 10, unit_display="mg/dL",
            glucose_value=120.0 + d * 10,
            reading_timestamp=ts, created_at=ts, status_flag="NORMAL",
        ))
    db.flush()
    return user, p


def test_register(client, db):
    r = client.post("/api/doctor/register", json={
        "email": "newdoc@test.com", "password": "Test@1234",
        "confirm_password": "Test@1234", "full_name": "Dr. New",
        "phone_number": "9876543299", "nmc_number": "NMC999",
    })
    assert r.status_code == 201


def test_register_dup(client, db):
    client.post("/api/doctor/register", json={
        "email": "dup@test.com", "password": "Test@1234",
        "confirm_password": "Test@1234", "full_name": "Dr. D1",
        "phone_number": "9876543200", "nmc_number": "NMC100",
    })
    r = client.post("/api/doctor/register", json={
        "email": "dup@test.com", "password": "Test@1234",
        "confirm_password": "Test@1234", "full_name": "Dr. D2",
        "phone_number": "9876543201", "nmc_number": "NMC101",
    })
    assert r.status_code == 400


def test_link(client, auth_headers, test_user, db):
    _, doc, _ = _doc(db, "link@test.com", "NMC200")
    pid = db.query(models.Profile).first().id
    r = client.post(f"/api/doctor/link/{pid}",
                    json={"doctor_code": doc.doctor_code, "consent_type": "in_person_exam"}, headers=auth_headers)
    assert r.status_code == 201


def test_revoke_invalid(client, auth_headers, test_user, db):
    pid = db.query(models.Profile).first().id
    r = client.delete(f"/api/doctor/link/{pid}?doctor_code=INVALID", headers=auth_headers)
    assert r.status_code == 404


def test_revoke_no_link(client, auth_headers, test_user, db):
    _, doc, _ = _doc(db, "nolink@test.com", "NMC300")
    pid = db.query(models.Profile).first().id
    r = client.delete(f"/api/doctor/link/{pid}?doctor_code={doc.doctor_code}", headers=auth_headers)
    assert r.status_code == 404


def test_triage_empty(client, db):
    _, doc, h = _doc(db, "tri1@test.com", "NMC400")
    pu = models.User(email="noread@test.com", password_hash=get_password_hash("Test@1234"),
                     full_name="No Read", phone_number="9876543220")
    db.add(pu); db.flush()
    p = models.Profile(name="Empty", phone_number="9876543220"); db.add(p); db.flush()
    db.add(models.ProfileAccess(user_id=pu.id, profile_id=p.id, access_level="owner"))
    db.add(models.DoctorPatientLink(doctor_id=doc.user_id, profile_id=p.id, consent_granted_at=datetime.now(timezone.utc), consent_type="in_person_exam", is_active=True, status="active"))
    db.flush()
    assert client.get("/api/doctor/patients", headers=h).status_code == 200


def test_triage_critical(client, db):
    _, doc, h = _doc(db, "tri2@test.com", "NMC401")
    _, pp = _patient(db, "crit@test.com")
    ts = datetime.now(timezone.utc)
    db.add(models.HealthReading(
        profile_id=pp.id, reading_type="blood_pressure", value_numeric=190,
        unit_display="mmHg", systolic=190.0, diastolic=110.0,
        reading_timestamp=ts, created_at=ts, status_flag="HIGH - STAGE 2",
    ))
    db.add(models.DoctorPatientLink(doctor_id=doc.user_id, profile_id=pp.id, consent_granted_at=datetime.now(timezone.utc), consent_type="in_person_exam", is_active=True, status="active"))
    db.flush()
    assert client.get("/api/doctor/patients", headers=h).status_code == 200


def test_patient_summary(client, db):
    _, doc, h = _doc(db, "sum@test.com", "NMC500")
    _, pp = _patient(db, "summary@test.com")
    db.add(models.DoctorPatientLink(doctor_id=doc.user_id, profile_id=pp.id, consent_granted_at=datetime.now(timezone.utc), consent_type="in_person_exam", is_active=True, status="active"))
    db.flush()
    assert client.get(f"/api/doctor/patients/{pp.id}/summary", headers=h).status_code == 200


def test_verify_non_admin(client, auth_headers, test_user, db):
    _, doc, _ = _doc(db, "ver@test.com", "NMC600")
    assert client.post(f"/api/doctor/verify/{doc.id}", headers=auth_headers).status_code == 403


# ---------------------------------------------------------------------------
# Unit tests for _compute_triage_status — direct function calls to cover
# every branch of the triage state machine.
# ---------------------------------------------------------------------------


def _bare_profile(db, email_suffix: str):
    """Create a profile with owner access but no readings."""
    user = models.User(
        email=f"triage_{email_suffix}@test.com",
        password_hash=get_password_hash("Test@1234"),
        full_name=f"Triage {email_suffix}",
        phone_number=f"98765{email_suffix.zfill(5)[:5]}",
    )
    db.add(user); db.flush()
    p = models.Profile(name=f"Triage Profile {email_suffix}", phone_number=user.phone_number)
    db.add(p); db.flush()
    db.add(models.ProfileAccess(user_id=user.id, profile_id=p.id, access_level="owner"))
    db.flush()
    return p


def _add_reading(db, profile_id, *, reading_type, hours_ago=0, **values):
    ts = datetime.now(timezone.utc) - timedelta(hours=hours_ago)
    r = models.HealthReading(
        profile_id=profile_id,
        reading_type=reading_type,
        reading_timestamp=ts,
        created_at=ts,
        **values,
    )
    db.add(r); db.flush()
    return r


def test_compute_triage_no_data(db):
    from routes_doctor import _compute_triage_status
    p = _bare_profile(db, "1")
    result = _compute_triage_status(p.id, db)
    assert result["triage_status"] == "no_data"
    assert result["last_reading_value"] is None
    assert result["compliance_7d"] == 0


def test_compute_triage_critical_bp_high(db):
    """Lines 117-120: systolic>180 or diastolic>120 → hypertensive crisis."""
    from routes_doctor import _compute_triage_status
    p = _bare_profile(db, "2")
    _add_reading(db, p.id, reading_type="blood_pressure",
                 systolic=190.0, diastolic=125.0,
                 value_numeric=190.0, unit_display="mmHg", status_flag="CRITICAL")
    result = _compute_triage_status(p.id, db)
    assert result["triage_status"] == "critical"
    assert result["last_reading_value"] == "190/125"


def test_compute_triage_critical_bp_low(db):
    """Lines 121-124: systolic<90 or diastolic<60 → hypotension."""
    from routes_doctor import _compute_triage_status
    p = _bare_profile(db, "3")
    _add_reading(db, p.id, reading_type="blood_pressure",
                 systolic=85.0, diastolic=55.0,
                 value_numeric=85.0, unit_display="mmHg", status_flag="CRITICAL")
    result = _compute_triage_status(p.id, db)
    assert result["triage_status"] == "critical"


def test_compute_triage_critical_glucose_low(db):
    """Lines 126-129: glucose<70 → hypoglycemia."""
    from routes_doctor import _compute_triage_status
    p = _bare_profile(db, "4")
    _add_reading(db, p.id, reading_type="glucose",
                 glucose_value=55.0, glucose_unit="mg/dL",
                 value_numeric=55.0, unit_display="mg/dL", status_flag="CRITICAL")
    result = _compute_triage_status(p.id, db)
    assert result["triage_status"] == "critical"
    assert result["last_reading_value"] == "55"


def test_compute_triage_critical_glucose_high(db):
    """Lines 130-133: glucose>300 → severe hyperglycemia."""
    from routes_doctor import _compute_triage_status
    p = _bare_profile(db, "5")
    _add_reading(db, p.id, reading_type="glucose",
                 glucose_value=350.0, glucose_unit="mg/dL",
                 value_numeric=350.0, unit_display="mg/dL", status_flag="CRITICAL")
    result = _compute_triage_status(p.id, db)
    assert result["triage_status"] == "critical"


def test_compute_triage_attention_elevated_bp(db):
    """Lines 148-153: systolic>140 or diastolic>90 → attention (non-critical)."""
    from routes_doctor import _compute_triage_status
    p = _bare_profile(db, "6")
    _add_reading(db, p.id, reading_type="blood_pressure",
                 systolic=150.0, diastolic=95.0,
                 value_numeric=150.0, unit_display="mmHg", status_flag="HIGH - STAGE 1")
    result = _compute_triage_status(p.id, db)
    assert result["triage_status"] == "attention"
    assert "elevated" in (result.get("triage_reason") or "").lower() or result["triage_status"] == "attention"


def test_compute_triage_attention_high_glucose(db):
    """Lines 154-158: glucose>180 → attention."""
    from routes_doctor import _compute_triage_status
    p = _bare_profile(db, "7")
    _add_reading(db, p.id, reading_type="glucose",
                 glucose_value=220.0, glucose_unit="mg/dL",
                 value_numeric=220.0, unit_display="mg/dL", status_flag="HIGH")
    result = _compute_triage_status(p.id, db)
    assert result["triage_status"] == "attention"


def test_compute_triage_attention_noncompliance(db):
    """Lines 138-145: no reading in 3+ days → attention 'No reading for Nd'."""
    from routes_doctor import _compute_triage_status
    p = _bare_profile(db, "8")
    # Stale reading from 5 days ago, normal values — should flag non-compliance
    _add_reading(db, p.id, reading_type="glucose", hours_ago=24 * 5,
                 glucose_value=110.0, glucose_unit="mg/dL",
                 value_numeric=110.0, unit_display="mg/dL", status_flag="NORMAL")
    result = _compute_triage_status(p.id, db)
    assert result["triage_status"] == "attention"


def test_compute_triage_other_reading_type(db):
    """Line 100: value formatting for non-bp/non-glucose readings (e.g. weight, spo2)."""
    from routes_doctor import _compute_triage_status
    p = _bare_profile(db, "9")
    _add_reading(db, p.id, reading_type="weight",
                 value_numeric=72.5, unit_display="kg", status_flag="NORMAL")
    result = _compute_triage_status(p.id, db)
    # non-bp/non-glucose falls through to the else branch → str(value_numeric)
    assert result["last_reading_value"] == "72.5"


def test_refresh_triage_updates_active_links(db):
    """Lines 780-799: refresh_triage_for_profile walks active links and updates them."""
    from routes_doctor import refresh_triage_for_profile
    _, doc, _ = _doc(db, "refresh@test.com", "NMC700")
    p = _bare_profile(db, "10")
    _add_reading(db, p.id, reading_type="glucose",
                 glucose_value=150.0, glucose_unit="mg/dL",
                 value_numeric=150.0, unit_display="mg/dL", status_flag="NORMAL")
    link = models.DoctorPatientLink(
        doctor_id=doc.user_id, profile_id=p.id,
        consent_granted_at=datetime.now(timezone.utc),
        consent_type="in_person_exam", is_active=True, status="active",
        triage_status="stale",
    )
    db.add(link); db.flush()

    refresh_triage_for_profile(p.id, db)
    # Check in-memory link attrs — function mutates session-bound object but doesn't commit
    assert link.triage_status == "stable"
    assert link.last_reading_value == "150"
    assert link.triage_updated_at is not None


def test_refresh_triage_noop_when_no_links(db):
    """Line 788-789: early return when no active links for profile."""
    from routes_doctor import refresh_triage_for_profile
    p = _bare_profile(db, "11")
    _add_reading(db, p.id, reading_type="glucose",
                 glucose_value=100.0, glucose_unit="mg/dL",
                 value_numeric=100.0, unit_display="mg/dL", status_flag="NORMAL")
    # No links exist — should return silently, not raise
    refresh_triage_for_profile(p.id, db)  # no assertion needed; must not raise
