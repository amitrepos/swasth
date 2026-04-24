import pytest
from datetime import datetime, timedelta, timezone
import models


# ---------------------------------------------------------------------------
# Registration weight auto-log
# ---------------------------------------------------------------------------

_REG_BASE = {
    "email": "newuser@swasth.app",
    "password": "Strong@123",
    "confirm_password": "Strong@123",
    "full_name": "New User",
    "phone_number": "9000000001",
    "age": 30,
    "gender": "Male",
    "height": 170.0,
    "consent_app_version": "1.0",
    "consent_language": "en",
}


def test_register_with_weight_creates_health_reading(client, db):
    """POST /register with weight must create a HealthReading of type 'weight'."""
    payload = {**_REG_BASE, "weight": 72.5}
    resp = client.post("/api/auth/register", json=payload)
    assert resp.status_code == 201

    profile = db.query(models.Profile).filter_by(name="My Health").first()
    assert profile is not None

    reading = (
        db.query(models.HealthReading)
        .filter_by(profile_id=profile.id, reading_type="weight")
        .first()
    )
    assert reading is not None, "Weight HealthReading must be created at registration"
    assert reading.weight_value == 72.5
    assert reading.value_numeric == 72.5
    assert reading.unit_display == "kg"
    assert reading.logged_by is not None


def test_register_without_weight_creates_no_weight_reading(client, db):
    """POST /register without weight must NOT create a weight HealthReading."""
    payload = {**_REG_BASE, "email": "noweight@swasth.app"}
    resp = client.post("/api/auth/register", json=payload)
    assert resp.status_code == 201

    profile = db.query(models.Profile).filter_by(name="My Health").first()
    reading = (
        db.query(models.HealthReading)
        .filter_by(profile_id=profile.id, reading_type="weight")
        .first()
    )
    assert reading is None, "No weight HealthReading should be created when weight is omitted"


def test_register_weight_reading_appears_in_readings_api(client, db):
    """Weight reading created at registration must be retrievable via GET /readings."""
    payload = {**_REG_BASE, "email": "weightapi@swasth.app", "weight": 68.0}
    reg_resp = client.post("/api/auth/register", json=payload)
    assert reg_resp.status_code == 201

    from auth import create_access_token
    token = create_access_token(data={"sub": "weightapi@swasth.app"})
    headers = {"Authorization": f"Bearer {token}"}

    profile = db.query(models.Profile).filter_by(name="My Health").first()
    resp = client.get(
        f"/api/readings?profile_id={profile.id}&reading_type=weight",
        headers=headers,
    )
    assert resp.status_code == 200
    readings = resp.json()
    assert any(r["reading_type"] == "weight" and r["weight_value"] == 68.0 for r in readings)

def _pid(db):
    return db.query(models.Profile).first().id

def _r(db, pid, rtype, val, days_ago=0, **kw):
    ts = datetime.now(timezone.utc) - timedelta(days=days_ago)
    r = models.HealthReading(
        profile_id=pid, reading_type=rtype, value_numeric=val,
        unit_display="kg" if rtype == "weight" else ("mg/dL" if rtype == "glucose" else "mmHg"),
        reading_timestamp=ts, created_at=ts, **kw
    )
    db.add(r); db.flush()
    return r

def test_save_weight_reading(client, auth_headers, db):
    """Verify weight readings can be logged via POST /api/readings."""
    pid = _pid(db)
    payload = {
        "profile_id": pid,
        "reading_type": "weight",
        "value_numeric": 75.5,
        "weight_value": 75.5,
        "unit_display": "kg",
        "reading_timestamp": datetime.now(timezone.utc).isoformat()
    }
    resp = client.post("/api/readings", json=payload, headers=auth_headers)
    assert resp.status_code == 201
    assert resp.json()["reading_type"] == "weight"
    assert resp.json()["weight_value"] == 75.5

def test_weight_trend_summary_falling(client, auth_headers, db):
    """Verify descending weight leads to a falling trend (↓)."""
    pid = _pid(db)
    # Log 3 readings in descending order
    _r(db, pid, "weight", 80.0, weight_value=80.0, days_ago=5)
    _r(db, pid, "weight", 79.0, weight_value=79.0, days_ago=3)
    _r(db, pid, "weight", 78.0, weight_value=78.0, days_ago=0)

    resp = client.get(f"/api/readings/trend-summary?profile_id={pid}", headers=auth_headers)
    assert resp.status_code == 200
    summary = resp.json()["summary"]
    assert "↓" in summary or "decreasing" in summary.lower()

def test_weight_trend_summary_rising(client, auth_headers, db):
    """Verify ascending weight leads to a rising trend (↑)."""
    pid = _pid(db)
    # Log 3 readings in ascending order
    _r(db, pid, "weight", 70.0, weight_value=70.0, days_ago=5)
    _r(db, pid, "weight", 72.0, weight_value=72.0, days_ago=3)
    _r(db, pid, "weight", 75.0, weight_value=75.0, days_ago=0)

    resp = client.get(f"/api/readings/trend-summary?profile_id={pid}", headers=auth_headers)
    assert resp.status_code == 200
    summary = resp.json()["summary"]
    assert "↑" in summary or "increasing" in summary.lower()

def test_bmi_insight_overweight_fallback(client, auth_headers, db):
    """Verify overweight BMI triggers the correct rule-based insight when AI fails."""
    profile = db.query(models.Profile).first()
    profile.height = 170.0  # cm
    db.flush()

    # 170cm, 80kg => BMI ~27.7 (Overweight)
    _r(db, profile.id, "weight", 80.0, weight_value=80.0, days_ago=0)

    # We use ai-insight endpoint, which falls back to rule-based if LLM fails or consent missing
    # To force fallback easily, we can use a query that bypasses LLM or just check the logic directly via a tailored mock if needed.
    # But get_ai_insight already returns fallback if glucose/BP are missing (per our previous fix).
    resp = client.get(f"/api/readings/ai-insight?profile_id={profile.id}", headers=auth_headers)
    assert resp.status_code == 200
    insight = resp.json()["insight"]
    assert "Overweight" in insight
    assert "27.7" in insight or "27.6" in insight # Floating point precision check

def test_shareable_summary_includes_weight(client, auth_headers, db):
    """Verify the text summary includes Weight averages."""
    pid = _pid(db)
    _r(db, pid, "weight", 75.0, weight_value=75.0, days_ago=1)
    _r(db, pid, "weight", 77.0, weight_value=77.0, days_ago=0)

    resp = client.get(f"/api/readings/trend-summary?profile_id={pid}&format=text", headers=auth_headers)
    assert resp.status_code == 200
    summary = resp.text
    assert "Weight" in summary
    assert "Avg: 76.0" in summary
