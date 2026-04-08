#!/bin/bash
# Save session state when Claude Code session ends
# Called by Stop hook in settings.local.json

PROJECT_DIR="/Users/amitkumarmishra/workspace/swasth/swasth_app"
SESSIONS_DIR="$PROJECT_DIR/.claude/sessions"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M')
SESSION_FILE="$SESSIONS_DIR/session_${TIMESTAMP}.md"

# Get git info
BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
LAST_COMMIT=$(git -C "$PROJECT_DIR" log --oneline -1 2>/dev/null || echo "none")
DIFF_STAT=$(git -C "$PROJECT_DIR" diff --stat 2>/dev/null || echo "clean")
UNCOMMITTED=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# Get recent AUDIT.md entries (last 10 lines)
RECENT_AUDIT=$(tail -10 "$PROJECT_DIR/AUDIT.md" 2>/dev/null || echo "no audit")

cat > "$SESSION_FILE" << EOF
# Session: ${TIMESTAMP}
Branch: ${BRANCH}
Last commit: ${LAST_COMMIT}
Uncommitted files: ${UNCOMMITTED}

## Changes this session
${DIFF_STAT}

## Recent audit entries
${RECENT_AUDIT}

## Learnings
<!-- Auto-populated by /learn skill if used -->
EOF

# Keep symlink to latest session for easy loading
ln -sf "$SESSION_FILE" "$SESSIONS_DIR/latest.md"

# Prune old sessions (keep last 20)
ls -t "$SESSIONS_DIR"/session_*.md 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null

echo "Session saved: $SESSION_FILE"
