#!/usr/bin/env bash
# check_coverage.sh — Gate C-quant. Runs pytest-cov and flutter --coverage,
# then defers to check_coverage.py for tier-aware verdict.
#
# Each suite is wrapped in `timeout 10m` per Matt audit M2.
# Backend tests skip @pytest.mark.integration here (those run in
# check_no_regression.sh, against ephemeral Postgres). Unit-only here.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "check_coverage: backend pytest..."
if [[ -d backend ]]; then
  (
    cd backend
    timeout 10m env TESTING=true python -m pytest tests/ \
      -m "not integration" --cov=. --cov-report=json:/tmp/coverage.json -q
  ) || {
    code=$?
    if [[ $code -eq 124 ]]; then
      echo "check_coverage: backend pytest TIMED OUT (10m)" >&2
      exit 124
    fi
    exit $code
  }
fi

echo "check_coverage: flutter test --coverage..."
if [[ -f pubspec.yaml ]]; then
  timeout 10m flutter test --coverage --exclude-tags=flow,integration || {
    code=$?
    if [[ $code -eq 124 ]]; then
      echo "check_coverage: flutter test TIMED OUT (10m)" >&2
      exit 124
    fi
    exit $code
  }
fi

echo "check_coverage: tier-aware verdict..."
python3 "$REPO_ROOT/scripts/check_coverage.py"
