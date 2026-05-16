#!/usr/bin/env bash
# jira_set_status_label.sh — swap the current agent-status:* label.
#
# Usage:
#   jira_set_status_label.sh <TICKET_KEY> <NEW_STATUS_SUFFIX>
#
# Removes ALL existing agent-status:* labels from the ticket, then adds
# agent-status:<NEW_STATUS_SUFFIX>. Idempotent.
#
# Lifecycle suffixes: enqueued | in-flight | pr-opened | needs-human |
# deferred | drift | qa-must-fix.

set -euo pipefail

TICKET="${1:?ticket key required}"
NEW_STATUS="${2:?status suffix required}"

: "${JIRA_URL:?JIRA_URL not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL not set}"
: "${JIRA_API_TOKEN:?JIRA_API_TOKEN not set}"

# Fetch current labels.
CURRENT=$(curl -sS -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "$JIRA_URL/rest/api/3/issue/$TICKET?fields=labels" \
  | jq -r '.fields.labels[]?' || true)

# Build update payload: remove every existing agent-status:* label, add the new one.
declare -a OPERATIONS
while IFS= read -r label; do
  if [[ -n "$label" && "$label" == agent-status:* ]]; then
    OPERATIONS+=("$(jq -nc --arg l "$label" '{remove: $l}')")
  fi
done <<< "$CURRENT"
OPERATIONS+=("$(jq -nc --arg l "agent-status:$NEW_STATUS" '{add: $l}')")

OPS_JSON=$(printf '%s\n' "${OPERATIONS[@]}" | jq -s '.')
PAYLOAD=$(jq -nc --argjson ops "$OPS_JSON" '{update:{labels:$ops}}')

HTTP_CODE=$(curl -sS -o /tmp/jira_status_label.out -w "%{http_code}" \
  -X PUT \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "$PAYLOAD" \
  "$JIRA_URL/rest/api/3/issue/$TICKET")

if [[ "$HTTP_CODE" != "204" ]]; then
  echo "jira_set_status_label: PUT returned $HTTP_CODE for $TICKET" >&2
  cat /tmp/jira_status_label.out >&2 || true
  exit 4
fi

echo "jira_set_status_label: $TICKET → agent-status:$NEW_STATUS"
