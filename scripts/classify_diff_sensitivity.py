#!/usr/bin/env python3
"""Classify a PR diff as SENSITIVE or low-risk for the merge policy (WS6).

A diff is SENSITIVE if any changed file matches a glob in `sensitive_globs` of
`.claude/reviewers-matrix.json` (auth, data/PHI, migrations, logging/serialization, infra).
Sensitive diffs require human approval (auto-merge disabled) even when all checks are green.
Low-risk diffs are eligible for auto-merge.

Usage:
    python3 scripts/classify_diff_sensitivity.py <file1> <file2> ...
    git diff --name-only A B | python3 scripts/classify_diff_sensitivity.py -
    python3 scripts/classify_diff_sensitivity.py --format json <files...>

Default output: `sensitive` or `low-risk` (single word).
JSON output: {"sensitivity": "...", "matched": {"<category>": ["<path>", ...]}}.
Exit 0 always.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MATRIX = os.path.join(ROOT, ".claude", "reviewers-matrix.json")


def classify(changed_files):
    with open(MATRIX) as f:
        cfg = json.load(f).get("sensitive_globs", {})
    matched = {}
    for category, globs in cfg.items():
        if category.startswith("$"):
            continue
        hits = [p for p in changed_files if any(re.search(g, p) for g in globs)]
        if hits:
            matched[category] = sorted(set(hits))
    return ("sensitive" if matched else "low-risk"), matched


def main(argv):
    fmt = "word"
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

    sensitivity, matched = classify(changed)
    if fmt == "json":
        print(json.dumps({"sensitivity": sensitivity, "matched": matched}))
    else:
        print(sensitivity)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
