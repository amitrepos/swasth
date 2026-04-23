"""add profile phone number

Revision ID: 0005
Revises: 0004
Create Date: 2026-04-23 11:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0005'
down_revision = '0004'
branch_labels = None
depends_on = None


def upgrade():
    # 1. Add column as nullable initially
    op.add_column('profiles', sa.Column('phone_number', sa.String(), nullable=True))
    
    # 2. Backfill: for each profile, copy owner-user's phone_number (join via profile_access)
    # This ensures we satisfy the NOT NULL constraint for existing production data.
    op.execute("""
        UPDATE profiles
        SET phone_number = u.phone_number
        FROM profile_access pa, users u
        WHERE pa.profile_id = profiles.id
          AND pa.access_level = 'owner'
          AND pa.user_id = u.id
          AND profiles.phone_number IS NULL
    """)
    
    # 3. Handle orphans (if any) or default to owner's phone if possible.
    # For safety, set a default for any remaining NULLs before setting NOT NULL.
    op.execute("UPDATE profiles SET phone_number = '0000000000' WHERE phone_number IS NULL")

    # 4. Set to NOT NULL
    op.alter_column('profiles', 'phone_number', nullable=False)


def downgrade():
    op.drop_column('profiles', 'phone_number')
