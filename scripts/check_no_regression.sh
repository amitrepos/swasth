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

# Step 1 — fast churn check.
python3 "$PY" || { code=$?; if [[ $code -eq 2 ]]; then exit 2; fi; }

# Step 2 — unit suite.
echo "check_no_regression: unit suite..."
if [[ -d backend ]]; then
  (
    cd backend
    timeout 10m env TESTING=true python -m pytest tests/ -m "not integration" \
      --json-report --json-report-file=/tmp/unit-pytest-report.json -q || true
  )
  if [[ -f /tmp/unit-pytest-report.json ]]; then
    jq '{passing:.summary.passed, failures:.summary.failed, skipped:.summary.skipped}' \
       /tmp/unit-pytest-report.json > /tmp/unit-summary.json
  else
    echo '{"passing":0,"failures":0,"skipped":0}' > /tmp/unit-summary.json
  fi
fi
if [[ -f pubspec.yaml ]]; then
  timeout 10m flutter test --exclude-tags=flow,integration --machine \
    > /tmp/flutter-unit-raw.json 2>/dev/null || true
  jq -s '{passing:(map(select(.type=="testDone" and .result=="success"))|length),failures:(map(select(.type=="testDone" and .result=="error"))|length),skipped:0}' \
     /tmp/flutter-unit-raw.json 2>/dev/null > /tmp/flutter-unit-summary.json \
    || echo '{"passing":0,"failures":0,"skipped":0}' > /tmp/flutter-unit-summary.json
  jq -s '.[0].passing + .[1].passing | {combined:.}' /tmp/unit-summary.json /tmp/flutter-unit-summary.json >/dev/null 2>&1 || true
fi

# Step 3 — integration suite (real Postgres; assumes DB env vars set by the workflow).
echo "check_no_regression: integration suite..."
if [[ -d backend ]]; then
  (
    cd backend
    timeout 10m env TESTING=true python -m pytest tests/ -m integration \
      --json-report --json-report-file=/tmp/integration-pytest-report.json -q || true
  )
  if [[ -f /tmp/integration-pytest-report.json ]]; then
    jq '{passing:.summary.passed, failures:.summary.failed, skipped:.summary.skipped}' \
       /tmp/integration-pytest-report.json > /tmp/integration-summary.json
  else
    echo '{"passing":0,"failures":0,"skipped":0}' > /tmp/integration-summary.json
  fi
fi

# Step 4 — smoke / E2E flow suite.
echo "check_no_regression: smoke/flow suite..."
if [[ -d test/flows ]]; then
  timeout 10m flutter test test/flows/ --timeout 30s --machine \
    > /tmp/flow-raw.json 2>/dev/null || true
  jq -s '{passing:(map(select(.type=="testDone" and .result=="success"))|length),failures:(map(select(.type=="testDone" and .result=="error"))|length),skipped:0}' \
     /tmp/flow-raw.json 2>/dev/null > /tmp/flow-summary.json \
    || echo '{"passing":0,"failures":0,"skipped":0}' > /tmp/flow-summary.json
fi

# Step 5 — baseline diff + final verdict.
python3 "$PY"
