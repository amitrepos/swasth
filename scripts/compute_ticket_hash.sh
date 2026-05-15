#!/usr/bin/env bash
# compute_ticket_hash.sh — canonical hashing for a JIRA ticket brief.
#
# Usage:
#   compute_ticket_hash.sh <path-to-ticket.md>
#
# Strips volatile lines (ISO8601 timestamps from JIRA comment metadata) so
# the hash is stable across re-fetches, then prints the sha256 hex digest.
#
# MUST be used by BOTH Priya (at enqueue) and verify_queue_entry.sh
# (at worker pop time). Mismatched hash routines triggered a false-positive
# drift detection in smoke run 25920554159.

set -euo pipefail

TICKET_FILE="${1:?ticket file required}"

if [[ ! -f "$TICKET_FILE" ]]; then
  echo "compute_ticket_hash: file not found: $TICKET_FILE" >&2
  exit 2
fi

# Strip ISO8601 timestamps to immunise the hash against the JIRA API's
# timestamp formatting changes when comments are present.
sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.+-]+/<TS>/g' "$TICKET_FILE" \
  | shasum -a 256 \
  | awk '{print $1}'
