import pytest
from datetime import datetime, timedelta, timezone
import models

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
