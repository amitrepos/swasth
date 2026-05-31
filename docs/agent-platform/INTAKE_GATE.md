# Intake Gate (WS5) — validate necessity before any code

> Phase 3. Shifts the "should we build this?" question **left**: after Priya's quality PASS, the
> ticket also gets a necessity verdict (Meera + Sunita + Doctor), then **holds for a human GO/NO-GO
> before any branch is created** (fixes G6 — gold-plating). Skills: see
> `.claude/skills/{reality-check,sunita,doctor-feedback,priya-ticket-quality}/SKILL.md`.

## Flow (when enabled)
```
agent:matt on a ticket
   → producer: Priya quality gate
       PASS/REWRITTEN → Intake necessity (Meera/Sunita/Doctor, aggregated by Priya)
           INTAKE_VERDICT: not-needed          → comment + label intake-not-needed + drop agent label.  STOP.
           INTAKE_VERDICT: needs-clarification → comment + label intake-needs-clarification + drop agent label.  HOLD.
           INTAKE_VERDICT: needed              → comment + label awaiting-go.  HOLD for human.
   (no enqueue, no worker — nothing is built yet)
   ─────────────────────────────────────────────────────────────────────────
Human reads the verdict → GO  → add label `agent:go` (JIRA rule re-fires producer with human_go=true)
   → producer skips intake, re-checks quality, ENQUEUES → worker builds.
```
When the gate is **OFF** (default), the producer behaves exactly as before: quality PASS/REWRITTEN
enqueues immediately. Nothing changes until you opt in.

## Enabling
1. **Repo variable:** set `SWASTH_INTAKE_GATE=on`
   (`gh variable set SWASTH_INTAKE_GATE --body on`). Unset/anything-else = off.
2. **JIRA automation rule** (the human-GO trigger): *When* label `agent:go` added to an issue *and*
   the issue has `agent-status:awaiting-go` → *send web request* `repository_dispatch`
   (`event_type: jira-ticket-assigned`) with `client_payload` including `ticket_key`, the original
   `agent:*` label, and **`human_go: "true"`**. (Mirror the existing `agent:matt` dispatch rule;
   just add `human_go`.)
3. Optional JIRA statuses/labels to make visible: `intake-not-needed`, `intake-needs-clarification`,
   `awaiting-go` (these are agent-status labels written via `scripts/jira_set_status_label.sh`).

## Disabling / rollback
`gh variable set SWASTH_INTAKE_GATE --body off` (or delete the variable). The intake steps become
no-ops and enqueue resumes immediately on quality PASS. Fully reversible; no code revert needed.

## Manual test (workflow_dispatch)
- **Hold path:** with `SWASTH_INTAKE_GATE=on`, dispatch the producer for a real ticket without
  `human_go`. Expect: intake verdict posted, ticket labelled, **no enqueue / no worker kick**
  (check the run Summary: "Intake verdict" set, Enqueue/Kick skipped).
- **GO path:** re-dispatch the same ticket with `human_go=true`. Expect: intake skipped, quality
  re-checked, **enqueue + worker kick** fire.

## Fail-safe
If the intake step yields no parseable `INTAKE_VERDICT`, the producer treats it as
**needs-clarification** and holds — it never silently proceeds to build.
