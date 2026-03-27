"""
Migration: migrate_to_profiles.py

One-time migration from the old single-user model to the multi-profile model.

What it does:
  1. Creates the new tables (profiles, profile_access, profile_invites) if they don't exist.
  2. For each existing User: creates a Profile from their health columns, then creates
     a ProfileAccess(owner) row linking them.
  3. For each existing HealthReading: sets profile_id from the user's auto-created profile
     and sets logged_by = user_id (preserving who logged it).
  4. Drops the health columns from the users table (age, gender, height, weight,
     blood_group, medical_conditions, other_medical_condition, current_medications).
  5. Drops the old user_id column from health_readings (renamed to logged_by in model).

Run once on dev DB, then once on prod before launch.
Safe to re-run: steps are guarded by existence checks.

Usage:
  cd backend
  source venv/bin/activate
  python migrate_to_profiles.py
"""

import sys
from datetime import datetime, timezone
from sqlalchemy import text, inspect
from database import engine, SessionLocal
import models


def column_exists(conn, table: str, column: str) -> bool:
    result = conn.execute(
        text(
            "SELECT COUNT(*) FROM information_schema.columns "
            "WHERE table_name = :t AND column_name = :c"
        ),
        {"t": table, "c": column},
    )
    return result.scalar() > 0


def table_exists(conn, table: str) -> bool:
    result = conn.execute(
        text(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_name = :t"
        ),
        {"t": table},
    )
    return result.scalar() > 0


def run():
    # Step 1: Create new tables
    print("Step 1: Creating new tables (profiles, profile_access, profile_invites)...")
    models.Base.metadata.create_all(bind=engine)
    print("  Done.")

    db = SessionLocal()
    try:
        with engine.begin() as conn:
            # Step 2: Migrate each user → Profile + ProfileAccess
            print("Step 2: Migrating users to profiles...")

            if not column_exists(conn, "users", "age"):
                print("  Skipping — health columns already removed from users table.")
            else:
                users = conn.execute(text("SELECT * FROM users")).mappings().all()
                print(f"  Found {len(users)} user(s).")

                for user in users:
                    # Check if a profile already exists for this user (idempotency)
                    existing = conn.execute(
                        text(
                            "SELECT pa.profile_id FROM profile_access pa "
                            "WHERE pa.user_id = :uid AND pa.access_level = 'owner'"
                        ),
                        {"uid": user["id"]},
                    ).fetchone()

                    if existing:
                        print(f"  User {user['id']} already has an owner profile — skipping.")
                        continue

                    # Create Profile
                    result = conn.execute(
                        text(
                            "INSERT INTO profiles "
                            "(name, age, gender, height, blood_group, "
                            " medical_conditions, other_medical_condition, current_medications, "
                            " created_at, updated_at) "
                            "VALUES (:name, :age, :gender, :height, :blood_group, "
                            "        :medical_conditions, :other_medical_condition, :current_medications, "
                            "        NOW(), NOW()) "
                            "RETURNING id"
                        ),
                        {
                            "name": "My Health",
                            "age": user.get("age"),
                            "gender": user.get("gender"),
                            "height": user.get("height"),
                            "blood_group": user.get("blood_group"),
                            "medical_conditions": user.get("medical_conditions"),
                            "other_medical_condition": user.get("other_medical_condition"),
                            "current_medications": user.get("current_medications"),
                        },
                    )
                    profile_id = result.scalar()

                    # Create ProfileAccess (owner)
                    conn.execute(
                        text(
                            "INSERT INTO profile_access (user_id, profile_id, access_level, created_at) "
                            "VALUES (:uid, :pid, 'owner', NOW())"
                        ),
                        {"uid": user["id"], "pid": profile_id},
                    )
                    print(f"  User {user['id']} ({user['email']}) → Profile {profile_id}")

            # Step 3: Migrate health_readings — add profile_id + logged_by
            print("Step 3: Migrating health_readings...")

            # Add profile_id column if missing
            if not column_exists(conn, "health_readings", "profile_id"):
                conn.execute(
                    text("ALTER TABLE health_readings ADD COLUMN profile_id INTEGER")
                )
                print("  Added profile_id column.")

            # Add logged_by column if missing (renamed from user_id)
            if not column_exists(conn, "health_readings", "logged_by"):
                if column_exists(conn, "health_readings", "user_id"):
                    conn.execute(
                        text("ALTER TABLE health_readings RENAME COLUMN user_id TO logged_by")
                    )
                    print("  Renamed user_id → logged_by.")
                else:
                    conn.execute(
                        text("ALTER TABLE health_readings ADD COLUMN logged_by INTEGER")
                    )
                    print("  Added logged_by column.")

            # Populate profile_id from the owner's profile
            conn.execute(
                text(
                    "UPDATE health_readings hr "
                    "SET profile_id = pa.profile_id "
                    "FROM profile_access pa "
                    "WHERE pa.user_id = hr.logged_by "
                    "  AND pa.access_level = 'owner' "
                    "  AND hr.profile_id IS NULL"
                )
            )
            print("  Populated profile_id on health_readings.")

            # Step 4: Drop health columns from users
            print("Step 4: Dropping health columns from users table...")
            health_cols = [
                "age", "gender", "height", "weight",
                "blood_group", "medical_conditions",
                "other_medical_condition", "current_medications",
            ]
            for col in health_cols:
                if column_exists(conn, "users", col):
                    conn.execute(text(f"ALTER TABLE users DROP COLUMN {col}"))
                    print(f"  Dropped users.{col}")
                else:
                    print(f"  users.{col} already gone — skipping.")

        print("\nMigration complete.")

    except Exception as e:
        print(f"\nMigration FAILED: {e}", file=sys.stderr)
        raise
    finally:
        db.close()


if __name__ == "__main__":
    run()
