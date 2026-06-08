#!/usr/bin/env bash
# check_no_regression.sh — Gate C-regress orchestrator.
#
# Order (per Matt audit M6, fail-fast on cheapest signal):
#   1. churn check (fast — runs inside check_no_regression.py)
#   2. unit suite (10m cap)
#   3. integration suite (10m cap, real Postgres)
#   4. smoke / E2E flow suite (10m cap)
#   5. baseline diff (fast)
#
# Each suite writes a tiny JSON summary the Python layer reads.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PY="$REPO_ROOT/scripts/check_no_regression.py"

# Step 0 — verify synthetic-only fixture invariant for integration DB.
if [[ -f backend/tests/fixtures/synthetic.sql ]]; then
  if ! head -3 backend/tests/fixtures/synthetic.sql | grep -qi "SYNTHETIC ONLY"; then
    echo "check_no_regression: backend/tests/fixtures/synthetic.sql missing 'SYNTHETIC ONLY' header" >&2
    exit 7
  fi
fi

# Step 1 — fast churn check ONLY (baseline runs at Step 5, after the suites produce summaries).
python3 "$PY" churn || { code=$?; if [[ $code -eq 2 ]]; then exit 2; fi; }

# Count extraction parses pytest's terminal summary line ("N passed, N failed, ...") — 100% reliable
# and always printed — instead of the `--json-report` plugin, which was emitting null/0 even when the
# suite passed (the NUO-155 "1105→0" false regression). Collection/import errors are surfaced
# explicitly so they read as "fix the import", not "tests regressed".
_pytest_summary() {                          # $1 = pytest marker expr, $2 = output summary json
  local log; log="/tmp/pytest-$(printf '%s' "$1" | tr -c 'a-zA-Z0-9' '_').log"
  ( cd backend && timeout 10m env TESTING=true python -m pytest tests/ -m "$1" -q -p no:cacheprovider ) > "$log" 2>&1 || true
  if grep -qE "errors during collection|ERROR collecting|Interrupted:" "$log"; then
    local ne; ne=$(grep -cE "ERROR collecting" "$log" || echo 0)
    local mods; mods=$(grep -oE "ERROR collecting [^ ]+" "$log" | awk '{print $3}' | paste -sd',' - 2>/dev/null || true)
    echo "{\"passing\":0,\"failures\":0,\"skipped\":0,\"collection_error\":true,\"error_count\":${ne:-0},\"error_modules\":\"${mods}\"}" > "$2"
    echo "check_no_regression: COLLECTION ERROR in: ${mods}" >&2
    return
  fi
  local line p f s
  line=$(grep -E "[0-9]+ (passed|failed|error)" "$log" | tail -1 || true)
  p=$(printf '%s' "$line" | grep -oE "[0-9]+ passed"  | grep -oE "[0-9]+" || true)
  f=$(printf '%s' "$line" | grep -oE "[0-9]+ (failed|error)" | grep -oE "[0-9]+" | paste -sd+ - | bc 2>/dev/null || true)
  s=$(printf '%s' "$line" | grep -oE "[0-9]+ skipped" | grep -oE "[0-9]+" || true)
  echo "{\"passing\":${p:-0},\"failures\":${f:-0},\"skipped\":${s:-0}}" > "$2"
}

# Step 2 — unit suite.
echo "check_no_regression: unit suite..."
if [[ -d backend ]]; then
  _pytest_summary "not integration" /tmp/unit-summary.json
fi
if [[ -f pubspec.yaml ]]; then
  timeout 10m flutter test --exclude-tags=flow,integration --machine \
    > /tmp/flutter-unit-raw.json 2>/dev/null || true
  jq -s '{passing:(map(select(.type=="testDone" and .result=="success"))|length),failures:(map(select(.type=="testDone" and .result=="error"))|length),skipped:0}' \
     /tmp/flutter-unit-raw.json 2>/dev/null > /tmp/flutter-unit-summary.json \
    || echo '{"passing":0,"failures":0,"skipped":0}' > /tmp/flutter-unit-summary.json
  jq -s '.[0].passing + .[1].passing | {combined:.}' /tmp/unit-summary.json /tmp/flutter-unit-summary.json >/dev/null 2>&1 || true
fi

# Steps 3-4 — integration (needs Postgres) + flutter E2E flow are HEAVY and flaky inside the agent
# worker, and are already enforced on the PR by ci.yml + pipeline.yml (Playwright). So they are
# SKIPPED here by default; the worker gate blocks on the unit suite + churn only. Set
# SWASTH_REGRESS_FULL=1 to run the full chain (e.g. for a release branch).
if [[ "${SWASTH_REGRESS_FULL:-0}" == "1" ]]; then
  echo "check_no_regression: integration suite..."
  [[ -d backend ]] && _pytest_summary "integration" /tmp/integration-summary.json

  echo "check_no_regression: smoke/flow suite..."
  if [[ -d test/flows ]]; then
    [[ -f pubspec.yaml ]] && (flutter pub get >/dev/null 2>&1 || true)
    timeout 10m flutter test test/flows/ --timeout 30s --machine \
      > /tmp/flow-raw.json 2>/tmp/flow-err.log || true
    fp=$(jq -s '[.[]|select(.type=="testDone" and .result=="success")]|length' /tmp/flow-raw.json 2>/dev/null || echo 0)
    ff=$(jq -s '[.[]|select(.type=="testDone" and (.result=="error" or .result=="failure"))]|length' /tmp/flow-raw.json 2>/dev/null || echo 0)
    if [[ "${fp:-0}" -eq 0 && "${ff:-0}" -eq 0 ]]; then
      hp=$(grep -oE "\+[0-9]+" /tmp/flow-err.log /tmp/flow-raw.json 2>/dev/null | grep -oE "[0-9]+" | tail -1 || true)
      fp=${hp:-0}
    fi
    echo "{\"passing\":${fp:-0},\"failures\":${ff:-0},\"skipped\":0}" > /tmp/flow-summary.json
    echo "check_no_regression: flow passing=${fp:-0} failures=${ff:-0}" >&2
  fi
else
  echo "check_no_regression: integration + flow SKIPPED (unit-only worker gate; set SWASTH_REGRESS_FULL=1 to enable)"
  echo '{"passing":0,"failures":0,"skipped":0}' > /tmp/integration-summary.json
  echo '{"passing":0,"failures":0,"skipped":0}' > /tmp/flow-summary.json
fi

# Step 5 — baseline diff (unit) + final verdict.
python3 "$PY" baseline
