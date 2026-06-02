#!/usr/bin/env bash
# jira_comment.sh — post a comment to a JIRA ticket (rendered ADF, optional persona identity).
#
# Usage:
#   jira_comment.sh [--as <persona>] <TICKET_KEY> <comment-text-or-@file>
#
# --as <persona>  (matt|priya|daniel|aditya|sunita|doctor|meera|security|phi|legal)
#   Prepends a persona header so the comment clearly reads as that agent, and — if a per-persona
#   credential pair JIRA_<PERSONA>_EMAIL + JIRA_<PERSONA>_TOKEN is set in the environment — posts AS
#   that JIRA account (so the avatar/author is Matt/Priya, not the token owner). Without those creds
#   it falls back to the default token and the header label still removes the confusion.
#
# If the body arg starts with @, the rest is a file path. Body is PHI-scrubbed (phi_scrub.py) and
# converted Markdown→ADF (md_to_adf.py) so JIRA renders headings/bold/bullets instead of raw markup.
#
# Closes Matt audit C5 (PHI leakage) + the "raw ###/** and wrong author" confusion.
set -euo pipefail

PERSONA=""
if [[ "${1:-}" == "--as" ]]; then
  PERSONA="${2:?persona name required after --as}"
  shift 2
fi

TICKET="${1:?ticket key required}"
BODY_ARG="${2:?comment body or @file required}"

: "${JIRA_URL:?JIRA_URL not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL not set}"
: "${JIRA_API_TOKEN:?JIRA_API_TOKEN not set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$BODY_ARG" == @* ]]; then
  RAW_BODY=$(<"${BODY_ARG:1}")
else
  RAW_BODY="$BODY_ARG"
fi

# Resolve persona → display label + (optional) per-persona credentials.
AUTH_EMAIL="$JIRA_EMAIL"
AUTH_TOKEN="$JIRA_API_TOKEN"
HEADER=""
if [[ -n "$PERSONA" ]]; then
  P_UPPER=$(printf '%s' "$PERSONA" | tr '[:lower:]' '[:upper:]')
  case "$(printf '%s' "$PERSONA" | tr '[:upper:]' '[:lower:]')" in
    priya)    LABEL="Priya — ticket-quality / QA gate" ;;
    anya)     LABEL="Anya — backlog grooming" ;;
    matt)     LABEL="Matt — builder" ;;
    daniel)   LABEL="Daniel — code review" ;;
    aditya)   LABEL="Aditya — UX review" ;;
    sunita)   LABEL="Sunita — patient review" ;;
    doctor)   LABEL="Dr. Ramesh — clinical review" ;;
    meera)    LABEL="Meera — necessity" ;;
    security) LABEL="Security review" ;;
    phi)      LABEL="PHI / data-protection review" ;;
    legal)    LABEL="Legal review" ;;
    *)        LABEL="$PERSONA" ;;
  esac
  HEADER="**🤖 ${LABEL}**"
  # Per-persona creds override (avatar = real account) if provided.
  P_EMAIL_VAR="JIRA_${P_UPPER}_EMAIL"; P_TOKEN_VAR="JIRA_${P_UPPER}_TOKEN"
  if [[ -n "${!P_EMAIL_VAR:-}" && -n "${!P_TOKEN_VAR:-}" ]]; then
    AUTH_EMAIL="${!P_EMAIL_VAR}"; AUTH_TOKEN="${!P_TOKEN_VAR}"
  fi
fi

# Scrub PHI, then prepend the persona header.
SCRUBBED_BODY=$(printf '%s' "$RAW_BODY" | python3 "$SCRIPT_DIR/phi_scrub.py")
if [[ -n "$HEADER" ]]; then
  SCRUBBED_BODY="${HEADER}"$'\n\n'"${SCRUBBED_BODY}"
fi

# Markdown → ADF so JIRA renders it (headings/bold/bullets), not raw markup.
ADF_CONTENT=$(printf '%s' "$SCRUBBED_BODY" | python3 "$SCRIPT_DIR/md_to_adf.py")
JSON_PAYLOAD=$(jq -nc --argjson content "$ADF_CONTENT" \
  '{ body: { type: "doc", version: 1, content: $content } }')

HTTP_CODE=$(curl -sS -o /tmp/jira_comment.out -w "%{http_code}" \
  -X POST \
  -u "$AUTH_EMAIL:$AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "$JSON_PAYLOAD" \
  "$JIRA_URL/rest/api/3/issue/$TICKET/comment")

if [[ "$HTTP_CODE" != "201" ]]; then
  echo "jira_comment: POST returned $HTTP_CODE for $TICKET" >&2
  cat /tmp/jira_comment.out >&2 || true
  exit 4
fi

echo "jira_comment: posted comment on $TICKET${PERSONA:+ as $PERSONA}"
