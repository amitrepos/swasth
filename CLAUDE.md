# Swasth Health App — Claude Code Instructions

## Response Length Rule
Full rule lives in `.claude/output-styles/swasth-concise.md` (active via `settings.local.json` → `outputStyle`). Enforced by `UserPromptSubmit` + `Stop` hooks. TL;DR: ≤ 100 words, bullets only, end with "Want an elaborative answer?" — unless user uses an elaborate trigger.

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
- `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` — **legal checklist for doctor portal** (NMC, DPDPA, SaMD, liability)
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

### Strategic
- `/reality-check` — Meera Krishnan: ex-McKinsey, challenges "should we build this at all?" (Stage 1.5 gate)

### Decision Support
- `/council` — 4-voice decision panel (Architect, Skeptic, Pragmatist, Critic)
- `/safety-guard` — Review planned operations for destructive risk

### Session Management
- `/learn` — Capture a project pattern or insight for future sessions
- `/compact-now` — Save full state + suggest optimal compaction point

## Development Pipeline (ENFORCED — no step is optional)

**This pipeline runs for EVERY feature, bug fix, or refactor. Each stage has a GATE that must pass before proceeding. If a gate fails, fix the issue and re-run that stage. Never skip ahead.**

```
┌───────────┐ ┌────────┐ ┌──────┐ ┌────────┐ ┌───────────┐ ┌────────┐ ┌────────┐ ┌─────────┐ ┌────────┐ ┌──────┐
│1.UNDERSTAND│▶│1.5MEERA│▶│2.PLAN│▶│3.VALID.│▶│4.IMPLEMENT│▶│5.VERIFY│▶│6.SECURE│▶│7.EXPERT │▶│8.REVIEW│▶│9.SHIP│
│            │ │REALITY │ │      │ │        │ │           │ │        │ │        │ │   QA    │ │        │ │      │
│ auto       │ │CHECK   │ │/bluep│ │/dr-feed│ │ /tdd      │ │/verify │ │/sec-aud│ │/ux-rev  │ │/review │ │commit│
│            │ │        │ │/cncil│ │/legal  │ │           │ │6 phase │ │/phi-com│ │/safe-grd│ │(Daniel)│ │PR    │
│            │ │/reality│ │      │ │        │ │           │ │        │ │        │ │/legal   │ │        │ │audit │
│            │ │-check  │ │      │ │        │ │           │ │        │ │        │ │/dr-feed │ │        │ │learn │
└────────────┘ └────────┘ └──────┘ └────────┘ └───────────┘ └────────┘ └────────┘ └─────────┘ └────────┘ └──────┘
    GATE:        GATE:      GATE:     GATE:       GATE:        GATE:      GATE:      GATE:       GATE:
  context      GREEN or   user      no show-   tests pass   6 phases  no CRITICAL no Must-Fix no CRITICAL
  loaded       YELLOW     approves  stoppers                  pass     findings    issues      issues
               from Meera   plan
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

### Stage 1.5: REALITY CHECK (Meera — strategic gate before planning)
**Skills used:** `/reality-check`
**Auto-triggers when ANY of these are true:**
- A new feature is being proposed (not a bug fix or refactor)
- A new module, screen, or API endpoint is being added
- Work will take more than 2 hours

**What Meera challenges (2-3 sentences, not a full audit):**
- "Do we have 100+ DAU yet? If not, does this help us GET there?"
- "Has a real user or doctor asked for this, or are we guessing?"
- "Is this building for the demo or for the daily?"
- "Could we validate this with a conversation instead of code?"

**Meera's grades:**
- **GREEN:** Directly helps acquire/retain/monetize real users. Build it.
- **YELLOW:** Plausible but unvalidated. Test with users before committing >4 hours.
- **RED:** No user has asked for this. Stop. Go talk to someone first.

**GATE:** GREEN = proceed to Stage 2. YELLOW = proceed with user approval. RED = do not build until validated with real user/doctor.

**SKIP conditions:** Bug fixes, security patches, legal blockers, infra (server migration, CI/CD), and anything the user explicitly says "just build it."

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
3. **TESTS:** `TESTING=true python -m pytest tests/ -v` + `flutter test test/` (includes E2E flow tests)
4. **COVERAGE (MANDATORY):** `pytest --cov` on each changed backend file. Tiered targets:
   - **Tier 1 (95%):** health_utils, routes_health, routes_meals, models, schemas — health-critical
   - **Tier 2 (90%):** dependencies, routes (auth), encryption_service — auth/security
   - **Tier 3 (85%):** all other backend files — general
   - Install `pytest-cov` if missing. This is a HARD GATE — write tests until coverage passes.
5. **QA REVIEW:** `/qa-review` — assess test QUALITY, not just coverage %. Check: boundary tests for health classifications, negative/error paths, timezone edge cases, network failure handling. List untested risk paths.
6. **SECURITY GREP:** scan for `print()`, hardcoded secrets, debug statements
7. **DIFF REVIEW:** `git diff --stat` — only intended files changed?
**GATE:** No FAIL in any phase. Coverage below tier target is a FAIL. QA CRITICAL findings must be fixed. If a phase fails, fix and re-run `/verify` from the beginning.

### E2E Flow Tests (MANDATORY on every PR — quality over quantity)
**When:** Every PR that touches Flutter code. No exceptions.
**Philosophy:** Whatever feature we build, it must work E2E before we implement any new feature.
**Run:** `flutter test test/flows/ --timeout 30s`
**Current coverage (82 flow tests, 187 total Flutter tests):**
- `auth_flow_test.dart` — login, registration, validation, navigation (9 tests)
- `dashboard_display_test.dart` — all screens render, no ErrorWidgets (6 tests)
- `health_reading_flow_test.dart` — BP + glucose entry, validation, boundary, save (14 tests)
- `meal_logging_flow_test.dart` — quick select, meal type, API save (8 tests)
- `chat_flow_test.dart` — input, send, response, quota (8 tests)
- `profile_flow_test.dart` — selection, create, validate, API loads (9 tests)
- `history_flow_test.dart` — readings list, data display (5 tests)
- `error_handling_test.dart` — wrong creds, server errors, validation (5 tests)
- `offline_sync_test.dart` — queue, sync, failed items, unreachable server (10 tests)
- `boundary_tests.dart` — clinical classification (BP/glucose), double-tap, token expiry (36 tests)

**Test infrastructure (must use):**
- `test/helpers/test_app.dart` — `TestEnv` bootstrapper, `pumpN()` helper
- `test/helpers/mock_http.dart` — mock HTTP for all 48 API endpoints
- `test/helpers/finders.dart` — Key-based widget finders
- NEVER use `pumpAndSettle()` — causes infinite hangs with animations. Always use `pumpN()`.
- NEVER use `FlutterSecureStorage` directly in tests — use `StorageService.useInMemoryStorage()`.
- Every new screen MUST get widget Keys on interactive elements.

**When adding a new feature:**
1. Add widget Keys to any new interactive elements
2. Write E2E flow test BEFORE or WITH the feature (not after)
3. Update mock_http.dart if new API endpoints are added
4. Run `flutter test test/flows/ --timeout 30s` — all must pass
5. If a test fails, fix the code, not the test (unless the test is wrong)

**GATE:** All E2E tests pass. Zero failures. This blocks the PR.

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

## Branch & Deployment Rules (ENFORCED BY HOOKS — NOT JUST DOCS)

### Branch Hygiene

**The rules below are enforced by `.githooks/pre-commit`, `.githooks/pre-push`,
`.claude/scripts/orphan-scan.sh` (session start), and
`.github/workflows/branch-hygiene.yml` (CI). Violating any of them stops the
commit / push / merge immediately. Memory rules alone are not enough — the
2026-04-10 `fix/admin-toggle-button` incident produced 4 orphaned commits
because advisory rules are suggestions, not gates.**

- **ALWAYS checkout master and pull before creating a new branch:**
  ```bash
  git checkout master && git pull origin master
  git checkout -b feature/your-feature-name
  ```
- **STOP using a branch the moment its PR merges.** Do NOT continue to commit
  follow-up work on a branch whose PR is already closed/merged. The pre-commit
  hook will refuse (`gh pr list --state merged --head <branch>` blocks).
  Recovery pattern:
  ```bash
  git stash                                    # save in-progress changes
  git checkout master && git pull
  git checkout -b <new-descriptive-branch>
  git stash pop                                # restore changes
  ```
- **Every push must be associated with an open PR.** The pre-push hook blocks
  branches that are ahead of origin but have no open PR. If you're pushing a
  fresh branch for the first time, rerun with `SWASTH_ALLOW_BRANCHLESS_PUSH=1`
  once, then immediately run `gh pr create --fill`.
- **NEVER** create a new branch from another feature branch.
- **NEVER** cherry-pick across feature branches — causes merge conflicts and
  lost changes.
- If master has advanced while you're on a feature branch, rebase:
  `git rebase origin/master`.

### First-time setup on a fresh clone

```bash
git config core.hooksPath .githooks
git config alias.scb '!bash .claude/scripts/scb.sh'
```

CI's `branch-hygiene.yml` will block the PR if `.githooks/` scripts are
missing or not executable, so the hooks themselves are tamper-resistant.

### Drift Prevention Protocol (added after 2026-04-18 incidents)

Health data = no room for "I think it's deployed." Three failures in
one session had the same skeleton: assumed state after action A, never
verified, downstream error much later. Three enforcement layers now:

**Layer 1 — deterministic hooks (strongest):**
- `git scb <branch>` creates a new branch from fresh `origin/master`.
  Refuses if local master is stale or working tree is dirty. Always
  use this instead of `git checkout -b`.
- `.githooks/pre-push` now also refuses a push if any branch commit
  has a `git patch-id` already on master (orphan-commit detection).
  Catches the "branched off a stale feature branch" failure mode.
- `.githooks/pre-commit` (Gate 2) refuses any commit that changes
  `backend/models.py` without a new Alembic migration in the same
  commit. CI re-runs `alembic upgrade head` + `alembic check` against
  ephemeral Postgres (`.github/workflows/migration-check.yml`). The
  hook is the spec — do not duplicate the schema-change procedure in
  prose. Escape hatch for genuine no-op edits: `SWASTH_NO_MIGRATION_NEEDED=1`.

**Layer 2 — verification discipline (required, always):**
- After ANY state-changing action, run an observable verification
  before moving to the next step. `gh secret set` → hit the live
  endpoint. `scp` → `ssh stat` the file. `pm2 restart` → curl a
  route. `git checkout -b` → `git log origin/master..HEAD` is empty.
- **Exit code 0 does NOT prove success.** The downstream surface
  working proves success.

**Layer 3 — memory (for coverage the hooks miss):**
- `~/.claude/projects/.../memory/feedback_state_verification.md`
- `~/.claude/projects/.../memory/feedback_quality_over_speed.md`
  Auto-loaded every session — future AI inherits the lessons.

**The meta-rule:** "Quality over speed. We handle health data."
When tempted to skip a verification or batch a too-big commit, stop.
One atomic change, verified, then the next.

### Domain Expert Review Matrix (ENFORCED via pre-commit hook)

Every `git commit` is intercepted by `.claude/scripts/check-required-reviewers.sh`,
which inspects the staged diff and computes the required experts from the
table below. Each required expert must produce a PASS verdict (no Must Fix
items) and write a content-hash-keyed marker before the commit is allowed.
Markers live in `.claude/markers/` (gitignored) and invalidate automatically
when staged content changes.

| Files in staged diff | Required experts (in order) |
|---|---|
| Any `.dart` or `.py` source | **Daniel** (`/daniel-review`) — always last, final correctness/security/architecture gate |
| `lib/screens/`, `lib/widgets/`, `lib/theme/` | **Sunita** (`/sunita`) → **Aditya** (`/aditya`) → **Dr. Rajesh** (`/doctor-feedback`) → Daniel |
| `lib/l10n/*.arb` | **Sunita** (Hindi naturalness) → **Aditya** (cultural fit) → Daniel |
| `routes_health.py`, `health_utils.py`, `routes_meals.py` | **Dr. Rajesh** → **PHI** (`/phi-compliance`) → **Legal** (`/legal-check`) → **Sunita** → **Priya** (`/qa-review`) → Daniel |
| `ai_service.py` | **Dr. Rajesh** → **Legal** → **PHI** → **Sunita** → Daniel |
| `models.py`, `schemas.py`, `backend/migrations/` | **Legal** → **PHI** → **Priya** → Daniel |
| `auth.py`, `dependencies.py`, `routes.py` | **Security** (`/security-audit`) → **Legal** → Daniel |
| `encryption_service.py` | **PHI** → **Security** → Daniel |
| `routes_doctor.py`, `lib/screens/doctor_*` | **Dr. Rajesh** → **Legal** (NMC) → Daniel |
| `routes_admin.py`, `admin_dashboard*` | **Legal** → **Aditya** → Daniel |
| `pubspec.yaml`, `backend/requirements.txt` | **Security** (CVE/supply chain) → Daniel |
| `backend/tests/*.py`, `test/*.dart` | **Priya** — audits test quality → Daniel |
| **Any NEW `.dart` or `.py` file** (git diff --diff-filter=A) | **Meera** (`/reality-check`) — "should we build this?" strategic gate. Runs FIRST. |

**Meera vs other experts** — Meera is NOT a code reviewer. She challenges whether
the feature should exist at all. She asks: "Has a real user asked for this? Does
this help us get to 100 DAU?" She grades GREEN/YELLOW/RED. RED blocks the commit.
Meera is skipped for bug fixes, security patches, and infra-only changes.

**Aditya vs Sunita** — NOT redundant. Aditya is a senior UX expert reviewing
accessibility heuristics, touch targets, color contrast, font sizes. Sunita
is a 55yo patient in Ranchi reviewing comprehension at arm's length without
glasses, Hindi naturalness, fear-vs-reassurance balance. Both review every
patient-facing change.

**Hard block on Must Fix** — any expert returning a Must Fix issue blocks
the commit. No soft override. Fix the issue, restage, rerun the review chain
on the new staged content (new hash → all prior markers invalidated).

After running an expert and getting a PASS verdict, write the marker:
```bash
.claude/scripts/write-review-marker.sh <expert>
# expert ∈ {sunita, aditya, doctor, daniel, phi, legal, security, priya}
```

### Server Deployment
- **ALWAYS** build from master (or from a branch that is up-to-date with master)
- **NEVER** deploy from a stale feature branch — this overwrites changes from other merged PRs
- Deploy commands (run in order):
  ```bash
  git checkout master && git pull origin master
  flutter build web --release --dart-define=SERVER_HOST=https://65.109.226.36:8443
  scp -i ~/.ssh/new-server-key -r build/web/* root@65.109.226.36:/var/www/swasth/web/
  ```
- If backend files changed, also deploy and restart:
  ```bash
  scp -i ~/.ssh/new-server-key backend/<changed_file>.py root@65.109.226.36:/var/www/swasth/backend/
  # If migrations/ has new revisions, apply BEFORE restart so the new code
  # never sees the old schema. alembic upgrade head is idempotent.
  ssh -i ~/.ssh/new-server-key root@65.109.226.36 "cd /var/www/swasth/backend && alembic upgrade head"
  ssh -i ~/.ssh/new-server-key root@65.109.226.36 "kill \$(lsof -ti :8007); sleep 2; cd /var/www/swasth/backend && nohup python3 -B main.py > /var/log/swasth-backend.log 2>&1 &"
  ```

### Pre-PR Checklist (run ALL before pushing)
```bash
flutter analyze --no-pub                              # Zero errors
flutter test test/flows/ --timeout 30s                # All E2E tests pass
flutter test                                          # All Flutter tests pass
cd backend && source venv/bin/activate
TESTING=true python -m pytest tests/ -v               # All backend tests pass
TESTING=true python -m pytest tests/ --cov=. --cov-report=term-missing  # Coverage >=85%
```

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
