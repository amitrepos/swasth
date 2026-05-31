# Development Pipeline (ENFORCED — no step is optional)

> Moved out of `CLAUDE.md` (Phase 1c of the agent-platform upgrade) to keep the root map small.
> `CLAUDE.md` links here. This is the full 9-stage pipeline + E2E test policy.

**This pipeline runs for EVERY feature, bug fix, or refactor. Each stage has a GATE that must pass before proceeding. If a gate fails, fix the issue and re-run that stage. Never skip ahead.**

```
┌───────────┐ ┌────────┐ ┌──────┐ ┌────────┐ ┌───────────┐ ┌────────┐ ┌────────┐ ┌─────────┐ ┌────────┐ ┌──────┐
│1.UNDERSTAND│▶│1.5MEERA│▶│2.PLAN│▶│3.VALID.│▶│4.IMPLEMENT│▶│5.VERIFY│▶│6.SECURE│▶│7.EXPERT │▶│8.REVIEW│▶│9.SHIP│
│ auto       │ │REALITY │ │/bluep│ │/dr-feed│ │ /tdd      │ │/verify │ │/sec-aud│ │   QA    │ │(Daniel)│ │commit│
│            │ │CHECK   │ │/cncil│ │/legal  │ │           │ │7 phase │ │/phi-com│ │/ux-rev  │ │        │ │PR    │
└────────────┘ └────────┘ └──────┘ └────────┘ └───────────┘ └────────┘ └────────┘ └─────────┘ └────────┘ └──────┘
```

**KEY: Domain experts fire TWICE — once to validate the idea (Stage 3), once to QA the code (Stage 7).**

> **Note (agent-platform upgrade):** for the **JIRA-driven (Path B)** flow, necessity validation
> (Meera/Sunita/Doctor) is moving to an **intake gate** owned by Priya, run *before* any code is
> written, with a human GO/NO-GO — see `docs/agent-platform/FINDINGS.md` and `SKILLS_AUDIT.md`. The
> stages below remain the model for **human-authored (Path A)** work.

### Stage 1: UNDERSTAND (automatic — runs before anything else)
**Skills used:** none (reads files)
- Read `WORKING-CONTEXT.md` — what sprint, what branch, what blockers
- Read `TASK_TRACKER_PENDING.md` — does this feature exist? what's its status? what tier is it?
- Read `.claude/learnings/` — any past patterns relevant to this work?
- Ask clarifying questions ONLY if genuinely ambiguous
**GATE:** Context is loaded. Proceed.

### Stage 1.5: REALITY CHECK (Meera — strategic gate before planning)
**Skills used:** `/reality-check`
**Auto-triggers when ANY of these are true:** a new feature is proposed (not a bug fix/refactor);
a new module/screen/API endpoint is added; work will take more than 2 hours.
**Meera's grades:** GREEN (helps acquire/retain/monetize → build) · YELLOW (plausible but
unvalidated → test before >4h) · RED (no user asked → stop, validate first).
**GATE:** GREEN = proceed. YELLOW = proceed with user approval. RED = do not build until validated.
**SKIP:** bug fixes, security patches, legal blockers, infra, or when the user says "just build it."

### Stage 2: PLAN (automatic for >50 lines; ask user for <50)
**Skills used:** `/blueprint` (multi-PR features) | `/council` (ambiguous decisions)
- Trivial (<50 lines): state the approach in 2-3 bullets, proceed.
- Non-trivial: run `/blueprint` — step-by-step plan with file list. Multiple valid options: `/council`.
**GATE:** User approves the plan. Do NOT proceed without approval.

### Stage 3: VALIDATE (domain experts review the PLAN before coding)
Catch "should we build this?" BEFORE writing code. Fires by what KIND of work is planned.
- **3a Doctor (`/doctor-feedback`):** new feature touching patient/clinical/AI flows. Will Bihar
  patients use it daily? Clinically accurate? NMC/liability concerns?
- **3b Legal (`/legal-check`):** new data collection, AI health advice, data sharing, consent/terms,
  or non-code legal docs. DPDPA 2023, NMC, SaMD classification, sharing/consent.
- **3c:** bug fix / refactor / infra-only → SKIP Stage 3.
**GATE:** No showstoppers. If Must Fix: update the plan, get user approval, then proceed.

### Stage 4: IMPLEMENT (TDD — mandatory)
**Skills used:** `/tdd` — RED (failing tests first: happy + edge + error) → GREEN (minimum code) →
REFACTOR (clean while green). Follow `RULES.md` (AppColors, AppLocalizations, ApiClient,
`Depends(get_current_user)`); add strings to both `app_en.arb` + `app_hi.arb`.
**GATE:** All new tests pass; all existing tests still pass.

