"""weight columns + 3 default drifts

Revision ID: 0002
Revises: 0001
Create Date: 2026-04-19

Two unrelated-looking changes bundled because they were diagnosed
together while introspecting prod against `models.py` on 2026-04-19,
and shipping them as one Alembic revision is the smallest atomic unit
that closes both gaps.

(1) Weight columns missing from prod
    PR #133 added `weight_value`, `weight_unit`, `weight_value_enc` to
    `models.py:HealthReading`. The pre-Alembic deploy mechanism was
    `Base.metadata.create_all()`, which only creates tables that don't
    yet exist — it never ALTERs to add new columns. So PR #133's columns
    reached every freshly-built dev/test DB but never reached prod.

(2) Three DB-side DEFAULTs drift from what `models.py` declares
    SQLAlchemy `default=` is a Python-side default applied at INSERT
    time by the ORM. The DB-side DEFAULT is independent and was set by
    older one-off `migrate_*.py` scripts. They diverged:
      • profile_invites.access_level: prod 'editor' vs code 'viewer'
        — security-relevant: raw SQL insert grants write access.
      • doctor_patient_links.status: prod 'active' vs code
        'pending_doctor_accept' — compliance-relevant: raw SQL insert
        bypasses NMC telemedicine consent flow.
      • users.timezone: prod 'Asia/Kolkata' vs code 'UTC' — chose UTC
        per "store UTC, transform at display" doctrine. New rows only;
        existing rows keep their stored value.

This migration changes column DEFAULTs only. It does NOT rewrite
existing row values — every existing user keeps their current timezone,
every existing invite keeps its current access_level, every existing
doctor link keeps its current status.

Downgrade restores the prior DEFAULTs and drops the three weight
columns. Any weight readings written between upgrade and downgrade are
lost on downgrade — by design, since the columns themselves are gone.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # (1) Weight columns — all nullable, no backfill.
    op.add_column(
        "health_readings",
        sa.Column("weight_value", sa.Float(), nullable=True),
    )
    op.add_column(
        "health_readings",
        sa.Column("weight_unit", sa.String(), nullable=True),
    )
    op.add_column(
        "health_readings",
        sa.Column("weight_value_enc", sa.Text(), nullable=True),
    )

    # (2) Default drift — align prod DEFAULT with models.py intent.
    op.alter_column(
        "profile_invites",
        "access_level",
        existing_type=sa.String(),
        existing_nullable=False,
        server_default="viewer",
    )
    op.alter_column(
        "doctor_patient_links",
        "status",
        existing_type=sa.String(),
        existing_nullable=False,
        server_default="pending_doctor_accept",
    )
    op.alter_column(
        "users",
        "timezone",
        existing_type=sa.String(),
        existing_nullable=False,
        server_default="UTC",
    )


def downgrade() -> None:
    op.alter_column(
        "users",
        "timezone",
        existing_type=sa.String(),
        existing_nullable=False,
        server_default="Asia/Kolkata",
    )
    op.alter_column(
        "doctor_patient_links",
        "status",
        existing_type=sa.String(),
        existing_nullable=False,
        server_default="active",
    )
    op.alter_column(
        "profile_invites",
        "access_level",
        existing_type=sa.String(),
        existing_nullable=False,
        server_default="editor",
    )

    op.drop_column("health_readings", "weight_value_enc")
    op.drop_column("health_readings", "weight_unit")
    op.drop_column("health_readings", "weight_value")
