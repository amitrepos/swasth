"""
Database Initialization Script for Swasth Health App

This script creates the database and tables.
Run this once before starting the backend server.

Usage: python init_db.py
"""

from database import engine, Base
import models

def init_database():
    """Initialize the database by creating all tables."""
    print("Creating database tables...")
    
    # Create all tables defined in models.py
    Base.metadata.create_all(bind=engine)
    
    print("✓ Database tables created successfully!")
    print("\nTables created:")
    print("- users")
    print("\nYou can now start the backend server with: python main.py")

if __name__ == "__main__":
    try:
        init_database()
    except Exception as e:
        print(f"\n✗ Error initializing database: {e}")
        print("\nPlease ensure:")
        print("1. PostgreSQL is installed and running")
        print("2. Database 'swasth_db' exists")
        print("3. DATABASE_URL in .env file is correct")
