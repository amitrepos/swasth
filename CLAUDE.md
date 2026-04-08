# Swasth Health App — Claude Code Instructions

## Project Overview
Flutter + FastAPI health monitoring app. Target: Bihar pilot.
Backend: Python/FastAPI + PostgreSQL. Frontend: Flutter (web + mobile).

## Session Start Protocol
**At the start of every session, automatically:**
1. The SessionStart hook loads previous session context + learnings (from `.claude/sessions/latest.md`)
2. Read `WORKING-CONTEXT.md` for current sprint state
3. Read `.claude/compact-state.md` if it exists (resume after compaction)
4. Check `.claude/learnings/` for project-specific patterns to follow

## Key Files (read these first)
- `WORKING-CONTEXT.md` — **live sprint board** (current branch, PRs, blockers, priorities)
- `RULES.md` — **Must Always / Must Never rules**, commit style, model routing
- `TASK_TRACKER.md` — full feature status across all modules (A–D)
- `KNOWN_ISSUES.md` — deferred issues tracked for pre-production
- `AUDIT.md` — change log (update on every session)
- `.claude/sessions/latest.md` — previous session summary (auto-loaded)
- `.claude/learnings/*.md` — project patterns discovered over time (auto-loaded)

## Slash Commands

### Development Workflow
- `/blueprint` — Multi-session feature planner (for big features spanning multiple PRs)
- `/tdd` — Test-driven development (RED → GREEN → REFACTOR)
- `/verify` — 6-phase pre-PR quality gate (build, lint, test, security, coverage, diff)
- `/security-audit` — OWASP Top 10 security scan on changed files
- `/review` — Daniel's senior engineer code review
- `/ship` — Full pipeline: test → security → review → commit → PR

### Domain Experts
- `/ux-review` — Healthify's UX/accessibility review
- `/qa-review` — Priya's QA testing strategy review (coverage quality, boundary tests, risk paths)
- `/doctor-feedback` — Dr. Rajesh's product feedback (doctor persona)
- `/legal-check` — India health-tech legal/compliance advisor
- `/phi-compliance` — Health data (PHI) compliance audit (DPDPA, DISHA, encryption)

### Decision Support
- `/council` — 4-voice decision panel (Architect, Skeptic, Pragmatist, Critic)
- `/safety-guard` — Review planned operations for destructive risk

### Session Management
- `/learn` — Capture a project pattern or insight for future sessions
- `/compact-now` — Save full state + suggest optimal compaction point

## Development Pipeline (ENFORCED — no step is optional)

**This pipeline runs for EVERY feature, bug fix, or refactor. Each stage has a GATE that must pass before proceeding. If a gate fails, fix the issue and re-run that stage. Never skip ahead.**

```
┌───────────┐ ┌──────┐ ┌────────┐ ┌───────────┐ ┌────────┐ ┌────────┐ ┌─────────┐ ┌────────┐ ┌──────┐
│1.UNDERSTAND│▶│2.PLAN│▶│3.VALID.│▶│4.IMPLEMENT│▶│5.VERIFY│▶│6.SECURE│▶│7.EXPERT │▶│8.REVIEW│▶│9.SHIP│
│            │ │      │ │        │ │           │ │        │ │        │ │   QA    │ │        │ │      │
│ auto       │ │/bluep│ │/dr-feed│ │ /tdd      │ │/verify │ │/sec-aud│ │/ux-rev  │ │/review │ │commit│
│            │ │/cncil│ │/legal  │ │           │ │6 phase │ │/phi-com│ │/safe-grd│ │(Daniel)│ │PR    │
│            │ │      │ │        │ │           │ │        │ │        │ │/legal   │ │        │ │audit │
│            │ │      │ │        │ │           │ │        │ │        │ │/dr-feed │ │        │ │learn │
└────────────┘ └──────┘ └────────┘ └───────────┘ └────────┘ └────────┘ └─────────┘ └────────┘ └──────┘
    GATE:        GATE:     GATE:       GATE:        GATE:      GATE:      GATE:       GATE:
  context     user approves no show-  tests pass  6 phases  no CRITICAL no Must-Fix no CRITICAL
  loaded        plan      stoppers                  pass     findings    issues      issues
```

**KEY: Domain experts fire TWICE — once to validate the idea (Stage 3), once to QA the code (Stage 7).**

### Stage 1: UNDERSTAND (automatic — runs before anything else)
**Skills used:** none (reads files)
**Actions:**
- Read `WORKING-CONTEXT.md` — what sprint, what branch, what blockers
- Read `TASK_TRACKER.md` — does this feature exist? what's its status?
- Read `.claude/learnings/` — any past patterns relevant to this work?
- Ask clarifying questions ONLY if genuinely ambiguous
**GATE:** Context is loaded. Proceed.

