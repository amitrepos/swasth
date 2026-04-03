"""
Migration: migrate_add_weight.py

Adds weight column to profiles table for BMI calculation.
  - profiles.weight (FLOAT NULL) — kg

Safe to re-run: guarded by information_schema check.

Usage:
  cd backend
  python migrate_add_weight.py
"""

import sys
from sqlalchemy import text
from database import engine


def column_exists(conn, table: str, column: str) -> bool:
    result = conn.execute(
        text(
            "SELECT COUNT(*) FROM information_schema.columns "
            "WHERE table_name = :t AND column_name = :c"
        ),
        {"t": table, "c": column},
    )
    return result.scalar() > 0


def migrate():
    with engine.begin() as conn:
        if not column_exists(conn, "profiles", "weight"):
            conn.execute(text("ALTER TABLE profiles ADD COLUMN weight FLOAT NULL"))
            print("Added profiles.weight")
        else:
            print("profiles.weight already exists — skipping")

    print("Migration complete.")


if __name__ == "__main__":
    migrate()
