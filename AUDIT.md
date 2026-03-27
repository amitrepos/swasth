# Swasth App — Change Audit Log

All significant changes made during Claude Code sessions are recorded here.
Format: date, summary, file-level details.

---

## 2026-03-27 — Initial setup, critical fixes, and refactoring

### Setup
- Created `backend/.env` with real DATABASE_URL and generated SECRET_KEY
- Created `swasth_db` PostgreSQL database
- Added `BREVO_SMTP_LOGIN` to `.env` (was missing, caused startup failure)
- Ran `backend/init_db.py` — created `users` table

### Critical Fixes
- `backend/.env`: replaced placeholder SECRET_KEY with a 64-char random hex key
- `backend/.env`: fixed DATABASE_URL to remove placeholder password (macOS Homebrew postgres has no local password)

### Backend Refactoring
- `backend/dependencies.py` *(new)*: created `get_current_user` FastAPI dependency — eliminates 8-line copy-pasted auth block that existed in 7 route handlers
- `backend/schemas.py`: extracted `_validate_password_strength()` shared function — was duplicated across 3 validator methods
- `backend/routes.py`: replaced manual token extraction in 2 handlers with `Depends(get_current_user)`; extracted `_get_valid_otp()` helper (was duplicated in verify + reset); removed all `print()` debug statements
- `backend/routes_health.py`: replaced manual token extraction in 5 handlers with `Depends(get_current_user)`; extracted `_get_user_reading()` helper (duplicated in get + delete); added `Query(ge=1, le=500)` cap on readings limit

### Flutter Refactoring
- `lib/services/api_client.dart` *(new)*: `ApiClient.headers()` and `ApiClient.errorDetail()` shared utilities
- `lib/services/api_service.dart`: replaced 7 inline header/error-parsing duplications with `ApiClient` calls
- `lib/services/health_reading_service.dart`: replaced 5 inline header/error-parsing duplications with `ApiClient` calls

### Tracking Files
- `KNOWN_ISSUES.md` *(new)*: all deferred issues tracked with file references and priority grouping
- `TASK_A2_MULTI_PROFILE.md` *(new)*: low-level design for multi-profile feature with 22-step execution plan
- `CLAUDE.md` *(new)*: project system prompt for Claude Code sessions
- `AUDIT.md` *(this file)*: change log

---
  - 13:51:29 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/pubspec.yaml

## 2026-03-27 — A2 Multi-Profile: backend complete, Flutter fixed, app running

### Backend (A2 Steps 2–6)
- `backend/schemas.py`: Rewrote for A2 — removed health fields from UserRegister/UserResponse, added ProfileCreate/ProfileUpdate/ProfileResponse/InviteRequest/InviteResponse/InviteRespondRequest, updated HealthReadingCreate (profile_id) and HealthReadingResponse (profile_id + logged_by)
- `backend/migrate_to_profiles.py` *(new)*: One-time migration script
- `backend/dependencies.py`: Added get_profile_access_or_403 and get_profile_owner_or_403
- `backend/email_service.py`: Added send_profile_invite_email()
- `backend/routes_profiles.py` *(new)*: Full profile CRUD + invite send/cancel/respond endpoints

### Database schema fixes
- `health_readings.logged_by`: Made nullable (matches ondelete=SET NULL in model)
- `health_readings.profile_id`: Added NOT NULL + FK to profiles + composite index

### Flutter fixes
- `lib/services/profile_service.dart`: Fixed critical URL bug (was /api/auth/profiles, now /api/profiles)
- `lib/screens/login_screen.dart`: Removed print() statements
- `lib/screens/home_screen.dart`: Removed unused _navigateToScan method
- `lib/screens/pending_invites_screen.dart`: Replaced deprecated WillPopScope with PopScope

---
  - 18:17:34 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/TASK_A2_MULTI_PROFILE.md

## 2026-03-27 — Added edit-mode sharing as A2 subtask
- Changed `TASK_A2_MULTI_PROFILE.md`: Added `Step 23` and a dedicated "Subtask 23 — Edit-Mode Sharing (`editor` access)" section so shared users in edit mode can add readings on behalf of the profile owner.
- Created `Updates.md`: Logged timestamped change entry for the new subtask definition.
  - 18:17:41 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/Updates.md
  - 18:17:45 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/AUDIT.md
  - 22:19:22 modified: /Users/amitkumarmishra/.claude/plans/giggly-sniffing-thompson.md
  - 22:26:25 modified: /Users/amitkumarmishra/.claude/plans/giggly-sniffing-thompson.md
  - 22:33:33 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/pubspec.yaml
  - 22:33:43 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/android/app/src/main/AndroidManifest.xml
  - 22:33:54 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/ios/Runner/Info.plist
  - 22:34:19 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/services/ocr_service.dart
  - 22:35:26 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/photo_scan_screen.dart
  - 22:36:23 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/reading_confirmation_screen.dart
  - 22:36:34 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/home_screen.dart
  - 22:36:43 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/home_screen.dart
  - 22:36:53 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/home_screen.dart

---

## 2026-03-27 — B1/B2 Photo OCR Scan feature: camera + ML Kit OCR pipeline

