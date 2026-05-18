"""
Migration: migrate_multilingual_json.py

DEPRECATED — superseded by Alembic revision 0011_meal_logs_tips_json.py.

This standalone script was used as a one-shot to add `meal_logs.tips_json`
and `health_readings.meal_context` on the prod box before Alembic
revision 0011 existed. It is retained because the user explicitly asked
for it ("i have use that migration to create col on prod") — but new
environments MUST use `alembic upgrade head` instead.

Behavior change from the original:
  - Now ALSO ports data from tip_en / tip_hi / tip_kn into tips_json
    before dropping the legacy columns. The original version explicitly
    skipped the port and left data stranded.
  - Idempotent: safe to re-run on a partially-migrated DB.

If you are setting up a new dev environment, do NOT run this script.
Run `alembic upgrade head` from `backend/` instead.
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
        # 1. Add meal_context to health_readings (Alembic 0010 equivalent).
        if not column_exists(conn, "health_readings", "meal_context"):
            conn.execute(text("ALTER TABLE health_readings ADD COLUMN meal_context VARCHAR(20) NULL"))
            print("Added health_readings.meal_context")
        else:
            print("health_readings.meal_context already exists — skipping")

        # 2. Add tips_json to meal_logs (Alembic 0011 equivalent).
        if not column_exists(conn, "meal_logs", "tips_json"):
            conn.execute(text("ALTER TABLE meal_logs ADD COLUMN tips_json JSONB NULL"))
            print("Added meal_logs.tips_json")
        else:
            print("meal_logs.tips_json already exists — skipping")

        # 3. Port data from tip_en / tip_hi / tip_kn into tips_json.
        # jsonb_strip_nulls drops keys whose value is NULL so downstream
        # consumers can key-test for "did this language have a tip?".
        # Only update rows that haven't been ported yet (tips_json IS NULL)
        # so re-runs are idempotent.
        legacy_cols_present = [
            c for c in ("tip_en", "tip_hi", "tip_kn")
            if column_exists(conn, "meal_logs", c)
        ]
        if legacy_cols_present:
            select_clause = ", ".join(
                f"'{c.split('_')[1]}', {c}" for c in legacy_cols_present
            )
            where_clause = " OR ".join(
                f"{c} IS NOT NULL" for c in legacy_cols_present
            )
            ported = conn.execute(text(
                f"""
                UPDATE meal_logs
                SET tips_json = jsonb_strip_nulls(jsonb_build_object({select_clause}))
                WHERE tips_json IS NULL AND ({where_clause});
                """
            ))
            print(f"Ported {ported.rowcount} legacy tip rows into tips_json")

            # 4. Drop legacy columns now that data is preserved.
            for col in legacy_cols_present:
                conn.execute(text(f"ALTER TABLE meal_logs DROP COLUMN {col}"))
                print(f"Dropped meal_logs.{col}")
        else:
            print("No legacy tip_* columns present — nothing to port")

    print("Migration complete.")


if __name__ == "__main__":
    migrate()
