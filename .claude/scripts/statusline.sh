#!/usr/bin/env bash
# Swasth statusline — delegates model / cost / context / burn-rate to ccusage
# (https://github.com/ryoppippi/ccusage) and appends branch + session nudges
# that ccusage does not provide (compact-now, fresh-session, save-session).
#
# Output layout:
#   <ccusage line>  │ <branch>  <nudges>
#
# Install once: npm install -g ccusage

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/Users/amitkumarmishra/workspace/swasth/swasth_app}"
STATE_DIR="$PROJECT_DIR/.claude/statusline-state"
mkdir -p "$STATE_DIR"

INPUT="$(cat)"
get() { echo "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }

# -----------------------------------------------------------------------------
# 1. Delegate to ccusage. Cache-backed; falls back to empty string if missing.
# -----------------------------------------------------------------------------
CCUSAGE_LINE=""
if command -v ccusage >/dev/null 2>&1; then
  CCUSAGE_LINE="$(echo "$INPUT" | ccusage statusline --visual-burn-rate emoji 2>/dev/null || true)"
fi

# -----------------------------------------------------------------------------
# 2. Our own signals: branch + session-duration nudges + turn-count nudges.
#    (ccusage already surfaces cost, model, context, and block reset time.)
# -----------------------------------------------------------------------------
SESSION_ID="$(get '.session_id')"; [[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"
CWD="$(get '.workspace.current_dir')"; [[ -z "$CWD" ]] && CWD="$(get '.cwd')"; [[ -z "$CWD" ]] && CWD="$PROJECT_DIR"
TURNS="$(get '.transcript.message_count')"; [[ -z "$TURNS" ]] && TURNS=0

START_FILE="$STATE_DIR/${SESSION_ID}.start"
[[ ! -f "$START_FILE" ]] && date +%s > "$START_FILE"
SESSION_START="$(cat "$START_FILE" 2>/dev/null || echo 0)"
DURATION_MIN=$(( ($(date +%s) - SESSION_START) / 60 ))

BRANCH="$(git -C "$CWD" branch --show-current 2>/dev/null || echo '-')"
[[ -z "$BRANCH" ]] && BRANCH="-"

NUDGES=""
(( DURATION_MIN > 90 )) && NUDGES="$NUDGES ⏰save-session"
(( TURNS > 60 )) && NUDGES="$NUDGES 💤fresh-session"

RESET=$'\033[0m'; DIM=$'\033[2m'; GREEN=$'\033[32m'

# -----------------------------------------------------------------------------
# 3. Emit. If ccusage is present, its line leads; we append branch + nudges.
#    If absent, emit a minimal line so the user still sees something useful.
# -----------------------------------------------------------------------------
# Line 1: always ccusage (or fallback).
if [[ -n "$CCUSAGE_LINE" ]]; then
  printf '%s\n' "$CCUSAGE_LINE"
else
  printf '(ccusage not installed — npm i -g ccusage)\n'
fi

# Line 2: always shown so the user has a stable, predictable layout.
# Displays branch + any active nudges; prints "ok" placeholder when quiet.
printf '%s└─%s %s%s%s  session %dm · turns %d%s%s\n' \
  "$DIM" "$RESET" \
  "$GREEN" "$BRANCH" "$RESET" \
  "$DURATION_MIN" "$TURNS" \
  "${NUDGES:+  }" "$NUDGES"
