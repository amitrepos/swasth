#!/usr/bin/env bash
# PreToolUse(Bash) guard — WS2 command allowlisting in the sandbox.
#
# AGENT-CONTEXT ONLY. When a sandboxed agent runs, the worker sets SWASTH_AGENT_SANDBOX=1. This guard
# then denies arbitrary shell: only a predefined safe set of top-level commands is allowed (git, the
# build/test toolchain, common read-only utilities). Anything else is blocked by default — the agent
# cannot curl|bash an installer, open a reverse shell, or reach the host.
#
# In the interactive developer session SWASTH_AGENT_SANDBOX is unset, so this is a NO-OP. (The
# separate `--no-verify` block in settings.local.json still applies to everyone.)
#
# This is defence-in-depth on top of the network egress allowlist (WS1) — never the only line.
set -euo pipefail

[[ "${SWASTH_AGENT_SANDBOX:-}" == "1" ]] || exit 0   # not in agent sandbox → no-op

raw="$(cat 2>/dev/null || true)"
[[ -z "$raw" ]] && raw="${TOOL_INPUT:-}"
[[ -z "$raw" ]] && exit 0

cmd="$(printf '%s' "$raw" | jq -r '(.tool_input.command // .command // "")' 2>/dev/null || true)"
[[ -z "$cmd" ]] && exit 0

# Safe top-level commands the agent may invoke. Extend deliberately, never to "make something work"
# at the cost of the boundary (brief §7).
ALLOW='^(git|gh|flutter|dart|python3?|pip3?|pytest|ruff|black|node|npm|npx|ls|cat|head|tail|grep|rg|sed|awk|echo|printf|cd|mkdir|cp|mv|test|true|false|env|pwd|find|sort|uniq|wc|diff|jq|bash|sh)$'

# Inspect each command in a pipeline / && / ; chain. Block if ANY segment's leading token is not
# allowed. Split on shell separators; process substitution keeps the while-loop in the current shell
# (bash 3.2 compatible — no `mapfile`) so a block can `exit 1` the whole guard.
while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"   # ltrim
  [[ -z "$seg" ]] && continue
  tok="${seg%%[[:space:]]*}"             # first word
  tok="${tok##*/}"                        # strip any path prefix
  [[ "$tok" == *=* ]] && continue        # leading env assignment (VAR=val) → skip
  if ! printf '%s' "$tok" | grep -qE "$ALLOW"; then
    echo "BLOCKED (sandbox command allowlist): '$tok' is not in the safe set." >&2
    echo "Arbitrary shell is denied inside the agent sandbox. Surface the blocker; do not widen the list to work around it." >&2
    exit 1
  fi
done < <(printf '%s\n' "$cmd" | tr ';|&\n' '\n')
exit 0
