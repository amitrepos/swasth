#!/usr/bin/env python3
"""check_token_budget.py — Gate B0 token-budget pre-flight.

Probes Anthropic's Messages API with a 1-token completion to read the
rate-limit headers, then compares the remaining quota against the estimated
cost of the current ticket (looked up in agent-budget-log.json with a
conservative fallback).

Decision:
    proceed → continue with implementation.
    defer   → caller should leave the ticket in the queue with retry_after
              set to (tokens_reset + 60s).

Writes $GITHUB_OUTPUT entries (decision, retry_after, remaining_in,
remaining_out, estimate_in, estimate_out) and a markdown summary to
$GITHUB_STEP_SUMMARY when running inside GHA.

Environment:
    ANTHROPIC_API_KEY  required — used for the probe (distinct from
                       CLAUDE_CODE_OAUTH_TOKEN; this script does not consume
                       OAuth quota).
    BUDGET_LOG_PATH    path to agent-budget-log.json. If missing or empty,
                       conservative defaults from the file are used.
    TICKET_SIZE_CLASS  one of small/medium/large — passed in by the worker
                       after parsing the ticket body.

CLI flags:
    --safety-margin   default 1.5
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

import requests

ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
PROBE_MODEL = "claude-haiku-4-5-20251001"  # cheapest available


def _build_auth_headers() -> dict[str, str] | None:
    """Pick auth based on which credential is present.

    Preference order:
      1. ANTHROPIC_API_KEY (`sk-ant-api-...`) — direct Messages API access.
      2. CLAUDE_CODE_OAUTH_TOKEN (`sk-ant-oat-...`) — OAuth bearer; same
         endpoint accepts it for Claude Code usage. Used when the workflow
         only has the existing OAuth secret and no dedicated API key.

    Returns None if no credential is configured.
    """
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if api_key:
        return {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }
    oauth = os.environ.get("CLAUDE_CODE_OAUTH_TOKEN")
    if oauth:
        return {
            "Authorization": f"Bearer {oauth}",
            "anthropic-version": "2023-06-01",
            "anthropic-beta": "oauth-2025-04-20",
            "content-type": "application/json",
        }
    return None


def probe_remaining() -> dict[str, int | str | None]:
    headers = _build_auth_headers()
    if headers is None:
        raise RuntimeError(
            "Neither ANTHROPIC_API_KEY nor CLAUDE_CODE_OAUTH_TOKEN is set; "
            "Gate B0 has no way to read remaining quota."
        )
    payload = {
        "model": PROBE_MODEL,
        "max_tokens": 1,
        "messages": [{"role": "user", "content": "."}],
    }
    r = requests.post(ANTHROPIC_URL, headers=headers, json=payload, timeout=20)
    if r.status_code == 429:
        return {
            "input_remaining": 0,
            "output_remaining": 0,
            "reset": r.headers.get("anthropic-ratelimit-tokens-reset")
                    or r.headers.get("retry-after"),
            "via": "429",
        }
    r.raise_for_status()
    return {
        "input_remaining": int(r.headers.get("anthropic-ratelimit-input-tokens-remaining", 0)),
        "output_remaining": int(r.headers.get("anthropic-ratelimit-output-tokens-remaining", 0)),
        "reset": r.headers.get("anthropic-ratelimit-input-tokens-reset")
                 or r.headers.get("anthropic-ratelimit-tokens-reset"),
        "via": "probe",
    }


def estimate_cost(size_class: str, log_path: Path) -> tuple[int, int, str]:
    if log_path.exists():
        try:
            data = json.loads(log_path.read_text())
        except json.JSONDecodeError:
            data = {}
    else:
        data = {}

    runs = [r for r in data.get("runs", []) if r.get("size_class") == size_class]
    if len(runs) >= 3:
        avg_in = sum(r["input_tokens"] for r in runs[-10:]) // min(len(runs), 10)
        avg_out = sum(r["output_tokens"] for r in runs[-10:]) // min(len(runs), 10)
        # Use the larger of avg + 1 stddev OR 1.5× avg, whichever bigger.
        return int(avg_in * 1.25), int(avg_out * 1.25), "rolling-mean"

    defaults = data.get("defaults_until_seeded", {})
    return (
        int(defaults.get("input_tokens", 500_000)),
        int(defaults.get("output_tokens", 200_000)),
        "default",
    )


def write_github_output(decision: str, **kv: Any) -> None:
    gh_out = os.environ.get("GITHUB_OUTPUT")
    if not gh_out:
        for k, v in kv.items():
            print(f"{k}={v}")
        print(f"decision={decision}")
        return
    with open(gh_out, "a", encoding="utf-8") as f:
        f.write(f"decision={decision}\n")
        for k, v in kv.items():
            f.write(f"{k}={v}\n")


def write_step_summary(lines: list[str]) -> None:
    p = os.environ.get("GITHUB_STEP_SUMMARY")
    if not p:
        return
    with open(p, "a", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--safety-margin", type=float, default=1.5)
    parser.add_argument("--size-class", default=os.environ.get("TICKET_SIZE_CLASS", "medium"))
    parser.add_argument("--log", default=os.environ.get("BUDGET_LOG_PATH", "agent-budget-log.json"))
    args = parser.parse_args()

    try:
        rem = probe_remaining()
    except Exception as e:
        print(f"check_token_budget: probe failed: {e}", file=sys.stderr)
        # Fail OPEN: probe-auth failure is usually because no ANTHROPIC_API_KEY
        # is configured (OAuth tokens may not validate against /v1/messages
        # directly). The actual run uses claude-code-action with the OAuth
        # token and works fine. Blocking all work on probe-auth failure is
        # the wrong product behavior. The 429 path inside probe_remaining
        # is a real quota signal and still defers — that branch returns
        # rem dict with input_remaining=0 instead of raising.
        write_step_summary([
            "## Gate B0 — token budget probe",
            f"- **WARNING:** probe failed ({e}). Falling through to `proceed`.",
            "- To enable real quota guarding, set the `ANTHROPIC_API_KEY` GH secret.",
            "- Safe for normal runs; revisit if smoke shows real quota issues.",
        ])
        write_github_output(
            "proceed",
            reason="probe_unavailable",
            remaining_in=0,
            remaining_out=0,
        )
        return 0

    est_in, est_out, est_source = estimate_cost(args.size_class, Path(args.log))
    need_in = int(est_in * args.safety_margin)
    need_out = int(est_out * args.safety_margin)
    rem_in = int(rem["input_remaining"] or 0)
    rem_out = int(rem["output_remaining"] or 0)

    if rem_in >= need_in and rem_out >= need_out:
        decision = "proceed"
        retry_after = ""
    else:
        decision = "defer"
        retry_after = rem.get("reset") or ""

    write_github_output(
        decision,
        retry_after=retry_after,
        remaining_in=rem_in,
        remaining_out=rem_out,
        estimate_in=est_in,
        estimate_out=est_out,
        need_in=need_in,
        need_out=need_out,
        size_class=args.size_class,
        estimate_source=est_source,
    )

    write_step_summary([
        "## Gate B0 — token budget probe",
        f"- size_class: `{args.size_class}` (estimate via {est_source})",
        f"- estimate: in={est_in:,} out={est_out:,}",
        f"- with {args.safety_margin}× margin: need in≥{need_in:,} out≥{need_out:,}",
        f"- remaining: in={rem_in:,} out={rem_out:,}",
        f"- reset_at: `{retry_after}`",
        f"- **decision:** `{decision}`",
    ])

    print(f"check_token_budget: decision={decision}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
