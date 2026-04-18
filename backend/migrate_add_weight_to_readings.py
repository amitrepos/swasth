"""
Migration: migrate_add_weight_to_readings.py

1. Adds weight columns to health_readings table:
   - weight_value (FLOAT NULL)
   - weight_unit (VARCHAR NULL)
   - weight_value_enc (TEXT NULL)
2. Data Migration:
   - Copies existing profiles.weight to health_readings table as the first entry for each profile.
   - Encrypts the weight value for the encrypted column.

Usage:
  cd backend
  python migrate_add_weight_to_readings.py
"""

import sys
from sqlalchemy import text
from database import engine, SessionLocal
import models
from encryption_service import encrypt_float
from datetime import datetime

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
    print("Starting migration: health_readings weight columns...")
    
    with engine.begin() as conn:
        # 1. Add columns if they don't exist
        if not column_exists(conn, "health_readings", "weight_value"):
            conn.execute(text("ALTER TABLE health_readings ADD COLUMN weight_value FLOAT NULL"))
            print("Added health_readings.weight_value")
        
        if not column_exists(conn, "health_readings", "weight_unit"):
            conn.execute(text("ALTER TABLE health_readings ADD COLUMN weight_unit VARCHAR NULL"))
            print("Added health_readings.weight_unit")
            
        if not column_exists(conn, "health_readings", "weight_value_enc"):
            conn.execute(text("ALTER TABLE health_readings ADD COLUMN weight_value_enc TEXT NULL"))
            print("Added health_readings.weight_value_enc")

    # 2. Data Migration: Profile weight -> HealthReading
    print("Starting data migration: Profile weight to health_readings...")
    db = SessionLocal()
    try:
        profiles = db.query(models.Profile).all()
        migrated_count = 0
        
        for profile in profiles:
            if profile.weight is not None:
                # Check if we already have a weight reading for this profile
                # (to avoid duplicate migration if run twice)
                existing = db.query(models.HealthReading).filter(
                    models.HealthReading.profile_id == profile.id,
                    models.HealthReading.reading_type == "weight"
                ).first()
                
                if not existing:
                    # Create the first weight reading
                    reading = models.HealthReading(
                        profile_id=profile.id,
                        logged_by=None, # System migration
                        reading_type="weight",
                        weight_value=profile.weight,
                        weight_unit="kg",
                        value_numeric=profile.weight,
                        unit_display="kg",
                        reading_timestamp=profile.created_at or datetime.now(),
                        weight_value_enc=encrypt_float(profile.weight)
                    )
                    db.add(reading)
                    migrated_count += 1
        
        db.commit()
        print(f"Data migration complete. Created {migrated_count} weight readings.")
        
    except Exception as e:
        print(f"Error during data migration: {e}")
        db.rollback()
    finally:
        db.close()

    print("Migration complete.")

if __name__ == "__main__":
    migrate()
