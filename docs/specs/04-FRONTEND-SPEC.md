# 04 — Frontend Spec

**Stack:** Flutter 3.22 · Dart 3.4 · Riverpod 3.x · Material 3 · gen-l10n
**Targets:** Android APK, Flutter web
**Entry points:** `lib/main_staging.dart`, `lib/main_production.dart`

---

## 1. Module layout

```
lib/
├── main.dart                   # Legacy entry (defers to staging)
├── main_staging.dart           # Staging flavor entry
├── main_production.dart        # Production flavor entry
├── bootstrap.dart              # App init (env, Riverpod, splash → home)
├── app.dart                    # MaterialApp, theme, localization, routes
│
├── screens/                    # UI screens (~30 files)
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── registration_screen.dart
│   ├── forgot_password_screen.dart
│   ├── otp_verification_screen.dart
│   ├── reset_password_screen.dart
│   ├── email_verification_screen.dart
│   ├── consent_screen.dart
│   ├── privacy_policy_screen.dart
│   ├── dashboard_screen.dart
│   ├── scan_screen.dart                 # Camera-based reading entry
│   ├── photo_scan_screen.dart
│   ├── reading_confirmation_screen.dart
│   ├── quick_select_screen.dart
│   ├── history_screen.dart
│   ├── insights_screen.dart
│   ├── food_photo_screen.dart
│   ├── meal_result_screen.dart
│   ├── chat_screen.dart
│   ├── profile_screen.dart
│   ├── create_profile_screen.dart
│   ├── select_profile_screen.dart
│   ├── manage_access_screen.dart
│   ├── pending_invites_screen.dart
│   ├── link_doctor_screen.dart
│   └── admin_create_user_screen.dart
│
├── services/                   # 16 services (HTTP, storage, sync, platform channels)
│   ├── api_client.dart          # Low-level HTTP wrapper (token, error mapping)
│   ├── api_service.dart         # Typed endpoint methods
│   ├── api_exception.dart       # Typed exception hierarchy
│   ├── error_mapper.dart        # Exception → localized user message
│   ├── storage_service.dart     # flutter_secure_storage wrapper (test-injectable)
│   ├── connectivity_service.dart
│   ├── sync_service.dart        # Offline write queue
│   ├── health_reading_service.dart
│   ├── meal_service.dart
│   ├── chat_service.dart
│   ├── doctor_service.dart
│   ├── admin_service.dart
│   ├── profile_service.dart
│   ├── ocr_service.dart         # MLKit wrapper
│   ├── pedometer_service.dart   # Native step-counter channel
│   └── reminder_service.dart    # Local notifications
│
├── models/                     # Dart data classes (with fromJson/toJson)
├── providers/                  # Riverpod providers
│   └── language_provider.dart
├── widgets/                    # Reusable UI components
├── theme/
│   └── app_theme.dart           # AppColors, text styles, Material3 theme
├── l10n/
│   ├── app_en.arb               # English strings
│   ├── app_hi.arb               # Hindi strings
│   └── app_localizations*.dart  # Generated — do not edit by hand
├── utils/                      # Validators, formatters, date/time
├── config/                     # Flavor, environment, API host
├── constants/                  # Magic numbers, timeouts
└── ble/                        # Bluetooth Low Energy (glucometer, BP monitor)
```

---

## 2. Startup flow

```
main_staging.dart / main_production.dart
   │
   ├─ bootstrap.dart
   │    ├─ Load flutter_dotenv
   │    ├─ Set up TimeZone
   │    ├─ Configure StorageService (secure or in-memory for tests)
   │    ├─ Initialize ProviderScope (Riverpod)
   │    └─ runApp(SwasthApp())
   │
   └─ app.dart (SwasthApp extends ConsumerWidget)
        ├─ MaterialApp with theme, localization, locale (from Riverpod)
        ├─ Home: SplashScreen
        │     └─ checks auth token in StorageService
        │           ├─ token valid → DashboardScreen
        │           └─ no/invalid token → LoginScreen
        └─ named routes + routeObserver
```

---

## 3. Flavors

```
lib/config/flavor.dart:
  enum Flavor { staging, production }
  static Flavor current;

lib/config/environment.dart:
  String get apiHost => switch (Flavor.current) {
    Flavor.staging    => 'https://65.109.226.36:8443',
    Flavor.production => 'https://swasth.app',
  };
```

Flavors are set by the entry point (`main_staging.dart` vs `main_production.dart`). Override via `--dart-define=SERVER_HOST=...` when running locally.

Build commands:
```bash
# Staging Android
flutter build apk --flavor staging -t lib/main_staging.dart

# Production Android
flutter build apk --flavor production -t lib/main_production.dart

# Production web
flutter build web --release -t lib/main_production.dart
```

