"""
Migration: Convert consent/login timestamps from TIMESTAMPTZ to TIMESTAMP WITHOUT TIME ZONE.

The AUDIT.md (2026-04-02) documents the design intent:
  "All user-facing timestamps (consent, login, updates) now correctly stored
   in user's local timezone."

The problem: DateTime(timezone=True) maps to PostgreSQL TIMESTAMPTZ, which ALWAYS
normalizes any inserted value to UTC — regardless of the offset you pass in.

The fix: DateTime(timezone=False) maps to TIMESTAMP (no timezone), which stores
the value exactly as provided. Since routes.py already converts UTC → user_tz
before inserting, the local time will be stored as-is.

Existing records are re-projected using each user's stored timezone so no data is lost.

Usage: python migrate_timestamps_to_local.py
"""

from database import engine
from sqlalchemy import text


def run():
    with engine.connect() as conn:
        print("Altering consent_timestamp, ai_consent_timestamp, last_login_at ...")
        print("  TIMESTAMPTZ → TIMESTAMP (without time zone)")
        print("  Existing records will be re-projected to local time using each user's timezone.\n")

        conn.execute(text("""
            ALTER TABLE users
                ALTER COLUMN consent_timestamp TYPE TIMESTAMP WITHOUT TIME ZONE
                    USING (consent_timestamp AT TIME ZONE timezone),
                ALTER COLUMN ai_consent_timestamp TYPE TIMESTAMP WITHOUT TIME ZONE
                    USING (ai_consent_timestamp AT TIME ZONE timezone),
                ALTER COLUMN last_login_at TYPE TIMESTAMP WITHOUT TIME ZONE
                    USING (last_login_at AT TIME ZONE timezone);
        """))
        conn.commit()
        print("Migration complete!\n")

        # Verify
        result = conn.execute(text(
            "SELECT full_name, timezone, consent_timestamp, ai_consent_timestamp, last_login_at "
            "FROM users ORDER BY id LIMIT 10"
        ))
        print("Sample rows after migration:")
        print(f"  {'Name':<15} {'Timezone':<20} {'Consent timestamp':<30} {'Last login'}")
        print("  " + "-" * 90)
        for row in result:
            consent = str(row.consent_timestamp) if row.consent_timestamp else "NULL"
            login   = str(row.last_login_at)     if row.last_login_at     else "NULL"
            print(f"  {row.full_name:<15} {row.timezone:<20} {consent:<30} {login}")
        print("\nDone. Local times should now be visible without +00 offset.")


if __name__ == "__main__":
    run()
