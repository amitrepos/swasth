# Known Issues — Fix Before Going Live

Track of deferred issues to resolve before production launch.
Issues are grouped by priority. Check them off as they are resolved.

---

## CRITICAL — Fix Before First Real User

- [ ] **CORS: restrict allowed origins**
  - `backend/main.py:25` — `allow_origins=["*"]` must be changed to a whitelist of specific origins (e.g. your production web URL).
  - Risk: any website can make authenticated requests on behalf of your users.

- [ ] **Move SMTP credentials out of tracked files**
  - `backend/.env` is currently committed to the repo. Real SMTP credentials must be injected via CI/CD secrets or a `.env.local` file added to `.gitignore`.
  - Risk: repo access = free email account access.

---

## HIGH — Security & Stability

- [ ] **Add rate limiting on auth and OTP endpoints**
  - Endpoints: `POST /api/auth/login`, `/register`, `/forgot-password`, `/verify-otp`
  - No limit means brute-force attacks on passwords and OTP codes are trivial.
  - Library: `slowapi` (FastAPI-compatible).

- [ ] **Hash OTP before storing in database**
  - `backend/models.py:67` — OTP is stored as plain text.
  - If the DB is ever read by an attacker, all active OTPs are exposed.
  - Fix: store `hashlib.sha256(otp.encode()).hexdigest()` and compare hashes.

- [ ] **Implement token refresh (refresh tokens)**
  - `backend/auth.py` only issues access tokens (30-min expiry).
  - Users are silently logged out mid-session with no graceful recovery.
  - Fix: issue a long-lived refresh token alongside the access token.

---

## MEDIUM — Code Quality & Performance

- [ ] **Add database connection pool configuration**
  - `backend/database.py:7` — `create_engine()` has no pool settings.
  - Add: `pool_pre_ping=True, pool_size=10, max_overflow=20` to survive reconnects and load.

- [ ] **Add index on `(user_id, reading_timestamp DESC)`**
  - `backend/models.py` — no composite index on the health readings table.
  - As data grows, per-user reading queries will slow down.
  - Fix: add `Index('ix_readings_user_time', 'user_id', 'reading_timestamp')` to the model.

- [ ] **Fix N+1 queries in `/readings/stats/summary`**
  - `backend/routes_health.py` — summary endpoint runs 4 separate DB queries.
  - Replace with a single aggregation query using `func.count()` and `case()`.

- [ ] **BLE packet bounds checking**
  - `lib/ble/glucose_service.dart:57-118` and `lib/ble/bp_service.dart:116-186`
  - Initial length check exists, but individual field accesses inside the loop have no bounds guards.
  - Risk: malformed BLE packet causes an out-of-bounds crash.

- [ ] **Cancel BLE subscriptions on screen disposal**
  - `lib/screens/dashboard_screen.dart` — `onValueReceived.listen(...)` subscriptions are never cancelled.
  - Causes memory leaks and stale callbacks firing after the screen is closed.
  - Fix: store `StreamSubscription` references and call `.cancel()` in `dispose()`.

- [ ] **Add HTTP request timeouts in Flutter**
  - `lib/services/api_service.dart`, `lib/services/health_reading_service.dart`
  - No timeout on any `http.get/post/put/delete` call.
  - A slow server will freeze the UI indefinitely.
  - Fix: wrap client with `http.Client()` and set `.connectionTimeout` / use `timeout()`.

---

## LOW — Technical Debt

- [ ] **Wire up Riverpod for shared state management**
  - `flutter_riverpod` is in `pubspec.yaml` but unused.
  - All screens use local `StatefulWidget` state; user/token data is fetched independently per screen.
  - Required before adding more screens or coordinating state across the app.

- [ ] **Add soft delete for users**
  - `backend/models.py` — no `deleted_at` field on `User`.
  - Hard-deleting users can break foreign key references on `health_readings`.

- [ ] **Make `ApiService` a singleton in Flutter**
  - `lib/screens/login_screen.dart`, `dashboard_screen.dart`, etc. — `final _apiService = ApiService()` is called per screen.
  - Use a top-level instance or a Riverpod provider.

- [ ] **Remove `// ignore_for_file: deprecated_member_use` suppressions**
  - `lib/screens/registration_screen.dart:2`
  - Suppressed deprecation warnings hide future breakage. Identify and fix the underlying deprecated API.

- [ ] **Add BLE reconnection logic**
  - If a BLE device disconnects mid-session, the app has no auto-reconnect.
  - Users must manually find and reconnect the device.

---

## Notes

- Issues already fixed in the current codebase are **not listed** here.
- When fixing an issue, remove it from this list and reference the commit in the PR description.
- Re-evaluate this list before every release milestone.
