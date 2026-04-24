"""0007 — PII encryption batch: dual-key split, doctor contact, is_primary, OTP hashing

Revision ID: 0007
Revises: 0006
Create Date: 2026-04-24

!!! DESTRUCTIVE !!!
This migration TRUNCATEs every table that holds PII (users, profiles,
profile_access, profile_invites, doctor_profiles, doctor_patient_links,
doctor_notes, doctor_access_log, health_readings, meal_logs, chat_messages,
chat_context_profiles, trend_summary_cache, ai_insight_logs, critical_alert_logs,
admin_audit_log, whatsapp_*, report_generation_logs, *_otps) and then DROPs
the plaintext PII columns.

Authorization:
  - swasth_db (dev, :8443):   Amit approved 2026-04-24. One-line test accounts
                              restored via backend/seeds/pii_seed.py.
  - swasth_prod (prod, :8444): Amit approved 2026-04-24 (pre-pilot, zero live users).

Re-running this migration without data loss is not possible — downgrade() raises.
Restore from backup if rollback is required.

What changes:
  - users:               email/full_name/phone_number  → *_enc + email_hash + phone_hash
  - profiles:            name + quasi-identifiers + medical/doctor strings → *_enc, phone_hash
  - profile_invites:     invited_email + relationship  → *_enc + invited_email_hash
  - password_reset_otps: email + otp → email_enc + email_hash + otp_hash
  - email_verification_otps: email + otp → email_enc + email_hash + otp_hash
  - phone_otps:          phone_number + otp → phone_number_enc + phone_hash + otp_hash
  - doctor_profiles:     nmc_number → nmc_number_enc + nmc_hash; new phone + whatsapp cols
  - doctor_patient_links: new is_primary column + partial unique index (tracker line 200)
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "0007"
down_revision: Union[str, None] = "0006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Order matters: children before parents. CASCADE on TRUNCATE handles FK chains,
# but listing the children explicitly is clearer for audit review.
TRUNCATE_TABLES = [
    "phone_otps",
    "email_verification_otps",
    "password_reset_otps",
    "doctor_notes",
    "doctor_access_log",
    "doctor_patient_links",
    "doctor_profiles",
    "critical_alert_logs",
    "ai_insight_logs",
    "chat_messages",
    "chat_context_profiles",
    "trend_summary_cache",
    "meal_logs",
    "health_readings",
    "whatsapp_inbound_logs",
    "whatsapp_sessions",
    "whatsapp_message_logs",
    "report_generation_logs",
    "admin_audit_log",
    "profile_invites",
    "profile_access",
    "profiles",
    "users",
]


def upgrade() -> None:
    bind = op.get_bind()

    # 1) Destructive truncate. CASCADE handles any FK chain we might have missed.
    bind.execute(sa.text(
        "TRUNCATE TABLE "
        + ", ".join(TRUNCATE_TABLES)
        + " RESTART IDENTITY CASCADE"
    ))

    # ---------- users ----------
    # Drop the plaintext PII columns. CASCADE also drops the `ix_users_email`
    # unique index / `users_email_key` constraint that hangs off `email`.
    bind.execute(sa.text("ALTER TABLE users DROP COLUMN IF EXISTS email CASCADE"))
    bind.execute(sa.text("ALTER TABLE users DROP COLUMN IF EXISTS full_name CASCADE"))
    bind.execute(sa.text("ALTER TABLE users DROP COLUMN IF EXISTS phone_number CASCADE"))

    op.add_column("users", sa.Column("email_enc", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("email_hash", sa.String(length=64), nullable=True))
    op.add_column("users", sa.Column("full_name_enc", sa.Text(), nullable=False))
    op.add_column("users", sa.Column("phone_number_enc", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("phone_hash", sa.String(length=64), nullable=True))
    op.create_index("ix_users_email_hash", "users", ["email_hash"], unique=True)
    op.create_index("ix_users_phone_hash", "users", ["phone_hash"], unique=False)

    # ---------- profiles ----------
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS name CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS relationship CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS age CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS gender CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS height CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS blood_group CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS medical_conditions CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS other_medical_condition CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS current_medications CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS doctor_name CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS doctor_specialty CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS doctor_whatsapp CASCADE"))
    bind.execute(sa.text("ALTER TABLE profiles DROP COLUMN IF EXISTS phone_number CASCADE"))

    op.add_column("profiles", sa.Column("name_enc", sa.Text(), nullable=False))
    op.add_column("profiles", sa.Column("relationship_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("gender_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("age_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("height_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("blood_group_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("medical_conditions_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("other_medical_condition_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("current_medications_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("doctor_name_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("doctor_specialty_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("doctor_whatsapp_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("phone_number_enc", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("phone_hash", sa.String(length=64), nullable=True))
    op.create_index("ix_profiles_phone_hash", "profiles", ["phone_hash"], unique=False)

    # ---------- profile_invites ----------
    bind.execute(sa.text("ALTER TABLE profile_invites DROP COLUMN IF EXISTS invited_email CASCADE"))
    bind.execute(sa.text("ALTER TABLE profile_invites DROP COLUMN IF EXISTS relationship CASCADE"))

    op.add_column("profile_invites", sa.Column("invited_email_enc", sa.Text(), nullable=False))
    op.add_column("profile_invites", sa.Column("invited_email_hash", sa.String(length=64), nullable=False))
    op.add_column("profile_invites", sa.Column("relationship_enc", sa.Text(), nullable=True))
    op.create_index(
        "ix_profile_invites_invited_email_hash",
        "profile_invites",
        ["invited_email_hash"],
        unique=False,
    )
    op.create_index(
        "uq_profile_invite_email_pending",
        "profile_invites",
        ["profile_id", "invited_email_hash"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
    )

    # ---------- password_reset_otps ----------
    bind.execute(sa.text("ALTER TABLE password_reset_otps DROP COLUMN IF EXISTS email CASCADE"))
    bind.execute(sa.text("ALTER TABLE password_reset_otps DROP COLUMN IF EXISTS otp CASCADE"))
    op.add_column("password_reset_otps", sa.Column("email_enc", sa.Text(), nullable=False))
    op.add_column("password_reset_otps", sa.Column("email_hash", sa.String(length=64), nullable=False))
    op.add_column("password_reset_otps", sa.Column("otp_hash", sa.String(length=64), nullable=False))
    op.create_index(
        "ix_password_reset_otps_email_hash",
        "password_reset_otps",
        ["email_hash"],
        unique=False,
    )

    # ---------- email_verification_otps ----------
    bind.execute(sa.text("ALTER TABLE email_verification_otps DROP COLUMN IF EXISTS email CASCADE"))
    bind.execute(sa.text("ALTER TABLE email_verification_otps DROP COLUMN IF EXISTS otp CASCADE"))
    op.add_column("email_verification_otps", sa.Column("email_enc", sa.Text(), nullable=False))
    op.add_column("email_verification_otps", sa.Column("email_hash", sa.String(length=64), nullable=False))
    op.add_column("email_verification_otps", sa.Column("otp_hash", sa.String(length=64), nullable=False))
    op.create_index(
        "ix_email_verification_otps_email_hash",
        "email_verification_otps",
        ["email_hash"],
        unique=False,
    )

    # ---------- phone_otps ----------
    bind.execute(sa.text("ALTER TABLE phone_otps DROP COLUMN IF EXISTS phone_number CASCADE"))
    bind.execute(sa.text("ALTER TABLE phone_otps DROP COLUMN IF EXISTS otp CASCADE"))
    op.add_column("phone_otps", sa.Column("phone_number_enc", sa.Text(), nullable=False))
    op.add_column("phone_otps", sa.Column("phone_hash", sa.String(length=64), nullable=False))
    op.add_column("phone_otps", sa.Column("otp_hash", sa.String(length=64), nullable=False))
    op.create_index("ix_phone_otps_phone_hash", "phone_otps", ["phone_hash"], unique=False)

    # ---------- doctor_profiles ----------
    bind.execute(sa.text("ALTER TABLE doctor_profiles DROP COLUMN IF EXISTS nmc_number CASCADE"))
    op.add_column("doctor_profiles", sa.Column("nmc_number_enc", sa.Text(), nullable=False))
    op.add_column("doctor_profiles", sa.Column("nmc_hash", sa.String(length=64), nullable=False))
    op.add_column("doctor_profiles", sa.Column("phone_number_enc", sa.Text(), nullable=True))
    op.add_column("doctor_profiles", sa.Column("phone_hash", sa.String(length=64), nullable=True))
    op.add_column("doctor_profiles", sa.Column("whatsapp_number_enc", sa.Text(), nullable=True))
    op.add_column("doctor_profiles", sa.Column("whatsapp_hash", sa.String(length=64), nullable=True))
    op.create_index("ix_doctor_profiles_nmc_hash", "doctor_profiles", ["nmc_hash"], unique=True)
    op.create_index("ix_doctor_profiles_phone_hash", "doctor_profiles", ["phone_hash"], unique=False)
    op.create_index("ix_doctor_profiles_whatsapp_hash", "doctor_profiles", ["whatsapp_hash"], unique=False)

    # ---------- doctor_patient_links ----------
    op.add_column("doctor_patient_links", sa.Column(
        "is_primary", sa.Boolean(), nullable=False, server_default=sa.text("false"),
    ))
    op.create_index(
        "uq_primary_doctor_per_profile",
        "doctor_patient_links",
        ["profile_id"],
        unique=True,
        postgresql_where=sa.text("is_primary = true AND status = 'active'"),
    )


def downgrade() -> None:
    """Restore plaintext schema columns as NULLABLE and drop the _enc/_hash
    columns. Data is not restored — the ciphertext cannot be reversed back
    into a row that never had plaintext. This downgrade exists purely to
    satisfy the CI round-trip (bootstrap-then-stamp → downgrade → upgrade).

    Hard-blocked outside of an opt-in environment so a hand-typed
    `alembic downgrade -1` against prod cannot accidentally wipe the
    encrypted state. CI sets SWASTH_ALLOW_DESTRUCTIVE_DOWNGRADE=1.
    """
    import os

    if os.environ.get("SWASTH_ALLOW_DESTRUCTIVE_DOWNGRADE") != "1":
        raise RuntimeError(
            "Refusing to downgrade 0007_pii_encryption_batch: this drops the "
            "encrypted PII columns. Ciphertext cannot be reversed into a row "
            "that never had plaintext. Restore from backup, or set "
            "SWASTH_ALLOW_DESTRUCTIVE_DOWNGRADE=1 if this is a disposable DB."
        )

    # ---------- doctor_patient_links ----------
    op.drop_index("uq_primary_doctor_per_profile", table_name="doctor_patient_links")
    op.drop_column("doctor_patient_links", "is_primary")

    # ---------- doctor_profiles ----------
    op.drop_index("ix_doctor_profiles_whatsapp_hash", table_name="doctor_profiles")
    op.drop_index("ix_doctor_profiles_phone_hash", table_name="doctor_profiles")
    op.drop_index("ix_doctor_profiles_nmc_hash", table_name="doctor_profiles")
    op.drop_column("doctor_profiles", "whatsapp_hash")
    op.drop_column("doctor_profiles", "whatsapp_number_enc")
    op.drop_column("doctor_profiles", "phone_hash")
    op.drop_column("doctor_profiles", "phone_number_enc")
    op.drop_column("doctor_profiles", "nmc_hash")
    op.drop_column("doctor_profiles", "nmc_number_enc")
    op.add_column("doctor_profiles", sa.Column("nmc_number", sa.String(), nullable=True))
    op.create_index("ix_doctor_profiles_nmc_number", "doctor_profiles", ["nmc_number"], unique=True)

    # ---------- phone_otps ----------
    op.drop_index("ix_phone_otps_phone_hash", table_name="phone_otps")
    op.drop_column("phone_otps", "otp_hash")
    op.drop_column("phone_otps", "phone_hash")
    op.drop_column("phone_otps", "phone_number_enc")
    op.add_column("phone_otps", sa.Column("phone_number", sa.String(), nullable=True))
    op.add_column("phone_otps", sa.Column("otp", sa.String(), nullable=True))
    op.create_index("ix_phone_otps_phone_number", "phone_otps", ["phone_number"], unique=False)

    # ---------- email_verification_otps ----------
    op.drop_index("ix_email_verification_otps_email_hash", table_name="email_verification_otps")
    op.drop_column("email_verification_otps", "otp_hash")
    op.drop_column("email_verification_otps", "email_hash")
    op.drop_column("email_verification_otps", "email_enc")
    op.add_column("email_verification_otps", sa.Column("email", sa.String(), nullable=True))
    op.add_column("email_verification_otps", sa.Column("otp", sa.String(), nullable=True))

    # ---------- password_reset_otps ----------
    op.drop_index("ix_password_reset_otps_email_hash", table_name="password_reset_otps")
    op.drop_column("password_reset_otps", "otp_hash")
    op.drop_column("password_reset_otps", "email_hash")
    op.drop_column("password_reset_otps", "email_enc")
    op.add_column("password_reset_otps", sa.Column("email", sa.String(), nullable=True))
    op.add_column("password_reset_otps", sa.Column("otp", sa.String(), nullable=True))

    # ---------- profile_invites ----------
    op.drop_index("uq_profile_invite_email_pending", table_name="profile_invites")
    op.drop_index("ix_profile_invites_invited_email_hash", table_name="profile_invites")
    op.drop_column("profile_invites", "relationship_enc")
    op.drop_column("profile_invites", "invited_email_hash")
    op.drop_column("profile_invites", "invited_email_enc")
    op.add_column("profile_invites", sa.Column("invited_email", sa.String(), nullable=True))
    op.add_column("profile_invites", sa.Column("relationship", sa.String(), nullable=True))
    op.create_index("ix_profile_invites_invited_email", "profile_invites", ["invited_email"], unique=False)
    op.create_index(
        "uq_profile_invite_email_pending",
        "profile_invites",
        ["profile_id", "invited_email"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
    )

    # ---------- profiles ----------
    op.drop_index("ix_profiles_phone_hash", table_name="profiles")
    op.drop_column("profiles", "phone_hash")
    op.drop_column("profiles", "phone_number_enc")
    op.drop_column("profiles", "doctor_whatsapp_enc")
    op.drop_column("profiles", "doctor_specialty_enc")
    op.drop_column("profiles", "doctor_name_enc")
    op.drop_column("profiles", "current_medications_enc")
    op.drop_column("profiles", "other_medical_condition_enc")
    op.drop_column("profiles", "medical_conditions_enc")
    op.drop_column("profiles", "blood_group_enc")
    op.drop_column("profiles", "height_enc")
    op.drop_column("profiles", "age_enc")
    op.drop_column("profiles", "gender_enc")
    op.drop_column("profiles", "relationship_enc")
    op.drop_column("profiles", "name_enc")
    op.add_column("profiles", sa.Column("name", sa.String(), nullable=True))
    op.add_column("profiles", sa.Column("relationship", sa.String(), nullable=True))
    op.add_column("profiles", sa.Column("gender", sa.String(), nullable=True))
    op.add_column("profiles", sa.Column("age", sa.Integer(), nullable=True))
    op.add_column("profiles", sa.Column("height", sa.Float(), nullable=True))
    op.add_column("profiles", sa.Column("blood_group", sa.String(), nullable=True))
    op.add_column("profiles", sa.Column("medical_conditions", sa.ARRAY(sa.String()), nullable=True))
    op.add_column("profiles", sa.Column("other_medical_condition", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("current_medications", sa.Text(), nullable=True))
    op.add_column("profiles", sa.Column("doctor_name", sa.String(), nullable=True))
    op.add_column("profiles", sa.Column("doctor_specialty", sa.String(), nullable=True))
    op.add_column("profiles", sa.Column("doctor_whatsapp", sa.String(), nullable=True))
    op.add_column("profiles", sa.Column("phone_number", sa.String(), nullable=True))
    op.create_index("ix_profiles_phone_number", "profiles", ["phone_number"], unique=False)

    # ---------- users ----------
    op.drop_index("ix_users_phone_hash", table_name="users")
    op.drop_index("ix_users_email_hash", table_name="users")
    op.drop_column("users", "phone_hash")
    op.drop_column("users", "phone_number_enc")
    op.drop_column("users", "full_name_enc")
    op.drop_column("users", "email_hash")
    op.drop_column("users", "email_enc")
    op.add_column("users", sa.Column("email", sa.String(), nullable=True))
    op.add_column("users", sa.Column("full_name", sa.String(), nullable=True))
    op.add_column("users", sa.Column("phone_number", sa.String(), nullable=True))
    op.create_index("ix_users_email", "users", ["email"], unique=True)