### Stage 5: VERIFY (7-phase quality gate)
**Skills used:** `/verify` + `/qa-review`. Run ALL 7 in order:
1. **BUILD:** `flutter analyze` + backend import check.
2. **LINT:** `flutter analyze` + `ruff check` (if installed).
3. **TESTS:** `TESTING=true python -m pytest tests/ -v` + `flutter test test/` (includes E2E).
4. **COVERAGE (MANDATORY):** `pytest --cov` per changed backend file. Tiers:
   - Tier 1 (95%): `health_utils`, `routes_health`, `routes_meals`, `models`, `schemas`.
   - Tier 2 (90%): `dependencies`, auth `routes`, `encryption_service`.
   - Tier 3 (85%): all other backend files. HARD GATE — write tests until coverage passes.
5. **QA REVIEW:** `/qa-review` — test QUALITY, not just %. Boundary tests for health classifications,
   negative/error paths, timezone edge cases, network failures. List untested risk paths.
6. **SECURITY GREP:** scan for `print()`, hardcoded secrets, debug statements.
7. **DIFF REVIEW:** `git diff --stat` — only intended files changed?
**GATE:** No FAIL. Coverage below tier = FAIL. QA CRITICAL must be fixed. Re-run `/verify` from start on failure.

#### E2E Flow Tests (MANDATORY on every PR touching Flutter)
**Run:** `flutter test test/flows/ --timeout 30s`. Whatever we build must work E2E before any new feature.
Current coverage (82 flow tests, 187 total Flutter tests): `auth_flow`, `dashboard_display`,
`health_reading_flow`, `meal_logging_flow`, `chat_flow`, `profile_flow`, `history_flow`,
`error_handling`, `offline_sync`, `boundary_tests`.
**Test infrastructure (must use):** `test/helpers/test_app.dart` (`TestEnv`, `pumpN()`),
`test/helpers/mock_http.dart` (48 endpoints), `test/helpers/finders.dart`.
- NEVER `pumpAndSettle()` (infinite hangs) — always `pumpN()`.
- NEVER `FlutterSecureStorage` directly in tests — use `StorageService.useInMemoryStorage()`.
- Every new screen MUST get widget Keys on interactive elements.
New feature: add Keys → write E2E test before/with the feature → update `mock_http.dart` for new
endpoints → all flow tests pass → fix the code not the test (unless the test is wrong).
**GATE:** All E2E tests pass. Zero failures. Blocks the PR.

### Stage 6: SECURITY (OWASP + health data compliance)
**Skills used:** `/security-audit` + `/phi-compliance` (auto if any changed file touches health data).
**GATE:** No CRITICAL/HIGH. MEDIUM → list in PR. CRITICAL → fix and re-run from Stage 5.

### Stage 7: EXPERT QA (domain experts review the CODE)
- **7a UX (`/ux-review` → Aditya):** diff touches `lib/screens/`, `lib/widgets/`, `lib/theme/app_theme.dart`,
  or `lib/l10n/*.arb`. Bihar grandmother test, Singapore daughter test, touch ≥48dp, font ≥14sp,
  solid colors, color-blind safe. GATE: no Must Fix; Should Fix noted in PR.
- **7b Doctor (`/doctor-feedback`)** — only if Stage 3a ran. Implementation matches the validated plan?
- **7c Legal (`/legal-check`):** diff touches `models.py`, `routes.py`, `ai_service.py`,
  `encryption_service.py`, `email_service.py`, or consent/sharing/invites/permissions. GATE: no HIGH.
- **7d Safety:** destructive git/bash, DB migrations, schema drops → now enforced by the WS2
  destructive-op hook (`.claude/scripts/hook-guard-destructive.sh`), not just the skill.

### Stage 8: CODE REVIEW (Daniel)
**Skills used:** `/review` — correctness, security, error handling, performance, maintainability,
test coverage, architecture; also reviews Stage-7 expert flags. CRITICAL → fix, re-run from Stage 5.
MEDIUM → fix if <10 min, else list in PR. MINOR → note. **GATE:** zero CRITICAL remain.

### Stage 9: SHIP (commit + PR + housekeeping)
1. `git add` relevant files (never `.env`, `.coverage`, build artifacts).
2. `git commit` — conventional message (`feat(module):` / `fix(module):` / `refactor(module):`).
3. `git push`.
4. `gh pr create` with: Summary · Test Plan · Security · Validation Reviews (Stage 3) · QA Reviews
   (Stage 7) · Code Review (Daniel).
5. Update `WORKING-CONTEXT.md` (new PR entry). 6. Update `AUDIT.md`. 7. Run `/learn`. 8. Stop hook
   auto-saves session state.

### Pipeline Shortcuts
- **"just implement"** → Stages 1-4, pause before verify.
- **"skip review"** → skip Stage 8 only (experts still fire).
- **"/ship"** → Stages 5-9.
- **"quick fix"** (<10 lines) → Stages 1,4,5,8,9.

### On-Demand Only
`/compact-now` (context full) · `/council` (ad-hoc decisions).