### New packages (pubspec.yaml)
- `camera: ^0.10.5+9` — live camera preview with frame guide overlay
- `image_picker: ^1.0.7` — image capture helper
- `google_mlkit_text_recognition: ^0.13.0` — on-device OCR (free, offline, no API key)

### Platform permissions
- `android/app/src/main/AndroidManifest.xml`: added CAMERA permission + hardware features
- `ios/Runner/Info.plist`: added NSCameraUsageDescription + NSPhotoLibraryUsageDescription

### New Flutter files
- `lib/services/ocr_service.dart` *(new)*: on-device OCR — extracts glucose value (2–3 digit number, HI/LO handling) or BP values (systolic/diastolic/pulse regex) from photo; returns OcrResult
- `lib/screens/photo_scan_screen.dart` *(new)*: full-screen camera preview with dimmed overlay + guide rectangle + corner accents, flash toggle, capture button, blurry-photo detection (falls back to manual if OCR returns no text), navigates to ReadingConfirmationScreen
- `lib/screens/reading_confirmation_screen.dart` *(new)*: shows OCR result ("We read 153 mg/dL — correct?") with edit option, meal context chips (Fasting/Before/After Meal) for glucose, timestamp picker, saves via existing POST /readings endpoint

### Modified Flutter files
- `lib/screens/home_screen.dart`: Glucometer and BP Meter buttons now show a bottom-sheet modal with two options — "Scan with Camera" (→ PhotoScanScreen) and "Connect via Bluetooth" (→ existing DashboardScreen BLE flow)

### Backend
- No changes needed — existing POST /readings accepts all required fields; meal_context stored in existing `notes` field
  - 22:38:01 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/AUDIT.md
  - 22:44:15 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/TASK_TRACKER.md
  - 22:57:23 modified: /Users/amitkumarmishra/.claude/plans/giggly-sniffing-thompson.md
  - 22:58:37 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/pubspec.yaml
  - 22:58:41 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/pubspec.yaml
  - 22:58:44 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/l10n.yaml

---

## 2026-03-27 — A6 Hindi/English language toggle: full gen-l10n implementation

### Infrastructure (new files)
- `l10n.yaml`: gen-l10n config pointing to `lib/l10n/`, template `app_en.arb`, output class `AppLocalizations`
- `lib/l10n/app_en.arb`: ~90 string keys covering all 16 screens, with parametric keys for `viewingProfile(name)`, `pendingInvitesBanner(count)`, `logReading(device)`, `saveFailed(error)`, `ageYears(age)`, `heightCm(height)`, `revokeAccessConfirm(name)`, `wantsToShare(profileName)`, `expiresInDays(days, date)`, `acceptedInvite(profileName)`, `rejectedInvite(profileName)`, `otpSentTo(email)`, `resendIn(seconds)`
- `lib/l10n/app_hi.arb`: Full Hindi (Devanagari) translations for all ~90 keys; Bihar-appropriate phrasing; medical condition API values left untranslated
- `lib/providers/language_provider.dart`: `LanguageNotifier extends StateNotifier<Locale>` — saves to FlutterSecureStorage on change and emits new Locale; `languageProvider` StateNotifierProvider

### Modified files
- `pubspec.yaml`: Added `flutter_localizations: sdk: flutter` dependency; added `generate: true` under `flutter:` section
- `lib/services/storage_service.dart`: Added `_languageKey`, `saveLanguage()`, `getLanguage()` — intentionally excluded from `clearAll()` so language preference survives logout
- `lib/main.dart`: `main()` made async, loads saved language from storage before `runApp` (no startup flash); `ProviderScope.overrides` injects correct initial Locale; `SwasthApp` converted from `StatelessWidget` to `ConsumerWidget` watching `languageProvider`; `MaterialApp` gains `locale`, `localizationsDelegates`, `supportedLocales`
- `lib/screens/profile_screen.dart`: Converted to `ConsumerStatefulWidget`; added `_buildLanguageToggle()` (animated segmented English/हिंदी chip row) in Account Settings; all hardcoded strings replaced with `AppLocalizations` keys

