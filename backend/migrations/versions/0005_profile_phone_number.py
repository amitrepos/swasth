"""add profile phone number

Revision ID: 0005
Revises: 0004
Create Date: 2026-04-23 11:30:00.000000

"""
from alembic import op
import sqlalchemy as sa
import re

# revision identifiers, used by Alembic.
revision = '0005'
down_revision = '0004'
branch_labels = None
depends_on = None

def normalize_phone(phone: str | None) -> str:
    """Copy of backend.utils.phone.normalize_phone to keep migration self-contained.
    Intentional divergence: Migration copies must remain frozen even if the 
    application helper changes, to ensure deterministic historical execution.
    """
    if not phone:
        return ""
    phone = phone.strip()
    digits = re.sub(r"[^\d]", "", phone)
    if not (10 <= len(digits) <= 15):
        return ""
    if len(digits) == 10:
        return f"+91{digits}"
    if len(digits) == 12 and digits.startswith("91"):
        return f"+{digits}"
    return f"+{digits}"

def upgrade():
    # 1. Add column as nullable initially + add index
    op.add_column('profiles', sa.Column('phone_number', sa.String(), nullable=True))
    op.create_index(op.f('ix_profiles_phone_number'), 'profiles', ['phone_number'], unique=False)
    
    # 2. Backfill: for each profile, copy owner-user's phone_number (join via profile_access)
    # Run values through normalize_phone during backfill.
    # Use portable data migration instead of Postgres-only UPDATE FROM.
    bind = op.get_bind()
    
    # Fetch profiles that need backfilling
    res = bind.execute(sa.text("""
        SELECT p.id, u.phone_number
        FROM profiles p
        JOIN profile_access pa ON p.id = pa.profile_id
        JOIN users u ON pa.user_id = u.id
        WHERE pa.access_level = 'owner'
          AND (p.phone_number IS NULL OR p.phone_number = '')
    """)).fetchall()
    
    for row in res:
        profile_id = row[0]
        raw_phone = row[1]
        norm_phone = normalize_phone(raw_phone)
        if norm_phone:
            bind.execute(
                sa.text("UPDATE profiles SET phone_number = :phone WHERE id = :id"),
                {"phone": norm_phone, "id": profile_id}
            )

    # Senior says "don't invent a phone number". Keep nullable for orphans.
    # No more UPDATE SET '0000000000'.

    # Normalise users.phone_number so DB lookups using normalize_phone() match.
    # Without this, routes that query users.phone_number == normalize_phone(input)
    # return None for pre-existing users and silently create duplicate accounts.
    user_rows = bind.execute(
        sa.text("SELECT id, phone_number FROM users WHERE phone_number IS NOT NULL AND phone_number != ''")
    ).fetchall()
    for row in user_rows:
        uid, raw = row[0], row[1]
        norm = normalize_phone(raw)
        if norm and norm != raw:
            bind.execute(
                sa.text("UPDATE users SET phone_number = :p WHERE id = :id"),
                {"p": norm, "id": uid}
            )

def downgrade():
    raise NotImplementedError(
        "Downgrade permanently deletes profile phone numbers and cannot be reversed. "
        "Restore from a database backup instead of running this downgrade."
    )
