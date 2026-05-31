#!/usr/bin/env bash
# jira_assign.sh — (re)assign a JIRA ticket to a user by accountId.
#
# Usage:
#   jira_assign.sh <TICKET_KEY> <ACCOUNT_ID>
#   jira_assign.sh NUO-92 5b10ac8d82e05b22cc7d4ef5
#
# Used by the assignee-driven flow to hand a ticket from Priya to Matt automatically after Priya's
# gate passes. Pass accountId "-1" to set the default assignee, or "null" to unassign.
set -euo pipefail

TICKET="${1:?ticket key required}"
ACCOUNT_ID="${2:?accountId required (or -1 default / null unassign)}"

: "${JIRA_URL:?JIRA_URL not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL not set}"
: "${JIRA_API_TOKEN:?JIRA_API_TOKEN not set}"

if [[ "$ACCOUNT_ID" == "null" ]]; then
  BODY='{"accountId": null}'
else
  BODY=$(jq -nc --arg a "$ACCOUNT_ID" '{accountId: $a}')
fi

HTTP_CODE=$(curl -sS -o /tmp/jira_assign.out -w "%{http_code}" \
  -X PUT \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data "$BODY" \
  "$JIRA_URL/rest/api/3/issue/$TICKET/assignee")

if [[ "$HTTP_CODE" == "204" ]]; then
  echo "jira_assign: $TICKET → assignee $ACCOUNT_ID"
  exit 0
fi

echo "jira_assign: failed (HTTP $HTTP_CODE) assigning $TICKET to $ACCOUNT_ID" >&2
cat /tmp/jira_assign.out >&2 || true
exit 5
