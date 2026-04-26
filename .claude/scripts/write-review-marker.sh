#!/usr/bin/env bash
# write-review-marker.sh <expert-name>
#
# Writes a review marker file after a domain expert returns a PASS verdict
# (no Must Fix items) on the current staged diff. The marker is keyed to
# the staged content hash, so any change to staged content invalidates all
# markers automatically.
#
# Usage:
#   .claude/scripts/write-review-marker.sh sunita
#   .claude/scripts/write-review-marker.sh aditya
#   .claude/scripts/write-review-marker.sh doctor
#   .claude/scripts/write-review-marker.sh daniel
#   .claude/scripts/write-review-marker.sh phi
#   .claude/scripts/write-review-marker.sh legal
#   .claude/scripts/write-review-marker.sh security
#   .claude/scripts/write-review-marker.sh priya
#   .claude/scripts/write-review-marker.sh meera
#
# Only call this AFTER the expert has explicitly given a PASS verdict.
# For Meera: call after /reality-check returns GREEN or YELLOW (with user approval).
# If there are Must Fix items, do NOT call this — fix the issues, restage,
# and run the expert again.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <expert-name>" >&2
  echo "Valid experts: sunita, aditya, doctor, daniel, phi, legal, security, priya, meera" >&2
  exit 2
fi

EXPERT="$1"

case "$EXPERT" in
  sunita|aditya|doctor|daniel|phi|legal|security|priya|meera) ;;
  *)
    echo "Unknown expert: $EXPERT" >&2
    echo "Valid experts: sunita, aditya, doctor, daniel, phi, legal, security, priya, meera" >&2
    exit 2
    ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

MARKER_DIR=".claude/markers"
mkdir -p "$MARKER_DIR"

STAGED_DIFF="$(git diff --cached)"
if [[ -z "$STAGED_DIFF" ]]; then
  echo "ERROR: No staged changes to mark. Stage your files first with git add." >&2
  exit 3
fi

HASH="$(printf '%s' "$STAGED_DIFF" | shasum -a 256 | cut -c1-12)"
MARKER="$MARKER_DIR/.review-${EXPERT}-${HASH}"

cat > "$MARKER" <<EOF
expert: $EXPERT
hash: $HASH
timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
verdict: PASS
EOF

echo "Marker written: $MARKER"
echo "Expert '$EXPERT' marked PASS for staged content hash $HASH."
