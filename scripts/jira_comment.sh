#!/usr/bin/env bash
# jira_comment.sh — post a comment to a JIRA ticket.
#
# Usage:
#   jira_comment.sh <TICKET_KEY> <comment-text-or-@file>
#
# If the second arg starts with @, the rest is treated as a file path whose
# contents are used as the comment body. Comment body is run through
# phi_scrub.py before being POSTed.
#
# Closes Matt audit C5 (PHI leakage into JIRA comments).

set -euo pipefail

TICKET="${1:?ticket key required}"
BODY_ARG="${2:?comment body or @file required}"

: "${JIRA_URL:?JIRA_URL not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL not set}"
: "${JIRA_API_TOKEN:?JIRA_API_TOKEN not set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$BODY_ARG" == @* ]]; then
  BODY_FILE="${BODY_ARG:1}"
  RAW_BODY=$(<"$BODY_FILE")
else
  RAW_BODY="$BODY_ARG"
fi

SCRUBBED_BODY=$(printf '%s' "$RAW_BODY" | python3 "$SCRIPT_DIR/phi_scrub.py")

# Build ADF body via jq (always available in GHA runners and dev macOS via brew).
JSON_PAYLOAD=$(jq -nc --arg text "$SCRUBBED_BODY" '
  {
    body: {
      type: "doc",
      version: 1,
      content: [
        { type: "paragraph", content: [ { type: "text", text: $text } ] }
      ]
    }
  }')

HTTP_CODE=$(curl -sS -o /tmp/jira_comment.out -w "%{http_code}" \
  -X POST \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "$JSON_PAYLOAD" \
  "$JIRA_URL/rest/api/3/issue/$TICKET/comment")

if [[ "$HTTP_CODE" != "201" ]]; then
  echo "jira_comment: POST returned $HTTP_CODE for $TICKET" >&2
  cat /tmp/jira_comment.out >&2 || true
  exit 4
fi

echo "jira_comment: posted comment on $TICKET"
