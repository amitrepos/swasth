# 01 — Developer Onboarding Manual

**Goal:** Get you from `git clone` to your first merged PR in one day.

---

## Day 1: Get the app running locally

### Prerequisites

| Tool | Version | Check with |
|---|---|---|
| Python | 3.12+ | `python3 --version` |
| Flutter SDK | 3.22+ (Dart 3.4+) | `flutter --version` |
| PostgreSQL | 14+ | `psql --version` |
| Git | any recent | `git --version` |
| Node.js (for tooling) | 18+ | `node --version` |

On macOS: `brew install python@3.12 postgresql@14 flutter git node`.
On Linux: use your distro package manager + install Flutter from https://docs.flutter.dev/get-started/install.

### Step 1 — Clone & install hooks

```bash
git clone git@github.com:<org>/swasth_app.git
cd swasth_app

# CRITICAL: install enforcement hooks (CI blocks PRs without these)
git config core.hooksPath .githooks
git config alias.scb '!bash .claude/scripts/scb.sh'
```

The `.githooks/pre-commit` hook blocks commits that modify `backend/models.py` without a matching Alembic migration, and `.githooks/pre-push` blocks pushes to branches whose PR has already merged. These are not optional.

### Step 2 — Backend setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Postgres: create the dev DB
createdb swasth_dev

# Env: copy example, fill in dev values
cp .env.example .env
# Edit .env — minimum required keys:
#   DATABASE_URL=postgresql://localhost:5432/swasth_dev
#   SECRET_KEY=dev-key-do-not-use-in-prod
#   ENCRYPTION_KEY=<64-char hex string>   # see below
#   GEMINI_API_KEY=<optional for AI features>

# Generate an ENCRYPTION_KEY (must be exactly 64 hex chars = 32 bytes):
python3 -c "import secrets; print(secrets.token_hex(32))"

# Apply migrations
alembic upgrade head

# Run the server
TESTING=false python3 -B main.py
# Or with hot reload:
uvicorn main:app --host 0.0.0.0 --port 8007 --reload

# Verify: open http://localhost:8007/docs — you should see Swagger UI.
```

### Step 3 — Flutter setup

```bash
cd ..  # back to repo root
flutter pub get
flutter gen-l10n  # regenerate localization files

# Run on web pointed at your local backend
flutter run -d chrome -t lib/main_staging.dart \
  --dart-define=SERVER_HOST=http://localhost:8007

# Run on Android emulator (use 10.0.2.2 to reach host machine)
flutter run -d emulator-5554 -t lib/main_staging.dart \
  --dart-define=SERVER_HOST=http://10.0.2.2:8007
```

### Step 4 — Seed a test user

```bash
# With backend running:
curl -X POST http://localhost:8007/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email":"you@example.com",
    "password":"Passw0rd!",
    "full_name":"You",
    "consent_given":true,
    "ai_consent":true
  }'
```

Log in with that email/password in the app. You're set up.

---

## Day 2: Make your first change

### The 9-stage pipeline (enforced)

Every change flows through this pipeline (see `CLAUDE.md` for full detail). Hooks enforce most gates — if you skip one, the commit or push will fail.

```
1. UNDERSTAND → 1.5 REALITY CHECK → 2. PLAN → 3. VALIDATE (doctor/legal)
→ 4. IMPLEMENT (TDD) → 5. VERIFY (7 phases) → 6. SECURE (OWASP + PHI)
→ 7. EXPERT QA (UX/Doctor/Legal/Safety) → 8. CODE REVIEW (Daniel) → 9. SHIP
```

**Stage 4 is where you actually code.** Everything before it prevents you from building the wrong thing. Everything after it prevents you from shipping broken code.

### Branch hygiene (hook-enforced)

```bash
# ALWAYS start from a fresh master
git scb feat/my-feature    # preferred — refuses if master is stale
# or:
git checkout master && git pull origin master
git checkout -b feat/my-feature
```

**Never** reuse a branch after its PR merged. Never create a branch from another feature branch. The pre-commit hook will refuse orphan commits.

### Your first commit

```bash
# Make your change, then:
flutter analyze                           # zero errors
flutter test test/flows/ --timeout 30s    # all E2E tests pass
cd backend && source venv/bin/activate
TESTING=true python -m pytest tests/ -v   # all backend tests pass

