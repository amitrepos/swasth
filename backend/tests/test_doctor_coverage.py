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
    p = models.Profile(name="Patient Health", age=45, gender="Male")
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
    p = models.Profile(name="Empty"); db.add(p); db.flush()
    db.add(models.ProfileAccess(user_id=pu.id, profile_id=p.id, access_level="owner"))
    db.add(models.DoctorPatientLink(doctor_id=doc.user_id, profile_id=p.id, consent_granted_at=datetime.now(timezone.utc), consent_type="in_person_exam", is_active=True))
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
    db.add(models.DoctorPatientLink(doctor_id=doc.user_id, profile_id=pp.id, consent_granted_at=datetime.now(timezone.utc), consent_type="in_person_exam", is_active=True))
    db.flush()
    assert client.get("/api/doctor/patients", headers=h).status_code == 200


def test_patient_summary(client, db):
    _, doc, h = _doc(db, "sum@test.com", "NMC500")
    _, pp = _patient(db, "summary@test.com")
    db.add(models.DoctorPatientLink(doctor_id=doc.user_id, profile_id=pp.id, consent_granted_at=datetime.now(timezone.utc), consent_type="in_person_exam", is_active=True))
    db.flush()
    assert client.get(f"/api/doctor/patients/{pp.id}/summary", headers=h).status_code == 200


def test_verify_non_admin(client, auth_headers, test_user, db):
    _, doc, _ = _doc(db, "ver@test.com", "NMC600")
    assert client.post(f"/api/doctor/verify/{doc.id}", headers=auth_headers).status_code == 403