### Screen localization (all 15 remaining screens)
- `lib/screens/login_screen.dart`: All UI strings localized
- `lib/screens/registration_screen.dart`: All UI strings localized; medical condition values kept as-is (API keys)
- `lib/screens/select_profile_screen.dart`: All UI strings localized including `pendingInvitesBanner(count:)`
- `lib/screens/home_screen.dart`: All UI strings localized; `_showInputModal()` uses `logReading(device:)` with localized device name
- `lib/screens/history_screen.dart`: Added `_localizedStatus(String? flag, AppLocalizations l10n)` helper to translate status flags without requiring BuildContext in the model; all UI strings localized
- `lib/screens/photo_scan_screen.dart`: Device label from `l10n.glucometer`/`l10n.bpMeter`; `scanTitle(device:)`, `placeDeviceInBox(device:)`, blurry error dialog localized; initState auto-capture (none here)
- `lib/screens/reading_confirmation_screen.dart`: All UI strings localized including `_OcrResultBanner` and `_ManualEntryHint` sub-widgets; `saveFailed(error:)` parametric key used; `_inputField()` simplified (removed `(optional)` suffix — `pulseLabel` already includes it)
- `lib/screens/create_profile_screen.dart`: All UI strings localized
- `lib/screens/manage_access_screen.dart`: All UI strings localized including `revokeAccessConfirm(name:)`
- `lib/screens/pending_invites_screen.dart`: All UI strings localized including `acceptedInvite(profileName:)`, `rejectedInvite(profileName:)`, `wantsToShare(profileName:)`, `expiresInDays(days:, date:)`
- `lib/screens/scan_screen.dart`: All UI strings localized; initial `_status` changed to `''` with fallback to `l10n.pressScanToFind`; `initState` auto-scan wrapped in `addPostFrameCallback` so l10n is available; BLE device-name strings left untranslated (not in ARB)
- `lib/screens/forgot_password_screen.dart`: All UI strings localized
- `lib/screens/otp_verification_screen.dart`: All UI strings localized including `resendIn(seconds:)` and `otpSentTo(email:)`
- `lib/screens/reset_password_screen.dart`: All UI strings localized
- `lib/screens/dashboard_screen.dart`: Device labels (`glucometer`, `bpMeter`, `armband`) localized in device panel; BLE status strings left in English (technical, no ARB keys)
  - 22:59:29 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/l10n/app_en.arb
  - 23:00:31 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/l10n/app_hi.arb
  - 23:00:37 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/providers/language_provider.dart
  - 23:00:41 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/services/storage_service.dart
  - 23:00:46 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/services/storage_service.dart
  - 23:01:00 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/main.dart
  - 23:01:06 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/main.dart
  - 23:01:52 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/profile_screen.dart
  - 23:07:01 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/login_screen.dart
  - 23:07:13 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/forgot_password_screen.dart
  - 23:07:29 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/otp_verification_screen.dart
  - 23:07:47 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/reset_password_screen.dart
  - 23:08:14 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/select_profile_screen.dart
  - 23:08:34 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/create_profile_screen.dart
  - 23:08:52 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/manage_access_screen.dart
  - 23:09:09 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/pending_invites_screen.dart
  - 23:09:48 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/home_screen.dart
  - 23:10:08 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/history_screen.dart
  - 23:10:44 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/photo_scan_screen.dart
  - 23:11:28 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/reading_confirmation_screen.dart
  - 23:11:48 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/scan_screen.dart
  - 23:12:31 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/registration_screen.dart
  - 23:12:35 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/dashboard_screen.dart
  - 23:12:43 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/dashboard_screen.dart
  - 23:13:27 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/AUDIT.md
  - 23:35:20 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/l10n.yaml
  - 23:37:37 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/lib/screens/pending_invites_screen.dart

---

## 2026-03-27 — A6 language toggle: compile fixes, import path correction, arg fixes

### Root Cause Fixes
- `l10n.yaml`: Added `synthetic-package: false` — gen-l10n was generating files in `lib/l10n/` but imports used `package:flutter_gen/gen_l10n/` (which requires the `.dart_tool/` synthetic package). Setting this flag aligns both paths.
- `pubspec.yaml`: Updated `intl` from `^0.19.0` to `^0.20.2` — `flutter_localizations` SDK dep pins `intl` to `0.20.2`; old version caused version-solving failure on `flutter run`.

### Import Path Fix (all 17 screen/main files)
- Changed all l10n imports from `package:flutter_gen/gen_l10n/app_localizations.dart` → `package:swasth_app/l10n/app_localizations.dart` to match actual generated file location in `lib/l10n/`.
- Affected: `lib/main.dart` and all 16 screen files.

### Positional Arg Fixes (gen-l10n generates positional params, not named)
- `lib/screens/profile_screen.dart`: `ageYears(age: ...)` → `ageYears(...)`, `heightCm(height: ...)` → `heightCm(...)`
- `lib/screens/manage_access_screen.dart`: `revokeAccessConfirm(name: ...)` → positional
- `lib/screens/photo_scan_screen.dart`: `scanTitle(device: ...)`, `placeDeviceInBox(device: ...)` → positional
- `lib/screens/home_screen.dart`: `viewingProfile(name: ...)`, `logReading(device: ...)` → positional
- `lib/screens/reading_confirmation_screen.dart`: `saveFailed(error: ...)` → positional
- `lib/screens/select_profile_screen.dart`: `pendingInvitesBanner(count: ...)` → positional
- `lib/screens/otp_verification_screen.dart`: `otpSentTo(email: ...)`, `resendIn(seconds: ...)` → positional
- `lib/screens/pending_invites_screen.dart`: `acceptedInvite`, `rejectedInvite`, `wantsToShare`, `expiresInDays` → all positional

### Generated Files (added to git)
- `lib/l10n/app_localizations.dart` *(generated)*: main export + localizationsDelegates
- `lib/l10n/app_localizations_en.dart` *(generated)*: English string implementations
- `lib/l10n/app_localizations_hi.dart` *(generated)*: Hindi string implementations
  - 23:41:56 modified: /Users/amitkumarmishra/workspace/swasth/swasth_app/AUDIT.md
