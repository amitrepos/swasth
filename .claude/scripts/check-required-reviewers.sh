#!/usr/bin/env bash
# check-required-reviewers.sh
#
# Walks the staged diff and computes which domain experts must review the
# changes before commit is allowed. Called as a PreToolUse Bash hook on
# `git commit`. Exits 0 (allow commit) if all required experts have written
# a marker matching the current staged-content hash, otherwise exits 1
# (block commit) and prints which expert must run next.
#
# Marker files live in .claude/markers/ and are gitignored.
# Marker filename format: .review-${expert}-${HASH}
# HASH is the first 12 chars of sha256 of `git diff --cached`.
#
# This script is intentionally permissive on errors — if git or sha256sum
# fails, it allows the commit (defensive default) rather than locking the
# user out of committing entirely. Hard failures should be hook bugs, not
# everyday occurrences.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  exit 0  # Not in a git repo, nothing to gate
fi

cd "$REPO_ROOT"

MARKER_DIR=".claude/markers"
mkdir -p "$MARKER_DIR"

# Compute staged content hash. If diff is empty (no staged changes),
# this is probably an --allow-empty commit or merge — let it through.
STAGED_DIFF="$(git diff --cached 2>/dev/null)"
if [[ -z "$STAGED_DIFF" ]]; then
  exit 0
fi

HASH="$(printf '%s' "$STAGED_DIFF" | shasum -a 256 | cut -c1-12)"
STAGED_FILES="$(git diff --cached --name-only 2>/dev/null)"

if [[ -z "$STAGED_FILES" ]]; then
  exit 0
fi

# Build list of required experts based on file paths in the staged diff.
required=()

# Daniel — always required if any source code changed
if printf '%s\n' "$STAGED_FILES" | grep -qE '\.(dart|py)$'; then
  required+=("daniel")
fi

# UI files: Sunita + Healthify + Dr. Rajesh
if printf '%s\n' "$STAGED_FILES" | grep -qE '^lib/(screens|widgets|theme)/'; then
  required+=("sunita" "aditya" "doctor")
fi

# Localization: Sunita (Hindi naturalness) + Healthify (cultural fit)
if printf '%s\n' "$STAGED_FILES" | grep -qE '^lib/l10n/.*\.arb$'; then
  required+=("sunita" "aditya")
fi

# Health endpoints / classification logic: Doctor + PHI + Legal + Sunita
if printf '%s\n' "$STAGED_FILES" | grep -qE '^backend/(routes_health|health_utils|routes_meals)\.py$'; then
  required+=("doctor" "phi" "legal" "sunita")
fi

# AI service: Doctor + Legal + PHI + Sunita
if printf '%s\n' "$STAGED_FILES" | grep -qE '^backend/ai_service\.py$'; then
  required+=("doctor" "legal" "phi" "sunita")
fi

# Models / schemas / migrations: Legal + PHI
if printf '%s\n' "$STAGED_FILES" | grep -qE '^backend/(models|schemas)\.py$|^backend/migrations/'; then
  required+=("legal" "phi")
fi

# Auth / dependencies: Security + Legal
if printf '%s\n' "$STAGED_FILES" | grep -qE '^backend/(auth|dependencies|routes)\.py$'; then
  required+=("security" "legal")
fi

# Encryption service: PHI + Security
if printf '%s\n' "$STAGED_FILES" | grep -q '^backend/encryption_service\.py$'; then
  required+=("phi" "security")
fi

# Doctor portal files (when they exist)
if printf '%s\n' "$STAGED_FILES" | grep -qE '^backend/routes_doctor\.py$|^lib/screens/doctor_'; then
  required+=("doctor" "legal")
fi

# Admin dashboard files
if printf '%s\n' "$STAGED_FILES" | grep -qE '^backend/(routes_admin|admin_dashboard)'; then
  required+=("legal" "aditya")
fi

# Dependency changes
if printf '%s\n' "$STAGED_FILES" | grep -qE '^pubspec\.yaml$|^backend/requirements\.txt$'; then
  required+=("security")
fi

# Test files: Priya (QA) reviews the tests themselves
if printf '%s\n' "$STAGED_FILES" | grep -qE '^backend/tests/.*\.py$|^test/.*\.dart$'; then
  required+=("priya")
fi

# Tier-1 health-critical code: Priya audits whether tests actually cover boundaries
if printf '%s\n' "$STAGED_FILES" | grep -qE '^backend/(routes_health|health_utils|routes_meals|ai_service|models|schemas)\.py$'; then
  required+=("priya")
fi

# Nothing required? Allow commit. (Check first to avoid set -u on empty array.)
if [[ ${#required[@]} -eq 0 ]]; then
  exit 0
fi

# Dedupe and sort (safe now that we know the array is non-empty)
required=($(printf '%s\n' "${required[@]}" | sort -u))

# Check each required expert for a marker matching the current hash.
missing=()
for expert in "${required[@]}"; do
  marker="$MARKER_DIR/.review-${expert}-${HASH}"
  if [[ ! -f "$marker" ]]; then
    missing+=("$expert")
  fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
  # All markers present — allow commit
  exit 0
fi

# Block commit and print actionable message
{
  echo "BLOCKED: Required domain expert reviews missing for staged commit."
  echo ""
  echo "Staged content hash: $HASH"
  echo "Files staged:"
  printf '  %s\n' $STAGED_FILES
  echo ""
  echo "Required experts (in this order): ${required[*]}"
  echo "Missing markers for: ${missing[*]}"
  echo ""
  echo "Next step: run /${missing[0]}"
  echo ""
  echo "After each expert returns a PASS verdict (no Must Fix items),"
  echo "the expert's skill should call: .claude/scripts/write-review-marker.sh ${missing[0]}"
  echo ""
  echo "Then retry the commit. The hook will re-check and either allow"
  echo "the commit or block on the next missing expert."
  echo ""
  echo "If any expert returns BLOCK (Must Fix items), address the issues"
  echo "in code first, restage, and start the review chain over."
} >&2

exit 1
