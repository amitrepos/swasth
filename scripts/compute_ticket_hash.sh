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

# Hash only the immutable ticket spec — the description body. We
# deliberately exclude everything the automation itself can mutate:
#   - Status (transitioned by drift / Needs Human / In Review)
#   - Labels (added/removed by drift handler)
#   - Comments (added by automation on every step)
#   - ISO8601 timestamps (drift, label adds, etc.)
# Otherwise the worker's recomputed hash would diverge from Priya's the
# moment the automation posts ANY comment between enqueue and pop.
python3 -c '
import re, sys
text = open(sys.argv[1]).read()
# Drop the "## Comments" section entirely (and anything after).
text = re.split(r"\n##\s+Comments\b", text, maxsplit=1)[0]
# Drop volatile header fields.
text = re.sub(r"^-\s+\*\*(?:Status|Labels|Priority)\*\*:.*$", "", text, flags=re.MULTILINE)
# Strip ISO8601 timestamps that might still be embedded.
text = re.sub(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.+-]+", "<TS>", text)
# Collapse blank-line runs.
text = re.sub(r"\n{3,}", "\n\n", text)
print(text.strip(), end="")
' "$TICKET_FILE" | shasum -a 256 | awk '{print $1}'
