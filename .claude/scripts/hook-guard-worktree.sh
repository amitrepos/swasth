#!/usr/bin/env bash
# PreToolUse(Edit|Write) guard — WS1/WS2 worktree confinement.
#
# AGENT-CONTEXT ONLY. When a sandboxed agent runs, the worker sets SWASTH_AGENT_WORKTREE=<abs path>
# to the git worktree assigned to that task. This guard then blocks any Edit/Write whose target
# resolves outside that worktree — the agent writes only inside its own scope (no host access, no
# sibling-worktree tampering).
#
# In the interactive developer session SWASTH_AGENT_WORKTREE is unset, so this is a NO-OP (it must
# not interfere with normal work such as writing to ~/.claude/ memory or plans).
#
# Mode (SWASTH_AGENT_WORKTREE_MODE): `audit` logs an out-of-worktree write but does not block (exit 0);
# anything else (default) enforces (exit 1). Audit-first mirrors the egress allowlist rollout.
set -euo pipefail

root="${SWASTH_AGENT_WORKTREE:-}"
[[ -z "$root" ]] && exit 0   # not in an agent sandbox → no confinement here
MODE="${SWASTH_AGENT_WORKTREE_MODE:-block}"

# WS8 audit logging (no-op unless SWASTH_AGENT_AUDIT_LOG is set).
source "$(dirname "$0")/hook-audit-lib.sh" 2>/dev/null || true
command -v swasth_audit_event >/dev/null 2>&1 || swasth_audit_event() { :; }

raw="$(cat 2>/dev/null || true)"
[[ -z "$raw" ]] && raw="${TOOL_INPUT:-}"
[[ -z "$raw" ]] && exit 0

fp="$(printf '%s' "$raw" | jq -r '(.tool_input.file_path // .file_path // "")' 2>/dev/null || true)"
[[ -z "$fp" ]] && exit 0

# Normalise to an absolute path (the file may not exist yet, so resolve the parent dir).
case "$fp" in
  /*) abs="$fp" ;;
  *)  abs="$root/$fp" ;;
esac
dir="$(cd "$(dirname "$abs")" 2>/dev/null && pwd || true)"
[[ -z "$dir" ]] && exit 0          # parent dir missing → let the tool surface the real error
abs="$dir/$(basename "$abs")"

case "$abs" in
  "$root"/*) exit 0 ;;             # inside the assigned worktree → allow
  *)
    if [[ "$MODE" == "audit" ]]; then
      swasth_audit_event "worktree" "audit" "$abs"
      echo "AUDIT (worktree confinement): '$abs' is outside the agent worktree '$root' (would block in enforce mode)." >&2
      exit 0
    fi
    swasth_audit_event "worktree" "block" "$abs"
    echo "BLOCKED (worktree confinement): '$abs' is outside the agent worktree '$root'." >&2
    echo "Sandboxed agents may only write inside their assigned worktree." >&2
    exit 1
    ;;
esac
