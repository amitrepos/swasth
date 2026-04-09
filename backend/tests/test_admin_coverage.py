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
