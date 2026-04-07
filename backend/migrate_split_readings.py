"""
Migration: Create separate glucose_readings and bp_readings tables

This migration creates new tables with proper sequence number support.
Since health_readings has already been dropped, this just creates the new structure.
"""

from sqlalchemy import create_engine, text
from config import settings
import sys

def migrate():
    """Create the new glucose_readings and bp_readings tables."""
    
    print("Starting migration: Create glucose_readings and bp_readings tables...")
    
    try:
        engine = create_engine(settings.DATABASE_URL)
        
        with engine.connect() as conn:
            # Start transaction
            trans = conn.begin()
            
            try:
                # 1. Create glucose_readings table
                print("Creating glucose_readings table...")
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS glucose_readings (
                        id SERIAL PRIMARY KEY,
                        profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
                        logged_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
                        
                        -- Glucose specific fields
                        sequence_number INTEGER NOT NULL,
                        glucose_value FLOAT NOT NULL,
                        glucose_unit VARCHAR(20) DEFAULT 'mg/dL',
                        sample_type VARCHAR(50),
                        sample_location VARCHAR(50),
                        
                        -- Common fields
                        status_flag VARCHAR(20),
                        notes TEXT,
                        
                        -- Encrypted fields
                        glucose_value_enc TEXT,
                        notes_enc TEXT,
                        
                        reading_timestamp TIMESTAMP NOT NULL,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        updated_at TIMESTAMP WITH TIME ZONE,
                        
                        -- Indexes
                        CONSTRAINT unique_profile_sequence UNIQUE (profile_id, sequence_number)
                    );
                    
                    CREATE INDEX IF NOT EXISTS idx_glucose_profile_time 
                    ON glucose_readings(profile_id, reading_timestamp);
                    
                    CREATE INDEX IF NOT EXISTS idx_glucose_sequence 
                    ON glucose_readings(profile_id, sequence_number);
                """))
                print("✓ glucose_readings table created")
                
                # 2. Create bp_readings table
                print("Creating bp_readings table...")
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS bp_readings (
                        id SERIAL PRIMARY KEY,
                        profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
                        logged_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
                        
                        -- BP specific fields
                        sequence_number INTEGER NOT NULL,
                        slot_number INTEGER NOT NULL,
                        systolic FLOAT NOT NULL,
                        diastolic FLOAT NOT NULL,
                        mean_arterial_pressure FLOAT,
                        pulse_rate FLOAT,
                        bp_unit VARCHAR(20) DEFAULT 'mmHg',
                        bp_status VARCHAR(50),
                        user_number INTEGER DEFAULT 1,
                        
                        -- Flags
                        irregular_heartbeat BOOLEAN DEFAULT FALSE,
                        body_movement BOOLEAN DEFAULT FALSE,
                        morning_reading BOOLEAN DEFAULT FALSE,
                        
                        -- Common fields
                        status_flag VARCHAR(20),
                        notes TEXT,
                        
                        -- Encrypted fields
                        systolic_enc TEXT,
                        diastolic_enc TEXT,
                        pulse_rate_enc TEXT,
                        notes_enc TEXT,
                        
                        reading_timestamp TIMESTAMP NOT NULL,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        updated_at TIMESTAMP WITH TIME ZONE,
                        
                        -- Indexes
                        CONSTRAINT unique_profile_seq_slot UNIQUE (profile_id, sequence_number, slot_number)
                    );
                    
                    CREATE INDEX IF NOT EXISTS idx_bp_profile_time 
                    ON bp_readings(profile_id, reading_timestamp);
                    
                    CREATE INDEX IF NOT EXISTS idx_bp_sequence 
                    ON bp_readings(profile_id, sequence_number, slot_number);
                """))
                print("✓ bp_readings table created")
                
                # Commit transaction
                trans.commit()
                print("\n✅ Migration completed successfully!")
                print("\nNew tables created:")
                print("  - glucose_readings (with sequence_number)")
                print("  - bp_readings (with sequence_number and slot_number)")
                print("\nBoth tables are ready to store new readings!")
                
            except Exception as e:
                trans.rollback()
                print(f"\n❌ Migration failed: {e}", file=sys.stderr)
                raise
                
    except Exception as e:
        print(f"\n❌ Database connection error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    migrate()
