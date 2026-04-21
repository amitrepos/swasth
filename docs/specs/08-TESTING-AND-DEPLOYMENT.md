# 08 — Testing & Deployment

**Principle:** Health data = no room for "I think it works." Every change is verified — locally, in CI, and after deploy. Skipping a verification step is how bugs reach production.

---

## 1. Testing philosophy

1. **Coverage is a floor, not a ceiling.** Tier 1 (health logic) has a 95% coverage gate because a missed branch is a missed edge case in clinical classification.
2. **Test quality > test count.** 100 tests that all hit the happy path are worse than 20 tests with boundary and error cases.
3. **E2E flow tests are the critical gate.** They prove the feature works end-to-end. Unit tests prove the pieces work in isolation.
4. **Write failing test first (TDD).** Especially for bug fixes — if you can't reproduce the bug in a test, you haven't fixed it.
5. **Never mock what you can run locally.** Backend tests run against SQLite in-memory; Flutter tests use `InMemoryStorage`. Only mock the expensive external services (Gemini, Twilio, Brevo).

---

## 2. Backend testing

### 2.1 Running tests

```bash
cd backend && source venv/bin/activate

# All tests, verbose
TESTING=true python -m pytest tests/ -v

# One file
TESTING=true python -m pytest tests/test_auth.py -v

# One test
TESTING=true python -m pytest tests/test_auth.py::test_register_success -v

# With coverage
TESTING=true python -m pytest tests/ --cov=. --cov-report=term-missing --cov-config=.coveragerc

# HTML coverage report
TESTING=true python -m pytest tests/ --cov=. --cov-report=html
open htmlcov/index.html
```

`TESTING=true` switches to in-memory SQLite and stubs external APIs. The switch is in `config.py` and `conftest.py`.

### 2.2 Coverage tiers (hard gate)

| Tier | Target | Files |
|---|---|---|
| **1 — Health-critical** | 95% | `health_utils.py`, `routes_health.py`, `routes_meals.py`, `models.py`, `schemas.py` |
| **2 — Auth/security** | 90% | `dependencies.py`, `routes.py` (auth), `encryption_service.py` |
| **3 — General** | 85% | Everything else |

**Coverage below the tier target is a FAIL.** Write tests until it passes. CI blocks the merge if coverage drops below a tier floor.

### 2.3 Test structure

```
backend/tests/
├── conftest.py                       # Fixtures: client, auth_headers, sample_profile, sample_reading
├── test_auth.py                       # /auth/* happy + denial paths
├── test_api_auth.py                   # Integration-level auth
├── test_health_*.py                   # Classification, readings, insights
├── test_meals.py · test_meal_insights.py
├── test_chat.py · test_chat_extended.py
├── test_doctor_*.py                   # Registration, linking, patient access, triage
├── test_admin.py · test_admin_coverage.py
├── test_profiles_endpoints.py
├── test_encryption.py
├── test_alert_service.py
├── test_ai_*.py
└── ...
```

### 2.4 Writing a good backend test

```python
# tests/test_health_readings.py
def test_high_bp_triggers_critical_alert(
    client, auth_headers, sample_profile, mock_alert_service
):
    # GIVEN — a profile with no prior readings
    # WHEN — user logs a stage-2 hypertension reading
    response = client.post(
        "/api/health/readings",
        headers=auth_headers,
        json={
            "profile_id": sample_profile.id,
            "reading_type": "blood_pressure",
            "systolic": 165,
            "diastolic": 105,
            "pulse_rate": 78,
            "reading_timestamp": "2026-04-20T08:30:00+05:30",
        },
    )
    # THEN — response is 201, status_flag is correct, alert fires
    assert response.status_code == 201
    assert response.json()["status_flag"] == "HIGH-STAGE-2"
    mock_alert_service.dispatch.assert_called_once()
```

**Rules:**

