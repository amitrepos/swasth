# JIRA Agent Automation — Runbook

Label a JIRA ticket with `agent:matt` (or `agent:aditya`, `agent:daniel`, `agent:sunita`, `agent:doctor`). Priya audits the ticket; if it passes, Matt implements end-to-end on a `feat/nuo-*` branch and opens a **draft** PR. You review, mark "Ready for review," and merge manually.

This document is the operator's runbook. The full design lives in `/Users/amitkumarmishra/.claude/plans/i-want-to-set-fuzzy-sun.md`.

## At a glance

```
JIRA label → repository_dispatch → trigger workflow
  └─ Gate A · Priya ticket-quality                  (read-only on repo)
  └─ enqueue to jira-work-queue.json (automation-state branch)
  └─ kick worker
       ├─ Gate B0 · token budget pre-flight
       ├─ Matt implements + iterative coverage loop
       ├─ Gate C-regress · churn → unit → integration → smoke → baseline
       ├─ Gate C-qual   · Priya /qa-review (3-class evidence table)
       └─ rebase + push + open DRAFT PR  + JIRA comment
DRAFT PR → daniel-pr-review.yml + agent-pr-policy.yml
         → YOU: Ready for review → CI → MERGE
```

## One-time setup

### 1. GitHub repository secrets (use `gh secret set`, never the UI)

```bash
gh secret set JIRA_URL --body "https://technologiesraycraft-1778048629514.atlassian.net"
gh secret set JIRA_EMAIL --body "amitkumarmishra@gmail.com"
gh secret set JIRA_API_TOKEN < ~/path/to/jira-api-token.txt
gh secret set ANTHROPIC_API_KEY < ~/path/to/anthropic-api-key.txt
# CLAUDE_CODE_OAUTH_TOKEN already exists (used by daniel-pr-review.yml).
```

### 2. JIRA Automation rule (project NUO → Automation → Create rule)

- **Trigger:** Issue field value changed → field = `Labels`.
- **Condition 1:** Labels contains regex `^agent:`.
- **Condition 2 (actor allowlist — per Matt audit C3):** Trigger user is one of `[amitkumarmishra@gmail.com]`. Extend this list when adding teammates.
- **Action:** Send web request:
  - URL: `https://api.github.com/repos/amitrepos/swasth/dispatches`
  - Method: POST
  - Headers:
    - `Authorization: Bearer <fine-grained PAT — see step 3>`
    - `Accept: application/vnd.github+json`
    - `User-Agent: swasth-jira-bot`
  - Body (JSON):
    ```json
    {
      "event_type": "jira-ticket-assigned",
      "client_payload": {
        "ticket_key": "{{issue.key}}",
        "agent": "{{#issue.labels}}{{#startsWith}}agent:{{/startsWith}}{{.}}{{/issue.labels}}",
        "summary": "{{issue.summary}}",
        "triggered_by": "{{initiator.displayName}}"
      }
    }
    ```

### 3. GitHub fine-grained PAT for JIRA (per Matt audit C4)

- Scopes: `Contents: write`, `Metadata: read`, `Pull requests: write` ONLY.
- Repository: `amitrepos/swasth` ONLY.
- Owner: your own account. No org-level admin.
- Store in JIRA Automation (not as a GitHub repo secret — JIRA needs to hold it).

### 4. Branch protection (per Matt audit C4)

On `master`:
- Require a pull request before merging (1 approval minimum).
- Require status checks to pass: `ci`, `branch-hygiene`, `migration-check`, `daniel-pr-review`, `agent-pr-policy`.
- Restrict who can push: maintainers only. Do NOT exempt any bot identity.
- Disable "Allow force pushes" and "Allow deletions".
- Disable "Allow specified actors to bypass required pull requests" (no bypass list).

On `automation-state`:
- Same as master EXCEPT allow pushes from `swasth-automation-bot` identity (the bot needs to write the queue / budget log).
- No human approval required (the worker workflow pushes hundreds of times a day).

### 5. JIRA workflow — add custom statuses to NUO

Statuses Priya and the worker need to transition to (if not already present):
- `Spec Ready` — Priya rewrote the ticket and it is ready for the worker.
- `Needs Info` — Priya asked clarifying questions; user must answer + re-label.
- `Needs Human` — A gate aborted; manual investigation needed.
- `In Review` — Worker opened a draft PR.

### 6. Test PR before going live (per Matt audit C4)

Once secrets and branch protection are in place, deliberately try a direct push from the bot identity to master to confirm it fails:
```bash
# As the bot user with a freshly minted fine-grained PAT:
GH_TOKEN=<bot-pat> git push https://github.com/amitrepos/swasth.git HEAD:master
# Expected: 403, "Resource not accessible by integration"
```

### 7. JIRA project PHI audit (per Matt audit C5)

Before turning automation on for the first ticket, scan existing NUO tickets for real patient data:
```bash
python3 -c "
import os, requests
r = requests.get(
  f\"{os.environ['JIRA_URL']}/rest/api/3/search?jql=project=NUO&fields=summary,description,comment&maxResults=200\",
  auth=(os.environ['JIRA_EMAIL'], os.environ['JIRA_API_TOKEN']))
for t in r.json().get('issues',[]):
  print(t['key'], (t['fields']['summary'] or '')[:80])
"
```
If real PHI is present in any ticket, sanitize it before continuing — `phi_scrub.py` only protects future comments, not history.

## Agent label cheat-sheet

