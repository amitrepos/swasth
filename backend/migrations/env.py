"""Alembic environment configuration.

Loads DATABASE_URL from config.settings (so secrets stay in env, not in
alembic.ini), imports models so all classes are registered onto
Base.metadata, and runs migrations against that metadata.

`compare_server_default=True` is intentional — without it, `alembic check`
silently ignores DEFAULT-value drift, and the 2026-04 profile_invites /
doctor_patient_links default drifts that motivated this scaffold would
slip past CI.
"""

import os
import sys

from alembic import context
from sqlalchemy import engine_from_config, pool

# backend/ on sys.path so we can import config, database, models.
sys.path.insert(
    0, os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from config import settings  # noqa: E402
from database import Base  # noqa: E402
import models  # noqa: E402, F401  — registers tables onto Base.metadata

config = context.config
# Escape `%` as `%%` because Alembic's config object uses Python's
# configparser internally, which treats `%` as interpolation syntax.
# Without this, a URL like `postgresql://user:pa%40ss@host/db`
# (containing a URL-encoded `@` or any other %xx) crashes with
# `ValueError: invalid interpolation syntax`.
config.set_main_option(
    "sqlalchemy.url", settings.DATABASE_URL.replace("%", "%%")
)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_server_default=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_server_default=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
