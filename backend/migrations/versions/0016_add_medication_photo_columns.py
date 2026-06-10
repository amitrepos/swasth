"""0016 — Add medication photo columns (NUO-127)

Revision ID: 0016
Revises: 0015
Create Date: 2026-06-09
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "0016"
down_revision: Union[str, None] = "0015"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("medications", sa.Column("photo_path", sa.String(), nullable=True))
    op.add_column(
        "medications",
        sa.Column("has_photo", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.alter_column("medications", "has_photo", server_default=None)


def downgrade() -> None:
    op.drop_column("medications", "has_photo")
    op.drop_column("medications", "photo_path")
