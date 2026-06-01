"""0014 — Add medications table (NUO-127) with encrypted PHI columns

Revision ID: 0014
Revises: 0013
Create Date: 2026-05-28

Patient-logged medication intake. Sensitive fields (name, dose, frequency,
notes) are stored as AES-256-GCM ciphertext in *_enc columns; ORM properties
decrypt on read.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "0014"
down_revision: Union[str, None] = "0013"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "medications",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("profile_id", sa.Integer(), nullable=False),
        sa.Column("logged_by", sa.Integer(), nullable=True),
        sa.Column("name_enc", sa.Text(), nullable=False),
        sa.Column("dose_enc", sa.Text(), nullable=True),
        sa.Column("frequency_enc", sa.Text(), nullable=True),
        sa.Column("notes_enc", sa.Text(), nullable=True),
        sa.Column("taken_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(["profile_id"], ["profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["logged_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_medications_profile_time",
        "medications",
        ["profile_id", "taken_at"],
        unique=False,
    )
    op.create_index(op.f("ix_medications_id"), "medications", ["id"], unique=False)
    op.create_index(
        op.f("ix_medications_profile_id"), "medications", ["profile_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_medications_profile_id"), table_name="medications")
    op.drop_index(op.f("ix_medications_id"), table_name="medications")
    op.drop_index("ix_medications_profile_time", table_name="medications")
    op.drop_table("medications")
