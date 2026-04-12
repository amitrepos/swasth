#!/usr/bin/env python3
"""
Migration: Add email verification columns to users table and create
email_verification_otps table.

Usage: python migrate_add_email_verification.py
"""

from database import engine
from sqlalchemy import text


def migrate():
    """Add email verification support to the database."""
    with engine.connect() as connection:
        # 1. Add email_verified column to users
        result = connection.execute(
            text("""
                SELECT EXISTS(
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name = 'users' AND column_name = 'email_verified'
                )
            """)
        )
        if result.scalar():
            print("  Column 'email_verified' already exists in users table")
        else:
            connection.execute(
                text("""
                    ALTER TABLE users
                    ADD COLUMN email_verified BOOLEAN DEFAULT FALSE
                """)
            )
            print("  Added 'email_verified' column to users table")

        # 2. Add email_verified_at column to users
        result = connection.execute(
            text("""
                SELECT EXISTS(
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name = 'users' AND column_name = 'email_verified_at'
                )
            """)
        )
        if result.scalar():
            print("  Column 'email_verified_at' already exists in users table")
        else:
            connection.execute(
                text("""
                    ALTER TABLE users
                    ADD COLUMN email_verified_at TIMESTAMPTZ
                """)
            )
            print("  Added 'email_verified_at' column to users table")

        # 3. Create email_verification_otps table
        result = connection.execute(
            text("""
                SELECT EXISTS(
                    SELECT 1 FROM information_schema.tables
                    WHERE table_name = 'email_verification_otps'
                )
            """)
        )
        if result.scalar():
            print("  Table 'email_verification_otps' already exists")
        else:
            connection.execute(
                text("""
                    CREATE TABLE email_verification_otps (
                        id SERIAL PRIMARY KEY,
                        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        email VARCHAR NOT NULL,
                        otp VARCHAR NOT NULL,
                        created_at TIMESTAMPTZ DEFAULT NOW(),
                        expires_at TIMESTAMP NOT NULL,
                        is_used BOOLEAN DEFAULT FALSE
                    )
                """)
            )
            connection.execute(
                text("CREATE INDEX ix_email_verification_otps_id ON email_verification_otps (id)")
            )
            print("  Created 'email_verification_otps' table")

        connection.commit()


if __name__ == "__main__":
    try:
        migrate()
        print("\nMigration completed successfully!")
    except Exception as e:
        print(f"Migration failed: {e}")
        raise
