#!/usr/bin/env python3
"""
Swasth test-data seeder — deterministic, idempotent, env-aware.

Usage:
    python seed_test_users.py --env prod
    python seed_test_users.py --env dev
    python seed_test_users.py --env prod --days 30
    python seed_test_users.py --env prod --dry-run

Environments:
    prod  → /var/www/swasth_prod/backend  (port 8009, swasth_prod DB)
    dev   → /var/www/swasth/backend       (port 8007, swasth_db DB)
    local → current directory             (local dev machine)

Idempotent: safe to re-run; skips existing users/readings.
"""

import argparse
import os
import random
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# ── CLI args ──────────────────────────────────────────────────────────────────

def parse_args():
    parser = argparse.ArgumentParser(description="Seed test users into Swasth DB")
    parser.add_argument(
        "--env", choices=["prod", "staging", "local"], required=True,
        help="Target environment"
    )
    parser.add_argument(
        "--days", type=int, default=90,
        help="Number of days of health readings to generate (default: 90)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print what would be created without writing to DB"
    )
    return parser.parse_args()

ENV_CONFIG = {
    "prod": {
        "backend_path": "/var/www/swasth/backend",
        "venv_python": "/var/www/swasth/venv/bin/python3",
        "db_url_override": None,
        "label": "PROD (swasth_prod DB, port 8007)",
    },
    "staging": {
        "backend_path": "/var/www/swasth/backend",
        "venv_python": "/var/www/swasth/venv/bin/python3",
        "db_url_override": "postgresql://swasth_admin:swasth_temp_change_me@127.0.0.1:5432/swasth_staging",
        "label": "STAGING (swasth_staging DB, port 8008)",
    },
    "local": {
        "backend_path": str(Path(__file__).parent.parent),
        "venv_python": sys.executable,
        "db_url_override": None,
        "label": "LOCAL (dev machine)",
    },
}

# ── Test user definitions ─────────────────────────────────────────────────────
# Each user has all required fields to avoid serialization errors.

TEST_USERS = [
    {
        "email": "ravi.kumar@test.swasth.app",
        "full_name": "Ravi Kumar",
        "phone_number": "+919876540001",
        "password": "Test@1234",
        "profile": {
            "name": "Ravi Kumar",
            "relationship": "myself",
            "gender": "Male",
            "age": "52",
            "height": "168",
            "blood_group": "B+",
        },
        # Hypertensive diabetic — mostly HIGH readings
        "bp": {"systolic": (145, 165), "diastolic": (92, 102)},
        "glucose": (180, 260),
        "weight": (82, 86),
        "trend": "stable",
    },
    {
        "email": "priya.sharma@test.swasth.app",
        "full_name": "Priya Sharma",
        "phone_number": "+919876540002",
        "password": "Test@1234",
        "profile": {
            "name": "Priya Sharma",
            "relationship": "myself",
            "gender": "Female",
            "age": "38",
            "height": "158",
            "blood_group": "O+",
        },
        # Mostly normal, occasional spikes
        "bp": {"systolic": (112, 130), "diastolic": (72, 85)},
        "glucose": (85, 115),
        "weight": (58, 61),
        "trend": "stable",
    },
    {
        "email": "mohan.das@test.swasth.app",
        "full_name": "Mohan Das",
        "phone_number": "+919876540003",
        "password": "Test@1234",
        "profile": {
            "name": "Mohan Das",
            "relationship": "myself",
            "gender": "Male",
            "age": "67",
            "height": "162",
            "blood_group": "A+",
        },
        # Borderline, improving trend over 90 days
        "bp": {"systolic": (130, 148), "diastolic": (82, 94)},
        "glucose": (110, 145),
        "weight": (74, 79),
        "trend": "improving",
    },
]

# ── Health classification helpers ─────────────────────────────────────────────

def bp_status(sys_val, dia_val):
    if sys_val >= 140 or dia_val >= 90: return "High"
    if sys_val >= 130 or dia_val >= 80: return "Elevated"
    if sys_val < 90 or dia_val < 60:   return "Low"
    return "Normal"

def glucose_status(val):
    if val >= 126: return "High"
    if val >= 100: return "Pre-diabetic"
    return "Normal"

# ── Seeder ────────────────────────────────────────────────────────────────────

