"""profile_invites.access_level default — viewer

Revision ID: 0003
Revises: 0002
Create Date: 2026-04-19

The 2026-04-19 prod investigation revealed that 0002's view of prod was
based on the WRONG database (`swasth_db` documented in TASK_TRACKER vs
`swasth_prod` actually in production). Real prod had:
- weight columns: present (added by some pre-Alembic ALTER, with 29 rows)
- users.timezone default: 'UTC' (already correct)
- doctor_patient_links.status default: 'pending_doctor_accept' (already correct)
- profile_invites.access_level default: NULL (NOT 'editor' as 0002 assumed,
  and NOT 'viewer' as models.py declares via `server_default="viewer"`)

So 5 of 6 ops in 0002 were no-ops on real prod; only the access_level
default needed fixing. This 0003 closes that one real drift.

Bootstrap path for prod (handled in .github/workflows/prod.yml):
1. First-time deploy after this PR: `alembic stamp 0002` (records prod
   as already at the historical pre-0003 state — accurate because 0002's
   intent matches what legacy migrate_*.py already produced, except for
   the access_level default we fix here).
2. `alembic upgrade head` → applies 0003 → access_level default = 'viewer'
   → models.py and prod schema agree.

Subsequent deploys are pure `alembic upgrade head` (no-op when nothing
pending).

Downgrade restores DEFAULT to NULL, matching prod's pre-0003 state.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "profile_invites",
        "access_level",
        existing_type=sa.String(),
        existing_nullable=False,
        server_default="viewer",
    )


def downgrade() -> None:
    op.alter_column(
        "profile_invites",
        "access_level",
        existing_type=sa.String(),
        existing_nullable=False,
        server_default=None,
    )
