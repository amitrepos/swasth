"""Coverage boost tests for routes_admin.py — targeting 68% → 85%."""
import pytest
from datetime import datetime, timedelta, timezone
from auth import get_password_hash, create_access_token
import models


def _admin(db):
    user = models.User(
        email="admin@swasth.app", password_hash=get_password_hash("Admin@1234"),
        full_name="Admin User", phone_number="9876543299",
        is_admin=True, role="admin",
    )
    db.add(user); db.flush()
    p = models.Profile(name="Admin Health")
    db.add(p); db.flush()
    db.add(models.ProfileAccess(user_id=user.id, profile_id=p.id, access_level="owner"))
    db.flush()
    return user, {"Authorization": f"Bearer {create_access_token(data={'sub': user.email})}"}


def _data_user(db, email="data@test.com"):
    user = models.User(
        email=email, password_hash=get_password_hash("Test@1234"),
        full_name="Data User", phone_number="9876543288",
        last_login_at=datetime.now(timezone.utc),
    )
    db.add(user); db.flush()
    p = models.Profile(name="Data Health", age=50, gender="Male")
    db.add(p); db.flush()
    db.add(models.ProfileAccess(user_id=user.id, profile_id=p.id, access_level="owner"))
    db.flush()
    now = datetime.now(timezone.utc)
    for d in range(3):
        ts = now - timedelta(days=d)
        db.add(models.HealthReading(
            profile_id=p.id, reading_type="glucose", value_numeric=120 + d * 10,
            unit_display="mg/dL", glucose_value=120.0 + d * 10,
            reading_timestamp=ts, created_at=ts, status_flag="NORMAL",
        ))
    db.add(models.ChatMessage(
        user_id=user.id, profile_id=p.id,
        user_message="Test question", ai_response="Test answer",
        created_at=now,
    ))
    db.add(models.AiInsightLog(
        profile_id=p.id, model_used="test",
        prompt_summary="test", response_text="test response", created_at=now,
    ))
    db.add(models.ChatContextProfile(profile_id=p.id, summary="Test summary", message_count=5))
    db.flush()
    return user, p


def test_dashboard(client, db):
    _, h = _admin(db)
    assert client.get("/api/admin", headers=h).status_code == 200


def test_metrics(client, db):
    _, h = _admin(db)
    _data_user(db)
    r = client.get("/api/admin/metrics", headers=h)
    assert r.status_code == 200
    assert "total_users" in r.json()


def test_metrics_retention(client, db):
    _, h = _admin(db)
    u, _ = _data_user(db, "retain@test.com")
    u.created_at = datetime.now(timezone.utc) - timedelta(days=2)
    u.last_login_at = datetime.now(timezone.utc)
    db.flush()
    assert client.get("/api/admin/metrics", headers=h).status_code == 200


def test_users_list(client, db):
    _, h = _admin(db)
    _data_user(db)
    r = client.get("/api/admin/users", headers=h)
    assert r.status_code == 200


def test_user_detail(client, db):
    _, h = _admin(db)
    u, _ = _data_user(db)
    assert client.get(f"/api/admin/users/{u.id}/detail", headers=h).status_code == 200


def test_update_memory(client, db):
    _, h = _admin(db)
    _, p = _data_user(db)
    assert client.put(f"/api/admin/profiles/{p.id}/ai-memory",
                      json={"summary": "Updated"}, headers=h).status_code in (200, 204)


def test_reset_memory(client, db):
    _, h = _admin(db)
    _, p = _data_user(db)
    assert client.delete(f"/api/admin/profiles/{p.id}/ai-memory", headers=h).status_code in (200, 204)


def test_non_admin(client, auth_headers, test_user, db):
    assert client.get("/api/admin/metrics", headers=auth_headers).status_code == 403


# ---------------------------------------------------------------------------
# Phase 1: Suspension, Doctor verification, Consent, Alerts, Audit log
# ---------------------------------------------------------------------------

