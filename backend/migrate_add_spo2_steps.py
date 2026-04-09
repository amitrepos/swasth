"""
Add SpO2 and Steps columns to health_readings table.
Run: python migrate_add_spo2_steps.py
"""

from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")


def migrate():
    engine = create_engine(DATABASE_URL)

    columns = [
        ("spo2_value", "FLOAT"),
        ("spo2_unit", "VARCHAR(10)"),
        ("spo2_enc", "TEXT"),
        ("steps_count", "INTEGER"),
        ("steps_goal", "INTEGER"),
    ]

    with engine.connect() as conn:
        for col_name, col_type in columns:
            # Check if column already exists
            exists = conn.execute(text("""
                SELECT EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name = 'health_readings' AND column_name = :col
                )
            """), {"col": col_name}).scalar()

            if not exists:
                print(f"Adding column {col_name} ({col_type})...")
                conn.execute(text(
                    f"ALTER TABLE health_readings ADD COLUMN {col_name} {col_type}"
                ))
            else:
                print(f"Column {col_name} already exists, skipping.")

        conn.commit()
    print("Migration complete.")


if __name__ == "__main__":
    migrate()
