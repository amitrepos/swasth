"""Add 7 days of sample step readings for local dev / Insights chart demos.

Run:
  cd backend && source venv/bin/activate && python seed_steps_readings.py

Idempotent: skips days that already have a non-zero step reading. If a day
already has a zero-step row (e.g. a failed pedometer sync), that row is
deleted and replaced with the sample non-zero reading.
"""
from datetime import datetime, timedelta, timezone

from database import SessionLocal
import models

GOAL = 7500
# Oldest → newest (7 calendar days including today)
DAILY_STEPS = [3200, 5100, 6800, 7500, 4200, 8900, 6100]


def _day_bounds(day):
    start = datetime.combine(day, datetime.min.time(), tzinfo=timezone.utc)
    end = start + timedelta(days=1)
    return start, end


def seed_steps_for_profile(db, profile_id):
    today = datetime.now(timezone.utc).date()
    start_day = today - timedelta(days=len(DAILY_STEPS) - 1)

    access = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == profile_id,
            models.ProfileAccess.access_level == "owner",
        )
        .first()
    )
    logged_by = access.user_id if access else None

    added = 0
    for i, steps in enumerate(DAILY_STEPS):
        day = start_day + timedelta(days=i)
        day_start, day_end = _day_bounds(day)
        existing = (
            db.query(models.HealthReading)
            .filter(
                models.HealthReading.profile_id == profile_id,
                models.HealthReading.reading_type == "steps",
                models.HealthReading.reading_timestamp >= day_start,
                models.HealthReading.reading_timestamp < day_end,
            )
            .first()
        )
        if existing:
            if (existing.steps_count or 0) > 0:
                continue
            db.delete(existing)

        ts = day_start.replace(hour=21, minute=0)
        db.add(
            models.HealthReading(
                profile_id=profile_id,
                logged_by=logged_by,
                reading_type="steps",
                steps_count=steps,
                steps_goal=GOAL,
                value_numeric=float(steps),
                unit_display="steps",
                status_flag="NORMAL",
                reading_timestamp=ts,
            )
        )
        added += 1
    return added


def main():
    db = SessionLocal()
    try:
        profiles = db.query(models.Profile).all()
        if not profiles:
            print("No profiles found — create a user first.")
            return

        total = 0
        for profile in profiles:
            n = seed_steps_for_profile(db, profile.id)
            if n:
                print(f"  ✓ profile {profile.id} ({profile.name}): +{n} step readings")
                total += n
            else:
                print(f"  ⏭  profile {profile.id} ({profile.name}): step data already present")

        db.commit()
        print(f"\nDone — {total} step readings added.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
