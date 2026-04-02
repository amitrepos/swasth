"""
Migration: migrate_add_invite_access_level.py

Fixes DB schema drift where the ORM expects profile_invites.access_level
but the existing Postgres table was created before this column existed.

Safe to re-run: guarded by information_schema checks.

Usage:
  cd backend
  python migrate_add_invite_access_level.py
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


def run():
    with engine.begin() as conn:
        if column_exists(conn, "profile_invites", "access_level"):
            print("profile_invites.access_level already exists — nothing to do.")
            return

        print("Adding profile_invites.access_level ...")
        conn.execute(
            text(
                "ALTER TABLE profile_invites "
                "ADD COLUMN access_level VARCHAR NOT NULL DEFAULT 'viewer'"
            )
        )
        print("Done.")


if __name__ == "__main__":
    try:
        run()
    except Exception as e:
        print(f"Migration FAILED: {e}", file=sys.stderr)
        raise

