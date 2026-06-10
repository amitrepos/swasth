"""0017 — Add referred_by_doctor_code to users (referral tracking)

Revision ID: 0017
Revises: 0016
Create Date: 2026-06-10

Stores the doctor_code of the doctor who referred the user to the app.
Nullable — most users self-register. Indexed so admin can GROUP BY referring
doctor to measure referral volume per doctor.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "0017"
down_revision: Union[str, None] = "0016"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "referred_by_doctor_code",
            sa.String(8),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_users_referred_by_doctor_code",
        "users",
        ["referred_by_doctor_code"],
    )


def downgrade() -> None:
    op.drop_index("ix_users_referred_by_doctor_code", table_name="users")
    op.drop_column("users", "referred_by_doctor_code")
