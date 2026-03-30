"""One-shot migration: populate _enc columns for existing HealthReading rows.

Run once after adding the encrypted columns to the database:
    python migrate_encrypt_readings.py

Requires ENCRYPTION_KEY to be set in .env.
"""

import sys
from dotenv import load_dotenv

load_dotenv()

from database import SessionLocal
import models
from encryption_service import encrypt, encrypt_float
from config import settings


def main():
    if not settings.ENCRYPTION_KEY:
        print("ERROR: ENCRYPTION_KEY not set in .env — cannot encrypt.")
        print("Generate one with: python -c \"import secrets; print(secrets.token_hex(32))\"")
        sys.exit(1)

    db = SessionLocal()
    try:
        readings = db.query(models.HealthReading).filter(
            models.HealthReading.glucose_value_enc.is_(None),
        ).all()

        total = len(readings)
        if total == 0:
            print("No unencrypted readings found. Nothing to do.")
            return

        print(f"Encrypting {total} readings...")
        for i, r in enumerate(readings, 1):
            if r.glucose_value is not None:
                r.glucose_value_enc = encrypt_float(r.glucose_value)
            if r.systolic is not None:
                r.systolic_enc = encrypt_float(r.systolic)
            if r.diastolic is not None:
                r.diastolic_enc = encrypt_float(r.diastolic)
            if r.pulse_rate is not None:
                r.pulse_rate_enc = encrypt_float(r.pulse_rate)
            if r.notes is not None:
                r.notes_enc = encrypt(r.notes)

            if i % 500 == 0:
                db.commit()
                print(f"  {i}/{total} done")

        db.commit()
        print(f"Done — {total} readings encrypted.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
