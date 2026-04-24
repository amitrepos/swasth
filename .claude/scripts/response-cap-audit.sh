#!/usr/bin/env bash
# Stop hook — audits the just-completed assistant response against the
# 100-word bullet cap. Logs violations to .claude/response-cap-violations.log
# and prints a visible warning so the next turn self-corrects.
#
# Limitations: hooks can't truncate a streamed reply. This is an AFTER-THE-FACT
# auditor. The UserPromptSubmit injector is the primary enforcement; this
# audit exists so repeated violations are visible and correctable.

set -euo pipefail

PROJECT_DIR="/Users/amitkumarmishra/workspace/swasth/swasth_app"
LOG="$PROJECT_DIR/.claude/response-cap-violations.log"
CAP_WORDS=100

# Read hook JSON. Claude Code passes the transcript path in `.transcript_path`
# (JSONL file, one message per line). Find the last assistant message and
# extract its text content.
HOOK_JSON="$(cat)"
TRANSCRIPT="$(echo "$HOOK_JSON" | jq -r '.transcript_path // ""' 2>/dev/null || true)"
LAST_PROMPT="$(echo "$HOOK_JSON" | jq -r '.prompt // .user_prompt // ""' 2>/dev/null || true)"

if [[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]]; then
  exit 0
fi

# Extract the last assistant message's concatenated text blocks.
LAST_ASSISTANT="$(
  jq -r '
    select(.type=="assistant") |
    .message.content // [] |
    map(select(.type=="text") | .text) |
    join(" ")
  ' "$TRANSCRIPT" 2>/dev/null | tail -n 1 || true
)"

[[ -z "$LAST_ASSISTANT" ]] && exit 0

# Check for elaborate-trigger in the last user prompt (same list as injector).
TRIGGERS='elaborate|long version|detailed plan|deep dive|draft the full thing|write the doc|full answer|expand|give me the long|write the file|long form'
if echo "$LAST_PROMPT" | tr '[:upper:]' '[:lower:]' | grep -Eq "$TRIGGERS"; then
  # User asked for elaboration — skip the audit.
  exit 0
fi

# Heuristic exceptions: if the reply is dominated by code fences, treat as
# "length driven by the work" and skip (covers code-diff and write-a-doc cases).
CODE_CHAR_COUNT="$(echo "$LAST_ASSISTANT" | grep -oE '```[^`]*```' | wc -c | tr -d ' ')"
TOTAL_CHAR_COUNT="$(echo -n "$LAST_ASSISTANT" | wc -c | tr -d ' ')"
if [[ "$TOTAL_CHAR_COUNT" -gt 0 && "$CODE_CHAR_COUNT" -gt 0 ]]; then
  # If >40% of the reply is inside code fences, skip.
  if (( CODE_CHAR_COUNT * 100 / TOTAL_CHAR_COUNT > 40 )); then
    exit 0
  fi
fi

# Strip code fences before word-counting (code length isn't chat length).
PROSE="$(echo "$LAST_ASSISTANT" | sed -E 's/```[^`]*```/ /g')"
WORD_COUNT="$(echo "$PROSE" | wc -w | tr -d ' ')"

# Bullet check: look for at least one bullet line (-, *, or numbered).
HAS_BULLETS="no"
if echo "$PROSE" | grep -Eq '^[[:space:]]*([-*•]|[0-9]+\.)[[:space:]]+'; then
  HAS_BULLETS="yes"
fi

# Offer check: did we end with the invitation to elaborate?
HAS_OFFER="no"
if echo "$PROSE" | tail -c 200 | grep -Eiq 'elaborative answer|expand any of these|want.*elaborat|want me to expand'; then
  HAS_OFFER="yes"
fi

VIOLATIONS=()
(( WORD_COUNT > CAP_WORDS )) && VIOLATIONS+=("word_count=${WORD_COUNT}>${CAP_WORDS}")
[[ "$HAS_BULLETS" == "no" ]] && VIOLATIONS+=("no_bullets")
[[ "$HAS_OFFER"   == "no" ]] && VIOLATIONS+=("no_elaboration_offer")

if (( ${#VIOLATIONS[@]} > 0 )); then
  TS="$(date '+%Y-%m-%d %H:%M:%S')"
  {
    echo "[$TS] RESPONSE CAP VIOLATION: ${VIOLATIONS[*]}"
    echo "  prompt: $(echo "$LAST_PROMPT" | head -c 160)"
    echo "  reply_words: $WORD_COUNT | bullets: $HAS_BULLETS | offer: $HAS_OFFER"
    echo "---"
  } >> "$LOG"

  # Surface a warning visible to Claude on the next turn via compact-state.
  {
    echo "## $(date '+%Y-%m-%d %H:%M') — Response cap violation"
    echo "Last reply was ${WORD_COUNT} words (cap=${CAP_WORDS}), bullets=${HAS_BULLETS}, offer=${HAS_OFFER}."
    echo "NEXT REPLY: acknowledge in 1 line ('Trimming to the 100-word bullet format.'), then re-answer short."
    echo "---"
  } >> "$PROJECT_DIR/.claude/compact-state.md"

  # Non-zero exit would block; we just warn.
  echo "⚠ response-cap audit: ${VIOLATIONS[*]} (logged to .claude/response-cap-violations.log)" >&2
fi

exit 0
