"""0008 — Convert naive TIMESTAMP columns to TIMESTAMPTZ

Revision ID: 0008
Revises: 0007
Create Date: 2026-04-25

Four columns were defined as plain TIMESTAMP (no timezone) while the rest of
the schema uses TIMESTAMPTZ. This migration converts them. Existing values are
assumed to be UTC (they were written by datetime.utcnow() / datetime.now(UTC)),
so the USING clause reinterprets them as UTC with no data loss.

Columns fixed:
  - health_readings.reading_timestamp
  - password_reset_otps.expires_at
  - email_verification_otps.expires_at
  - phone_otps.expires_at
"""

from alembic import op
import sqlalchemy as sa


revision = '0008'
down_revision = '0007'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        ALTER TABLE health_readings
            ALTER COLUMN reading_timestamp TYPE TIMESTAMPTZ
            USING reading_timestamp AT TIME ZONE 'UTC'
    """)
    op.execute("""
        ALTER TABLE password_reset_otps
            ALTER COLUMN expires_at TYPE TIMESTAMPTZ
            USING expires_at AT TIME ZONE 'UTC'
    """)
    op.execute("""
        ALTER TABLE email_verification_otps
            ALTER COLUMN expires_at TYPE TIMESTAMPTZ
            USING expires_at AT TIME ZONE 'UTC'
    """)
    op.execute("""
        ALTER TABLE phone_otps
            ALTER COLUMN expires_at TYPE TIMESTAMPTZ
            USING expires_at AT TIME ZONE 'UTC'
    """)


def downgrade():
    op.execute("""
        ALTER TABLE health_readings
            ALTER COLUMN reading_timestamp TYPE TIMESTAMP
            USING reading_timestamp AT TIME ZONE 'UTC'
    """)
    op.execute("""
        ALTER TABLE password_reset_otps
            ALTER COLUMN expires_at TYPE TIMESTAMP
            USING expires_at AT TIME ZONE 'UTC'
    """)
    op.execute("""
        ALTER TABLE email_verification_otps
            ALTER COLUMN expires_at TYPE TIMESTAMP
            USING expires_at AT TIME ZONE 'UTC'
    """)
    op.execute("""
        ALTER TABLE phone_otps
            ALTER COLUMN expires_at TYPE TIMESTAMP
            USING expires_at AT TIME ZONE 'UTC'
    """)
