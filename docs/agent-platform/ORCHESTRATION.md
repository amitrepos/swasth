# Parallel Orchestration (WS3) + JIRA completion (WS7)

> Phase 6. WS7 (Matt completion summary on merge) is **shipped and live**. WS3 (cap=2 parallel
> orchestration with per-task worktrees) ships its **safe foundation** here; the live-worker cutover
> is a **supervised follow-up** (it rewrites the production worker and needs a real test run).

## WS7 — Matt completion summary (LIVE)
`jira-agent-pr-closed.yml` merged-path now posts a Matt-authored completion summary to the ticket —
what was built (PR title), PR link + merge SHA, change size (files/+/-), CI-checks-at-merge, and key
files — then moves the ticket to Done. Deterministic (composed from PR metadata via the API), so it
is reliable and free (no model call).

## WS3 — why a primitive first
The current worker is **single-concurrency** and its queue **pop is not atomic**: it reads the head,
then marks `in_flight` only later (when it creates the branch). Two concurrent workers would pick the
**same** ticket in that window. So you cannot safely raise concurrency by changing the
`concurrency:` group alone — you first need an **atomic claim**.

### The atomic-claim primitive (shipped + tested)
`scripts/orchestrator_claim.py` claims up to `cap` ready tickets **and marks them in_flight in the
same pass**. Run inside `scripts/write_to_automation_state.sh`'s rebase-retry mutator (single-writer
at a time on the `automation-state` branch), a second concurrent claim sees the first's marks and
never double-picks. Concurrency = total in_flight; `available = cap - current_in_flight`. Tests:
`tests/agent-platform/test_orchestrator_claim.py` (cap respect, saturation, deferred skip, routing,
no-double-pick).

It also carries the **routing seam**: each entry's `agent` label → `route()` → a builder. Today every
ticket routes to `matt` (Richa/Karan deferred); the seam lets component/label routing be added later
without changing callers.

## WS3 — the cutover design (NOT yet applied to the live worker)
When ready, rebuild `jira-agent-worker.yml` into an **orchestrator + builders**:

1. **Cap as one config value:** repo var `SWASTH_AGENT_CONCURRENCY` (default `2`).
2. **Dispatcher job:** reconcile in_flight, then `orchestrator_claim.py --cap $N` inside the
   automation-state mutator → claims up to N ready tickets atomically → outputs the claimed set as a
   matrix.
3. **Builder matrix job** (`strategy.matrix` over the claimed tickets, `max-parallel: N`): each leg
   - creates a **per-task git worktree** (`git worktree add ../wt-<ticket> origin/master`) so the two
     builders never share a working tree;
   - sets `SWASTH_AGENT_WORKTREE=<that worktree>` + `SWASTH_AGENT_SANDBOX` so the Phase-2 guards
     confine each builder to its own worktree;
   - runs the existing gate chain (token budget → drift → coverage → regression → Priya QA → draft PR)
     scoped to its ticket;
   - **orchestrator map:** before building, Matt selects only the relevant files via ripgrep/index
     and works from a scoped brief (not the whole repo in-prompt).
4. **Model tiering:** cheap model (sonnet) for dispatcher triage/file-selection and the reviewers;
   frontier model for the build step.
5. **Concurrency:** drop the single `group: jira-agent-worker`; the cap is enforced by the claim
   (in_flight ≤ N) + `max-parallel: N`, not by a mutex.

### Acceptance (collect on the supervised test run)
2 ready tickets → 2 worktrees → 2 draft PRs concurrently, each touching only its scoped files, within
cap and the token budget; no queue double-pick; every merged ticket ends Done with a Matt summary.

### Why it's a supervised follow-up
This rewrites the production worker that the team relies on for merges. Per "quality over speed — we
handle health data," the cutover should be done with a live smoke test (e.g. 2 planted low-risk
tickets) watched end-to-end, not shipped blind. The atomic-claim primitive + worktree guards + WS7
land now so that cutover is then a mechanical, well-tested step.