def seed(args, backend_path, db_url_override=None):
    sys.path.insert(0, backend_path)
    os.chdir(backend_path)

    if db_url_override:
        os.environ["DATABASE_URL"] = db_url_override

    from database import SessionLocal
    from models import User, Profile, ProfileAccess, HealthReading
    from auth import get_password_hash
    from encryption_service import encrypt_float, hash_email, encrypt_pii, hash_phone, normalize_phone

    db = SessionLocal()
    NOW = datetime.now(timezone.utc)
    days = args.days

    for u_def in TEST_USERS:
        email = u_def["email"]
        email_hash = hash_email(email)

        # ── User ──────────────────────────────────────────────────────────────
        existing_user = db.query(User).filter(User.email_hash == email_hash).first()
        if existing_user:
            print(f"  SKIP user (exists): {email} → user_id={existing_user.id}")
            user = existing_user
        else:
            if args.dry_run:
                print(f"  [DRY-RUN] Would create user: {email}")
                continue
            norm_phone = normalize_phone(u_def["phone_number"])
            user = User(
                email=email,
                full_name=u_def["full_name"],
                phone_number_enc=encrypt_pii(norm_phone),
                phone_hash=hash_phone(norm_phone),
                password_hash=get_password_hash(u_def["password"]),
                is_active=True,
                email_verified=True,
                email_verified_at=NOW,
            )
            db.add(user)
            db.flush()
            print(f"  CREATED user: {email} → user_id={user.id}")

        # ── Profile ───────────────────────────────────────────────────────────
        existing_access = db.query(ProfileAccess).filter(
            ProfileAccess.user_id == user.id
        ).first()

        if existing_access:
            profile_id = existing_access.profile_id
            print(f"  SKIP profile (exists): profile_id={profile_id}")
        else:
            if args.dry_run:
                print(f"  [DRY-RUN] Would create profile for {email}")
                continue
            p = u_def["profile"]
            profile = Profile(
                name=p["name"], relationship=p["relationship"],
                gender=p["gender"], age=p["age"],
                height=p["height"], blood_group=p["blood_group"],
                weight=u_def["weight"][0],
            )
            db.add(profile)
            db.flush()
            db.add(ProfileAccess(
                user_id=user.id,
                profile_id=profile.id,
                access_level="owner",
            ))
            db.flush()
            profile_id = profile.id
            print(f"  CREATED profile: profile_id={profile_id}")

        # ── Health readings ───────────────────────────────────────────────────
        for reading_type in ["blood_pressure", "glucose", "weight"]:
            existing_count = db.query(HealthReading).filter(
                HealthReading.profile_id == profile_id,
                HealthReading.reading_type == reading_type,
            ).count()
            if existing_count > 0:
                print(f"  SKIP readings (exists): {reading_type} × {existing_count}")
                continue

            if args.dry_run:
                expected = days if reading_type != "weight" else days // 3
                print(f"  [DRY-RUN] Would create {expected} {reading_type} readings")
                continue

            records = []
            improving = u_def["trend"] == "improving"

            for day in range(days):
                ts = NOW - timedelta(days=days - 1 - day)
                trend_delta = -0.05 * day if improving else 0

                if reading_type == "blood_pressure":
                    s_lo, s_hi = u_def["bp"]["systolic"]
                    d_lo, d_hi = u_def["bp"]["diastolic"]
                    sys_val = round(random.uniform(s_lo, s_hi) + trend_delta, 1)
                    dia_val = round(random.uniform(d_lo, d_hi) + trend_delta * 0.6, 1)
                    pulse   = round(random.uniform(62, 88), 1)
                    map_val = round((sys_val + 2 * dia_val) / 3, 1)
                    status  = bp_status(sys_val, dia_val)
                    records.append(HealthReading(
                        profile_id=profile_id, logged_by=user.id,
                        reading_type="blood_pressure",
                        systolic=sys_val, diastolic=dia_val,
                        mean_arterial_pressure=map_val, pulse_rate=pulse,
                        bp_unit="mmHg", bp_status=status,
                        systolic_enc=encrypt_float(sys_val),
                        diastolic_enc=encrypt_float(dia_val),
                        pulse_rate_enc=encrypt_float(pulse),
                        value_numeric=sys_val, unit_display="mmHg",
                        status_flag=status,
                        reading_timestamp=ts.replace(hour=7, minute=random.randint(0, 30), second=0, microsecond=0),
                    ))

                elif reading_type == "glucose":
                    g_lo, g_hi = u_def["glucose"]
                    g_val   = round(random.uniform(g_lo, g_hi) + trend_delta * 2, 1)
                    g_status = glucose_status(g_val)
                    records.append(HealthReading(
                        profile_id=profile_id, logged_by=user.id,
                        reading_type="glucose",
                        glucose_value=g_val, glucose_unit="mg/dL", sample_type="fasting",
                        glucose_value_enc=encrypt_float(g_val),
                        value_numeric=g_val, unit_display="mg/dL",
                        status_flag=g_status,
                        reading_timestamp=ts.replace(hour=7, minute=random.randint(31, 59), second=0, microsecond=0),
                    ))

                elif reading_type == "weight" and day % 3 == 0:
                    w_lo, w_hi = u_def["weight"]
                    w_val = round(random.uniform(w_lo, w_hi) + trend_delta * 0.1, 1)
                    records.append(HealthReading(
                        profile_id=profile_id, logged_by=user.id,
                        reading_type="weight",
                        weight_value=w_val, weight_unit="kg",
                        weight_value_enc=encrypt_float(w_val),
                        value_numeric=w_val, unit_display="kg",
                        status_flag="Normal",
                        reading_timestamp=ts.replace(hour=8, minute=0, second=0, microsecond=0),
                    ))

            db.bulk_save_objects(records)
            db.commit()
            print(f"  CREATED {len(records)} {reading_type} readings")

    db.close()
    print("\nDone.")

# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    args = parse_args()
    cfg = ENV_CONFIG[args.env]

    print(f"\n{'[DRY-RUN] ' if args.dry_run else ''}Seeding → {cfg['label']}")
    print(f"Days: {args.days} | Users: {len(TEST_USERS)}\n")

    seed(args, cfg["backend_path"], db_url_override=cfg.get("db_url_override"))
