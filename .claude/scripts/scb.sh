#!/usr/bin/env bash
# scb.sh — "safe checkout branch"
#
# Refuses to create a new branch unless you are on master AND master is
# up to date with origin/master. This stops the "orphan commit" class of
# failure where a new branch is created from a stale feature branch,
# inheriting commits that are already on master under different SHAs
# (via squash-merge), then fails to merge back into master with
# "CONFLICTING" / "DIRTY" status.
#
# Root-cause analysis: 2026-04-18 drift incidents (2/3 were orphan-
# commit failures). See feedback_state_verification.md in Claude memory.
#
# Usage:
#     git scb feat/some-branch-name
#
# Equivalent safe flow, enforced in one command:
#     git checkout master
#     git pull --ff-only origin master
#     git checkout -b <name>
#
# Escape hatch: if you truly need to branch off a non-master base (e.g.
# stacking a fix on an in-review PR), invoke `git checkout -b` directly.
# This helper is an accelerator for the 99% case, not a prison.
#
# Exit codes:
#   0 — branch created successfully
#   1 — preconditions not met, no branch created

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: git scb <new-branch-name>" >&2
  echo "" >&2
  echo "Creates a new branch from origin/master after verifying local" >&2
  echo "master is fully up to date. Refuses if you're on a feature" >&2
  echo "branch with unmerged work, or if local master is behind origin." >&2
  exit 1
fi

NEW_BRANCH="$1"

# Validate branch name — refuse the obvious footguns.
if [[ "$NEW_BRANCH" == "master" || "$NEW_BRANCH" == "main" ]]; then
  echo "[scb] refusing to create branch named '$NEW_BRANCH'" >&2
  exit 1
fi

# Check we're in a git repo.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "[scb] not inside a git repository" >&2
  exit 1
fi
cd "$REPO_ROOT"

# Refuse if working tree is dirty — prevents silent loss of work when
# the checkout-master step overwrites tracked files.
if ! git diff-index --quiet HEAD --; then
  echo "[scb] refusing: working tree has uncommitted changes." >&2
  echo "     Commit, stash, or reset them first." >&2
  echo "     git status:" >&2
  git status --short | head -20 >&2
  exit 1
fi

# Refuse if the target branch name already exists locally.
if git show-ref --verify --quiet "refs/heads/$NEW_BRANCH"; then
  echo "[scb] refusing: branch '$NEW_BRANCH' already exists locally." >&2
  echo "     Pick a different name or delete the existing branch:" >&2
  echo "       git branch -D $NEW_BRANCH" >&2
  exit 1
fi

# Fetch latest origin/master (silent, best-effort).
echo "[scb] fetching origin/master..."
if ! git fetch origin master --quiet; then
  echo "[scb] warning: git fetch origin master failed." >&2
  echo "     Continuing with whatever is in origin/master locally," >&2
  echo "     but you might be about to branch off a stale reference." >&2
  echo "     If the network is down, either fix it or accept the risk." >&2
fi

# Determine local master's SHA and origin/master's SHA.
LOCAL_MASTER="$(git rev-parse master 2>/dev/null || echo 'NONE')"
REMOTE_MASTER="$(git rev-parse origin/master 2>/dev/null || echo 'NONE')"

if [[ "$LOCAL_MASTER" == "NONE" ]]; then
  echo "[scb] no local 'master' branch. Create one first:" >&2
  echo "     git branch master origin/master" >&2
  exit 1
fi

# Switch to master if we're not already on it.
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "master" ]]; then
  echo "[scb] switching to master (was on: $CURRENT_BRANCH)"
  git checkout master --quiet
fi

# Fast-forward local master if it's behind origin/master.
if [[ "$LOCAL_MASTER" != "$REMOTE_MASTER" ]]; then
  echo "[scb] local master is out of date — fast-forwarding..."
  if ! git merge --ff-only origin/master --quiet; then
    echo "[scb] refusing: local master has diverged from origin/master." >&2
    echo "     This should never happen on master. Investigate with:" >&2
    echo "       git log --oneline --graph origin/master..master" >&2
    echo "       git log --oneline --graph master..origin/master" >&2
    exit 1
  fi
  echo "[scb] local master now at $(git rev-parse --short HEAD)"
fi

# All preconditions met. Create the new branch.
git checkout -b "$NEW_BRANCH"
echo "[scb] created '$NEW_BRANCH' from master @ $(git rev-parse --short master)"