def _doctor_user(db, email="doc@test.com", nmc="MH202512345"):
    """Create a doctor user with DoctorProfile."""
    user = models.User(
        email=email, password_hash=get_password_hash("Doc@1234"),
        full_name="Dr. Test", phone_number="9876543277",
        role="doctor",
    )
    db.add(user); db.flush()
    dp = models.DoctorProfile(
        user_id=user.id, nmc_number=nmc, specialty="General Physician",
        clinic_name="Test Clinic", doctor_code=f"DR{user.id:05d}",
        is_verified=False,
    )
    db.add(dp); db.flush()
    return user, dp


# -- G2: Suspension tests --

def test_suspend_user(client, db):
    admin, h = _admin(db)
    u, _ = _data_user(db)
    r = client.patch(f"/api/admin/users/{u.id}/suspend",
                     json={"suspend": True, "reason": "Misuse of platform"}, headers=h)
    assert r.status_code == 200
    assert "suspended" in r.json()["message"]
    # Verify user is actually suspended
    db.refresh(u)
    assert u.is_active is False


def test_reactivate_user(client, db):
    admin, h = _admin(db)
    u, _ = _data_user(db)
    u.is_active = False; db.flush()
    r = client.patch(f"/api/admin/users/{u.id}/suspend",
                     json={"suspend": False, "reason": "Reviewed and cleared"}, headers=h)
    assert r.status_code == 200
    assert "reactivated" in r.json()["message"]


def test_cannot_suspend_self(client, db):
    admin, h = _admin(db)
    r = client.patch(f"/api/admin/users/{admin.id}/suspend",
                     json={"suspend": True, "reason": "Testing"}, headers=h)
    assert r.status_code == 400


def test_suspend_nonexistent_user(client, db):
    _, h = _admin(db)
    r = client.patch("/api/admin/users/99999/suspend",
                     json={"suspend": True, "reason": "Testing"}, headers=h)
    assert r.status_code == 404


def test_suspended_user_cannot_login(client, db):
    """Suspended user gets 403 on any authenticated endpoint."""
    admin, h = _admin(db)
    u, _ = _data_user(db)
    token = create_access_token(data={"sub": u.email})
    user_headers = {"Authorization": f"Bearer {token}"}

    # Suspend the user
    client.patch(f"/api/admin/users/{u.id}/suspend",
                 json={"suspend": True, "reason": "Test"}, headers=h)

    # User should get 403
    r = client.get("/api/profiles", headers=user_headers)
    assert r.status_code == 403
    assert "suspended" in r.json()["detail"].lower()


# -- G1: Doctor verification tests --

def test_list_doctors_all(client, db):
    _, h = _admin(db)
    _doctor_user(db)
    r = client.get("/api/admin/doctors", headers=h)
    assert r.status_code == 200
    assert r.json()["total"] >= 1


def test_list_doctors_filter_unverified(client, db):
    _, h = _admin(db)
    _doctor_user(db)
    r = client.get("/api/admin/doctors?verified=false", headers=h)
    assert r.status_code == 200
    assert all(not d["is_verified"] for d in r.json()["doctors"])


def test_verify_doctor(client, db):
    _, h = _admin(db)
    doc, dp = _doctor_user(db)
    r = client.post(f"/api/admin/doctors/{doc.id}/verify",
                    json={"notes": "NMC verified on registry"}, headers=h)
    assert r.status_code == 200
    assert "verified" in r.json()["message"]
    db.refresh(dp)
    assert dp.is_verified is True
    assert dp.verified_at is not None


def test_verify_already_verified(client, db):
    _, h = _admin(db)
    doc, dp = _doctor_user(db)
    dp.is_verified = True; db.flush()
    r = client.post(f"/api/admin/doctors/{doc.id}/verify",
                    json={"notes": "test"}, headers=h)
    assert r.status_code == 400


def test_verify_nonexistent_doctor(client, db):
    _, h = _admin(db)
    r = client.post("/api/admin/doctors/99999/verify",
                    json={"notes": "test"}, headers=h)
    assert r.status_code == 404


def test_reject_doctor(client, db):
    _, h = _admin(db)
    doc, dp = _doctor_user(db)
    r = client.post(f"/api/admin/doctors/{doc.id}/reject",
                    json={"reason": "Invalid NMC number", "notes": "Checked registry"}, headers=h)
    assert r.status_code == 200
    assert "rejected" in r.json()["message"]


