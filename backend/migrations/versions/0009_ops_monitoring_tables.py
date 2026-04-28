"""0009 — Add ops_alert_logs and system_health_snapshots tables

Revision ID: 0009
Revises: 0008
Create Date: 2026-04-27

Adds two new tables for operational monitoring:
  - ops_alert_logs: deduplication ledger for P0/P1/P2 email alerts
  - system_health_snapshots: periodic snapshots of system health metrics

PHI invariant: both tables store ONLY aggregate counts, rates, and booleans.
No user IDs, health values, or PII are stored in these tables.
"""

from alembic import op
import sqlalchemy as sa


revision = '0009'
down_revision = '0008'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'ops_alert_logs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('alert_key', sa.String(length=100), nullable=False),
        sa.Column('tier', sa.String(length=5), nullable=False),
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('body_json', sa.Text(), nullable=True),
        sa.Column('email_sent', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('email_sent_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('resolved_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_ops_alert_logs_id', 'ops_alert_logs', ['id'])
    op.create_index('ix_ops_alert_logs_alert_key', 'ops_alert_logs', ['alert_key'])
    op.create_index('ix_ops_alert_logs_created_at', 'ops_alert_logs', ['created_at'])
    op.create_index('ix_ops_alert_key_time', 'ops_alert_logs', ['alert_key', 'created_at'])

    op.create_table(
        'system_health_snapshots',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('snapshot_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('api_healthy', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('db_healthy', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('db_pool_used', sa.Integer(), nullable=True),
        sa.Column('db_pool_size', sa.Integer(), nullable=True),
        sa.Column('db_slow_queries_1h', sa.Integer(), nullable=True),
        sa.Column('gemini_healthy', sa.Boolean(), nullable=True),
        sa.Column('deepseek_healthy', sa.Boolean(), nullable=True),
        sa.Column('all_ai_keys_failed', sa.Boolean(), nullable=True, server_default='false'),
        sa.Column('scheduler_healthy', sa.Boolean(), nullable=True),
        sa.Column('error_rate_5xx_5min', sa.Integer(), nullable=True),
        sa.Column('error_rate_4xx_5min', sa.Integer(), nullable=True),
        sa.Column('error_rate_401_5min', sa.Integer(), nullable=True),
        sa.Column('error_rate_422_5min', sa.Integer(), nullable=True),
        sa.Column('p50_latency_ms', sa.Integer(), nullable=True),
        sa.Column('p95_latency_ms', sa.Integer(), nullable=True),
        sa.Column('concurrent_requests', sa.Integer(), nullable=True),
        sa.Column('concurrent_peak', sa.Integer(), nullable=True),
        sa.Column('memory_pct', sa.Float(), nullable=True),
        sa.Column('memory_rss_mb', sa.Float(), nullable=True),
        sa.Column('swap_active', sa.Boolean(), nullable=True, server_default='false'),
        sa.Column('disk_pct', sa.Float(), nullable=True),
        sa.Column('cpu_burst_credits_low', sa.Boolean(), nullable=True, server_default='false'),
        sa.Column('file_descriptors', sa.Integer(), nullable=True),
        sa.Column('memory_growth_mb_per_hour', sa.Float(), nullable=True),
        sa.Column('ai_fallback_rate_1h', sa.Float(), nullable=True),
        sa.Column('pending_doctor_verifications', sa.Integer(), nullable=True),
        sa.Column('critical_alerts_unacked_2h', sa.Integer(), nullable=True),
        sa.Column('critical_alerts_failed_today', sa.Integer(), nullable=True),
        sa.Column('patients_no_reading_7d', sa.Integer(), nullable=True),
        sa.Column('whatsapp_fail_rate_today', sa.Float(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_system_health_snapshots_id', 'system_health_snapshots', ['id'])
    op.create_index('ix_system_health_snapshots_snapshot_at', 'system_health_snapshots', ['snapshot_at'])


def downgrade():
    op.drop_index('ix_system_health_snapshots_snapshot_at', table_name='system_health_snapshots')
    op.drop_index('ix_system_health_snapshots_id', table_name='system_health_snapshots')
    op.drop_table('system_health_snapshots')

    op.drop_index('ix_ops_alert_key_time', table_name='ops_alert_logs')
    op.drop_index('ix_ops_alert_logs_created_at', table_name='ops_alert_logs')
    op.drop_index('ix_ops_alert_logs_alert_key', table_name='ops_alert_logs')
    op.drop_index('ix_ops_alert_logs_id', table_name='ops_alert_logs')
    op.drop_table('ops_alert_logs')
