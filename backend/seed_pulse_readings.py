"""Add 7 days of sample blood-pressure readings (with pulse / heart rate) for
local dev / Insights chart demos — populates the 7-day Heart Rate card.

Run:
  cd backend && source venv/bin/activate && python seed_pulse_readings.py

Idempotent: skips a day that already has a blood-pressure reading. If that
existing same-day reading has no pulse_rate, the sample pulse is backfilled
onto it (rather than inserting a duplicate) so the Heart Rate chart renders.
"""
import logging
from datetime import datetime, timedelta, timezone

from database import SessionLocal
import models

logger = logging.getLogger(__name__)

# Oldest → newest (7 calendar days including today): (pulse bpm, systolic, diastolic).
# A spread of normal/elevated/stage-1 values so the demo data is clinically
# plausible — bp_status() below derives the correct flag per row.
DAILY_VITALS = [
    (72, 122, 80),
    (78, 128, 82),
    (68, 118, 76),
    (85, 134, 86),
    (74, 124, 79),
    (70, 120, 78),
    (81, 130, 84),
]


def bp_status(systolic: int, diastolic: int) -> str:
    """Match the exact status vocabulary used by seed_demo_data.py / the app
    (no AHA 'Elevated' tier — the UI's BP info sheet only maps these strings)."""
    if systolic > 140 or diastolic > 90:
        return "HIGH - STAGE 2"
    if systolic > 131 or diastolic > 86:
        return "HIGH - STAGE 1"
    if systolic < 90 or diastolic < 60:
        return "LOW"
    return "NORMAL"


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
    if access is None:
        # No owner → no user to attribute the reading to. Skip rather than
        # stage rows with logged_by=None that would be orphaned.
        logger.warning("profile %s: no owner found, skipping", profile_id)
        return 0
    logged_by = access.user_id

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

        status = bp_status(systolic, diastolic)
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
                bp_status=status,
                value_numeric=float(systolic),
                unit_display="mmHg",
                status_flag=status,
                reading_timestamp=ts,
            )
        )
        added += 1
    return added


def main():
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    db = SessionLocal()
    try:
        profiles = db.query(models.Profile).all()
        if not profiles:
            logger.info("No profiles found — create a user first.")
            return

        total = 0
        for profile in profiles:
            n = seed_pulse_for_profile(db, profile.id)
            if n:
                logger.info("  ✓ profile %s (%s): +%s pulse/BP readings", profile.id, profile.name, n)
                total += n
            else:
                logger.info("  ⏭  profile %s (%s): BP data already present", profile.id, profile.name)

        db.commit()
        logger.info("\nDone — %s pulse/BP readings added.", total)
    finally:
        db.close()


if __name__ == "__main__":
    main()
