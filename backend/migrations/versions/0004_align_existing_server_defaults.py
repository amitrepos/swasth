"""align models.py server_defaults with prod's existing DB defaults

Revision ID: 0004
Revises: 0003
Create Date: 2026-04-19

After PR #146 brought prod under Alembic management, `alembic check` on
prod surfaced 4 columns where the DB has a server_default but `models.py`
did not declare one (legacy `migrate_*.py` scripts set them at table-
creation time):

  email_verification_otps.is_used → false
  users.is_admin                  → false
  users.role                      → 'patient'::userrole
  users.email_verified            → false

The runtime is not affected — application code always specifies these on
INSERT — but `alembic check` reports drift, which would mean the next
`alembic revision --autogenerate` produces a noisy migration that
includes spurious "drop these defaults" ops, easy to merge by mistake.

This migration is metadata-only on prod (the DEFAULTs already exist;
SET DEFAULT to the same value is a no-op). On any fresh-bootstrap path
(via Base.metadata.create_all() in tests/CI), the new server_default=
declarations on models.py mean create_all() bakes the defaults in, then
this migration is a no-op there too. Either way, after this revision
both sides agree and `alembic check` is clean.

Downgrade drops all 4 defaults — reverts to the state the columns were
in immediately after PR #146 merged but before this PR.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "users",
        "is_admin",
        existing_type=sa.Boolean(),
        existing_nullable=True,
        server_default=sa.text("false"),
    )
    op.alter_column(
        "users",
        "role",
        existing_type=sa.Enum(
            "patient", "doctor", "admin", name="userrole"
        ),
        existing_nullable=False,
        server_default="patient",
    )
    op.alter_column(
        "users",
        "email_verified",
        existing_type=sa.Boolean(),
        existing_nullable=True,
        server_default=sa.text("false"),
    )
    op.alter_column(
        "email_verification_otps",
        "is_used",
        existing_type=sa.Boolean(),
        existing_nullable=True,
        server_default=sa.text("false"),
    )


def downgrade() -> None:
    op.alter_column(
        "email_verification_otps",
        "is_used",
        existing_type=sa.Boolean(),
        existing_nullable=True,
        server_default=None,
    )
    op.alter_column(
        "users",
        "email_verified",
        existing_type=sa.Boolean(),
        existing_nullable=True,
        server_default=None,
    )
    op.alter_column(
        "users",
        "role",
        existing_type=sa.Enum(
            "patient", "doctor", "admin", name="userrole"
        ),
        existing_nullable=False,
        server_default=None,
    )
    op.alter_column(
        "users",
        "is_admin",
        existing_type=sa.Boolean(),
        existing_nullable=True,
        server_default=None,
    )
