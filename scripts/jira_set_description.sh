#!/usr/bin/env bash
# jira_set_description.sh — replace a JIRA ticket's description.
#
# Usage:
#   jira_set_description.sh <TICKET_KEY> @<file>     # file contains JIRA-wiki markup
#   jira_set_description.sh <TICKET_KEY> "<text>"
#
# Uses the v2 API so the body is stored as wiki markup (h2./{{...}}), which jira_fetch_ticket.py then
# renders to `## ` headings + backticks — the form the churn gate parses. Used by the grooming flow so
# Anya's AI-ready rewrite lands in the DESCRIPTION (which the build reads), not only in a comment.
set -euo pipefail

TICKET="${1:?ticket key required}"
ARG="${2:?description text or @file required}"

: "${JIRA_URL:?JIRA_URL not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL not set}"
: "${JIRA_API_TOKEN:?JIRA_API_TOKEN not set}"

if [[ "$ARG" == @* ]]; then
  BODY_TEXT=$(<"${ARG:1}")
else
  BODY_TEXT="$ARG"
fi

PAYLOAD=$(jq -nc --arg d "$BODY_TEXT" '{fields: {description: $d}}')

HTTP_CODE=$(curl -sS -o /tmp/jira_set_description.out -w "%{http_code}" \
  -X PUT \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data "$PAYLOAD" \
  "$JIRA_URL/rest/api/2/issue/$TICKET")

if [[ "$HTTP_CODE" == "204" ]]; then
  echo "jira_set_description: updated $TICKET description"
  exit 0
fi

echo "jira_set_description: failed (HTTP $HTTP_CODE) on $TICKET" >&2
cat /tmp/jira_set_description.out >&2 || true
exit 5
