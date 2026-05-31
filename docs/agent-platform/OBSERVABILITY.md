# Observability & Audit (WS8)

> Phase 7 (final). Every agent run is reconstructable: the guards log what they saw, the worker
> attaches a summary to the run + JIRA, and alert-worthy events open a GitHub issue.

## What is captured
The WS2 guard hooks emit a JSONL **audit event** at every interesting decision (via
`.claude/scripts/hook-audit-lib.sh`, active only when `SWASTH_AGENT_AUDIT_LOG` is set — a no-op in
interactive dev):

```json
{"ts":"2026-05-31T14:19:53Z","guard":"command","event":"block","detail":"curl"}
{"ts":"...","guard":"config-edit","event":"bypass","detail":"SWASTH_BYPASS_CONFIG_EDIT=1"}
{"ts":"...","guard":"worktree","event":"audit","detail":"/etc/passwd"}
```

- **guard:** `command` · `worktree` · `config-edit` · `destructive`
- **event:** `block` (denied) · `audit` (would-block in audit mode) · `bypass` (escape hatch used)
- Network egress is logged separately by **harden-runner** (its own run annotations / StepSecurity
  dashboard); the guard log covers commands, file writes, and gate/config tampering.

## Per-run reporting (worker)
`jira-agent-worker.yml` sets `SWASTH_AGENT_AUDIT_LOG` on the agent steps, then in a **non-fatal,
`if: always()`** step:
- runs `scripts/summarize_agent_audit.py` → markdown summary into the **GitHub run summary** and a
  **JIRA comment** on the ticket;
- **uploads the raw JSONL** as a build artifact (`guard-audit-<run_id>`);
- if any `block`/`bypass`/`error` event is present, **opens a GitHub issue** (`agent-alert` label).

This step can never break a build — it is pure reporting (`|| true`, `continue-on-error`).

## Alerts
Alert-worthy = any `block` (a guard stopped something), `bypass` (an escape hatch was used — should
be rare and reviewed), or `error` (a malformed audit line / hook failure). These surface as:
- a GitHub issue (`agent-alert`) per run, and
- the run summary + JIRA comment.

Blocked **egress** attempts are surfaced by harden-runner directly. When the egress policy flips from
`audit` to `block` (a later reviewed change), those become hard denials visible in the run.

## Acceptance
Any merged or rejected change is fully reconstructable from: the PR + Daniel/persona reviews (WS4),
the worker run summary + uploaded audit log (WS8), the JIRA trail (WS7 completion summary), and the
queue state on the `automation-state` branch. A guard that fires is never silent.

## Local use
`SWASTH_AGENT_AUDIT_LOG=/tmp/a.jsonl <run guards> ; python3 scripts/summarize_agent_audit.py /tmp/a.jsonl`
