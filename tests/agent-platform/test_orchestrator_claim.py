#!/usr/bin/env python3
"""Tests for scripts/orchestrator_claim.py (WS3 atomic multi-claim). Pure python, no pytest.

Run: python3 tests/agent-platform/test_orchestrator_claim.py
Exits non-zero on failure.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import orchestrator_claim as oc  # noqa: E402

NOW = "2026-05-31T12:00:00Z"
FAILS = []


def check(cond, name):
    print(("  ok   " if cond else "  FAIL ") + name)
    if not cond:
        FAILS.append(name)


def q(*entries):
    return {"entries": [dict(e) for e in entries]}


def e(key, state="queued", rank=0, queued_at="2026-05-31T10:00:00Z", retry_after=None, agent="agent:matt"):
    d = {"ticket_key": key, "state": state, "priority_rank": rank, "queued_at": queued_at, "agent": agent}
    if retry_after:
        d["retry_after"] = retry_after
    return d


# cap=2, two ready → claim both
_, claimed = oc.claim(q(e("A"), e("B")), cap=2, run_id="r1", now=NOW)
check(len(claimed) == 2, "cap=2 with 2 ready claims both")

# cap=1, two ready → claim one (highest priority/oldest)
_, claimed = oc.claim(q(e("A", rank=1), e("B", rank=5)), cap=1, run_id="r1", now=NOW)
check(len(claimed) == 1 and claimed[0]["ticket_key"] == "B", "cap=1 claims highest priority")

# one already in_flight, cap=2 → claim one more (total in_flight stays <= cap)
queue, claimed = oc.claim(q(e("A", state="in_flight"), e("B"), e("C")), cap=2, run_id="r1", now=NOW)
inflight = [x for x in queue["entries"] if x["state"] == "in_flight"]
check(len(claimed) == 1 and len(inflight) == 2, "respects cap with one already in_flight")

# two already in_flight, cap=2 → claim none
_, claimed = oc.claim(q(e("A", state="in_flight"), e("B", state="in_flight"), e("C")), cap=2, run_id="r1", now=NOW)
check(len(claimed) == 0, "claims none when cap already saturated")

# deferred entry (retry_after in the future) is not claimed
_, claimed = oc.claim(q(e("A", retry_after="2099-01-01T00:00:00Z"), e("B")), cap=2, run_id="r1", now=NOW)
check(len(claimed) == 1 and claimed[0]["ticket_key"] == "B", "skips deferred (future retry_after)")

# claimed entries are marked in_flight with the run id and a builder (routing seam)
queue, claimed = oc.claim(q(e("A")), cap=2, run_id="run-xyz", now=NOW)
a = queue["entries"][0]
check(a["state"] == "in_flight" and a["worker_run_id"] == "run-xyz" and a.get("_builder") == "matt",
      "claimed entry marked in_flight + run id + routed to matt")

# atomicity: a SECOND claim on the already-mutated queue does not re-pick the same ticket
queue2, claimed2 = oc.claim(queue, cap=2, run_id="run-2", now=NOW)
check(len(claimed2) == 0, "second claim on mutated queue does not double-pick")

print()
print(f"RESULT: orchestrator_claim — {7 - len(FAILS)} passed, {len(FAILS)} failed")
sys.exit(1 if FAILS else 0)
