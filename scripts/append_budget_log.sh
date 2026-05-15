#!/usr/bin/env bash
# append_budget_log.sh — append a completed run to agent-budget-log.json.
#
# Usage:
#   append_budget_log.sh <TICKET> <SIZE_CLASS> <INPUT_TOK> <OUTPUT_TOK> <DURATION_MIN>
#
# C1 fix: mutation runs INSIDE the rebase loop.

set -euo pipefail

TICKET="${1:?ticket required}"
SIZE_CLASS="${2:?size class required}"
INPUT_TOK="${3:?input tokens required}"
OUTPUT_TOK="${4:?output tokens required}"
DURATION_MIN="${5:?duration required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRITE_HELPER="$SCRIPT_DIR/write_to_automation_state.sh"

export ABL_TICKET="$TICKET"
export ABL_SIZE_CLASS="$SIZE_CLASS"
export ABL_INPUT_TOK="$INPUT_TOK"
export ABL_OUTPUT_TOK="$OUTPUT_TOK"
export ABL_DURATION_MIN="$DURATION_MIN"
export ABL_NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

MUTATOR=$(cat <<'MUT'
  if [ "$CURRENT" = "/dev/null" ] || [ ! -s "$CURRENT" ]; then
    INPUT='{"schema_version":1,"defaults_until_seeded":{"input_tokens":500000,"output_tokens":200000,"duration_min":30},"runs":[]}'
  else
    INPUT=$(cat "$CURRENT")
  fi
  printf '%s' "$INPUT" | jq \
    --arg ticket "$ABL_TICKET" \
    --arg size_class "$ABL_SIZE_CLASS" \
    --argjson input_tokens "$ABL_INPUT_TOK" \
    --argjson output_tokens "$ABL_OUTPUT_TOK" \
    --argjson duration_min "$ABL_DURATION_MIN" \
    --arg completed_at "$ABL_NOW" \
    '
      .runs = ((.runs // []) + [{
        ticket_key:$ticket,
        size_class:$size_class,
        input_tokens:$input_tokens,
        output_tokens:$output_tokens,
        duration_min:$duration_min,
        completed_at:$completed_at
      }])
      | .runs |= (if length > 200 then .[-200:] else . end)
    ' > "$NEXT"
MUT
)

"$WRITE_HELPER" "agent-budget-log.json" --mutator "$MUTATOR" \
  "budget-log: append $TICKET ($SIZE_CLASS, ${INPUT_TOK}in/${OUTPUT_TOK}out)"

echo "append_budget_log: appended $TICKET"
