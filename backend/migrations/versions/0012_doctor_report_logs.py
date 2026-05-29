"""0012 — Add doctor_report_generation_logs table

Revision ID: 0012
Revises: 0011
Create Date: 2026-05-26

The two enum types (reporttriggertype, reportgenerationstatus) were
introduced by 0011 and are shared with patient-side weekly reports.
This migration MUST NOT try to (re-)create them; it only adds a new
table that references them by name.

CI hit `psycopg2.errors.DuplicateObject: type "reporttriggertype"
already exists` because `sa.Enum(..., create_type=False)` does NOT
honour create_type — that kwarg is dialect-specific and only effective
on `sqlalchemy.dialects.postgresql.ENUM`. With plain `sa.Enum`, the
table-create event still fires `CREATE TYPE` and blows up on the
second upgrade after a downgrade.

The fix is to use `postgresql.ENUM(create_type=False)` directly, which
genuinely skips the CREATE TYPE step (its `create()` checks the flag
and returns early).
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ENUM as PgEnum


revision = '0012'
down_revision = '0011'
branch_labels = None
depends_on = None


# Pre-built type references — these MUST point at the enum types that
# 0011 (or earlier) already created. create_type=False here is the
# whole point: without it, Postgres errors on re-create when CI runs
# `alembic downgrade -1 && alembic upgrade head` (the downgrade
# intentionally does not drop the enum because patient-side reports
# still depend on it).
_trigger_type_enum = PgEnum(
    'scheduled', 'manual',
    name='reporttriggertype',
    create_type=False,
)
_status_enum = PgEnum(
    'success', 'partial', 'failed',
    name='reportgenerationstatus',
    create_type=False,
)


def upgrade():
    op.create_table(
        'doctor_report_generation_logs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('doctor_id', sa.Integer(), nullable=False),
        sa.Column('trigger_type', _trigger_type_enum, nullable=False),
        sa.Column('report_date', sa.Date(), nullable=False),
        sa.Column('generated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('patients_linked_count', sa.Integer(), nullable=False),
        sa.Column('patients_with_data_count', sa.Integer(), nullable=False),
        sa.Column('critical_patients_count', sa.Integer(), nullable=False),
        sa.Column('status', _status_enum, nullable=False),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['doctor_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_doctor_report_generation_logs_doctor_id', 'doctor_report_generation_logs', ['doctor_id'])
    op.create_index('ix_doctor_report_generation_logs_id', 'doctor_report_generation_logs', ['id'])


def downgrade():
    # We drop the table but NOT the enum types: they are shared with
    # patient-side weekly reports (introduced in 0011) and still in
    # use by report_generation_logs / whatsapp_message_logs. Dropping
    # the type here would cascade-break those tables.
    op.drop_index('ix_doctor_report_generation_logs_id', table_name='doctor_report_generation_logs')
    op.drop_index('ix_doctor_report_generation_logs_doctor_id', table_name='doctor_report_generation_logs')
    op.drop_table('doctor_report_generation_logs')
