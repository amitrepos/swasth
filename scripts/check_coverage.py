#!/usr/bin/env python3
"""check_coverage.py — diff-filtered coverage check against tier targets.

Tier targets (from CLAUDE.md Stage 5):
    Tier 1 (95%): health_utils.py, routes_health.py, routes_meals.py, models.py, schemas.py
    Tier 2 (90%): dependencies.py, routes.py (auth), encryption_service.py
    Tier 3 (85%): all other backend .py + all changed lib/**.dart

Reads:
    /tmp/coverage.json  (pytest-cov JSON report, written by check_coverage.sh)
    coverage/lcov.info  (flutter --coverage)

Writes:
    /tmp/coverage-report.md  — human-readable per-file table + verdict.

Exit:
    0 if every changed file meets its tier threshold.
    1 otherwise (with the report explaining which file fell short).
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

TIER1 = {"backend/health_utils.py", "backend/routes_health.py", "backend/routes_meals.py",
         "backend/models.py", "backend/schemas.py"}
TIER2 = {"backend/dependencies.py", "backend/routes.py", "backend/encryption_service.py"}


def tier_for(path: str) -> tuple[int, int]:
    """Return (tier_num, threshold_pct)."""
    if path in TIER1:
        return 1, 95
    if path in TIER2:
        return 2, 90
    return 3, 85


def changed_files() -> list[str]:
    out = subprocess.check_output(
        ["git", "diff", "--name-only", "origin/master...HEAD"],
        text=True,
    )
    return [line.strip() for line in out.splitlines() if line.strip()]


def parse_pytest_cov(path: Path) -> dict[str, float]:
    if not path.exists():
        return {}
    data = json.loads(path.read_text())
    out: dict[str, float] = {}
    for fp, entry in (data.get("files") or {}).items():
        # Normalise to repo-relative path.
        norm = fp.lstrip("./")
        if not norm.startswith("backend/"):
            norm = f"backend/{norm}"
        summary = entry.get("summary") or {}
        pct = summary.get("percent_covered")
        if pct is not None:
            out[norm] = float(pct)
    return out


def parse_lcov(path: Path) -> dict[str, float]:
    if not path.exists():
        return {}
    out: dict[str, float] = {}
    current: str | None = None
    lh = lf = 0
    for line in path.read_text().splitlines():
        if line.startswith("SF:"):
            current = line[3:].strip()
            lh = lf = 0
        elif line.startswith("LH:"):
            lh = int(line[3:])
        elif line.startswith("LF:"):
            lf = int(line[3:])
        elif line.strip() == "end_of_record" and current and lf > 0:
            out[current] = (lh / lf) * 100.0
            current = None
    return out


def main() -> int:
    backend_cov = parse_pytest_cov(Path("/tmp/coverage.json"))
    flutter_cov = parse_lcov(Path("coverage/lcov.info"))
    coverage = {**backend_cov, **flutter_cov}

    changed = changed_files()
    targets = [
        c for c in changed
        if (c.endswith(".py") and c.startswith("backend/") and "/tests/" not in c
            and "/migrations/" not in c)
        or (c.endswith(".dart") and c.startswith("lib/") and "/l10n/" not in c)
    ]

    rows: list[tuple[str, int, int, float, str]] = []
    any_fail = False
    for f in targets:
        tier, threshold = tier_for(f)
        pct = coverage.get(f)
        if pct is None:
            verdict = "MISSING"
            any_fail = True
            pct_display = 0.0
        else:
            verdict = "PASS" if pct >= threshold else "FAIL"
            if verdict == "FAIL":
                any_fail = True
            pct_display = pct
        rows.append((f, tier, threshold, pct_display, verdict))

    report = ["# Coverage report\n",
              "| File | Tier | Target | Coverage | Verdict |",
              "|------|------|--------|----------|---------|"]
    for f, tier, target, pct, verdict in rows:
        report.append(f"| `{f}` | T{tier} | {target}% | {pct:.1f}% | **{verdict}** |")
    if not rows:
        report.append("\n_(no source files changed under coverage scope)_\n")
    report.append("")
    report.append(f"**Overall:** {'FAIL — see rows above' if any_fail else 'PASS'}")
    Path("/tmp/coverage-report.md").write_text("\n".join(report) + "\n")

    print("check_coverage:", "FAIL" if any_fail else "PASS")
    return 1 if any_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
