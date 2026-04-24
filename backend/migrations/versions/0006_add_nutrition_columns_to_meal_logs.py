"""Add nutrition columns to meal_logs table

Revision ID: 0006
Revises: 0005
Create Date: 2026-04-24

This migration adds nutrition data columns to support persisting Gemini Vision
analysis results (calories, macros, meal score) for clinical tracking.
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0006'
down_revision = '0005'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Add nutrition columns to meal_logs table."""
    op.add_column('meal_logs', sa.Column('total_calories', sa.Float(), nullable=True))
    op.add_column('meal_logs', sa.Column('total_carbs_g', sa.Float(), nullable=True))
    op.add_column('meal_logs', sa.Column('total_protein_g', sa.Float(), nullable=True))
    op.add_column('meal_logs', sa.Column('total_fat_g', sa.Float(), nullable=True))
    op.add_column('meal_logs', sa.Column('total_fiber_g', sa.Float(), nullable=True))
    op.add_column('meal_logs', sa.Column('meal_score', sa.Integer(), nullable=True))


def downgrade() -> None:
    """Remove nutrition columns from meal_logs table."""
    op.drop_column('meal_logs', 'meal_score')
    op.drop_column('meal_logs', 'total_fiber_g')
    op.drop_column('meal_logs', 'total_fat_g')
    op.drop_column('meal_logs', 'total_protein_g')
    op.drop_column('meal_logs', 'total_carbs_g')
    op.drop_column('meal_logs', 'total_calories')