---

## 4. State management — Riverpod

Riverpod 3.x is the only state library. Do not introduce Provider, Bloc, or GetX.

**Canonical patterns:**

```dart
// 1. Global singleton service
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// 2. Reactive state
final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  return LanguageNotifier();
});

// 3. Async data (remote fetch)
final readingsProvider = FutureProvider.family<List<HealthReading>, int>(
  (ref, profileId) async {
    final svc = ref.watch(healthReadingServiceProvider);
    return svc.fetchReadings(profileId: profileId);
  },
);

// 4. Invalidation after a write
ref.invalidate(readingsProvider(profileId));
```

**Screen pattern:** extend `ConsumerWidget` or `ConsumerStatefulWidget`. Never use `setState` for data that also lives in Riverpod — pick one source of truth per piece of state.

---

## 5. Networking — `ApiClient`

All HTTP calls route through `lib/services/api_client.dart`. Never `import 'package:http/http.dart';` directly in a screen.

**What ApiClient does:**

- Injects `Authorization: Bearer <token>` from `StorageService`.
- Adds `X-App-Version`, `X-Locale` headers.
- Times out after 15s (configurable per call).
- Maps HTTP status to typed exceptions:

| Status | Exception |
|---|---|
| 200–299 | (returns parsed JSON) |
| 400–422 | `ValidationException(field, message)` |
| 401 | `UnauthorizedException` (caller usually logs out) |
| 403 | `ForbiddenException` |
| 404 | `NotFoundException` |
| 429 | `RateLimitException` |
| 5xx | `ServerException` |
| network | `NetworkException` (connectivity / timeout) |

**Error rendering:** always route through `error_mapper.dart → friendlyMessage(exception, context)`. This returns a localized user-facing string (no raw stack traces or English-only errors in the UI).

**Example screen usage:**

```dart
try {
  await ref.read(healthReadingServiceProvider).createReading(data);
  ref.invalidate(readingsProvider(profileId));
} on UnauthorizedException {
  await _logout();
} catch (e) {
  _showSnackBar(ErrorMapper.friendlyMessage(e, context));
}
```

---

## 6. Offline-first — `sync_service`

The app treats network as unreliable by default.

**Write path:**

```
User action → Service method → ApiClient.post()
                                 │
                                 ├── online → server → success
                                 └── offline (NetworkException)
                                       │
                                       └── SyncService.enqueue(request)
                                           → optimistic local update
                                           → return success to UI
```

**Queue behavior:**

- Backed by `flutter_secure_storage` (survives app restart).
- FIFO order preserved.
- On `ConnectivityService.onConnected`, drains the queue.
- Per-request retry with exponential backoff (max 3 attempts).
- Failed items after retry budget are surfaced to the user in the `history` screen with a "Retry" affordance.

**Read path:** local cache first (stale-while-revalidate). Background refresh when connectivity returns.

See `test/flows/offline_sync_test.dart` for the canonical test harness.

---

## 7. Storage — `storage_service`

Wraps `flutter_secure_storage` with a test-injection seam:

```dart
// Production
StorageService.useSecureStorage();

// Tests
StorageService.useInMemoryStorage();
```

**Never** instantiate `FlutterSecureStorage()` directly — it blows up in widget tests (no platform channels) and you'll lose hours. `test/helpers/test_app.dart` already configures in-memory storage in its `TestEnv.setup()`.

**What's stored:**

| Key | Value |
|---|---|
| `auth_token` | JWT |
| `user_email` | cached email |
| `current_profile_id` | selected profile |
| `sync_queue` | JSON-encoded offline queue |
| `locale` | `en` or `hi` |

---

## 8. Localization

**ARB-driven, fully generated.** Never hardcode UI text.

```
lib/l10n/app_en.arb           # base (English)
lib/l10n/app_hi.arb           # Hindi
```

Every new string must be added to **both** files. `app_hi.arb` can use the English text as a placeholder — Sunita (persona) reviews Hindi naturalness before merge.

**Generate:**

```bash
flutter gen-l10n
```

This regenerates `lib/l10n/app_localizations*.dart`. Do not edit the generated files.

**Use in code:**

```dart
final l = AppLocalizations.of(context)!;
Text(l.loginButton);
Text(l.greetingWithName('Amit'));
```

**Language switching:** via `languageProvider` (Riverpod). Locale is persisted in `StorageService`. The Hindi/English toggle in the profile screen updates the provider.

---

## 9. Theming — `app_theme.dart`

All colors and text styles live in `lib/theme/app_theme.dart`. Never hardcode `Colors.red` or `TextStyle(fontSize: 14)` in screens.

```dart
class AppColors {
  static const Color primary = Color(0xFF...);
  static const Color critical = Color(0xFF...);
  static const Color success = ...;
  // etc.
}
```

