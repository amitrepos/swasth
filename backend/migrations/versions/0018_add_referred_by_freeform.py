"""0018 — Add referred_by free-form text to users

Revision ID: 0018
Revises: 0017
Create Date: 2026-06-11

Adds users.referred_by VARCHAR(255) nullable — free-form referral source
captured at registration or editable on profile. Separate from the
existing referred_by_doctor_code (structured doctor code, 8-char max).
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "0018"
down_revision: Union[str, None] = "0017"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "referred_by",
            sa.String(255),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "referred_by")
