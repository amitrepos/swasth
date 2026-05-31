#!/usr/bin/env python3
"""Compute the required reviewer set for a PR from the data-driven review matrix (WS4).

Reads `.claude/reviewers-matrix.json` (the canonical source of truth) and a list of changed file
paths, and prints the required experts. Used by `.github/workflows/pr-persona-review.yml` to fan out
independent reviewer agents as status checks — the gate of record, independent of any author-written
local markers.

Usage:
    python3 scripts/compute_required_reviewers.py <file1> <file2> ...
    git diff --name-only origin/master... | python3 scripts/compute_required_reviewers.py -
    python3 scripts/compute_required_reviewers.py --format json <files...>

Output (default): one expert per line, in matrix order, deduped, daniel last.
Output (--format json): {"experts": [...], "mandatory_blocking": [...]}.
Exit 0 always (an empty set is valid — means no reviewers required).
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MATRIX = os.path.join(ROOT, ".claude", "reviewers-matrix.json")


def load_matrix():
    with open(MATRIX) as f:
        return json.load(f)


def compute(changed_files, matrix):
    rules = matrix.get("rules", [])
    always_last = matrix.get("always_last", "daniel")
    mandatory = set(matrix.get("mandatory_blocking", []))

    ordered = []  # preserve matrix order, dedupe
    seen = set()

    def add(expert):
        if expert not in seen:
            seen.add(expert)
            ordered.append(expert)

    for rule in rules:
        globs = rule.get("globs", [])
        if not globs:
            continue
        hit = any(
            re.search(pat, path)
            for pat in globs
            for path in changed_files
        )
        if hit:
            for expert in rule.get("experts", []):
                if expert != always_last:
                    add(expert)

    # Daniel always last, only if anything is required at all (i.e. a source file was touched).
    if ordered or any(re.search(r"\.(dart|py)$", p) for p in changed_files):
        add(always_last)

    required_mandatory = [e for e in ordered if e in mandatory]
    return ordered, required_mandatory


def main(argv):
    fmt = "lines"
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == "--format":
            fmt = argv[i + 1]
            i += 2
        else:
            args.append(argv[i])
            i += 1

    if args == ["-"] or not args:
        changed = [ln.strip() for ln in sys.stdin if ln.strip()]
    else:
        changed = args

    experts, mandatory = compute(changed, load_matrix())

    if fmt == "json":
        print(json.dumps({"experts": experts, "mandatory_blocking": mandatory}))
    else:
        for e in experts:
            print(e)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
