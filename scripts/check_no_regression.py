#!/usr/bin/env python3
"""check_no_regression.py — Gate C-regress logic.

Steps (all run with `timeout 10m` from check_no_regression.sh):
    1. churn check (FAST — runs first, fails fast per Matt audit M6)
    2. unit suite
    3. integration suite (real Postgres)
    4. smoke / E2E flow suite
    5. baseline diff

Inputs:
    .claude/test-baseline.json on master  (committed)
    .agent-tmp/ticket.md                   (Affected Surfaces section)
    git diff --name-only origin/master...HEAD
    /tmp/unit-summary.json, /tmp/integration-summary.json, /tmp/flow-summary.json
        (written by the shell wrapper)

Output:
    /tmp/regression-report.md
    exit code 0 = clean, non-zero = abort with Needs Human.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

GLOBAL_ALLOWED_PREFIXES = (
    "lib/l10n/",
    "backend/migrations/",
)
GLOBAL_ALLOWED_FILES = {
    ".claude/agent-budget-log.json",
}
MAX_OUTSIDE_SCOPE = 3


def changed_files() -> list[str]:
    out = subprocess.check_output(
        ["git", "diff", "--name-only", "origin/master...HEAD"], text=True
    )
    return [s.strip() for s in out.splitlines() if s.strip()]


def parse_affected_surfaces(ticket_md: Path) -> list[str]:
    """Extract Affected Surfaces lines from the ticket brief Priya guarantees."""
    if not ticket_md.exists():
        return []
    content = ticket_md.read_text()
    # Look for a "Affected Surfaces" header (any heading level).
    m = re.search(r"(?i)#+\s*Affected Surfaces\s*\n(.+?)(?:\n#+ |\Z)", content, re.DOTALL)
    if not m:
        return []
    section = m.group(1)
    # Pull bullet-listed file/path tokens (anything inside backticks).
    surfaces = re.findall(r"`([^`]+)`", section)
    return [s.strip() for s in surfaces if s.strip()]


def is_in_scope(path: str, surfaces: list[str]) -> bool:
    if path.startswith(GLOBAL_ALLOWED_PREFIXES):
        return True
    if path in GLOBAL_ALLOWED_FILES:
        return True
    for s in surfaces:
        if s.endswith("/"):
            if path.startswith(s):
                return True
        elif "*" in s:
            # Glob-ish: replace * with .*
            import fnmatch
            if fnmatch.fnmatch(path, s):
                return True
        elif path == s:
            return True
        elif s.startswith("lib/") or s.startswith("backend/"):
            if path.startswith(s.rstrip("/") + "/"):
                return True
    return False


def churn_check(report: list[str]) -> bool:
    # Accept either path so we work whether worker wrote to .agent-tmp/ (new)
    # or /tmp/ (legacy callsite).
    ticket_path = Path(".agent-tmp/ticket.md")
    if not ticket_path.exists():
        ticket_path = Path("/tmp/ticket.md")
    surfaces = parse_affected_surfaces(ticket_path)
    changed = changed_files()
    if not surfaces:
        report.append("## Churn check\n\n**FAIL** — no `Affected Surfaces` block in ticket brief. Priya should have guaranteed this in Gate A.")
        return False
    outside = [p for p in changed if not is_in_scope(p, surfaces)]
    if len(outside) > MAX_OUTSIDE_SCOPE:
        report.append(f"## Churn check\n\n**FAIL** — {len(outside)} files changed outside declared scope (max {MAX_OUTSIDE_SCOPE}). Out-of-scope files:")
        for p in outside:
            report.append(f"- `{p}`")
        return False
    report.append(f"## Churn check\n\n**PASS** — {len(changed)} files changed, {len(outside)} outside declared scope (within tolerance).")
    return True


def baseline_diff(report: list[str]) -> bool:
    baseline_path = Path(".claude/test-baseline.json")
    if not baseline_path.exists():
        report.append("## Baseline diff\n\n_(skipped — no baseline file yet)_")
        return True
    try:
        baseline = json.loads(baseline_path.read_text())
    except json.JSONDecodeError:
        report.append("## Baseline diff\n\n**FAIL** — baseline file is malformed.")
        return False

    def _load(p: str) -> dict:
        path = Path(p)
        if not path.exists():
            return {}
        try:
            return json.loads(path.read_text())
        except json.JSONDecodeError:
            return {}

    unit = _load("/tmp/unit-summary.json")
    integ = _load("/tmp/integration-summary.json")
    flow = _load("/tmp/flow-summary.json")

    issues: list[str] = []
    if unit.get("failures", 0) > 0:
        issues.append(f"unit failures: {unit['failures']}")
    if integ.get("failures", 0) > 0:
        issues.append(f"integration failures: {integ['failures']}")
    if flow.get("failures", 0) > 0:
        issues.append(f"flow failures: {flow['failures']}")

    new_unit_passing = unit.get("passing", 0)
    base_unit = baseline.get("unit_passing", 0)
    if base_unit and new_unit_passing < base_unit:
        issues.append(f"unit-passing regression: was {base_unit}, now {new_unit_passing}")
    new_flow_passing = flow.get("passing", 0)
    base_flow = baseline.get("flow_passing", 0)
    if base_flow and new_flow_passing < base_flow:
        issues.append(f"flow-passing regression: was {base_flow}, now {new_flow_passing}")

    if issues:
        report.append("## Baseline diff\n\n**FAIL**:")
        for i in issues:
            report.append(f"- {i}")
        return False

    report.append(
        f"## Baseline diff\n\n**PASS** — unit:{new_unit_passing}/{base_unit} integ-fail:{integ.get('failures',0)} flow:{new_flow_passing}/{base_flow}"
    )
    return True


def main() -> int:
    report = ["# Gate C-regress report\n"]
    ok = True
    ok &= churn_check(report)
    if not ok:
        # Fail-fast on cheapest signal per M6.
        Path("/tmp/regression-report.md").write_text("\n".join(report) + "\n")
        print("check_no_regression: FAIL (churn)")
        return 2

    ok &= baseline_diff(report)
    Path("/tmp/regression-report.md").write_text("\n".join(report) + "\n")
    if not ok:
        print("check_no_regression: FAIL (baseline)")
        return 3
    print("check_no_regression: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
