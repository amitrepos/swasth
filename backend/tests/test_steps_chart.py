"""Tests for the 7-day steps daily-aggregate endpoint (NUO-22)."""
from datetime import datetime, timezone, timedelta, date

import pytest

import models


def _profile_id_for(user, db):
    return (
        db.query(models.ProfileAccess)
        .filter(models.ProfileAccess.user_id == user.id)
        .first()
        .profile_id
    )


def _add_steps(db, profile_id, ts, count, goal=None):
    db.add(models.HealthReading(
        profile_id=profile_id,
        reading_type="steps",
        steps_count=count,
        steps_goal=goal,
        value_numeric=count,
        unit_display="steps",
        reading_timestamp=ts,
    ))


def test_daily_steps_returns_seven_days_oldest_first(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    now = datetime.now(timezone.utc)
    _add_steps(db, pid, now, 5000, goal=8000)
    _add_steps(db, pid, now - timedelta(days=2), 3000)
    db.commit()

    r = client.get(f"/api/readings/steps/daily?profile_id={pid}&days=7", headers=auth_headers)
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body["days"]) == 7
    # Oldest-first
    dates = [d["date"] for d in body["days"]]
    assert dates == sorted(dates)
    # Last entry is today
    assert body["days"][-1]["date"] == date.today().isoformat()
    assert body["days"][-1]["steps"] == 5000


def test_daily_steps_takes_max_per_day(client, db, test_user, auth_headers):
    """Pedometer pushes cumulative counts — we should pick the highest."""
    pid = _profile_id_for(test_user, db)
    now = datetime.now(timezone.utc).replace(hour=12, minute=0)
    _add_steps(db, pid, now.replace(hour=8), 2000)
    _add_steps(db, pid, now.replace(hour=14), 6000)
    _add_steps(db, pid, now.replace(hour=20), 4500)  # later but lower (device hiccup)
    db.commit()

    r = client.get(f"/api/readings/steps/daily?profile_id={pid}&days=7", headers=auth_headers)
    body = r.json()
    today_row = body["days"][-1]
    assert today_row["steps"] == 6000


def test_daily_steps_fills_zero_for_empty_days(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    db.commit()
    r = client.get(f"/api/readings/steps/daily?profile_id={pid}&days=7", headers=auth_headers)
    body = r.json()
    assert len(body["days"]) == 7
    assert all(d["steps"] == 0 for d in body["days"])
    assert body["total"] == 0
    assert body["avg"] == 0
    assert body["goal"] is None
    assert body["goal_hit_days"] == 0


def test_daily_steps_computes_total_avg_and_goal_hits(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    base = datetime.now(timezone.utc).replace(hour=12)
    # 7-day window with explicit values + goal
    values = [8500, 7000, 9000, 5000, 8001, 0, 8000]  # 4 hits >= 8000
    for i, v in enumerate(values):
        _add_steps(db, pid, base - timedelta(days=6 - i), v, goal=8000)
    db.commit()

    r = client.get(f"/api/readings/steps/daily?profile_id={pid}&days=7", headers=auth_headers)
    body = r.json()
    assert body["total"] == sum(values)
    assert body["avg"] == round(sum(values) / 7)
    assert body["goal"] == 8000
    assert body["goal_hit_days"] == 4


def test_daily_steps_ignores_other_reading_types(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    now = datetime.now(timezone.utc)
    # Glucose reading should NOT inflate steps
    db.add(models.HealthReading(
        profile_id=pid,
        reading_type="glucose",
        glucose_value=120,
        glucose_unit="mg/dL",
        value_numeric=120,
        unit_display="mg/dL",
        reading_timestamp=now,
    ))
    db.commit()

    r = client.get(f"/api/readings/steps/daily?profile_id={pid}&days=7", headers=auth_headers)
    body = r.json()
    assert body["total"] == 0


def test_daily_steps_requires_auth(client, test_user, db):
    pid = _profile_id_for(test_user, db)
    r = client.get(f"/api/readings/steps/daily?profile_id={pid}&days=7")
    assert r.status_code == 401


def test_daily_steps_403_on_unrelated_profile(client, db, auth_headers):
    other = models.Profile(name="Stranger")
    db.add(other)
    db.commit()
    db.refresh(other)
    r = client.get(f"/api/readings/steps/daily?profile_id={other.id}&days=7", headers=auth_headers)
    assert r.status_code == 403


def test_daily_steps_rejects_days_out_of_range(client, test_user, db, auth_headers):
    pid = _profile_id_for(test_user, db)
    r = client.get(f"/api/readings/steps/daily?profile_id={pid}&days=0", headers=auth_headers)
    assert r.status_code == 422
    r = client.get(f"/api/readings/steps/daily?profile_id={pid}&days=99", headers=auth_headers)
    assert r.status_code == 422


def test_daily_steps_30_day_window(client, db, test_user, auth_headers):
    pid = _profile_id_for(test_user, db)
    now = datetime.now(timezone.utc)
    _add_steps(db, pid, now, 1000)
    _add_steps(db, pid, now - timedelta(days=25), 2000)
    _add_steps(db, pid, now - timedelta(days=29), 3000)
    db.commit()

    r = client.get(f"/api/readings/steps/daily?profile_id={pid}&days=30", headers=auth_headers)
    body = r.json()
    assert len(body["days"]) == 30
    assert body["total"] == 6000


def test_daily_steps_goal_uses_latest_non_null(client, db, test_user, auth_headers):
    """Latest goal value seen in the window wins — supports goal changes mid-week."""
    pid = _profile_id_for(test_user, db)
    base = datetime.now(timezone.utc).replace(hour=12)
    _add_steps(db, pid, base - timedelta(days=4), 1000, goal=6000)
    _add_steps(db, pid, base - timedelta(days=1), 1000, goal=10000)
    db.commit()

    r = client.get(f"/api/readings/steps/daily?profile_id={pid}&days=7", headers=auth_headers)
    assert r.json()["goal"] == 10000
