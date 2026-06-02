#!/usr/bin/env bash
# jira_add_label.sh — add one or more labels to a JIRA ticket (idempotent).
#
# Usage:
#   jira_add_label.sh <TICKET_KEY> <label> [<label> ...]
#   jira_add_label.sh NUO-156 ai-ready
#
# Unlike jira_set_status_label.sh (which manages only the agent-status:* namespace and replaces),
# this ADDS arbitrary labels without touching others. Used by the grooming flow for
# ai-ready / needs-split / needs-human. Adding a label that already exists is a no-op.
set -euo pipefail

TICKET="${1:?ticket key required}"
shift
[[ "$#" -ge 1 ]] || { echo "jira_add_label: at least one label required" >&2; exit 2; }

: "${JIRA_URL:?JIRA_URL not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL not set}"
: "${JIRA_API_TOKEN:?JIRA_API_TOKEN not set}"

# Build the update.labels add-operations array from the remaining args.
OPS=$(printf '%s\n' "$@" | jq -R '{add: .}' | jq -cs '.')
BODY=$(jq -nc --argjson ops "$OPS" '{update: {labels: $ops}}')

HTTP_CODE=$(curl -sS -o /tmp/jira_add_label.out -w "%{http_code}" \
  -X PUT \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data "$BODY" \
  "$JIRA_URL/rest/api/3/issue/$TICKET")

if [[ "$HTTP_CODE" == "204" ]]; then
  echo "jira_add_label: $TICKET += [$*]"
  exit 0
fi

echo "jira_add_label: failed (HTTP $HTTP_CODE) adding [$*] to $TICKET" >&2
cat /tmp/jira_add_label.out >&2 || true
exit 5
