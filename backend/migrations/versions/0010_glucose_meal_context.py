"""0010 — Add meal_context column to health_readings (glucose typing).

Revision ID: 0010
Revises: 0009
Create Date: 2026-05-14

The reading_confirmation screen already captures fasting / before_meal /
after_meal but stores it as free text in the `notes` field. This migration
promotes that signal to a typed column so the dashboard classifier can pick
the right range table (fasting <100 vs post-meal <140 for non-diabetics,
etc.).

PHI invariant: meal_context is enum-like metadata, not health data. Not
encrypted — same treatment as `reading_type` and `status_flag`.
"""

from alembic import op
import sqlalchemy as sa


revision = '0010'
down_revision = '0009'
branch_labels = None
depends_on = None


_ALLOWED = ('fasting', 'before_meal', 'post_meal', 'random', 'unknown')


def upgrade():
    op.add_column(
        'health_readings',
        sa.Column('meal_context', sa.String(length=20), nullable=True),
    )

    # Backfill from notes for existing glucose readings. Heuristic-based; we
    # use the exact strings the entry chips wrote, so most rows pick up the
    # right context. Rows that don't match → 'unknown' (sheet will prompt
    # the user to re-tag).
    op.execute(
        """
        UPDATE health_readings
        SET meal_context = CASE
            WHEN lower(coalesce(notes, '')) LIKE '%fasting%'           THEN 'fasting'
            WHEN lower(coalesce(notes, '')) LIKE '%before%meal%'       THEN 'before_meal'
            WHEN lower(coalesce(notes, '')) LIKE '%after%meal%'        THEN 'post_meal'
            WHEN lower(coalesce(notes, '')) LIKE '%post%meal%'         THEN 'post_meal'
            WHEN lower(coalesce(notes, '')) LIKE '%random%'            THEN 'random'
            ELSE 'unknown'
        END
        WHERE reading_type = 'glucose';
        """
    )

    # Enforce the enum at the DB level so future inserts can't drift.
    op.create_check_constraint(
        'ck_health_readings_meal_context',
        'health_readings',
        f"meal_context IS NULL OR meal_context IN {_ALLOWED!r}",
    )


def downgrade():
    op.drop_constraint(
        'ck_health_readings_meal_context',
        'health_readings',
        type_='check',
    )
    op.drop_column('health_readings', 'meal_context')
