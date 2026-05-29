"""0013 — Add composite index for WhatsApp manual-trigger cooldown query

Revision ID: 0013
Revises: 0012
Create Date: 2026-05-28

The doctor manual-trigger cooldown check in routes_doctor.py filters
whatsapp_message_logs on (user_id, trigger_type, status, sent_at).
The pre-existing single-column index on user_id forces Postgres to
fetch every row for that user and apply the remaining three filters
in memory. At Bihar pilot scale this is fine; once a single active
doctor has thousands of log rows the cooldown endpoint slows linearly.

This migration adds a composite index covering the exact filter shape.
We use CREATE INDEX CONCURRENTLY (via raw SQL) so the index build does
NOT block writes to whatsapp_message_logs while it runs. Concurrent
index builds cannot run inside a transaction, so this migration sets
`transactional_ddl = False` for upgrade/downgrade.
"""

from alembic import op


revision = '0013'
down_revision = '0012'
branch_labels = None
depends_on = None


def upgrade():
    # CONCURRENTLY must run outside a transaction. Alembic's default
    # transaction wrapper would error out; using op.execute with a raw
    # statement and the autocommit isolation level keeps the index
    # build online.
    with op.get_context().autocommit_block():
        op.execute(
            "CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_wa_msg_log_cooldown "
            "ON whatsapp_message_logs (user_id, trigger_type, status, sent_at)"
        )


def downgrade():
    with op.get_context().autocommit_block():
        op.execute(
            "DROP INDEX CONCURRENTLY IF EXISTS ix_wa_msg_log_cooldown"
        )
