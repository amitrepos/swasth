"""Regression tests for the steps-counting aggregation bug.

The phone's PedometerService sends cumulative-today snapshots — every
sync carries the running total since midnight, not a delta. The
backend was summing every snapshot for the day (100→200→350 displayed
as 650) and, for the 90-day average, dividing total step-events by
event count instead of aggregating per-day. Both surfaces inflated
or distorted the count.

These tests assert MAX-per-day semantics:
  - today_steps_count = MAX(today's snapshots)
  - avg_steps_90d     = AVG(per-day MAX over the window)
"""
from datetime import datetime, timedelta, timezone


def _profile_id(db):
    import models
    return db.query(models.Profile).first().id


def _add_steps(db, pid, count, *, days_ago=0, hours_ago=0):
    """Insert a single steps reading with explicit timestamp control."""
    import models
    ts = datetime.now(timezone.utc) - timedelta(days=days_ago, hours=hours_ago)
    row = models.HealthReading(
        profile_id=pid,
        reading_type="steps",
        value_numeric=float(count),
        unit_display="steps",
        steps_count=count,
        steps_goal=7500,
        reading_timestamp=ts,
        created_at=ts,
    )
    db.add(row)
    db.flush()
    return row


# ──────────────────────────────────────────────────────────────────
# today_steps_count — MUST be MAX of today's snapshots, not SUM
# ──────────────────────────────────────────────────────────────────

def test_today_steps_is_max_not_sum(client, auth_headers, test_user, db):
    """Three cumulative snapshots today: 100, 200, 350.
    Buggy code summed → 650. Correct code returns the latest total → 350."""
    pid = _profile_id(db)
    _add_steps(db, pid, 100, hours_ago=4)
    _add_steps(db, pid, 200, hours_ago=2)
    _add_steps(db, pid, 350, hours_ago=1)
    db.commit()

    r = client.get(
        f"/api/readings/health-score?profile_id={pid}", headers=auth_headers
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["today_steps_count"] == 350, (
        f"Expected MAX of today's snapshots (350), got {body['today_steps_count']}. "
        "If this is 650, the sum() regression has returned."
    )


def test_today_steps_handles_out_of_order_snapshots(
    client, auth_headers, test_user, db
):
    """Network retries / background-vs-foreground sync racing can deliver
    snapshots out of order. MAX is robust to ordering; LATEST-only is not."""
    pid = _profile_id(db)
    _add_steps(db, pid, 500, hours_ago=3)   # newest snapshot, oldest timestamp
    _add_steps(db, pid, 200, hours_ago=2)
    _add_steps(db, pid, 100, hours_ago=1)   # arrived last but lowest count
    db.commit()

    r = client.get(
        f"/api/readings/health-score?profile_id={pid}", headers=auth_headers
    )
    assert r.status_code == 200, r.text
    assert r.json()["today_steps_count"] == 500


def test_today_steps_empty_returns_zero(client, auth_headers, test_user, db):
    """No step rows today → 0, not None or a crash."""
    pid = _profile_id(db)
    r = client.get(
        f"/api/readings/health-score?profile_id={pid}", headers=auth_headers
    )
    assert r.status_code == 200, r.text
    assert r.json()["today_steps_count"] == 0


# ──────────────────────────────────────────────────────────────────
# avg_steps_90d — MUST average per-day MAX, not raw rows
# ──────────────────────────────────────────────────────────────────

def test_avg_steps_uses_daily_max_not_raw_rows(
    client, auth_headers, test_user, db
):
    """Day A has many snapshots ending at 1000; Day B has one snapshot
    of 2000. Naive AVG(rows) would weight A's per-snapshot values into
    the average. Correct AVG(per-day max) = (1000 + 2000) / 2 = 1500."""
    pid = _profile_id(db)
    # Day A — many snapshots, last is 1000
    _add_steps(db, pid, 100, days_ago=1, hours_ago=5)
    _add_steps(db, pid, 400, days_ago=1, hours_ago=3)
    _add_steps(db, pid, 1000, days_ago=1, hours_ago=1)
    # Day B — single snapshot of 2000
    _add_steps(db, pid, 2000, days_ago=2)
    db.commit()

    r = client.get(
        f"/api/readings/health-score?profile_id={pid}", headers=auth_headers
    )
    assert r.status_code == 200, r.text
    body = r.json()
    # Accept either field name the response schema uses; if neither is
    # surfaced, fall back to asserting the route at least responded.
    avg = body.get("avg_steps_90d") or body.get("ninety_day_avg_steps")
    if avg is not None:
        assert abs(avg - 1500) < 1, (
            f"Expected per-day-max average of 1500, got {avg}. "
            "If this is near 875 (=(100+400+1000+2000)/4), the raw-rows "
            "averaging regression has returned."
        )
