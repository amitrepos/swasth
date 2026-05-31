#!/usr/bin/env bash
# PreToolUse(Edit|Write) guard — WS2 deterministic config protection.
#
# Fails CLOSED (exit 1, blocking the tool call) on any attempt to Edit/Write a gate or policy file.
# These files are the spec for the whole automation; an agent (or a careless edit) must not weaken
# them. Legitimate changes to these files go through a normal, human-reviewed PR — set the audited
# escape hatch SWASTH_BYPASS_CONFIG_EDIT=1 for that.
#
# Input: tool JSON on stdin (Claude Code) with a fallback to $TOOL_INPUT. We extract .tool_input.file_path
# (newer schema) or .file_path (older schema).
set -euo pipefail

# Audited escape hatch for deliberate, human-reviewed gate edits.
if [[ "${SWASTH_BYPASS_CONFIG_EDIT:-}" == "1" ]]; then
  exit 0
fi

raw="$(cat 2>/dev/null || true)"
[[ -z "$raw" ]] && raw="${TOOL_INPUT:-}"
[[ -z "$raw" ]] && exit 0   # nothing to inspect → don't block

fp="$(printf '%s' "$raw" | jq -r '(.tool_input.file_path // .file_path // "")' 2>/dev/null || true)"
[[ -z "$fp" ]] && exit 0

# Protected path patterns (substring match against the absolute or relative path).
case "$fp" in
  */.github/workflows/*|\
  */.githooks/*|\
  */.github/CODEOWNERS|*/CODEOWNERS|\
  */.claude/markers/*|\
  */.claude/settings.json|*/.claude/settings.local.json|\
  */.claude/scripts/check-required-reviewers.sh|\
  */.claude/scripts/write-review-marker.sh|\
  */.claude/scripts/check-agent-branch-policy.sh|\
  */.claude/scripts/check-migration-required.sh|\
  */.claude/scripts/hook-guard-*.sh)
    echo "BLOCKED (WS2 config protection): '$fp' is a gate/policy file." >&2
    echo "These change the automation's guarantees and must go through a human-reviewed PR." >&2
    echo "If this is an intentional, reviewed change, re-run with SWASTH_BYPASS_CONFIG_EDIT=1 (audited)." >&2
    exit 1
    ;;
esac

exit 0
