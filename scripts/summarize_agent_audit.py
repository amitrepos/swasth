#!/usr/bin/env python3
"""Summarize a guard audit log (WS8 observability) and flag alert-worthy events.

Reads the JSONL written by the WS2 guards (via .claude/scripts/hook-audit-lib.sh when
SWASTH_AGENT_AUDIT_LOG is set): one object per line with keys ts, guard, event, detail.
Produces a markdown summary for the PR/JIRA run report, and decides whether the run is
alert-worthy (any block or bypass event, or a hook failure).

Usage:
    python3 scripts/summarize_agent_audit.py <audit.jsonl> [--github-output]
    cat audit.jsonl | python3 scripts/summarize_agent_audit.py -

`--github-output` appends `alert=true|false` and `alert_count=<n>` to $GITHUB_OUTPUT so a workflow
can open an alert issue when alert == true. Missing/empty log → clean summary, alert=false.
"""
import json
import os
import sys

# Events that warrant an alert (gate-bypass, a hard block, or a hook failure).
ALERT_EVENTS = {"block", "bypass", "error"}


def load(lines):
    events = []
    for ln in lines:
        ln = ln.strip()
        if not ln:
            continue
        try:
            events.append(json.loads(ln))
        except json.JSONDecodeError:
            events.append({"guard": "?", "event": "error", "detail": "unparseable audit line"})
    return events


def summarize(events):
    by_guard = {}
    by_event = {}
    alerts = []
    for e in events:
        g = e.get("guard", "?")
        ev = e.get("event", "?")
        by_guard[g] = by_guard.get(g, 0) + 1
        by_event[ev] = by_event.get(ev, 0) + 1
        if ev in ALERT_EVENTS:
            alerts.append(e)

    lines = ["### 🛡️ Agent run — guard audit summary", ""]
    if not events:
        lines.append("_No guard events recorded (clean run)._")
    else:
        lines.append(f"- Total guard events: **{len(events)}**")
        lines.append("- By event: " + ", ".join(f"`{k}`×{v}" for k, v in sorted(by_event.items())))
        lines.append("- By guard: " + ", ".join(f"`{k}`×{v}" for k, v in sorted(by_guard.items())))
        if alerts:
            lines.append("")
            lines.append(f"#### ⚠️ {len(alerts)} alert-worthy event(s)")
            for e in alerts[:50]:
                lines.append(f"- `{e.get('guard')}` **{e.get('event')}** — `{e.get('detail','')}` "
                             f"({e.get('ts','?')})")
    return "\n".join(lines), alerts


def main(argv):
    gh_out = "--github-output" in argv
    args = [a for a in argv if not a.startswith("--")]
    path = args[0] if args else "-"

    if path == "-":
        events = load(sys.stdin.readlines())
    elif not os.path.exists(path):
        events = []
    else:
        with open(path) as f:
            events = load(f.readlines())

    md, alerts = summarize(events)
    print(md)

    if gh_out and os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as f:
            f.write(f"alert={'true' if alerts else 'false'}\n")
            f.write(f"alert_count={len(alerts)}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
