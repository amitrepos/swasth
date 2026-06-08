"""0015 — Add intake_period to medications (NUO-127)

Revision ID: 0015
Revises: 0014
Create Date: 2026-06-07

Morning/Afternoon/Evening/Night intake period for patient medicine logs.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "0015"
down_revision: Union[str, None] = "0014"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_VALID_PERIODS = ("MORNING", "AFTERNOON", "EVENING", "NIGHT")
_CHECK = "intake_period IN ('MORNING', 'AFTERNOON', 'EVENING', 'NIGHT')"


def upgrade() -> None:
    op.add_column(
        "medications",
        sa.Column(
            "intake_period",
            sa.String(),
            nullable=False,
            server_default="MORNING",
        ),
    )
    op.create_check_constraint(
        "ck_medications_intake_period",
        "medications",
        _CHECK,
    )
    # PG: drop default so new rows must supply intake_period from the API.
    # SQLite lacks ALTER COLUMN … DROP DEFAULT — skip (tests use create_all).
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.alter_column("medications", "intake_period", server_default=None)


def downgrade() -> None:
    op.drop_constraint("ck_medications_intake_period", "medications", type_="check")
    op.drop_column("medications", "intake_period")
