#!/bin/bash
# Refuse a commit that changes backend/models.py without a new Alembic
# migration in the same commit.
#
# Why this exists: PR #133 (2026-04-19) added three columns to
# HealthReading in models.py and shipped without a migration because the
# project had no Alembic. The deploy mechanism, Base.metadata.create_all(),
# silently ignores existing tables, so the new columns reached every dev
# DB but never reached prod. The downstream weight-update task discovered
# the gap weeks later.
#
# After Alembic was scaffolded, the obvious next failure mode is "edited
# models.py, forgot to generate a migration." This hook closes that hole
# deterministically — no relying on memory or CLAUDE.md prose.
#
# Heuristic: any staged change to backend/models.py requires a new file
# under backend/migrations/versions/ to also be staged. False positives
# (pure docstring/comment edits) are accepted as a tax — the escape hatch
# is `SWASTH_NO_MIGRATION_NEEDED=1 git commit ...` for the rare case.
#
# CI re-runs `alembic check` against ephemeral Postgres
# (.github/workflows/migration-check.yml) — that's the second layer that
# catches "yes you have a migration but it doesn't actually match the
# model change."

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

# Files staged for this commit (Added, Copied, Modified, Renamed).
staged="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"

if ! echo "$staged" | grep -qx "backend/models.py"; then
  exit 0  # models.py not in this commit — nothing to enforce.
fi

# models.py is staged. Require at least one NEW migration file alongside.
new_migrations="$(git diff --cached --name-only --diff-filter=A 2>/dev/null \
  | grep -E '^backend/migrations/versions/.*\.py$' || true)"

if [[ -n "$new_migrations" ]]; then
  exit 0  # at least one new migration file is staged. Pass.
fi

if [[ "${SWASTH_NO_MIGRATION_NEEDED:-}" == "1" ]]; then
  echo "[check-migration-required] SWASTH_NO_MIGRATION_NEEDED=1 set — allowing commit." >&2
  exit 0
fi

{
  echo "BLOCKED: backend/models.py is staged without a new Alembic migration."
  echo ""
  echo "Schema changes must ship with their migration in the same commit so prod"
  echo "stays in sync. PR #133 violated this and broke weight tracking in prod;"
  echo "this hook exists so we never repeat that."
  echo ""
  echo "To fix:"
  echo "  cd backend"
  echo "  alembic revision --autogenerate -m '<short_description>' --rev-id <NNNN>"
  echo "      # use the next sequential id; ls migrations/versions to check"
  echo "  # Review the generated file by hand — autogenerate is a draft."
  echo "  alembic upgrade head    # try it locally against your dev Postgres"
  echo "  alembic check           # confirms models.py == migration head"
  echo "  git add backend/migrations/versions/<new_file>.py"
  echo "  git commit ..."
  echo ""
  echo "If this commit genuinely makes no schema change (docstrings, comments,"
  echo "type hints on existing fields, etc.) and you've verified with"
  echo "  cd backend && alembic check"
  echo "then bypass this check for THIS commit only:"
  echo "  SWASTH_NO_MIGRATION_NEEDED=1 git commit ..."
} >&2
exit 1
