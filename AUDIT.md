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
