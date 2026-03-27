"""
Add health_readings table to database
Run this after adding the HealthReading model
"""

from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

def migrate_database():
    """Create health_readings table"""
    print("Creating health_readings table...")
    
    engine = create_engine(DATABASE_URL)
    
    with engine.connect() as conn:
        # Check if table exists
        result = conn.execute(text("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.tables 
                WHERE table_name = 'health_readings'
            )
        """)).scalar()
        
        if not result:
            print("Creating health_readings table...")
            conn.execute(text("""
                CREATE TABLE health_readings (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    reading_type VARCHAR(50) NOT NULL,
                    glucose_value FLOAT,
                    glucose_unit VARCHAR(20),
                    sample_type VARCHAR(100),
                    systolic FLOAT,
                    diastolic FLOAT,
                    mean_arterial_pressure FLOAT,
                    pulse_rate FLOAT,
                    bp_unit VARCHAR(20),
                    bp_status VARCHAR(50),
                    value_numeric FLOAT NOT NULL,
                    unit_display VARCHAR(20) NOT NULL,
                    status_flag VARCHAR(50),
                    notes TEXT,
                    reading_timestamp TIMESTAMP NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP
                )
            """))
            
            # Create index on user_id and reading_timestamp for faster queries
            conn.execute(text("""
                CREATE INDEX idx_readings_user_id ON health_readings(user_id)
            """))
            conn.execute(text("""
                CREATE INDEX idx_readings_timestamp ON health_readings(reading_timestamp DESC)
            """))
            conn.execute(text("""
                CREATE INDEX idx_readings_type ON health_readings(reading_type)
            """))
            
            conn.commit()
            print("✓ Created health_readings table with indexes")
        else:
            print("✓ health_readings table already exists")
    
    print("\n✅ Database migration completed successfully!")
    print("You can now restart the backend server.")

if __name__ == "__main__":
    try:
        migrate_database()
    except Exception as e:
        print(f"\n✗ Error during migration: {e}")
        print("\nPlease check:")
        print("1. PostgreSQL is running")
        print("2. Database exists")
        print("3. DATABASE_URL in .env is correct")
