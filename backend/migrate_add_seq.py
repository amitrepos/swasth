"""
Add seq (sequence number) column to health_readings table.
This prevents duplicate BLE readings by using device sequence numbers.
Higher seq = newer reading. If seq exists in DB, skip storing.
"""

from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

def migrate_database():
    """Add seq column to health_readings table"""
    print("Adding seq column to health_readings table...")
    
    engine = create_engine(DATABASE_URL)
    
    with engine.connect() as conn:
        # Check if column already exists
        result = conn.execute(text("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'health_readings' AND column_name = 'seq'
            )
        """)).scalar()
        
        if result:
            print("✓ seq column already exists")
            return
        
        print("Adding seq column...")
        conn.execute(text("""
            ALTER TABLE health_readings 
            ADD COLUMN seq INTEGER
        """))
        
        # Add index for faster duplicate checks
        print("Adding index on seq...")
        conn.execute(text("""
            CREATE INDEX idx_readings_seq ON health_readings(seq)
            WHERE seq IS NOT NULL
        """))
        
        conn.commit()
        print("✓ Migration completed successfully")
        print("  - Added seq column (INTEGER, nullable)")
        print("  - Added partial index on seq for performance")

if __name__ == "__main__":
    migrate_database()
