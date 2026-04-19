# Swasth backend migrations

Schema changes are managed via [Alembic](https://alembic.sqlalchemy.org/).
This directory holds the migration history; `versions/` contains the
revision files in sequence.

## Why

Before Alembic, schema evolved via hand-written `ALTER` scripts plus
`Base.metadata.create_all()` on backend startup. `create_all()` silently
ignores existing tables, so any new column added to `models.py` after a
table existed in prod was never applied — model said the column existed,
prod said it didn't. That's exactly what blocked the 2026-04-19 weight
update task: PR #133 added `weight_value` / `weight_unit` /
`weight_value_enc` to `models.py`, and they never reached prod.

## How (developer workflow)

1. Edit `backend/models.py` (add a column, change a default, etc.).
2. Generate a migration:
   ```bash
   cd backend
   alembic revision --autogenerate -m "what_changed" --rev-id 0003
   ```
   Use the next sequential rev-id (`ls migrations/versions` to check).
3. **Review the generated file by hand.** Autogenerate is a starting
   point, not a spec — verify it captures exactly what you intended,
   especially for renames (autogenerate sees rename as drop+add and
   loses data).
4. Test the migration locally:
   ```bash
   alembic upgrade head            # applies it
   alembic check                   # confirms models.py == head
   alembic downgrade -1            # exercises the downgrade path
   alembic upgrade head            # back to head
   ```
5. Commit `backend/models.py` AND the new migration file in the **same
   commit**. The pre-commit hook (`check-migration-required.sh`) refuses
   commits where one is staged without the other.

## How (deploy)

`alembic upgrade head` runs **before** the backend restart on each deploy
(see `CLAUDE.md` "Server Deployment" section). It is idempotent — running
it again with no pending revisions is a no-op.

## One-time prod baseline

Recipe for any env that already has the schema but no `alembic_version`
table (e.g. prod as of 2026-04-19).

### Pre-cutover state verification (MANDATORY — run first)

`alembic upgrade head` will fail partway through — leaving prod in an
inconsistent state — if any of the assumptions below are wrong. Verify
every one BEFORE running the cutover. If any fails, STOP and investigate.

```bash
# Expect: empty (alembic not yet adopted on this DB).
ssh root@65.109.226.36 \
  'psql -d swasth_db -tAc "SELECT to_regclass('"'"'alembic_version'"'"')"'
# Expect: 0 (weight columns do not exist yet — they are what 0002 adds).
ssh root@65.109.226.36 \
  "psql -d swasth_db -tAc \"SELECT COUNT(*) FROM information_schema.columns WHERE table_name='health_readings' AND column_name LIKE 'weight%'\""
# Expect: 'Asia/Kolkata' — matches the pre-migration default 0002 reverts to.
ssh root@65.109.226.36 \
  "psql -d swasth_db -tAc \"SELECT column_default FROM information_schema.columns WHERE table_name='users' AND column_name='timezone'\""
# Expect: 'editor' — matches the pre-migration default 0002 reverts to.
ssh root@65.109.226.36 \
  "psql -d swasth_db -tAc \"SELECT column_default FROM information_schema.columns WHERE table_name='profile_invites' AND column_name='access_level'\""
# Expect: 'active' — matches the pre-migration default 0002 reverts to.
ssh root@65.109.226.36 \
  "psql -d swasth_db -tAc \"SELECT column_default FROM information_schema.columns WHERE table_name='doctor_patient_links' AND column_name='status'\""
```

If any value differs from the Expected, the state assumed by this PR
doesn't match prod anymore. Do NOT run the cutover — investigate first.

### Cutover

```bash
ssh root@65.109.226.36
cd /var/www/swasth/backend
pip install 'alembic>=1.13.0'
alembic stamp 0001    # mark prod as already at the empty baseline
alembic upgrade head  # applies 0002 and beyond
# Verify post-cutover:
psql -d swasth_db -c "\d health_readings" | grep weight
psql -d swasth_db -c "SELECT column_default FROM information_schema.columns WHERE table_name IN ('users','profile_invites','doctor_patient_links') AND column_name IN ('timezone','access_level','status') ORDER BY table_name;"
```

The first revision (`0001_baseline.py`) is intentionally empty — it
exists to establish the tracking row in `alembic_version`. Prod is
stamped to `0001` (no DDL run), then `0002` applies normally.

## Cross-DB note

These migrations target **Postgres**. Tests use SQLite via
`Base.metadata.create_all()` in `tests/conftest.py` — they do NOT run
Alembic. So Postgres-specific operations (e.g. `ALTER COLUMN ... SET
DEFAULT`) are fine; we never need cross-DB compatibility from a
migration file.