def test_reject_nonexistent_doctor(client, db):
    _, h = _admin(db)
    r = client.post("/api/admin/doctors/99999/reject",
                    json={"reason": "Test"}, headers=h)
    assert r.status_code == 404


# -- G5: Consent dashboard tests --

def test_consent_dashboard(client, db):
    _, h = _admin(db)
    u, _ = _data_user(db)
    u.consent_timestamp = datetime.now(timezone.utc)
    u.consent_app_version = "1.0.0"
    u.consent_language = "en"
    db.flush()
    r = client.get("/api/admin/consent", headers=h)
    assert r.status_code == 200
    data = r.json()
    assert data["consented_count"] >= 1
    assert "not_consented" in data


# -- G4: Alerts tests --

def test_alerts_empty(client, db):
    _, h = _admin(db)
    r = client.get("/api/admin/alerts", headers=h)
    assert r.status_code == 200
    assert "alerts" in r.json()


def test_alerts_pending_doctor(client, db):
    _, h = _admin(db)
    doc, dp = _doctor_user(db)
    dp.created_at = datetime.now(timezone.utc) - timedelta(hours=50)
    db.flush()
    r = client.get("/api/admin/alerts", headers=h)
    assert r.status_code == 200
    alerts = r.json()["alerts"]
    doctor_alerts = [a for a in alerts if a["type"] == "DOCTOR_PENDING_VERIFICATION"]
    assert len(doctor_alerts) >= 1


def test_alerts_critical_reading(client, db):
    _, h = _admin(db)
    u, p = _data_user(db)
    db.add(models.HealthReading(
        profile_id=p.id, reading_type="glucose", value_numeric=450,
        unit_display="mg/dL", glucose_value=450.0,
        reading_timestamp=datetime.now(timezone.utc) - timedelta(hours=30),
        created_at=datetime.now(timezone.utc) - timedelta(hours=30),
        status_flag="CRITICAL",
    ))
    db.flush()
    r = client.get("/api/admin/alerts", headers=h)
    assert r.status_code == 200
    critical = [a for a in r.json()["alerts"] if a["type"] == "CRITICAL_READING_UNADDRESSED"]
    assert len(critical) >= 1


# -- G3: Audit log tests --

def test_audit_log_records_actions(client, db):
    admin, h = _admin(db)
    u, _ = _data_user(db)
    # Perform an action that creates an audit entry
    client.get(f"/api/admin/users/{u.id}/detail", headers=h)
    # Check audit log
    r = client.get("/api/admin/audit-log", headers=h)
    assert r.status_code == 200
    entries = r.json()["entries"]
    assert len(entries) >= 1
    assert any(e["action_type"] == "VIEW_USER_DETAIL" for e in entries)


def test_audit_log_filter_by_action(client, db):
    admin, h = _admin(db)
    u, _ = _data_user(db)
    client.get(f"/api/admin/users/{u.id}/detail", headers=h)
    r = client.get("/api/admin/audit-log?action_type=VIEW_USER_DETAIL", headers=h)
    assert r.status_code == 200
    assert all(e["action_type"] == "VIEW_USER_DETAIL" for e in r.json()["entries"])


def test_audit_log_suspension_recorded(client, db):
    admin, h = _admin(db)
    u, _ = _data_user(db)
    client.patch(f"/api/admin/users/{u.id}/suspend",
                 json={"suspend": True, "reason": "Test audit"}, headers=h)
    r = client.get("/api/admin/audit-log?action_type=SUSPEND_USER", headers=h)
    assert r.status_code == 200
    entries = r.json()["entries"]
    assert len(entries) >= 1
    assert entries[0]["details"]["reason"] == "Test audit"


def test_admin_toggle_audited(client, db):
    admin, h = _admin(db)
    u, _ = _data_user(db)
    client.patch(f"/api/admin/users/{u.id}", json={"is_admin": True}, headers=h)
    r = client.get("/api/admin/audit-log?action_type=TOGGLE_ADMIN", headers=h)
    assert r.status_code == 200
    assert len(r.json()["entries"]) >= 1
