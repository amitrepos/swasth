#!/usr/bin/env python3
"""Atomic multi-claim for the agent work queue (WS3 — parallel orchestration, cap=N).

The current serial worker pops the queue head and only marks it `in_flight` LATER, so two concurrent
workers could pick the same ticket. This module claims up to `cap` ready tickets **and marks them
in_flight in the same pass**, so when run inside `scripts/write_to_automation_state.sh`'s
rebase-retry mutator (single-writer-at-a-time on the automation-state branch), a second concurrent
claim sees the first's marks and never double-picks.

Concurrency = total in_flight. available = cap - current_in_flight; claim min(available, ready).

Routing seam (WS3): each entry carries an `agent` label; `route()` maps it to a builder. Today every
ticket routes to `matt` (Richa/Karan deferred); the seam exists so component/label routing can be
added later without changing callers.

CLI (for use as a write_to_automation_state mutator):
    orchestrator_claim.py --in "$CURRENT" --out "$NEXT" --claimed claimed.json \
        --cap 2 --run-id "$WORKER_RUN_ID" --now "$NOW"
Writes the updated queue to --out and the claimed entries (with assigned builder) to --claimed.
"""
import argparse
import json
import sys


def route(agent_label):
    """Map an agent label to a builder. Seam for future component routing; all → matt for now."""
    # e.g. future: if label endswith ':frontend' -> 'richa'; ':infra' -> 'karan'
    return "matt"


def claim(queue, cap, run_id, now, started_at=None):
    entries = queue.get("entries", [])
    in_flight = [e for e in entries if e.get("state") == "in_flight"]
    available = max(0, cap - len(in_flight))

    ready = [
        e for e in entries
        if e.get("state") == "queued" and (e.get("retry_after") or now) <= now
    ]
    ready.sort(key=lambda e: (-(e.get("priority_rank") or 0), e.get("queued_at") or ""))

    claimed = []
    for e in ready[:available]:
        e["state"] = "in_flight"
        e["worker_run_id"] = run_id
        if started_at:
            e["started_at"] = started_at
        e["_builder"] = route(e.get("agent", ""))
        claimed.append(e)
    return queue, claimed


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True)
    ap.add_argument("--out", dest="out", required=True)
    ap.add_argument("--claimed", dest="claimed", required=True)
    ap.add_argument("--cap", type=int, default=2)
    ap.add_argument("--run-id", default="local")
    ap.add_argument("--now", required=True)
    ap.add_argument("--started-at", default=None)
    args = ap.parse_args(argv)

    if args.inp in ("/dev/null", "-"):
        queue = {"entries": []}
    else:
        try:
            with open(args.inp) as f:
                queue = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            queue = {"entries": []}

    queue, claimed = claim(queue, args.cap, args.run_id, args.now, args.started_at)

    with open(args.out, "w") as f:
        json.dump(queue, f, indent=2)
    with open(args.claimed, "w") as f:
        json.dump({"claimed": claimed, "count": len(claimed)}, f, indent=2)
    print(f"claimed {len(claimed)} ticket(s)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
