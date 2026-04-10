"""Phase 4 — doctor-side accept flow.

Adds the lifecycle-state columns to doctor_patient_links and backfills
any pre-existing rows as status='active' so already-linked doctors on
dev don't lose access when Phase 4 ships.

New columns:
  - status                    VARCHAR NOT NULL DEFAULT 'active'
  - revoke_reason             VARCHAR
  - accepted_at               TIMESTAMPTZ
  - accepted_by_doctor_id     INTEGER (FK users.id, ON DELETE SET NULL)
  - examined_on               DATE
  - examined_for_condition    VARCHAR

Backfill rule:
  - rows where is_active = TRUE           → status = 'active'
  - rows where is_active = FALSE          → status = 'revoked'

After this migration, new links created by POST /api/doctor/link/{id}
will default to status='pending_doctor_accept' per the application
layer (not the DB default).

Run: python migrate_add_doctor_link_states.py
"""
from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")


def _column_exists(conn, table: str, column: str) -> bool:
    row = conn.execute(
        text(
            """
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = :table AND column_name = :column
            )
            """
        ),
        {"table": table, "column": column},
    ).scalar()
    return bool(row)


def migrate():
    if not DATABASE_URL:
        raise SystemExit("DATABASE_URL is not set — refusing to run.")

    engine = create_engine(DATABASE_URL)
    adds = [
        ("status", "VARCHAR NOT NULL DEFAULT 'active'"),
        ("revoke_reason", "VARCHAR"),
        ("accepted_at", "TIMESTAMPTZ"),
        ("accepted_by_doctor_id", "INTEGER REFERENCES users(id) ON DELETE SET NULL"),
        ("examined_on", "DATE"),
        ("examined_for_condition", "VARCHAR"),
    ]

    with engine.begin() as conn:
        for col_name, col_type in adds:
            if _column_exists(conn, "doctor_patient_links", col_name):
                print(f"  · {col_name:25} already exists — skipping")
                continue
            conn.execute(
                text(
                    f"ALTER TABLE doctor_patient_links ADD COLUMN {col_name} {col_type}"
                )
            )
            print(f"  + {col_name:25} added")

        # Backfill: pre-existing rows with is_active=False should be
        # treated as already-revoked, not as new pending requests.
        result = conn.execute(
            text(
                """
                UPDATE doctor_patient_links
                   SET status = 'revoked'
                 WHERE is_active = FALSE AND status = 'active'
                """
            )
        )
        print(f"  · backfilled {result.rowcount} inactive rows as status='revoked'")

    print("Migration complete.")


if __name__ == "__main__":
    migrate()