- Every test has GIVEN / WHEN / THEN (comment or convention).
- Test the **denial path** — 401s, 403s, validation errors. Not just the happy path.
- For clinical logic, use **boundary values** (139/89 → not hypertension; 140/90 → stage 1).
- For encryption, test **encrypt → decrypt roundtrip** produces the original value.
- Mock only external network (Gemini, Brevo, Twilio). Use the real DB (SQLite in-memory).

### 2.5 Fixtures to know (`conftest.py`)

- `client` — FastAPI TestClient.
- `db` — in-memory SQLite session.
- `sample_user` — pre-seeded user.
- `auth_headers` — pre-signed JWT for `sample_user`.
- `sample_profile` — profile owned by `sample_user`.
- `sample_doctor` — doctor user with verified `DoctorProfile`.
- `mock_gemini`, `mock_brevo`, `mock_twilio` — stubbed external services.

---

## 3. Flutter testing

### 3.1 Running tests

```bash
# Static analysis (zero errors required)
flutter analyze

# E2E flow tests — THE critical gate
flutter test test/flows/ --timeout 30s

# Full test suite (187 tests)
flutter test

# Single file
flutter test test/flows/auth_flow_test.dart -v

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### 3.2 E2E flow tests — the non-negotiable gate

Every PR that touches Flutter code must pass `flutter test test/flows/ --timeout 30s` with zero failures. No exceptions.

**Current coverage (82 flow tests, 187 total):**

| File | Tests | What it covers |
|---|---|---|
| `auth_flow_test.dart` | 9 | Login, registration, validation, navigation |
| `dashboard_display_test.dart` | 6 | All screens render, no ErrorWidgets |
| `health_reading_flow_test.dart` | 14 | BP + glucose entry, validation, boundary, save |
| `meal_logging_flow_test.dart` | 8 | Quick select, meal type, API save |
| `chat_flow_test.dart` | 8 | Input, send, response, quota |
| `profile_flow_test.dart` | 9 | Selection, create, validate, API loads |
| `history_flow_test.dart` | 5 | Readings list, data display |
| `error_handling_test.dart` | 5 | Wrong creds, server errors, validation |
| `offline_sync_test.dart` | 10 | Queue, sync, failed items, unreachable server |
| `boundary_tests.dart` | 36 | Clinical classification (BP/glucose), double-tap, token expiry |

### 3.3 Test infrastructure

```
test/
├── flows/                      # E2E flow tests (don't skip these)
├── helpers/
│   ├── test_app.dart            # TestEnv.setup(), pumpN()
│   ├── mock_http.dart           # Mock for all 48 API endpoints
│   └── finders.dart             # Key-based widget finders
├── screens/                    # Per-screen widget tests
└── services/                   # Service-level unit tests
```

### 3.4 Test-writing rules (non-negotiable)

1. **Never `pumpAndSettle()`** — it hangs forever with animations. Use `await pumpN(tester, 5)` which pumps a fixed number of frames.
2. **Never `FlutterSecureStorage()` directly** — use `StorageService.useInMemoryStorage()` in test setup.
3. **Every interactive widget needs a `Key`** — `Key('submit_button')`. Tests find by key, not by text.
4. **Every new API endpoint needs a mock in `mock_http.dart`** — tests fail loudly if the endpoint is hit without a mock.
5. **Test the error path** — wrong credentials, server 500, offline, validation error. Not just success.
6. **Include `created_at` in mock data** — the app crashes without it.
7. **Test boundary values for health classifications** — 139/89 vs 140/90 vs 160/100.

### 3.5 Writing a flow test

```dart
// test/flows/health_reading_flow_test.dart
testWidgets('BP entry at stage 2 shows critical banner', (tester) async {
  // GIVEN — logged-in user with a selected profile
  await TestEnv.setup(tester);
  MockHttp.stub(
    'POST /api/health/readings',
    (req) => Response(
      jsonEncode({'id': 1, 'status_flag': 'HIGH-STAGE-2', ...}),
      201,
    ),
  );

  // WHEN — user enters 165/105 on scan screen
  await tester.tap(find.byKey(const Key('bp_tab')));
  await pumpN(tester, 3);
  await tester.enterText(find.byKey(const Key('systolic_input')), '165');
  await tester.enterText(find.byKey(const Key('diastolic_input')), '105');
  await tester.tap(find.byKey(const Key('save_reading')));
  await pumpN(tester, 5);

  // THEN — critical banner visible
  expect(find.byKey(const Key('critical_banner')), findsOneWidget);
});
```

---

## 4. Continuous Integration (GitHub Actions)

### 4.1 `ci.yml` — runs on every push + PR

1. **Backend tests** — `pytest tests/ -v --cov=. --cov-config=.coveragerc`; fails if coverage < tier floor.
2. **Flutter analyze** — `flutter analyze --no-fatal-infos`; zero errors required.
3. **Flutter tests** — `flutter test`; all 187 must pass.

### 4.2 `migration-check.yml` — runs on backend changes

Spins up an ephemeral PostgreSQL, runs:

```bash
alembic upgrade head
alembic check
```

Ensures:
- Every `models.py` change has a matching migration.
- The migration actually applies cleanly.
- `alembic check` finds no drift (no orphan model attributes).

Paired with the pre-commit hook — belt and suspenders.

### 4.3 `branch-hygiene.yml` — enforces branch rules

- Refuses merge commits on `master` (linear history only).
- Blocks force-push to `master`.
- Verifies `.githooks/` scripts are present and executable.

### 4.4 `dev.yml` — auto-deploy to staging

Triggers on push to `master`. Deploys:

- Backend: SSH to staging, `git pull`, `pip install -r requirements.txt`, `alembic upgrade head`, systemctl restart.
- Flutter web: builds, syncs to `/var/www/swasth/web/`.

### 4.5 `prod.yml` — manual production deploy

Manual workflow_dispatch. Requires approval. Same steps as `dev.yml`, targeting production host.

---

## 5. Local pre-push checklist

Run **all** of these before `git push`. Most are enforced by hooks, but running them locally catches problems before CI.

```bash
# Flutter
flutter analyze --no-pub                              # Zero errors
flutter test test/flows/ --timeout 30s                # E2E pass
flutter test                                          # Full suite pass