| Label | Implementer | Persona lens loaded | Best for |
|---|---|---|---|
| `agent:matt` *(default)* | `/matt` | none | refactors, bug fixes, backend |
| `agent:engineer` | `/matt` | none | alias for `agent:matt` |
| `agent:daniel` | `/matt` | `/daniel-review` | backend hardening |
| `agent:aditya` | `/matt` | `/aditya` | Flutter UI/UX |
| `agent:sunita` | `/matt` | `/sunita` | patient-flow copy, Hindi |
| `agent:doctor` | `/matt` | `/doctor-feedback` | clinical features |

## Bypass labels (use sparingly, audited)

- `bypass-priya` — skip Gate A (ticket quality). Only honored if the user who added it is in the JIRA Automation allowlist.
- `bypass-budget-check` — skip Gate B0 (token budget). Accept half-finished-run risk.
- `SWASTH_BYPASS_AGENT_POLICY=1` — env var that bypasses the local pre-commit / pre-push markers check. Only for emergency local hotfixes; CI will still enforce.

## What gates do, what they don't

**Gate A · Priya ticket-quality** — does the ticket have a user story, ≥2 acceptance criteria, scope, affected surfaces, edge cases? Priya quotes each rubric check verbatim from the ticket body; the workflow's `verify_priya_evidence.sh` greps each quote against the body and force-downgrades a hallucinated PASS to NEEDS_INFO.

**Gate B0 · Token-budget pre-flight** — probes Anthropic's rate-limit headers, looks up size-class average in `agent-budget-log.json`, applies 1.5× margin, defers (keeps in queue, sets `retry_after`) if insufficient. Cron `*/15m` retries.

**Gate C-quant · Coverage** — `pytest-cov` + `flutter test --coverage` over the diff, tier targets 95/90/85% from `CLAUDE.md` Stage 5. Matt iterates up to 3 times writing more tests.

**Gate C-regress · No regression / no churn** — churn check FIRST (fail-fast), then unit + integration + smoke suites (each capped at 10m), then diff against `.claude/test-baseline.json`. Any regression → `Needs Human`.

**Gate C-qual · Priya /qa-review** — three-class evidence table (unit / integration / smoke). If any required class shows `GAP`, verdict is MUST_FIX.

**Gate B · Merge stays with you** — PR is opened as draft. Branch protection requires reviews. Worker's tool whitelist excludes `gh pr merge` and `gh pr ready`. Only you can mark the PR ready and merge.

## PHI scrubbing — defense-in-depth (per Matt audit N3)

`scripts/phi_scrub.py` runs on every JIRA comment write. It is REGEX-based and best-effort. The primary PHI control is `backend/tests/fixtures/synthetic.sql` carrying the `-- SYNTHETIC ONLY` header — integration tests cannot see real patient data because the integration DB is seeded only from that fixture.

If real PHI ever sneaks into a test fixture, `check_no_regression.sh` aborts the run.

## Debugging a failed run

1. **Actions tab** → look for the run titled `worker · NUO-92 · …`.
2. **JIRA ticket** → audit log + comments show what the bot said.
3. **`automation-state` branch** → `queue-status.md` shows current head + in-flight.
4. **GHA logs** retention is 7 days; export earlier if needed.

Common failure modes:
- **Stuck queue (>6h head)** → `queue-stuck-alert.yml` fires automatically (JIRA comment + GH issue).
- **Drift detected at pop time** → ticket was edited after Priya approved; worker re-routes to Priya. Re-add the agent label after confirming spec.
- **Push blocked by pre-push hook** → markers missing or `quality-passed` label not set. Re-run the worker; do not bypass.
- **PR opened but Daniel review is angry** → fix manually on the branch; worker won't re-pick up the same branch.

## Disable temporarily

Toggle the JIRA Automation rule off in JIRA UI. No code change needed. The worker cron keeps running but the queue stays empty.

## Manual merge flow

1. Read the draft PR diff end-to-end.
2. Read Daniel's auto-review.
3. Run local tests if you don't trust CI (`flutter test test/flows/`, `pytest`).
4. Mark "Ready for review."
5. Wait for CI to re-run (Daniel + agent-pr-policy + branch-hygiene + migration-check).
6. Click **Merge** (squash recommended).

## Meera's YELLOW conditions (kill-switch metrics)

Meera (reality-check) graded the pipeline YELLOW with user approval, given the new context: 30 active patients, 3 doctors testing, POC-blocker backlog, team downsized to 1–2 devs. The two things that must hold for this to keep earning its keep over the next 4 weeks:

1. **Throughput delta with quality held constant.**
   - Baseline: POC-blockers closed per week with humans only (likely 2–4).
   - Target post-launch: ≥2× baseline.
   - Guardrail: Daniel-review reject rate < 30% on agent PRs.
   - Hard stop: zero rollback-causing bugs reaching the 30 patients.
   - If reject rate climbs above 30%, the agents are creating review work, not removing it — pause and recalibrate.

2. **Cost-per-merged-PR ceiling.**
   - Track LLM spend per merged agent PR (Anthropic dashboard + `agent-budget-log.json`).
   - Target: ≤ ₹500 / merged PR (≈ 1 hour of human dev cost at current burn).
   - Kill switch: ≥ ₹1,000 / merged PR → pause the automation, investigate before resuming.

Owner of the metrics: the same person who reviews the PRs. Tracked weekly in `WORKING-CONTEXT.md` for the first month.

## Follow-ups (still open)

- **m1** — actor-restrict `bypass-priya` and `bypass-budget-check` (currently only doc-restricted).
- **m2** — confirm CODEOWNERS file actually lists `automation-state` correctly.
- **m4** — worker pins `.claude/test-baseline.json` SHA at pop time (currently reads at evaluation time; race window is small but exists).
