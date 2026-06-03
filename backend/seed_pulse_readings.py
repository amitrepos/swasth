"""Add 7 days of sample blood-pressure readings (with pulse / heart rate) for
local dev / Insights chart demos — populates the 7-day Heart Rate card.

Run:
  cd backend && source venv/bin/activate && python seed_pulse_readings.py

Idempotent: skips a day that already has a blood-pressure reading. If that
existing same-day reading has no pulse_rate, the sample pulse is backfilled
onto it (rather than inserting a duplicate) so the Heart Rate chart renders.
"""
from datetime import datetime, timedelta, timezone

from database import SessionLocal
import models

# Oldest → newest (7 calendar days including today): (pulse bpm, systolic, diastolic).
DAILY_VITALS = [
    (72, 122, 80),
    (78, 128, 82),
    (68, 118, 76),
    (85, 134, 86),
    (74, 124, 79),
    (70, 120, 78),
    (81, 130, 84),
]


def _day_bounds(day):
    start = datetime.combine(day, datetime.min.time(), tzinfo=timezone.utc)
    end = start + timedelta(days=1)
    return start, end


def seed_pulse_for_profile(db, profile_id):
    today = datetime.now(timezone.utc).date()
    start_day = today - timedelta(days=len(DAILY_VITALS) - 1)

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
    for i, (pulse, systolic, diastolic) in enumerate(DAILY_VITALS):
        day = start_day + timedelta(days=i)
        day_start, day_end = _day_bounds(day)
        existing = (
            db.query(models.HealthReading)
            .filter(
                models.HealthReading.profile_id == profile_id,
                models.HealthReading.reading_type == "blood_pressure",
                models.HealthReading.reading_timestamp >= day_start,
                models.HealthReading.reading_timestamp < day_end,
            )
            .first()
        )
        if existing:
            if existing.pulse_rate is None:
                existing.pulse_rate = float(pulse)
                added += 1
            continue

        ts = day_start.replace(hour=21, minute=0)
        db.add(
            models.HealthReading(
                profile_id=profile_id,
                logged_by=logged_by,
                reading_type="blood_pressure",
                systolic=float(systolic),
                diastolic=float(diastolic),
                pulse_rate=float(pulse),
                bp_unit="mmHg",
                bp_status="NORMAL",
                value_numeric=float(systolic),
                unit_display="mmHg",
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
            n = seed_pulse_for_profile(db, profile.id)
            if n:
                print(f"  ✓ profile {profile.id} ({profile.name}): +{n} pulse/BP readings")
                total += n
            else:
                print(f"  ⏭  profile {profile.id} ({profile.name}): BP data already present")

        db.commit()
        print(f"\nDone — {total} pulse/BP readings added.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
