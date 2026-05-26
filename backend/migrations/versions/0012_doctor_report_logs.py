"""0012 — Add doctor_report_generation_logs table

Revision ID: 0012
Revises: 0011
Create Date: 2026-05-26
"""

from alembic import op
import sqlalchemy as sa


revision = '0012'
down_revision = '0011'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'doctor_report_generation_logs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('doctor_id', sa.Integer(), nullable=False),
        sa.Column('trigger_type', sa.Enum('SCHEDULED', 'MANUAL', 'ON_DEMAND', name='reporttriggertype', create_type=False), nullable=False),
        sa.Column('report_date', sa.Date(), nullable=False),
        sa.Column('generated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('patients_linked_count', sa.Integer(), nullable=False),
        sa.Column('patients_with_data_count', sa.Integer(), nullable=False),
        sa.Column('critical_patients_count', sa.Integer(), nullable=False),
        sa.Column('status', sa.Enum('SUCCESS', 'PARTIAL', 'FAILED', name='reportgenerationstatus', create_type=False), nullable=False),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['doctor_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_doctor_report_generation_logs_doctor_id', 'doctor_report_generation_logs', ['doctor_id'])
    op.create_index('ix_doctor_report_generation_logs_id', 'doctor_report_generation_logs', ['id'])


def downgrade():
    op.drop_index('ix_doctor_report_generation_logs_id', table_name='doctor_report_generation_logs')
    op.drop_index('ix_doctor_report_generation_logs_doctor_id', table_name='doctor_report_generation_logs')
    op.drop_table('doctor_report_generation_logs')
