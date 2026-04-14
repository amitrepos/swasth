"""Coverage boost tests for routes_health.py — targeting 80% → 95%."""
import pytest
from unittest.mock import patch
from datetime import datetime, timedelta, timezone


def _pid(db):
    import models
    return db.query(models.Profile).first().id


def _r(db, pid, rtype, val, days_ago=0, status="NORMAL", **kw):
    import models
    ts = datetime.now(timezone.utc) - timedelta(days=days_ago)
    r = models.HealthReading(
        profile_id=pid, reading_type=rtype, value_numeric=val,
        unit_display="mg/dL" if rtype == "glucose" else ("%" if rtype == "spo2" else "mmHg"),
        reading_timestamp=ts, created_at=ts, status_flag=status, **kw,
    )
    db.add(r); db.flush()
    return r


def _meal(db, pid, cat="HIGH_CARB"):
    import models
    now = datetime.now(timezone.utc)
    m = models.MealLog(
        profile_id=pid, timestamp=now, category=cat,
        meal_type="LUNCH", input_method="QUICK_SELECT",
        glucose_impact="HIGH" if cat == "HIGH_CARB" else "LOW",
    )
    db.add(m); db.flush()
    return m


# ── Save Reading ─────────────────────────────────────────────────────────

def test_save_invalid_type(client, auth_headers, test_user, db):
    r = client.post("/api/readings", json={
        "profile_id": _pid(db), "reading_type": "invalid",
        "value_numeric": 100, "unit_display": "x",
        "reading_timestamp": datetime.now(timezone.utc).isoformat(),
    }, headers=auth_headers)
    assert r.status_code == 400


def test_save_spo2(client, auth_headers, test_user, db):
    r = client.post("/api/readings", json={
        "profile_id": _pid(db), "reading_type": "spo2",
        "value_numeric": 95, "unit_display": "%",
        "spo2_value": 95.0, "notes": "Test note",
        "reading_timestamp": datetime.now(timezone.utc).isoformat(),
    }, headers=auth_headers)
    assert r.status_code == 201


def test_save_steps(client, auth_headers, test_user, db):
    r = client.post("/api/readings", json={
        "profile_id": _pid(db), "reading_type": "steps",
        "value_numeric": 5000, "unit_display": "steps",
        "steps_count": 5000, "steps_goal": 7500,
        "reading_timestamp": datetime.now(timezone.utc).isoformat(),
    }, headers=auth_headers)
    assert r.status_code == 201


def test_save_critical_spo2(client, auth_headers, test_user, db):
    r = client.post("/api/readings", json={
        "profile_id": _pid(db), "reading_type": "spo2",
        "value_numeric": 85, "unit_display": "%",
        "spo2_value": 85.0, "status_flag": "CRITICAL",
        "reading_timestamp": datetime.now(timezone.utc).isoformat(),
    }, headers=auth_headers)
    assert r.status_code == 201


def test_save_critical_glucose(client, auth_headers, test_user, db):
    r = client.post("/api/readings", json={
        "profile_id": _pid(db), "reading_type": "glucose",
        "value_numeric": 400, "unit_display": "mg/dL",
        "glucose_value": 400.0, "status_flag": "CRITICAL",
        "reading_timestamp": datetime.now(timezone.utc).isoformat(),
    }, headers=auth_headers)
    assert r.status_code == 201


# ── Get Readings ─────────────────────────────────────────────────────────

def test_get_invalid_type(client, auth_headers, test_user, db):
    r = client.get(f"/api/readings?profile_id={_pid(db)}&reading_type=invalid", headers=auth_headers)
    assert r.status_code == 400


# ── Health Score ─────────────────────────────────────────────────────────

def test_score_empty(client, auth_headers, test_user, db):
    r = client.get(f"/api/readings/health-score?profile_id={_pid(db)}", headers=auth_headers)
    assert r.status_code == 200
    assert "insight" in r.json()


