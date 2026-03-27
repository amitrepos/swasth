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
