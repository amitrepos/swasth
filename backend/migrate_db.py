"""
Database Migration Script - Add Missing Columns

This script adds missing columns to existing tables.
Run this if you're getting 'column does not exist' errors.

Usage: python migrate_db.py
"""

from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

def migrate_database():
    """Add missing columns to existing tables."""
    print("Starting database migration...")
    
    engine = create_engine(DATABASE_URL)
    
    with engine.connect() as conn:
        # Check and add is_active column to users table
        print("Checking users table...")
        
        # Check if column exists
        result = conn.execute(text("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'users' 
                AND column_name = 'is_active'
            )
        """)).scalar()
        
        if not result:
            print("Adding is_active column to users table...")
            conn.execute(text("""
                ALTER TABLE users 
                ADD COLUMN is_active BOOLEAN DEFAULT TRUE
            """))
            conn.commit()
            print("✓ Added is_active column")
            
            # Set is_active = TRUE for all existing users
            print("Setting is_active = TRUE for all existing users...")
            conn.execute(text("""
                UPDATE users SET is_active = TRUE WHERE is_active IS NULL
            """))
            conn.commit()
            print("✓ Updated existing users")
        else:
            print("✓ is_active column already exists")
        
        # Check and add other_medical_condition column
        result = conn.execute(text("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'users' 
                AND column_name = 'other_medical_condition'
            )
        """)).scalar()
        
        if not result:
            print("Adding other_medical_condition column to users table...")
            conn.execute(text("""
                ALTER TABLE users 
                ADD COLUMN other_medical_condition TEXT
            """))
            conn.commit()
            print("✓ Added other_medical_condition column")
        else:
            print("✓ other_medical_condition column already exists")
    
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
