#!/usr/bin/env bash
# Shared audit-logging helper for the WS2 guard hooks (WS8 observability).
#
# When SWASTH_AGENT_AUDIT_LOG points at a file, guards append one JSON line per interesting decision
# (block / audit / bypass). When it is unset (interactive dev), this is a no-op — zero behaviour
# change. The log is JSONL so scripts/summarize_agent_audit.py can aggregate it and flag alerts.
#
# Usage in a guard:
#   source "$(dirname "$0")/hook-audit-lib.sh" 2>/dev/null || true
#   command -v swasth_audit_event >/dev/null 2>&1 || swasth_audit_event() { :; }   # fallback no-op
#   swasth_audit_event "command" "block" "curl"

swasth_audit_event() {
  # $1 = guard name, $2 = event (block|audit|bypass), $3 = detail
  [ -n "${SWASTH_AGENT_AUDIT_LOG:-}" ] || return 0
  local ts d
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
  d="${3//\\/\\\\}"; d="${d//\"/\\\"}"   # minimal JSON escaping (backslash, quote)
  printf '{"ts":"%s","guard":"%s","event":"%s","detail":"%s"}\n' \
    "$ts" "$1" "$2" "$d" >> "$SWASTH_AGENT_AUDIT_LOG" 2>/dev/null || true
}
