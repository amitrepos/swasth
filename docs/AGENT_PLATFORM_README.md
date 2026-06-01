# Agent Platform — One-Page Summary

JIRA-driven, guard-railed agent platform that takes a ticket from assignment to merged PR with no
human required on the happy path. Built in 8 phases; each phase doc lives in
[`docs/agent-platform/`](agent-platform/).

## Phases

| Phase | Name | Doc |
|-------|------|-----|
| 0 | Discovery — current-state map, sizing math, sandbox decision | [FINDINGS.md](agent-platform/FINDINGS.md) |
| 1 | Skills audit — reconcile 21 skills; shrink `CLAUDE.md` to a stable index | [SKILLS_AUDIT.md](agent-platform/SKILLS_AUDIT.md) |
| 2 | Sandbox — GitHub-hosted ephemeral isolation with egress allowlist + guards | [SANDBOX.md](agent-platform/SANDBOX.md) |
| 3 | Intake gate — Priya quality + Meera/Sunita/Doctor necessity verdict before any branch | [INTAKE_GATE.md](agent-platform/INTAKE_GATE.md) |
| 4 | Independent review — CI-run reviewer personas emit commit statuses on PR diff | [INDEPENDENT_REVIEW.md](agent-platform/INDEPENDENT_REVIEW.md) |
| 5 | Merge policy — auto-merge on green; human hold for sensitive diffs | [MERGE_POLICY.md](agent-platform/MERGE_POLICY.md) |
| 6 | Parallel orchestration — cap-2 worktrees + JIRA completion summary on merge | [ORCHESTRATION.md](agent-platform/ORCHESTRATION.md) |
| 7 | Assignee flow — assign to Priya → auto-handoff to Matt → Done, fully automatic | [ASSIGNEE_FLOW.md](agent-platform/ASSIGNEE_FLOW.md) |

## Key design choices

- **Audit-first rollout:** guards and egress controls start in `audit` mode; flip to `enforce` after
  observing one or two real runs.
- **Flag-gated toggles:** phases 3–7 ship with feature flags off; enable via repo variables
  (`SWASTH_ASSIGNEE_FLOW`, `SWASTH_INTAKE_GATE`, etc.) once prerequisites are met.
- **No self-certification:** review markers are gitignored; CI runs personas against the PR diff
  independent of the author (Phase 4).
- **Malicious-ticket hardening spec:** [`MALICIOUS_TICKET_SPEC.md`](agent-platform/MALICIOUS_TICKET_SPEC.md).
