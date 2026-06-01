"""
Add `medications` table — patient-logged medication intake (NUO-127).
Surfaced to doctor in patient summary + WhatsApp report.

Run: python migrate_add_medications.py
"""

import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")


def migrate():
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL not set in environment / .env")

    engine = create_engine(DATABASE_URL)
    is_sqlite = DATABASE_URL.startswith("sqlite")

    # SQLAlchemy `Base.metadata.create_all` already handles fresh DBs in
    # main.py's startup. This script is for existing prod DBs that need
    # the new table without restarting under create_all semantics.
    if is_sqlite:
        ddl = """
        CREATE TABLE IF NOT EXISTS medications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
            logged_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
            name_enc TEXT NOT NULL,
            dose_enc TEXT,
            frequency_enc TEXT,
            notes_enc TEXT,
            taken_at TIMESTAMP NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
        idx = "CREATE INDEX IF NOT EXISTS ix_medications_profile_time ON medications(profile_id, taken_at);"
    else:
        ddl = """
        CREATE TABLE IF NOT EXISTS medications (
            id SERIAL PRIMARY KEY,
            profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
            logged_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
            name_enc TEXT NOT NULL,
            dose_enc TEXT,
            frequency_enc TEXT,
            notes_enc TEXT,
            taken_at TIMESTAMP WITH TIME ZONE NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        """
        idx = "CREATE INDEX IF NOT EXISTS ix_medications_profile_time ON medications(profile_id, taken_at);"

    with engine.begin() as conn:
        conn.execute(text(ddl))
        conn.execute(text(idx))
    print("✅ medications table ensured.")


if __name__ == "__main__":
    migrate()