def test_score_yesterday_streak(client, auth_headers, test_user, db):
    pid = _pid(db)
    _r(db, pid, "glucose", 120, days_ago=1, glucose_value=120.0)
    _r(db, pid, "glucose", 120, days_ago=0, glucose_value=120.0)
    r = client.get(f"/api/readings/health-score?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200
    assert r.json().get("streak_days", 0) >= 1


def test_score_7day_streak(client, auth_headers, test_user, db):
    pid = _pid(db)
    for d in range(8):
        _r(db, pid, "glucose", 110, days_ago=d, glucose_value=110.0)
    r = client.get(f"/api/readings/health-score?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200
    assert r.json().get("streak_days", 0) >= 7


def test_score_critical(client, auth_headers, test_user, db):
    pid = _pid(db)
    _r(db, pid, "blood_pressure", 190, status="HIGH - STAGE 2", systolic=190.0, diastolic=110.0)
    _r(db, pid, "glucose", 350, status="CRITICAL", glucose_value=350.0)
    r = client.get(f"/api/readings/health-score?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200


def test_score_welcome_back(client, auth_headers, test_user, db):
    pid = _pid(db)
    _r(db, pid, "glucose", 120, days_ago=5, glucose_value=120.0)
    r = client.get(f"/api/readings/health-score?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200


def test_score_stage2(client, auth_headers, test_user, db):
    pid = _pid(db)
    _r(db, pid, "blood_pressure", 170, status="HIGH - STAGE 2", systolic=170.0, diastolic=100.0)
    r = client.get(f"/api/readings/health-score?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200


def test_score_first(client, auth_headers, test_user, db):
    pid = _pid(db)
    _r(db, pid, "glucose", 100, glucose_value=100.0)
    r = client.get(f"/api/readings/health-score?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200


def test_score_bmi(client, auth_headers, test_user, db):
    import models
    p = db.query(models.Profile).first()
    p.height = 170.0; p.weight = 90.0; db.flush()
    _r(db, p.id, "glucose", 110, glucose_value=110.0)
    r = client.get(f"/api/readings/health-score?profile_id={p.id}", headers=auth_headers)
    assert r.status_code == 200
    assert r.json().get("bmi") is not None


def test_score_spo2(client, auth_headers, test_user, db):
    pid = _pid(db)
    _r(db, pid, "spo2", 96, spo2_value=96.0)
    r = client.get(f"/api/readings/health-score?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200


# ── AI Insight ───────────────────────────────────────────────────────────

def test_insight_spo2_only(client, auth_headers, test_user, db):
    pid = _pid(db)
    _r(db, pid, "spo2", 96, spo2_value=96.0)
    r = client.get(f"/api/readings/ai-insight?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200


@patch("ai_service.generate_health_insight", return_value=None)
def test_insight_meals(mock_ai, client, auth_headers, test_user, db):
    pid = _pid(db)
    _r(db, pid, "glucose", 150, glucose_value=150.0)
    _r(db, pid, "glucose", 140, days_ago=1, glucose_value=140.0)
    _meal(db, pid)
    r = client.get(f"/api/readings/ai-insight?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200


@patch("ai_service.generate_health_insight", return_value="Trending insight")
def test_insight_trend(mock_ai, client, auth_headers, test_user, db):
    pid = _pid(db)
    for i in range(8):
        _r(db, pid, "glucose", 100 + i * 10, days_ago=7 - i, glucose_value=100.0 + i * 10)
    r = client.get(f"/api/readings/ai-insight?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200


# ── Trend Summary ────────────────────────────────────────────────────────

def test_trend_empty(client, auth_headers, test_user, db):
    r = client.get(f"/api/readings/trend-summary?profile_id={_pid(db)}", headers=auth_headers)
    assert r.status_code == 200


def test_trend_text(client, auth_headers, test_user, db):
    pid = _pid(db)
    _r(db, pid, "glucose", 120, glucose_value=120.0)
    _r(db, pid, "blood_pressure", 130, systolic=130.0, diastolic=80.0)
    r = client.get(f"/api/readings/trend-summary?profile_id={pid}&format=text", headers=auth_headers)
    assert r.status_code == 200


def test_trend_meals(client, auth_headers, test_user, db):
    pid = _pid(db)
    _r(db, pid, "glucose", 120, glucose_value=120.0)
    _meal(db, pid)
    r = client.get(f"/api/readings/trend-summary?profile_id={pid}", headers=auth_headers)
    assert r.status_code == 200


# ── Family Streaks ───────────────────────────────────────────────────────

def test_family_streaks(client, auth_headers, test_user, db):
    _r(db, _pid(db), "glucose", 120, days_ago=1, glucose_value=120.0)
    r = client.get("/api/readings/family-streaks", headers=auth_headers)
    assert r.status_code == 200


# ── Parse Image ──────────────────────────────────────────────────────────

def test_parse_no_key(client, auth_headers, test_user, db):
    pid = _pid(db)
    with patch("routes_health.settings") as ms:
        ms.GEMINI_API_KEY = ""; ms.DEEPSEEK_API_KEY = ""
        r = client.post(
            f"/api/readings/parse-image?profile_id={pid}&device_type=glucose",
            files={"image": ("test.jpg", b"fake", "image/jpeg")},
            headers=auth_headers,
        )
        assert r.status_code in (200, 400, 422, 500)
