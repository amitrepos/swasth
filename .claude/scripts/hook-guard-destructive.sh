#!/usr/bin/env bash
# PreToolUse(Bash) guard — WS2 destructive-operation block (folds the old `safety-guard` skill into a
# deterministic hook). Always-on for everyone (not just the sandbox); the probabilistic skill could be
# skimmed, a hook cannot.
#
# Blocks the unambiguously dangerous shapes. Escape hatch for a deliberate, understood operation:
# SWASTH_ALLOW_DESTRUCTIVE=1 (audited).
set -euo pipefail

# WS8 audit logging (no-op unless SWASTH_AGENT_AUDIT_LOG is set).
source "$(dirname "$0")/hook-audit-lib.sh" 2>/dev/null || true
command -v swasth_audit_event >/dev/null 2>&1 || swasth_audit_event() { :; }

if [[ "${SWASTH_ALLOW_DESTRUCTIVE:-}" == "1" ]]; then
  swasth_audit_event "destructive" "bypass" "SWASTH_ALLOW_DESTRUCTIVE=1"
  exit 0
fi

raw="$(cat 2>/dev/null || true)"
[[ -z "$raw" ]] && raw="${TOOL_INPUT:-}"
[[ -z "$raw" ]] && exit 0

cmd="$(printf '%s' "$raw" | jq -r '(.tool_input.command // .command // "")' 2>/dev/null || true)"
[[ -z "$cmd" ]] && exit 0

block() {
  swasth_audit_event "destructive" "block" "$1"
  echo "BLOCKED (WS2 destructive-op guard): $1" >&2
  echo "If this is intentional and understood, re-run with SWASTH_ALLOW_DESTRUCTIVE=1 (audited)." >&2
  exit 1
}

# Normalise whitespace for matching.
norm="$(printf '%s' "$cmd" | tr -s '[:space:]' ' ')"

# 1. Force-push to a shared/protected branch.
if printf '%s' "$norm" | grep -qiE 'git +push .*(--force\b|-f\b)' ; then
  if printf '%s' "$norm" | grep -qiE '(origin )?(master|main)\b'; then
    block "force-push to master/main."
  fi
fi

# 2. rm -rf targeting root, home, or a path that is not clearly under /tmp or the cwd.
if printf '%s' "$norm" | grep -qiE 'rm +(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|-rf|-fr) '; then
  if printf '%s' "$norm" | grep -qiE 'rm +-[rf]+ +(/|~|/\*|\$HOME|/Users/[^ ]*/?$|\. )'; then
    block "rm -rf targeting root/home/cwd."
  fi
fi

# 3. Destructive SQL.
if printf '%s' "$norm" | grep -qiE '\b(DROP +(TABLE|DATABASE|SCHEMA)|TRUNCATE +TABLE|DELETE +FROM +[a-z_]+ *;?)\b'; then
  block "destructive SQL (DROP/TRUNCATE/bare DELETE)."
fi

# 4. git reset --hard onto a remote ref (silent loss of local commits).
if printf '%s' "$norm" | grep -qiE 'git +reset +--hard +origin/'; then
  block "git reset --hard onto a remote ref (discards local commits)."
fi

# 5. History rewrite of a shared branch.
if printf '%s' "$norm" | grep -qiE 'git +(push +.*--mirror|update-ref +-d +refs/heads/(master|main))'; then
  block "branch deletion / mirror push of a protected ref."
fi

exit 0
