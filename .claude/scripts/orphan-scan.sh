#!/usr/bin/env bash
# orphan-scan.sh
#
# Detects local branches that have drifted into dangerous states and
# prints a loud banner at session start so the user (and Claude) can't
# miss it. Runs as part of load-session.sh.
#
# Danger states detected:
#   1. Branch is ahead of origin AND its PR has already merged
#      → orphaned commits that will never ship (the 2026-04-10 incident).
#   2. Branch is ahead of origin AND has no open PR at all
#      → unpushed commits that might be forgotten.
#
# Silent if there's nothing dangerous. Never blocks — this is a warning,
# not a gate. The blocking happens in pre-commit and pre-push.
#
# Performance: makes a SINGLE `gh pr list` call upfront (not one per
# branch). With 50+ local branches the previous design made ~100 API
# calls per session start; this makes 1. Requires jq for local filtering;
# falls back to silent-skip if jq is missing.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -z "$REPO_ROOT" ]] && exit 0
cd "$REPO_ROOT"

# Portable timeout helper.
_with_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    "$@"
  fi
}

# Need gh + jq to query and filter PR state. If either is missing or
# unauthenticated, skip silently — local hooks still enforce at
# commit/push time.
command -v gh >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0
_with_timeout 3 gh auth status >/dev/null 2>&1 || exit 0

# Fetch latest state quietly (bounded). Network failure is OK.
_with_timeout 5 git fetch --quiet origin 2>/dev/null || true

# Fetch ALL PRs once. 500 is well above the total ever opened for this repo.
# If the call fails or times out, fall back to empty list — scan silently
# reports nothing rather than blocking the session.
pr_json="$(_with_timeout 10 gh pr list --state all --limit 500 --json number,headRefName,state 2>/dev/null || echo '[]')"

ORPHAN_MERGED=()
AHEAD_NO_PR=()

while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue
  [[ "$branch" == "master" ]] && continue

  # Is this branch ahead of its upstream (or of origin/master)?
  upstream="$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null || echo '')"
  if [[ -n "$upstream" ]]; then
    ahead=$(git rev-list --count "$upstream..$branch" 2>/dev/null || echo 0)
  else
    ahead=$(git rev-list --count "origin/master..$branch" 2>/dev/null || echo 0)
  fi
  [[ "$ahead" -eq 0 ]] && continue

  # Local lookup from the cached PR JSON — no additional network calls.
  # stderr suppressed: if gh returned partial output due to a timeout,
  # jq would spam errors at session start. Silent failure is correct
  # for a warning-only scan.
  merged_pr="$(jq -r --arg b "$branch" '[.[] | select(.headRefName == $b and .state == "MERGED")] | .[0].number // empty' <<<"$pr_json" 2>/dev/null)"
  if [[ -n "$merged_pr" && "$merged_pr" != "null" ]]; then
    ORPHAN_MERGED+=("$branch|$ahead|$merged_pr")
    continue
  fi

  open_pr="$(jq -r --arg b "$branch" '[.[] | select(.headRefName == $b and .state == "OPEN")] | .[0].number // empty' <<<"$pr_json" 2>/dev/null)"
  if [[ -z "$open_pr" ]]; then
    AHEAD_NO_PR+=("$branch|$ahead")
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

# Nothing to report? Exit silently.
if [[ ${#ORPHAN_MERGED[@]} -eq 0 && ${#AHEAD_NO_PR[@]} -eq 0 ]]; then
  exit 0
fi

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  ⚠  Branch hygiene warning"
echo "══════════════════════════════════════════════════════════════════"

if [[ ${#ORPHAN_MERGED[@]} -gt 0 ]]; then
  echo ""
  echo "ORPHANED — these branches have extra commits but their PR has already merged."
  echo "Continuing to commit or push here will create work that never reaches master."
  echo ""
  for entry in "${ORPHAN_MERGED[@]}"; do
    IFS='|' read -r br ahead pr <<< "$entry"
    echo "    $br  ($ahead unpushed commits — PR #$pr already merged)"
  done
  echo ""
  echo "To recover each:"
  echo "  git checkout <branch>                       # see what the commits are"
  echo "  git log origin/master..HEAD --oneline"
  echo "  git checkout master && git pull && git checkout -b <new-branch>"
  echo "  git cherry-pick <sha1> <sha2> ...           # port the commits"
fi

if [[ ${#AHEAD_NO_PR[@]} -gt 0 ]]; then
  echo ""
  echo "NO OPEN PR — these branches have unpushed or unshipped work with no PR."
  echo ""
  for entry in "${AHEAD_NO_PR[@]}"; do
    IFS='|' read -r br ahead <<< "$entry"
    echo "    $br  ($ahead commits ahead)"
  done
  echo ""
  echo "Either push + open a PR, or delete the branch if it's abandoned."
fi

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo ""
