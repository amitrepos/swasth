#!/usr/bin/env bash
# jira_transition.sh — transition a JIRA ticket to a named status.
#
# Usage:
#   jira_transition.sh <TICKET_KEY> <TARGET_STATUS_NAME>
#
# Looks up the transition id whose `to.name` matches TARGET_STATUS_NAME
# (case-insensitive), then POSTs the transition. Exits non-zero if no
# matching transition is available from the current state.

set -euo pipefail

TICKET="${1:?ticket key required}"
TARGET="${2:?target status name required}"

: "${JIRA_URL:?JIRA_URL not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL not set}"
: "${JIRA_API_TOKEN:?JIRA_API_TOKEN not set}"

TRANSITIONS=$(curl -sS \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Accept: application/json" \
  "$JIRA_URL/rest/api/3/issue/$TICKET/transitions")

TARGET_LOWER=$(printf '%s' "$TARGET" | tr '[:upper:]' '[:lower:]')
TRANSITION_ID=$(printf '%s' "$TRANSITIONS" | \
  jq -r --arg target "$TARGET_LOWER" '
    .transitions[]
    | select((.to.name | ascii_downcase) == $target)
    | .id' | head -1)

if [[ -z "$TRANSITION_ID" || "$TRANSITION_ID" == "null" ]]; then
  echo "jira_transition: no transition to '$TARGET' available from current state of $TICKET" >&2
  echo "jira_transition: available targets:" >&2
  printf '%s' "$TRANSITIONS" | jq -r '.transitions[].to.name' >&2 || true
  exit 4
fi

HTTP_CODE=$(curl -sS -o /tmp/jira_transition.out -w "%{http_code}" \
  -X POST \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "{\"transition\":{\"id\":\"$TRANSITION_ID\"}}" \
  "$JIRA_URL/rest/api/3/issue/$TICKET/transitions")

if [[ "$HTTP_CODE" != "204" ]]; then
  echo "jira_transition: POST returned $HTTP_CODE for $TICKET" >&2
  cat /tmp/jira_transition.out >&2 || true
  exit 5
fi

echo "jira_transition: $TICKET → $TARGET (transition id $TRANSITION_ID)"
