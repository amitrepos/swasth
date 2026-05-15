#!/usr/bin/env bash
# verify_queue_entry.sh — drift-check that a popped queue entry still matches
# the JIRA ticket Priya approved.
#
# Usage:
#   verify_queue_entry.sh <TICKET_KEY> <EXPECTED_PRIYA_HASH>
#
# Recomputes the SHA-256 of the current JIRA ticket's normalized body and
# compares against the hash captured at enqueue time. Exits non-zero if
# they differ — the caller (worker) then routes the entry back to Priya.
#
# Closes Matt audit "drift / staleness" (the M1 fix has the worker also
# pin origin/master SHA at pop time and rebase later).

set -euo pipefail

TICKET="${1:?ticket key required}"
EXPECTED_HASH="${2:?expected priya_hash required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TICKET_PATH="/tmp/verify_ticket.md"

# Reuse jira_fetch_ticket.py to render canonical brief.
JIRA_FETCH="$SCRIPT_DIR/jira_fetch_ticket.py"
python3 "$JIRA_FETCH" "$TICKET" --out "$TICKET_PATH" >/dev/null

# Strip volatile lines (timestamps) before hashing so re-renders are stable.
NORMALIZED=$(sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.+-]+/<TS>/g' "$TICKET_PATH")
CURRENT_HASH=$(printf '%s' "$NORMALIZED" | shasum -a 256 | awk '{print $1}')

if [[ "$CURRENT_HASH" != "$EXPECTED_HASH" ]]; then
  echo "verify_queue_entry: DRIFT detected for $TICKET" >&2
  echo "verify_queue_entry: expected $EXPECTED_HASH, got $CURRENT_HASH" >&2
  exit 6
fi

echo "verify_queue_entry: $TICKET hash matches ($CURRENT_HASH)"
