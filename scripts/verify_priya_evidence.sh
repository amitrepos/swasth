#!/usr/bin/env bash
# verify_priya_evidence.sh — mechanical check that Priya's PASS verdict is
# substantiated by ticket-body evidence.
#
# Usage:
#   verify_priya_evidence.sh <PRIYA_OUTPUT_FILE> <TICKET_MD>
#
# Greps PRIYA_OUTPUT_FILE for lines matching:
#   Check N (<topic>): "<quote>" — ...
# For each such line, verifies the quote appears verbatim in TICKET_MD.
# Exits 0 if all checks substantiate, else exits non-zero (caller should
# force the verdict to NEEDS_INFO).
#
# Closes Matt audit M3 (Priya hallucination detector).

set -euo pipefail

PRIYA_OUT="${1:?priya output file required}"
TICKET_MD="${2:?ticket brief required}"

REQUIRED_CHECKS=7
FAILED=0
FOUND=0

while IFS= read -r line; do
  if [[ ! "$line" =~ ^Check[[:space:]]+[0-9]+ ]]; then
    continue
  fi
  FOUND=$((FOUND + 1))
  # Extract the quoted substring (first "..." pair on the line).
  quote=$(printf '%s' "$line" | sed -E 's/^[^"]*"([^"]*)".*/\1/')
  if [[ -z "$quote" || "$quote" == "$line" ]]; then
    echo "verify_priya_evidence: check missing quoted evidence: $line" >&2
    FAILED=$((FAILED + 1))
    continue
  fi
  if ! grep -qF -- "$quote" "$TICKET_MD"; then
    echo "verify_priya_evidence: quote not found in ticket body: '$quote'" >&2
    FAILED=$((FAILED + 1))
  fi
done < "$PRIYA_OUT"

if (( FOUND < REQUIRED_CHECKS )); then
  echo "verify_priya_evidence: expected $REQUIRED_CHECKS evidence lines, found $FOUND" >&2
  exit 8
fi
if (( FAILED > 0 )); then
  echo "verify_priya_evidence: $FAILED of $FOUND evidence lines could not be substantiated" >&2
  exit 9
fi

echo "verify_priya_evidence: all $FOUND evidence quotes verified against ticket body."
