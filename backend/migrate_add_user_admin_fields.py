"""
Migration: migrate_add_user_admin_fields.py

Adds admin-related fields introduced in newer User model versions:
  - users.is_admin (BOOLEAN NOT NULL DEFAULT FALSE)
  - users.last_login_at (TIMESTAMP WITH TIME ZONE NULL)

Safe to re-run: guarded by information_schema checks.

Usage:
  cd backend
  python migrate_add_user_admin_fields.py
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
        if not column_exists(conn, "users", "is_admin"):
            print("Adding users.is_admin ...")
            conn.execute(
                text(
                    "ALTER TABLE users "
                    "ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE"
                )
            )
        else:
            print("users.is_admin already exists.")

        if not column_exists(conn, "users", "last_login_at"):
            print("Adding users.last_login_at ...")
            conn.execute(
                text(
                    "ALTER TABLE users "
                    "ADD COLUMN last_login_at TIMESTAMPTZ NULL"
                )
            )
        else:
            print("users.last_login_at already exists.")

        print("Done.")


if __name__ == "__main__":
    try:
        run()
    except Exception as e:
        print(f"Migration FAILED: {e}", file=sys.stderr)
        raise
