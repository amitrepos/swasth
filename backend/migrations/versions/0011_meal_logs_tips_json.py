"""0011 — Consolidate meal_logs tip_en/tip_hi/tip_kn into tips_json.

Revision ID: 0011
Revises: 0010
Create Date: 2026-05-18

Multilingual rollout (kn/te/ta added in this PR) made the per-language
column approach untenable — each new language would require an ALTER.
This migration collapses the three legacy columns (tip_en, tip_hi,
tip_kn) into a single JSON column (tips_json) keyed by language code.

Backfill is data-preserving: existing rows are converted to
{"en": tip_en, "hi": tip_hi, "kn": tip_kn} with NULL values omitted.
After the JSON is populated, the old columns are dropped.

PHI invariant: tips are AI-generated coaching strings, not health data.
Same treatment as `category` — not encrypted.
"""

from alembic import op
import sqlalchemy as sa


revision = '0011'
down_revision = '0010'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    dialect = bind.dialect.name

    # 1. Add the new JSON column (JSONB on Postgres, JSON elsewhere).
    if dialect == 'postgresql':
        op.execute(
            "ALTER TABLE meal_logs ADD COLUMN IF NOT EXISTS tips_json JSONB"
        )
    else:
        # SQLite / other backends — generic JSON
        with op.batch_alter_table('meal_logs') as batch:
            batch.add_column(sa.Column('tips_json', sa.JSON(), nullable=True))

    # 2. Backfill from legacy columns. Use JSON object construction that
    # omits NULL values so downstream consumers can rely on key presence
    # as a signal that the language was populated.
    if dialect == 'postgresql':
        op.execute(
            """
            UPDATE meal_logs
            SET tips_json = (
                SELECT jsonb_strip_nulls(jsonb_build_object(
                    'en', tip_en,
                    'hi', tip_hi,
                    'kn', tip_kn
                ))
            )
            WHERE tips_json IS NULL
              AND (tip_en IS NOT NULL OR tip_hi IS NOT NULL OR tip_kn IS NOT NULL);
            """
        )
    else:
        # SQLite — JSON1 ext is available in stdlib sqlite3 (3.38+).
        op.execute(
            """
            UPDATE meal_logs
            SET tips_json = json_object(
                'en', tip_en,
                'hi', tip_hi,
                'kn', tip_kn
            )
            WHERE tips_json IS NULL
              AND (tip_en IS NOT NULL OR tip_hi IS NOT NULL OR tip_kn IS NOT NULL);
            """
        )

    # 3. Drop legacy columns. Use IF EXISTS so a partially-migrated
    # environment (e.g. dev box that ran the standalone script) can
    # still complete the upgrade.
    if dialect == 'postgresql':
        op.execute("ALTER TABLE meal_logs DROP COLUMN IF EXISTS tip_en")
        op.execute("ALTER TABLE meal_logs DROP COLUMN IF EXISTS tip_hi")
        op.execute("ALTER TABLE meal_logs DROP COLUMN IF EXISTS tip_kn")
    else:
        with op.batch_alter_table('meal_logs') as batch:
            for col in ('tip_en', 'tip_hi', 'tip_kn'):
                try:
                    batch.drop_column(col)
                except Exception:
                    # Column may not exist if the dev box already cleaned up.
                    pass


def downgrade():
    bind = op.get_bind()
    dialect = bind.dialect.name

    # 1. Re-add legacy columns.
    op.add_column('meal_logs', sa.Column('tip_en', sa.Text(), nullable=True))
    op.add_column('meal_logs', sa.Column('tip_hi', sa.Text(), nullable=True))
    op.add_column('meal_logs', sa.Column('tip_kn', sa.Text(), nullable=True))

    # 2. Backfill from JSON. Postgres uses ->>, SQLite uses json_extract.
    if dialect == 'postgresql':
        op.execute(
            """
            UPDATE meal_logs
            SET tip_en = tips_json->>'en',
                tip_hi = tips_json->>'hi',
                tip_kn = tips_json->>'kn'
            WHERE tips_json IS NOT NULL;
            """
        )
    else:
        op.execute(
            """
            UPDATE meal_logs
            SET tip_en = json_extract(tips_json, '$.en'),
                tip_hi = json_extract(tips_json, '$.hi'),
                tip_kn = json_extract(tips_json, '$.kn')
            WHERE tips_json IS NOT NULL;
            """
        )

    # 3. Drop the JSON column.
    if dialect == 'postgresql':
        op.execute("ALTER TABLE meal_logs DROP COLUMN IF EXISTS tips_json")
    else:
        with op.batch_alter_table('meal_logs') as batch:
            batch.drop_column('tips_json')