git add <specific files>   # NEVER git add -A (catches .env, .coverage)
git commit -m "feat(module): short description"
git push -u origin feat/my-feature
gh pr create --fill
```

The pre-commit hook runs the domain-expert review matrix (Sunita / Aditya / Dr. Rajesh / Daniel / Priya / Legal / PHI / Security) based on what files you changed. You must produce a PASS verdict from each required expert before committing. See `CLAUDE.md` → **Domain Expert Review Matrix**.

### Commit message style

Conventional commits, lowercase scope:
```
feat(health): add SpO2 trend chart
fix(auth): clear token on 401 response
refactor(doctor): extract triage calculation
chore(backend): align server defaults with prod
docs(specs): add developer onboarding manual
```

---

## Daily workflow

### Start of session

1. `git checkout master && git pull`
2. Read `WORKING-CONTEXT.md` for current sprint state.
3. Check `TASK_TRACKER.md` for what's in flight.
4. Read `.claude/sessions/latest.md` if continuing prior work.

### During the day

- Work on one branch at a time.
- Run tests constantly — don't wait for CI.
- If you're touching health/AI/consent code, talk to product before coding.
- When stuck, check `KNOWN_ISSUES.md` and `AUDIT.md`.

### End of session

- Push your branch even if WIP (as a draft PR).
- Update `TASK_TRACKER.md` if you finished a sub-task.
- Append a one-line note to `AUDIT.md`.

---

## The rules you must never break

From `RULES.md` — a subset. Read the full file before week 2.

### Code

1. **Colors:** Use `AppColors.*` from `lib/theme/app_theme.dart`. Never `Colors.red` directly.
2. **Strings:** Use `AppLocalizations.of(context)!.*`. Never hardcode UI text. Add new strings to both `app_en.arb` and `app_hi.arb`.
3. **HTTP:** All network calls go through `ApiClient` in `lib/services/api_client.dart`. Never import `package:http/http.dart` directly in a screen.
4. **Auth:** All protected backend routes use `Depends(get_current_user)`. Never pass user identity through a request body.
5. **Prints:** No `print()` in backend code. Use the logging module.
6. **Secrets:** `backend/.env` is gitignored. Never commit it. Never paste keys into code.

### Git

7. **No direct pushes to master.** Always branch → PR.
8. **No `--force` or `--no-verify`** unless the user explicitly approves.
9. **One atomic change per commit** — especially for health-data code.
10. **Model changes require migrations in the same commit** (hook-enforced).

### Testing

11. **Every new Flutter screen gets widget Keys** on interactive elements.
12. **Never use `pumpAndSettle()`** in tests — it causes hangs. Use `pumpN()` from `test/helpers/test_app.dart`.
13. **Never use `FlutterSecureStorage` directly in tests** — use `StorageService.useInMemoryStorage()`.
14. **Backend coverage tiers are hard gates** — 95% for health logic, 90% for auth, 85% for everything else.

---

## Folder map — where everything lives

```
swasth_app/
├── backend/                    # FastAPI + PostgreSQL backend
│   ├── main.py                 # App entry, middleware, exception handlers
│   ├── routes*.py              # Route modules by domain
│   ├── models.py               # SQLAlchemy ORM models
│   ├── schemas.py              # Pydantic request/response schemas
│   ├── auth.py                 # JWT + bcrypt helpers
│   ├── dependencies.py         # get_current_user, access guards
│   ├── ai_service.py           # Gemini + DeepSeek fallback chain
│   ├── *_service.py            # Email, SMS, WhatsApp, encryption, alerts
│   ├── migrations/             # Alembic migration files
│   └── tests/                  # pytest test suite
│
├── lib/                        # Flutter app
│   ├── main.dart               # Legacy entry (uses staging)
│   ├── main_staging.dart       # Staging flavor entry
│   ├── main_production.dart    # Production flavor entry
│   ├── app.dart                # MaterialApp, theme, routes
│   ├── bootstrap.dart          # App init (env, Riverpod, splash)
│   ├── screens/                # 30+ UI screens
│   ├── services/               # API, storage, sync, OCR, BLE, etc.
│   ├── models/                 # Dart data classes
│   ├── providers/              # Riverpod state providers
│   ├── widgets/                # Reusable UI components
│   ├── theme/app_theme.dart    # AppColors, text styles
│   ├── l10n/                   # app_en.arb, app_hi.arb
│   ├── utils/                  # Validators, formatters
│   ├── config/                 # Flavor config, environment
│   └── ble/                    # Bluetooth device pairing
│
├── test/                       # Flutter tests
│   ├── flows/                  # E2E flow tests (the important ones)
│   ├── helpers/                # Test fixtures, mock HTTP
│   ├── screens/                # Per-screen widget tests
│   └── services/               # Service unit tests
│
├── .github/workflows/          # CI pipelines (ci, dev, prod, migration-check, etc.)
├── .githooks/                  # Local enforcement hooks (pre-commit, pre-push)
├── .claude/                    # Claude Code configuration
│   ├── sessions/               # Auto-saved session summaries
│   ├── learnings/              # Project-specific patterns
│   └── scripts/                # Helper scripts (scb, orphan-scan, review markers)
├── deploy/                     # Server setup, Nginx, systemd
├── docs/                       # Product, legal, marketing, design docs
│   └── specs/                  # ← you are here
├── CLAUDE.md                   # Development pipeline (read first)
├── RULES.md                    # Coding rules (read second)
├── WORKING-CONTEXT.md          # Current sprint (read on every session start)
└── TASK_TRACKER.md             # Feature status
```

---

## Getting help / unstuck

1. **Search `docs/` first** — most questions have been answered once.
2. **Check `KNOWN_ISSUES.md`** — deferred issues with context.
3. **Grep the codebase** — `rg "your_search_term"` (ripgrep) is fastest.
4. **Ask Claude Code** via `/council` for architectural questions or `/reality-check` for "should we even build this?"
5. **Ask Amit** for product, strategy, or when the codebase contradicts itself.

---

## What success looks like in week 1

- [x] Backend + Flutter running locally, you can log in
- [x] Tests pass locally (`pytest` and `flutter test`)
- [x] One merged PR (however small — even a docstring fix)
- [x] Read `CLAUDE.md`, `RULES.md`, and the 8 spec documents in this folder
- [x] Understand the 9-stage pipeline and can point to where each stage happens
- [x] Know where to add a new API endpoint and a new Flutter screen

Welcome to Swasth.
