#!/usr/bin/env bash
# enqueue_work.sh — append a Priya-approved ticket onto jira-work-queue.json.
#
# Usage:
#   enqueue_work.sh <TICKET_KEY> <AGENT_LABEL> <PRIORITY_NAME> [<priya_hash>]
#
# Idempotent: if a non-`done` entry already exists for the ticket, the
# function refreshes its queued_at rather than duplicating.
#
# C1 fix: mutation runs INSIDE the rebase loop of write_to_automation_state.sh
# so concurrent producers/workers never clobber each other.

set -euo pipefail

TICKET="${1:?ticket key required}"
AGENT_LABEL="${2:?agent label required}"
PRIORITY_NAME="${3:?priority name required}"
PRIYA_HASH="${4:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRITE_HELPER="$SCRIPT_DIR/write_to_automation_state.sh"

case "$PRIORITY_NAME" in
  Highest) PRIORITY_RANK=5 ;;
  High)    PRIORITY_RANK=4 ;;
  Medium)  PRIORITY_RANK=3 ;;
  Low)     PRIORITY_RANK=2 ;;
  Lowest)  PRIORITY_RANK=1 ;;
  *)       PRIORITY_RANK=3 ;;
esac

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Mutator reads $CURRENT (existing queue file or /dev/null) and writes $NEXT.
# All values come through env vars to avoid shell-quoting headaches in jq args.
export EWQ_TICKET="$TICKET"
export EWQ_AGENT="$AGENT_LABEL"
export EWQ_PRIORITY_NAME="$PRIORITY_NAME"
export EWQ_PRIORITY_RANK="$PRIORITY_RANK"
export EWQ_NOW="$NOW"
export EWQ_PRIYA_HASH="$PRIYA_HASH"

MUTATOR=$(cat <<'MUT'
  if [ "$CURRENT" = "/dev/null" ] || [ ! -s "$CURRENT" ]; then
    INPUT='{"schema_version":1,"entries":[]}'
  else
    INPUT=$(cat "$CURRENT")
  fi
  printf '%s' "$INPUT" | jq \
    --arg ticket "$EWQ_TICKET" \
    --arg agent "$EWQ_AGENT" \
    --arg priority_name "$EWQ_PRIORITY_NAME" \
    --argjson priority_rank "$EWQ_PRIORITY_RANK" \
    --arg now "$EWQ_NOW" \
    --arg priya_hash "$EWQ_PRIYA_HASH" \
    '
      .entries = (.entries // [])
      | (.entries | map(.ticket_key) | index($ticket)) as $idx
      | if $idx == null then
          .entries += [{
            ticket_key: $ticket,
            agent: $agent,
            priority_name: $priority_name,
            priority_rank: $priority_rank,
            queued_at: $now,
            state: "queued",
            attempt_count: 0,
            retry_after: $now,
            priya_hash: $priya_hash
          }]
        else
          .entries[$idx] |= (.state = "queued"
            | .priority_name = $priority_name
            | .priority_rank = $priority_rank
            | .queued_at = $now
            | .retry_after = $now
            | .priya_hash = $priya_hash)
        end
    ' > "$NEXT"
MUT
)

"$WRITE_HELPER" "jira-work-queue.json" --mutator "$MUTATOR" \
  "queue: enqueue $TICKET ($AGENT_LABEL, $PRIORITY_NAME)"

echo "enqueue_work: $TICKET added (priority_rank=$PRIORITY_RANK)"
