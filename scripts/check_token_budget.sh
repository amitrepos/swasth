#!/usr/bin/env bash
# check_token_budget.sh — thin shim around check_token_budget.py.
#
# Usage:
#   check_token_budget.sh <TICKET_KEY> <SIZE_CLASS>
#
# SIZE_CLASS ∈ {small, medium, large}. Worker derives it from the ticket
# body (number of acceptance bullets + presence of complex-surface keywords).

set -euo pipefail

TICKET="${1:?ticket key required}"
SIZE_CLASS="${2:-medium}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PATH="${BUDGET_LOG_PATH:-$SCRIPT_DIR/../agent-budget-log.json}"

TICKET_SIZE_CLASS="$SIZE_CLASS" BUDGET_LOG_PATH="$LOG_PATH" \
  python3 "$SCRIPT_DIR/check_token_budget.py" --size-class "$SIZE_CLASS" --log "$LOG_PATH"
