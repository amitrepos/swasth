# Swasth Health App — Claude Code Instructions

> **Map, not manual.** This file is a small, stable index. Hard rules live in **hooks** (deterministic,
> fail-closed), not in prose here. Detailed procedures live in the linked docs. (Slimmed in Phase 1c
> of the agent-platform upgrade — see `docs/agent-platform/FINDINGS.md`.)

## Project Overview
Flutter + FastAPI health monitoring app. Target: Bihar pilot.
Backend: Python/FastAPI + PostgreSQL. Frontend: Flutter (web + mobile).
Production: **AWS Mumbai (ap-south-1)**, EC2 `swasth-prod` t3.micro, Elastic IP `13.127.215.113`
(source of truth: `docs/aws/AWS_ARTIFACTS.md`; Hetzner is decommissioned).

## Response Length Rule
Full rule in `.claude/output-styles/swasth-concise.md` (active via `settings.local.json` →
`outputStyle`; enforced by `UserPromptSubmit` + `Stop` hooks). TL;DR: ≤ 100 words, bullets only, end
with "Want an elaborative answer?" — unless the user uses an elaborate trigger.

## Session Start Protocol (automatic)
1. SessionStart hook loads previous context + learnings (`.claude/sessions/latest.md`).
2. Read `WORKING-CONTEXT.md` (current sprint state).
3. Read `.claude/compact-state.md` if present (resume after compaction).
4. Check `.claude/learnings/` for project patterns.

## Key Files (read these first)
- `WORKING-CONTEXT.md` — **live sprint board** (branch, PRs, blockers, priorities).
- `RULES.md` — **Must Always / Must Never**, commit style, model routing.
- `TASK_TRACKER_PENDING.md` — active incomplete tasks (🔴 blocker → 🟡 nice → 🔵 post-pilot → ⚪ future).
  Note: JIRA (project NUO) is the primary tracker for new work; creds in `.env`.
- `TASK_TRACKER_COMPLETED.md` — shipped-task + PR archive (read-only).
- `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` — doctor-portal legal checklist (NMC, DPDPA, SaMD).
- `AUDIT.md` — change log (update every session).

## How we work (linked, not inlined)
- **`docs/DEVELOPMENT_PIPELINE.md`** — the enforced 9-stage pipeline (understand → reality-check →
  plan → validate → implement (TDD) → verify (7-phase) → secure → expert QA → review → ship) + E2E
  test policy. No step is optional.
- **`.claude/workflows/branch-safety.md`** — branch hygiene, drift-prevention, the review matrix, and
  AWS deployment commands. **Enforced by git hooks + CI**, not advisory.
- **`docs/ARCHITECTURE_DECISIONS.md`** — locked technical choices.
- **`docs/agent-platform/`** — the agent-platform upgrade (FINDINGS, SKILLS_AUDIT, MALICIOUS_TICKET_SPEC).

## Deterministic guardrails (hooks — they block, prose doesn't)
Rules that must hold are enforced in code that fails closed:
- **Git hooks** (`.githooks/pre-commit`, `pre-push`): branch hygiene, orphan-commit detection,
  migration-required, the domain-expert review-marker chain.
- **Claude Code hooks** (`.claude/settings.json`): config/gate-file edits blocked
  (`hook-guard-config-edit.sh`, bypass `SWASTH_BYPASS_CONFIG_EDIT=1`); destructive ops blocked
  (`hook-guard-destructive.sh`, bypass `SWASTH_ALLOW_DESTRUCTIVE=1`); sandboxed-agent worktree
  confinement + command allowlist (`hook-guard-worktree.sh`, `hook-guard-command.sh`, agent-context only).
- **Review matrix:** canonical data in `.claude/reviewers-matrix.json`, enforced by
  `.claude/scripts/check-required-reviewers.sh`. Daniel is always last. **Meera moved to the intake
  gate** (validate necessity before building).

## Slash Commands
**Dev:** `/blueprint` · `/tdd` · `/verify` · `/security-audit` · `/review` (Daniel) · `/ship`.
**Domain experts:** `/ux-review` (Aditya) · `/qa-review` (Priya) · `/doctor-feedback` (Dr. Ramesh) ·
`/legal-check` · `/phi-compliance` · `/sunita`.
**Strategic / decision:** `/reality-check` (Meera) · `/council` (standalone) · `/safety-guard`.
**Session:** `/learn` · `/compact-now`.

## Code Rules (full list in `RULES.md`)
- Colors via `AppColors.*` — never raw `Colors.*`.
- Strings via `AppLocalizations.of(context).*` — never hardcode UI text.
- HTTP via `ApiClient.headers()` + `ApiClient.errorDetail()`.
- Auth via `Depends(get_current_user)`.
- No `print()` in backend.
- Check `TASK_TRACKER_PENDING.md` / JIRA before starting new feature work.
