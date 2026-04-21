"""Add phone_otps table for phone-based authentication

Revision ID: add_phone_otps
Revises: 
Create Date: 2026-04-20

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'add_phone_otps'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('phone_otps',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('phone_number', sa.String(), nullable=False),
        sa.Column('otp', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.Column('is_used', sa.Boolean(), server_default='false', nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_phone_otps_id'), 'phone_otps', ['id'], unique=False)
    op.create_index(op.f('ix_phone_otps_phone_number'), 'phone_otps', ['phone_number'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_phone_otps_phone_number'), table_name='phone_otps')
    op.drop_index(op.f('ix_phone_otps_id'), table_name='phone_otps')
    op.drop_table('phone_otps')