# Backend
cd backend && source venv/bin/activate
TESTING=true python -m pytest tests/ -v               # All pass
TESTING=true python -m pytest tests/ --cov=. --cov-config=.coveragerc

# Migrations (if you edited models.py)
alembic upgrade head
alembic check   # "No new upgrade operations detected"
```

---

## 6. Deployment

### 6.1 Deploy targets

| Env | Host | Trigger | Approval |
|---|---|---|---|
| **Staging** | `65.109.226.36:8443` | auto on push to `master` | none |
| **Production** | TBD | manual via `prod.yml` | required |

### 6.2 What a deploy actually does

1. **Pre-deploy:** CI has already passed (tests, coverage, migrations).
2. **Pull:** SSH to host, `git pull origin master`.
3. **Install:** `pip install -r requirements.txt` inside venv.
4. **Migrate:** `alembic upgrade head` — **before** the restart, so new code never sees old schema.
5. **Restart:** `kill $(lsof -ti :8007); sleep 2; cd /var/www/swasth/backend && nohup python3 -B main.py > /var/log/swasth-backend.log 2>&1 &`
6. **(If web changed):** `scp -r build/web/* root@host:/var/www/swasth/web/`
7. **Verify:** `curl https://<host>/api/docs` returns 200.

### 6.3 Manual staging deploy (from your machine)

```bash
git checkout master && git pull origin master

# Flutter web
flutter build web --release --dart-define=SERVER_HOST=https://65.109.226.36:8443
scp -i ~/.ssh/new-server-key -r build/web/* root@65.109.226.36:/var/www/swasth/web/

# Backend (if changed)
scp -i ~/.ssh/new-server-key backend/<changed_file>.py root@65.109.226.36:/var/www/swasth/backend/

# Migrations (before restart — idempotent)
ssh -i ~/.ssh/new-server-key root@65.109.226.36 \
  "cd /var/www/swasth/backend && alembic upgrade head"

# Restart
ssh -i ~/.ssh/new-server-key root@65.109.226.36 \
  "kill \$(lsof -ti :8007); sleep 2; cd /var/www/swasth/backend && nohup python3 -B main.py > /var/log/swasth-backend.log 2>&1 &"

# Verify
curl -k https://65.109.226.36:8443/api/docs
```

### 6.4 Rollback

Preferred: **roll forward** with a corrective commit. Rollback is error-prone for database-migrated services.

Emergency rollback:

```bash
ssh root@host
cd /var/www/swasth/backend
git log --oneline -10     # find previous good SHA
git checkout <good-sha>
alembic downgrade <prev-revision>   # only if schema regressed
systemctl restart swasth-backend
```

**Never** run `alembic downgrade` without understanding what data it will drop. Prefer a corrective forward migration.

---

## 7. Play Store releases (Android)

Full runbook: `docs/PLAY_STORE_RUNBOOK.md`.

Summary:

```bash
# Version bump
# Edit pubspec.yaml: version: 1.4.3+43  (semver+buildNumber)

# Build signed AAB
flutter build appbundle \
  --release \
  --flavor production \
  --target lib/main_production.dart

# Output: build/app/outputs/bundle/productionRelease/app-production-release.aab

# Upload via Play Console (manual) or fastlane (future)
```

Keystore lives at `~/.swasth/` — never committed. Bundle ID: `health.swasth.app`. Admin account: `swasth.admin@gmail.com`.

---

## 8. Verification discipline (post-deploy)

**Exit code 0 does NOT prove success.** After every deploy, run observable verifications:

- `curl https://<host>/api/docs` — returns 200 with Swagger UI.
- `curl -X POST https://<host>/api/auth/login -d 'username=...&password=...'` — returns a token.
- SSH `tail -50 /var/log/swasth-backend.log` — no tracebacks in last minute.
- SSH `alembic current` — matches latest revision ID.
- Login via Flutter web and log a reading end-to-end.

If any step fails, investigate before claiming the deploy succeeded. See `feedback_state_verification.md` in the user's memory — this is the #1 source of post-deploy bugs.

---

## 9. Monitoring (current state + gaps)

**In place:**

- systemd journal captures all backend stdout/stderr.
- `admin_audit_log` provides action-level audit.
- `critical_alert_logs` records every alert fanout outcome.
- `ai_insight_logs` captures every AI call (cost + latency + errors).

**Gaps (tracked in `KNOWN_ISSUES.md`):**

- No centralized error tracking (Sentry, Rollbar) — reviewing at DAU > 100.
- No uptime pinger — planned.
- No Flutter crash reporter — planned post-Play Store launch.
- No per-endpoint latency dashboard.

---

## 10. The 9-stage pipeline (once more, with feeling)

Every change flows through CLAUDE.md's pipeline:

```
1. UNDERSTAND → 1.5 REALITY → 2. PLAN → 3. VALIDATE → 4. IMPLEMENT
→ 5. VERIFY (7 phases) → 6. SECURE → 7. EXPERT QA → 8. CODE REVIEW → 9. SHIP
```

Stages **5–9** are what this document is about. If you've completed 1–4, run `/verify`, then `/security-audit`, then the domain experts, then `/review`, then `/ship`. The skills chain the whole thing.

The pipeline is not bureaucratic overhead. It's the difference between "I think this works" and "I know this works." For health data, that difference is the product.

---

**End of the spec set.** Start at [README](README.md) if you got here by accident. Continue to [CLAUDE.md](../../CLAUDE.md) for the operational pipeline.
