#!/usr/bin/env bash
# verify_priya_evidence.sh — mechanical check that Priya's PASS verdict is
# substantiated by ticket-body evidence.
#
# Usage:
#   verify_priya_evidence.sh <PRIYA_OUTPUT_FILE> <TICKET_MD>
#
# For each `Check N (...): "<quote>" — ...` line in PRIYA_OUTPUT_FILE,
# verifies that the quote is reasonably grounded in TICKET_MD via a
# token-overlap heuristic: at least 75% of "meaningful" tokens in the
# quote (length ≥ 3 chars, not in a small stop-list) must appear in the
# normalised ticket body. Tolerates legitimate rephrasing (bullet markers
# stripped, quote-character variants, line breaks) while still rejecting
# fabricated quotes whose tokens never appear in the body.
#
# Exits 0 on full substantiation, non-zero otherwise.
# Closes Matt audit M3 (Priya hallucination detector).

set -euo pipefail

PRIYA_OUT="${1:?priya output file required}"
TICKET_MD="${2:?ticket brief required}"

REQUIRED_CHECKS=7
MIN_TOKEN_OVERLAP_PCT=75
FAILED=0
FOUND=0

_normalise() {
  python3 -c '
import re, sys, unicodedata
text = sys.stdin.read()
# Unicode quote → straight ASCII.
text = (text.replace("‘","'\''").replace("’","'\''")
            .replace("“","\"").replace("”","\"")
            .replace("–","-").replace("—","-"))
# Lowercase, collapse whitespace, strip common bullet markers.
text = text.lower()
text = re.sub(r"^\s*[-*]\s+", " ", text, flags=re.MULTILINE)
text = re.sub(r"\s+", " ", text).strip()
print(text)
'
}

NORMALISED_BODY=$(_normalise < "$TICKET_MD")

# Tiny stop-list — single-letter / glue words are not "meaningful tokens".
_STOPWORDS_RE='^(the|and|or|of|to|a|an|in|on|for|is|are|be|will|with|by|at|from|that|this|it|as|but|not|no|yes)$'

_token_overlap_pct() {
  # Args: $1 = quote, $2 = normalised body. Prints integer 0..100.
  python3 -c '
import re, sys, unicodedata
quote = sys.argv[1]
body  = sys.argv[2]
# Same normalisation pipeline as the body.
def norm(t):
    t = (t.replace("‘","'\''").replace("’","'\''")
           .replace("“","\"").replace("”","\"")
           .replace("–","-").replace("—","-"))
    t = t.lower()
    t = re.sub(r"[^a-z0-9_.]+"," ", t)
    return t.split()
stop = set("the and or of to a an in on for is are be will with by at from that this it as but not no yes".split())
tokens = [w for w in norm(quote) if len(w) >= 3 and w not in stop]
if not tokens:
    print(100); sys.exit(0)
body_set = set(norm(body))
hit = sum(1 for t in tokens if t in body_set)
print(int(round(100 * hit / len(tokens))))
' "$1" "$2"
}

while IFS= read -r line; do
  if [[ ! "$line" =~ ^Check[[:space:]]+([0-9]+) ]]; then
    continue
  fi
  check_num="${BASH_REMATCH[1]}"
  FOUND=$((FOUND + 1))
  # Check 7 ("No ambiguous language") is an *absence* assertion — it proves a
  # negative (no "improve"/"make better"/"etc." in the ticket). There is no
  # positive quote to ground, so the token-overlap heuristic does not apply.
  # Naming a banned word as the thing being confirmed-absent would (correctly)
  # score 0% against the body. Exempt it from the quote requirement.
  if [[ "$check_num" == "7" ]]; then
    continue
  fi
  quote=$(printf '%s' "$line" | sed -E 's/^[^"]*"([^"]*)".*/\1/')
  if [[ -z "$quote" || "$quote" == "$line" ]]; then
    echo "verify_priya_evidence: check missing quoted evidence: $line" >&2
    FAILED=$((FAILED + 1))
    continue
  fi
  pct=$(_token_overlap_pct "$quote" "$NORMALISED_BODY")
  if (( pct < MIN_TOKEN_OVERLAP_PCT )); then
    echo "verify_priya_evidence: quote token-overlap ${pct}% < ${MIN_TOKEN_OVERLAP_PCT}% threshold: '$quote'" >&2
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