### Stage 2: PLAN (automatic for >50 lines; ask user for <50)
**Skills used:** `/blueprint` (multi-PR features) | `/council` (ambiguous decisions)
**Actions:**
- For trivial changes (<50 lines): state the approach in 2-3 bullets, proceed
- For non-trivial changes: run `/blueprint` — produce step-by-step plan with file list
- If the approach has multiple valid options: run `/council` — 4-voice debate
- Present plan to user
**GATE:** User says "go" or approves the plan. Do NOT proceed without approval.

### Stage 3: VALIDATE (domain experts review the PLAN before coding)

**Purpose: Catch "should we build this?" problems BEFORE writing code. This prevents rework.**

**This stage fires based on what KIND of work is planned, not what files changed (files don't exist yet).**

#### 3a — Doctor Validation (`/doctor-feedback`)
**Auto-triggers when ANY of these are true:**
- A new feature is being planned (blueprint produced in Stage 2)
- The feature touches patient-facing health flows, clinical data, or AI insights
- The feature changes how patients interact with the app

**What Dr. Rajesh validates:**
- Will Bihar patients actually use this daily?
- Is the clinical approach accurate and not misleading?
- Any NMC compliance or liability concerns?
- What should change in the plan before we build?

#### 3b — Legal Validation (`/legal-check`)
**Auto-triggers when ANY of these are true:**
- The feature involves new data collection (new DB tables, new user input)
- The feature involves AI generating health advice
- The feature involves sharing data between users
- The feature involves consent, terms, or communications
- The work produces non-code documents (pitch decks, contracts, agreements)

**What Legal validates:**
- DPDPA 2023 compliance for new data collection
- NMC guidelines for health advice
- SaMD classification risk for AI features
- Data sharing and consent requirements

#### 3c — Trigger Decision Flow:
```
Is this a new feature (blueprint produced)?
  AND touches health/patient/AI/clinical?
  → YES: run /doctor-feedback

Does this involve new data collection, AI advice, sharing, consent, or legal docs?
  → YES: run /legal-check

Is this a bug fix, refactor, or infra-only change?
  → SKIP Stage 3 entirely. Proceed to Stage 4.
```

**GATE:** No showstoppers from experts. If Must Fix items raised:
1. Update the blueprint/spec with their recommendations
2. Get user approval on the updated plan
3. THEN proceed to Stage 4

### Stage 4: IMPLEMENT (TDD approach — mandatory)
**Skills used:** `/tdd`
**Actions:**
- **RED:** Write failing tests FIRST — cover happy path, edge cases, error cases
- **GREEN:** Write minimum code to make tests pass
- **REFACTOR:** Clean up while tests stay green
- Follow `RULES.md`: AppColors, AppLocalizations, ApiClient, Depends(get_current_user)
- Add localization strings to both `app_en.arb` + `app_hi.arb` if adding UI text
**GATE:** All new tests pass. All existing tests still pass. Proceed.

### Stage 5: VERIFY (7-phase quality gate)
**Skills used:** `/verify` + `/qa-review`
**Actions — run ALL 7 phases in order:**
1. **BUILD:** `flutter analyze` + backend import check
2. **LINT:** `flutter analyze` + `ruff check` (if installed)
3. **TESTS:** `TESTING=true python -m pytest tests/ -v` + `flutter test`
4. **COVERAGE (MANDATORY):** `pytest --cov` on each changed backend file. Tiered targets:
   - **Tier 1 (95%):** health_utils, routes_health, routes_meals, models, schemas — health-critical
   - **Tier 2 (90%):** dependencies, routes (auth), encryption_service — auth/security
   - **Tier 3 (85%):** all other backend files — general
   - Install `pytest-cov` if missing. This is a HARD GATE — write tests until coverage passes.
5. **QA REVIEW:** `/qa-review` — assess test QUALITY, not just coverage %. Check: boundary tests for health classifications, negative/error paths, timezone edge cases, network failure handling. List untested risk paths.
6. **SECURITY GREP:** scan for `print()`, hardcoded secrets, debug statements
7. **DIFF REVIEW:** `git diff --stat` — only intended files changed?
**GATE:** No FAIL in any phase. Coverage below tier target is a FAIL. QA CRITICAL findings must be fixed. If a phase fails, fix and re-run `/verify` from the beginning.

### Pre-Production Gate: E2E Tests
**When:** Before deploying to production (not on every PR — only on release branches)
**Actions:**
- Run Flutter integration tests (`flutter test integration_test/`) that simulate real user flows:
  - Register → log reading → log meal → see insight → check trend
  - Network failure mid-save → offline queue → sync on reconnect
  - Language switch mid-flow → all strings update correctly
- These are automated UI tests (no manual doctor testing needed)
- Use Flutter's `integration_test` package with `patrol` or `integration_test` driver
**GATE:** All E2E smoke tests pass before any production deployment.

### Stage 6: SECURITY (OWASP + health data compliance)
**Skills used:** `/security-audit` + `/phi-compliance` (conditional)
**Actions:**
- Run `/security-audit` on all changed files — full OWASP Top 10 checklist
- **Auto-trigger `/phi-compliance`** if ANY changed file touches health data
**GATE:** No CRITICAL or HIGH findings. MEDIUM findings: list them in the PR description. If CRITICAL found → fix and re-run from Stage 5.

### Stage 7: EXPERT QA (domain experts review the CODE after implementation)

**Purpose: Catch "did we build it right?" problems in the actual code/UI. Different question from Stage 3.**

#### 7a — UX Review (Healthify): `/ux-review`
**Auto-triggers when ANY of these files are in the diff:**
- `lib/screens/*.dart`, `lib/widgets/*.dart`, `lib/theme/app_theme.dart`
- `lib/l10n/app_en.arb` or `app_hi.arb` (UI text changed)

**What Healthify checks:**
- Bihar grandmother test (understands in 3 seconds?)
- Singapore daughter test (parent safe in 1 second?)
- Touch targets ≥48dp, font sizes ≥14sp, solid colors, color-blind safe

**GATE:** No "Must Fix" issues. "Should Fix" noted in PR.

#### 7b — Doctor QA (`/doctor-feedback`) — only if Stage 3 was triggered
**Auto-triggers when:** Stage 3a ran (doctor validated the plan). Now re-checks the built result.
**What Dr. Rajesh checks:** Does the implementation match what was validated? Any new clinical concerns?
**GATE:** Implementation matches approved plan.

#### 7c — Legal QA (`/legal-check`) — code-level check
**Auto-triggers when ANY of these files are in the diff:**
- `models.py`, `routes.py`, `ai_service.py`, `encryption_service.py`, `email_service.py`
- Any file touching consent, sharing, invites, permissions

**What Legal checks:** Code-level DPDPA compliance, AI disclaimers present, data sharing permissions correct.
**GATE:** No HIGH risk findings.

#### 7d — Safety Guard: `/safety-guard`
**Auto-triggers when ANY of these are true:**
- Destructive git/bash commands, DB migrations, schema drops
**GATE:** User explicitly confirms each destructive operation.

### Stage 8: CODE REVIEW (Daniel)
**Skills used:** `/review`
**Actions:**
- Run `/review` — Daniel reviews all changes for correctness, security, error handling, performance, maintainability, test coverage, architecture
- Daniel also reviews any issues flagged by Stage 7 domain experts
- CRITICAL issues: fix immediately, then re-run from Stage 5
- MEDIUM issues: fix if straightforward (<10 min); otherwise list in PR
- MINOR issues: note but don't block
**GATE:** Zero CRITICAL issues remain. Proceed to ship.

### Stage 9: SHIP (commit + PR + housekeeping)
**Skills used:** none (orchestration)
**Actions — ALL of these, in order:**
1. `git add` relevant files (never `.env`, `.coverage`, build artifacts)
2. `git commit` with conventional message: `feat(module):` / `fix(module):` / `refactor(module):`
3. `git push` to remote branch
4. `gh pr create` with structured body:
   - Summary (what changed and why)
   - Test Plan (what was tested)
   - Security (PASS/CONDITIONAL PASS + any MEDIUM findings)
   - Validation Reviews (Stage 3 — which experts validated + their verdicts)
   - QA Reviews (Stage 7 — which experts QA'd + their verdicts)
   - Code Review (Daniel's verdict)
5. Update `WORKING-CONTEXT.md` with new PR entry
6. Update `AUDIT.md` with session changes
7. Run `/learn` — capture any non-obvious patterns discovered during this work
8. Stop hook auto-saves session state

**The pipeline is complete. Every skill has fired at its trigger point. Nothing was skipped.**

### Pipeline Shortcuts
- User says **"just implement"** → run Stages 1-4 only, pause before verify
- User says **"skip review"** → skip Stage 8 only (experts still fire)
- User says **"/ship"** → run Stages 5-9 (assumes implementation is done)
- User says **"quick fix"** for <10 line changes → Stages 1,4,5,8,9 (skip plan/validate/expert QA)

### On-Demand Only
These are NOT auto-triggered but can be called anytime:
- `/compact-now` — invoke when context window is getting full
- `/council` — can also be invoked outside Stage 2 for any ad-hoc decision

## Architecture Decisions (do not change without discussion)
- Auth: email + password + JWT (no Firebase for PoC)
- DB: PostgreSQL via SQLAlchemy
- Auth dependency: `backend/dependencies.py → get_current_user`
- Shared HTTP utils: `lib/services/api_client.dart → ApiClient`
- Theme: all colors via `AppColors` in `lib/theme/app_theme.dart` — never hardcode colors
- Localization: Flutter gen-l10n — strings in `lib/l10n/app_en.arb` + `app_hi.arb`; never hardcode UI strings
- Secrets never committed — `backend/.env` is gitignored

## Code Rules
See `RULES.md` for the full list. Critical rules:
- All colors via `AppColors.*` — never raw `Colors.*`
- All strings via `AppLocalizations.of(context).*` — never hardcode
- All HTTP via `ApiClient.headers()` + `ApiClient.errorDetail()`
- All auth via `Depends(get_current_user)`
- No `print()` in backend
- Check `TASK_TRACKER.md` before starting any new feature work
