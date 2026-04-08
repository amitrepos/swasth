#!/bin/bash
# Load previous session context when Claude Code starts
# Called by SessionStart hook in settings.local.json

PROJECT_DIR="/Users/amitkumarmishra/workspace/swasth/swasth_app"
SESSIONS_DIR="$PROJECT_DIR/.claude/sessions"
LATEST="$SESSIONS_DIR/latest.md"
LEARNINGS_DIR="$PROJECT_DIR/.claude/learnings"

if [ -f "$LATEST" ]; then
  echo "=== PREVIOUS SESSION ==="
  cat "$LATEST"
  echo ""
fi

# Load active learnings
if [ -d "$LEARNINGS_DIR" ] && [ "$(ls -A "$LEARNINGS_DIR" 2>/dev/null)" ]; then
  echo "=== PROJECT LEARNINGS ==="
  for f in "$LEARNINGS_DIR"/*.md; do
    [ -f "$f" ] && cat "$f" && echo ""
  done
fi

# Show current git state
echo "=== CURRENT STATE ==="
echo "Branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null)"
echo "Last commit: $(git -C "$PROJECT_DIR" log --oneline -1 2>/dev/null)"
echo "Uncommitted: $(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ') files"
