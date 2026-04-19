"""baseline — represents prod schema state as of 2026-04-19

Revision ID: 0001
Revises:
Create Date: 2026-04-19

This revision is intentionally empty. It exists to establish the
`alembic_version` tracking row at a known starting point so subsequent
migrations have a parent to attach to.

Prod (and any environment that pre-existed the adoption of Alembic) was
brought under management via:

    alembic stamp 0001

…which writes `0001` into `alembic_version` without running any DDL.
The actual schema in prod at that moment is documented in
`docs/DATABASE_SCHEMA.md` (or in the TASK_TRACKER session log for
2026-04-19 if the schema doc is rebuilt later).

For a brand-new environment created via `Base.metadata.create_all()`
(e.g. SQLite test database, or a fresh dev Postgres), the schema is
built from `models.py`, then `alembic stamp head` brings it under
management — no DDL is run by 0001 in that path either.
"""
from typing import Sequence, Union

from alembic import op  # noqa: F401
import sqlalchemy as sa  # noqa: F401


revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