**Rules:**

- Touch targets ≥ 48dp (Bihar grandmother test).
- Base font size ≥ 14sp, body text 16sp.
- Use solid colors, not gradients, for critical UI (readable under sun glare).
- Color-blind safe: critical = red+icon, not red alone.

The Healthify / Sunita / Aditya domain experts enforce these during the Stage 7 review.

---

## 10. Screens — authoring checklist

When adding a new screen:

1. **Every interactive element gets a `Key`**:
   ```dart
   ElevatedButton(key: const Key('submit_button'), ...)
   ```
   Tests rely on these (`test/helpers/finders.dart`).

2. **State is Riverpod, not `setState`** (except for pure UI state like "is dropdown open").

3. **Service calls go through a service class**, not raw `ApiClient` calls from the screen.

4. **All text goes through `AppLocalizations`**.

5. **All colors come from `AppColors`**.

6. **Error handling uses `ErrorMapper`**.

7. **Write an E2E flow test FIRST** in `test/flows/<feature>_flow_test.dart`. See §12.

8. **Register in routes** if navigated via named routes (check `lib/app.dart`).

---

## 11. Platform integrations

### 11.1 Camera

`scan_screen.dart` and `food_photo_screen.dart` use the `camera` package for live preview + capture. Permissions handled via `permission_handler`. On iOS, Info.plist entries are required (see `ios/Runner/Info.plist`).

### 11.2 OCR (MLKit)

`ocr_service.dart` wraps `google_mlkit_text_recognition`. Parses blood pressure (`<sys>/<dia>`) and glucose values from photos of device displays. On-device, so it works offline.

Fallback: `POST /api/health/readings/parse-image` does server-side parsing if MLKit fails (e.g., web clients).

### 11.3 Bluetooth (BLE)

`lib/ble/` contains the device pairing code for supported glucometers and BP monitors. Still experimental — not in the critical path for the Bihar pilot.

### 11.4 Pedometer

`pedometer_service.dart` uses the `pedometer` package (platform channel to native step counter). Steps are polled every 60 seconds when the app is in foreground.

### 11.5 Local notifications

`reminder_service.dart` uses `flutter_local_notifications` for:

- Mealtime reminders (configurable per profile).
- Daily health-check reminders.

Timezone handling uses the `timezone` package; users set their timezone in `profile_screen`.

---

## 12. Testing

The canonical command:

```bash
flutter analyze                               # zero errors required
flutter test test/flows/ --timeout 30s         # E2E flows — MUST pass on every PR
flutter test                                   # full suite (187 tests)
```

**Flow tests are the non-negotiable gate.** Every new feature must either (a) add a new flow test, or (b) extend an existing one.

**Key helpers (`test/helpers/`):**

- `test_app.dart` — `TestEnv.setup()`, `pumpN()` helper (never use `pumpAndSettle` — it hangs with animations).
- `mock_http.dart` — mock HTTP for all 48 API endpoints.
- `finders.dart` — Key-based widget finders.

**Existing flow coverage:**

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
| `boundary_tests.dart` | 36 | BP/glucose classification, double-tap, token expiry |

Full testing methodology in [08 — Testing & Deployment](08-TESTING-AND-DEPLOYMENT.md).

---

## 13. Deploying the Flutter client

**Web (staging):**

```bash
git checkout master && git pull
flutter build web --release --target lib/main_staging.dart \
  --dart-define=SERVER_HOST=https://65.109.226.36:8443
scp -i ~/.ssh/new-server-key -r build/web/* root@65.109.226.36:/var/www/swasth/web/
```

**Android (Play Store):**

See `docs/PLAY_STORE_RUNBOOK.md` for the full signing + upload flow (keystore location, Bundle ID, version bump).

---

## 14. Things to avoid

1. **Don't hardcode colors, strings, or API hosts.** Use `AppColors`, `AppLocalizations`, `environment.apiHost`.
2. **Don't use `pumpAndSettle()` in tests.** It hangs with animations. Use `pumpN()`.
3. **Don't use `FlutterSecureStorage` directly in tests.** Use `StorageService.useInMemoryStorage()`.
4. **Don't call `ApiClient` from screens.** Use a service.
5. **Don't forget to `flutter gen-l10n`** after editing ARB files — CI will fail.
6. **Don't mix `setState` and Riverpod** for the same state.
7. **Don't add a new package without discussion** — pubspec.yaml bloat kills startup time on low-end devices.
8. **Don't commit `.flutter-plugins*` or `.dart_tool/`** — they're gitignored; don't work around it.

---

Next: [05 — Data Model](05-DATA-MODEL.md) · [06 — API Reference](06-API-REFERENCE.md)
