#!/usr/bin/env bash
# write_to_automation_state.sh — atomic-ish writer for the automation-state branch.
#
# Usage:
#   write_to_automation_state.sh <branch-path> --mutator '<shell expr>' "<commit msg>"
#   write_to_automation_state.sh <branch-path> <source-file>          "<commit msg>"   # legacy
#
# Modes:
#   --mutator mode (preferred):
#     The mutator is a shell expression evaluated INSIDE every retry iteration
#     of the rebase loop. It receives env vars $CURRENT (path to the freshly
#     fetched branch-path content, or /dev/null if missing) and $NEXT (path to
#     the staging file the loop will commit). The mutator MUST write the new
#     desired content to "$NEXT". This is the only race-safe mode for files
#     where concurrent producers and the worker may mutate the SAME file
#     (e.g. jira-work-queue.json) — see Daniel audit C1.
#
#   legacy mode (snapshot push):
#     Used for files where the new content is fully determined at the caller
#     (e.g. README.md, queue-status.md). The caller writes its new content to
#     <source-file>; we commit-and-push it. Last-writer-wins semantics — only
#     use for files where that's acceptable.
#
# In either mode, retries are bounded (5 attempts, exponential 1s/2s/4s/8s/16s)
# and a non-FF push triggers re-fetch + re-evaluate the mutator on fresh state.

set -euo pipefail

BRANCH_PATH="${1:?branch-path required}"
MODE_OR_SRC="${2:?mutator expression or source file required}"

if [[ "$MODE_OR_SRC" == "--mutator" ]]; then
  MUTATOR="${3:?mutator expression required}"
  COMMIT_MSG="${4:?commit message required}"
  MODE=mutator
else
  SOURCE_FILE="$MODE_OR_SRC"
  COMMIT_MSG="${3:?commit message required}"
  MODE=legacy
  if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "write_to_automation_state: source file does not exist: $SOURCE_FILE" >&2
    exit 2
  fi
fi

REMOTE="${SWASTH_AUTOMATION_REMOTE:-origin}"
BRANCH="${SWASTH_AUTOMATION_BRANCH:-automation-state}"
MAX_ATTEMPTS=5

WORKTREE_DIR="$(mktemp -d -t swasth-autostate.XXXXXX)"
trap 'git worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true; rm -rf "$WORKTREE_DIR"' EXIT

GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-swasth-automation-bot}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-bot@swasth.health}"
export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

# Bootstrap if remote branch is missing (fresh repo, first run).
if ! git ls-remote --exit-code --heads "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
  echo "write_to_automation_state: bootstrapping orphan branch '$BRANCH' on $REMOTE..."
  git worktree add --detach "$WORKTREE_DIR" HEAD >/dev/null
  (
    cd "$WORKTREE_DIR"
    git checkout --orphan "$BRANCH"
    git rm -rf . >/dev/null 2>&1 || true
    mkdir -p "$(dirname "$BRANCH_PATH")"
    if [[ "$MODE" == "mutator" ]]; then
      CURRENT="/dev/null"
      NEXT="$WORKTREE_DIR/$BRANCH_PATH"
      mkdir -p "$(dirname "$NEXT")"
      export CURRENT NEXT
      bash -c "$MUTATOR"
    else
      cp "$SOURCE_FILE" "$BRANCH_PATH"
    fi
    git add "$BRANCH_PATH"
    git commit -m "$COMMIT_MSG" >/dev/null
    git push "$REMOTE" "$BRANCH"
  )
  echo "write_to_automation_state: bootstrap complete."
  exit 0
fi

# Add worktree pointing at the remote branch.
git fetch "$REMOTE" "$BRANCH" --quiet
git worktree add "$WORKTREE_DIR" "$REMOTE/$BRANCH" >/dev/null

attempt=0
backoff=1
while (( attempt < MAX_ATTEMPTS )); do
  attempt=$((attempt + 1))

  # Refresh worktree to current remote, then compute next content.
  (
    cd "$WORKTREE_DIR"
    git checkout -B "$BRANCH" "$REMOTE/$BRANCH" --quiet
    git pull --rebase --quiet "$REMOTE" "$BRANCH"

    mkdir -p "$(dirname "$BRANCH_PATH")"
    if [[ "$MODE" == "mutator" ]]; then
      CURRENT="$WORKTREE_DIR/$BRANCH_PATH"
      [[ -f "$CURRENT" ]] || CURRENT="/dev/null"
      NEXT="$WORKTREE_DIR/$BRANCH_PATH.next"
      export CURRENT NEXT
      bash -c "$MUTATOR"
      if [[ ! -f "$NEXT" ]]; then
        echo "write_to_automation_state: mutator did not write \$NEXT ($NEXT)" >&2
        exit 5
      fi
      mv "$NEXT" "$BRANCH_PATH"
    else
      cp "$SOURCE_FILE" "$BRANCH_PATH"
    fi

    if git diff --quiet -- "$BRANCH_PATH"; then
      echo "write_to_automation_state: no change in $BRANCH_PATH, skipping commit."
      exit 0
    fi
    git add "$BRANCH_PATH"
    git commit -m "$COMMIT_MSG" >/dev/null
  )
  inner_status=$?
  if (( inner_status != 0 )); then
    exit $inner_status
  fi

  if (cd "$WORKTREE_DIR" && git push "$REMOTE" "$BRANCH" --quiet 2>/tmp/push-err); then
    echo "write_to_automation_state: pushed '$BRANCH_PATH' to $REMOTE/$BRANCH (attempt $attempt)."
    exit 0
  fi
  echo "write_to_automation_state: push attempt $attempt failed:" >&2
  cat /tmp/push-err >&2 || true
  rm -f /tmp/push-err
  if (( attempt < MAX_ATTEMPTS )); then
    echo "write_to_automation_state: sleeping ${backoff}s then retrying (will re-run mutator on fresh state)..." >&2
    sleep "$backoff"
    backoff=$((backoff * 2))
    git -C "$WORKTREE_DIR" fetch "$REMOTE" "$BRANCH" --quiet
  fi
done

echo "write_to_automation_state: FAILED after $MAX_ATTEMPTS attempts to write '$BRANCH_PATH' on $REMOTE/$BRANCH." >&2
exit 3
