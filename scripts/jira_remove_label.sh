#!/usr/bin/env bash
# jira_remove_label.sh — remove a label from a JIRA ticket.
#
# Usage:
#   jira_remove_label.sh <TICKET_KEY> <LABEL>
#
# Used by Priya when she returns NEEDS_INFO — removes the `agent:*` label so
# the automation cannot re-fire until the user re-adds it.

set -euo pipefail

TICKET="${1:?ticket key required}"
LABEL="${2:?label required}"

: "${JIRA_URL:?JIRA_URL not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL not set}"
: "${JIRA_API_TOKEN:?JIRA_API_TOKEN not set}"

PAYLOAD=$(jq -nc --arg label "$LABEL" '
  { update: { labels: [ { remove: $label } ] } }')

HTTP_CODE=$(curl -sS -o /tmp/jira_remove_label.out -w "%{http_code}" \
  -X PUT \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "$PAYLOAD" \
  "$JIRA_URL/rest/api/3/issue/$TICKET")

if [[ "$HTTP_CODE" != "204" ]]; then
  echo "jira_remove_label: PUT returned $HTTP_CODE for $TICKET" >&2
  cat /tmp/jira_remove_label.out >&2 || true
  exit 4
fi

echo "jira_remove_label: removed '$LABEL' from $TICKET"
