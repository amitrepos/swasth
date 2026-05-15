#!/usr/bin/env bash
# check-agent-branch-policy.sh — enforces content-hash markers on
# agent-authored branches.
#
# Usage:
#   check-agent-branch-policy.sh commit
#   check-agent-branch-policy.sh push
#
# Detects agent branches by name regex (^feat/nuo-[0-9]+-) AND/OR by
# committer identity (swasth-automation-bot). Non-agent branches are a
# no-op exit 0.
#
# On agent branches:
#   commit mode → require .claude/markers/{priya-quality,coverage-pass,regression-pass}-<hash>
#   push   mode → ALSO require .claude/markers/qa-pass-<hash> AND JIRA label `quality-passed`
#
# Hash key: sha256 of `git diff --cached` (commit mode) or
#   `git diff origin/master...HEAD` (push mode), kept consistent with the
# existing reviewer-marker pattern in .claude/scripts/check-required-reviewers.sh.

set -euo pipefail

MODE="${1:-commit}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT"

BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo '')"
COMMITTER="$(git config user.email 2>/dev/null || echo '')"

# Skip if not an agent branch.
is_agent_branch="false"
if [[ "$BRANCH" =~ ^feat/nuo-[0-9]+- ]]; then
  is_agent_branch="true"
fi
if [[ "$COMMITTER" == "bot@swasth.health" ]]; then
  is_agent_branch="true"
fi
if [[ "$is_agent_branch" != "true" ]]; then
  exit 0
fi

# Allow opt-out for emergencies.
if [[ "${SWASTH_BYPASS_AGENT_POLICY:-0}" == "1" ]]; then
  echo "[agent-branch-policy] SWASTH_BYPASS_AGENT_POLICY=1 set; skipping checks." >&2
  exit 0
fi

MARKER_DIR="$REPO_ROOT/.claude/markers"
mkdir -p "$MARKER_DIR"

# Compute hash. Use the SAME convention as check-required-reviewers.sh:
#   - hash sha256 of `git diff --cached`
#   - first 12 chars
#   - marker filename = .review-<expert>-<hash> (no .marker suffix)
# This makes write-review-marker.sh and this script bit-compatible.
DIFF=$(git diff --cached)
if [[ -z "$DIFF" && "$MODE" == "push" ]]; then
  # On push, fall back to origin/master diff if no staged content.
  if git rev-parse --verify --quiet origin/master >/dev/null; then
    DIFF=$(git diff origin/master...HEAD)
  fi
fi
HASH=$(printf '%s' "$DIFF" | shasum -a 256 | cut -c1-12)

required=()
if [[ "$MODE" == "commit" ]]; then
  required=(priya-quality coverage-pass regression-pass)
elif [[ "$MODE" == "push" ]]; then
  required=(priya-quality coverage-pass regression-pass qa-pass)
else
  echo "[agent-branch-policy] unknown mode '$MODE'" >&2
  exit 1
fi

missing=()
for marker in "${required[@]}"; do
  if [[ ! -f "$MARKER_DIR/.review-${marker}-${HASH}" ]]; then
    missing+=(".review-${marker}-${HASH}")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "" >&2
  echo "[agent-branch-policy] $MODE blocked on agent branch '$BRANCH'." >&2
  echo "[agent-branch-policy] missing markers (under .claude/markers/):" >&2
  for m in "${missing[@]}"; do
    echo "  - ${m}" >&2
  done
  echo "" >&2
  echo "[agent-branch-policy] These markers are written by the worker workflow" >&2
  echo "[agent-branch-policy] after Priya-quality, coverage, regression, and QA" >&2
  echo "[agent-branch-policy] reviews pass. To override in an emergency, run with" >&2
  echo "[agent-branch-policy] SWASTH_BYPASS_AGENT_POLICY=1 (audited)." >&2
  exit 11
fi

# Push-only: also verify the JIRA ticket carries `quality-passed`.
if [[ "$MODE" == "push" ]]; then
  TICKET=$(echo "$BRANCH" | sed -nE 's@^feat/(nuo-[0-9]+).*@\1@p' | tr '[:lower:]' '[:upper:]')
  if [[ -z "$TICKET" ]] || [[ -z "${JIRA_URL:-}" ]] || [[ -z "${JIRA_EMAIL:-}" ]] || [[ -z "${JIRA_API_TOKEN:-}" ]]; then
    # No JIRA creds → soft-warn locally. CI re-check will enforce.
    echo "[agent-branch-policy] JIRA creds not present locally; skipping label check (CI will enforce)." >&2
    exit 0
  fi
  LABELS=$(curl -sS -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
    "$JIRA_URL/rest/api/3/issue/$TICKET?fields=labels" 2>/dev/null \
    | jq -r '.fields.labels[]?' 2>/dev/null || echo "")
  if ! echo "$LABELS" | grep -q '^quality-passed$'; then
    echo "[agent-branch-policy] JIRA ticket $TICKET is missing the 'quality-passed' label." >&2
    echo "[agent-branch-policy] Priya must mark the ticket as quality-passed before push." >&2
    exit 12
  fi
fi

echo "[agent-branch-policy] $MODE OK (hash=${HASH:0:12}…)"
exit 0
