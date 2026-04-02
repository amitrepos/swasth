#!/usr/bin/env python3
"""
Migration: Add timezone column to users table
Usage: python migrate_add_timezone.py
"""

from database import engine
from sqlalchemy import text

def add_timezone_column():
    """Add timezone column to users table with default value."""
    with engine.connect() as connection:
        # Check if column already exists
        result = connection.execute(
            text("""
                SELECT EXISTS(
                    SELECT 1 FROM information_schema.columns 
                    WHERE table_name = 'users' AND column_name = 'timezone'
                )
            """)
        )
        column_exists = result.scalar()
        
        if column_exists:
            print("✓ Column 'timezone' already exists in users table")
            return
        
        # Add timezone column
        connection.execute(
            text("""
                ALTER TABLE users 
                ADD COLUMN timezone VARCHAR DEFAULT 'Asia/Kolkata' NOT NULL
            """)
        )
        connection.commit()
        print("✓ Added 'timezone' column to users table")
        
        # Verify
        result = connection.execute(
            text("SELECT COUNT(*) FROM users WHERE timezone IS NULL")
        )
        null_count = result.scalar()
        print(f"✓ Users with timezone set: {null_count == 0}")

if __name__ == "__main__":
    try:
        add_timezone_column()
        print("\n✅ Migration completed successfully!")
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        raise
