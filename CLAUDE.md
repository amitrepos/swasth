# Swasth Health App — Claude Code Instructions

## Project Overview
Flutter + FastAPI health monitoring app. Target: Bihar pilot.
Backend: Python/FastAPI + PostgreSQL. Frontend: Flutter (web + mobile).

## Key Directories
- `backend/` — FastAPI backend (Python)
- `lib/` — Flutter frontend (Dart)
- `TASK_A2_MULTI_PROFILE.md` — active feature task breakdown
- `KNOWN_ISSUES.md` — deferred issues tracked for pre-production
- `AUDIT.md` — change log (update on every session)

## Mandatory: Audit Log
**Every session, before ending, append a summary of all changes made to `AUDIT.md`.**

Format:
```
## YYYY-MM-DD — <one line summary of session work>
- Changed `file/path.py`: what and why
- Created `file/path.dart`: what and why
```

## Active Feature
**A2 — Multi-Profile with Cross-User Sharing**
Full task breakdown in `TASK_A2_MULTI_PROFILE.md`. Follow the execution order (Steps 1–22).

## Architecture Decisions (do not change without discussion)
- Auth: email + password + JWT (no Firebase for PoC)
- DB: PostgreSQL via SQLAlchemy
- Auth dependency: `backend/dependencies.py → get_current_user`
- Shared HTTP utils: `lib/services/api_client.dart → ApiClient`
- Secrets never committed — `backend/.env` is gitignored

## Code Rules
- Never copy-paste auth boilerplate — use `Depends(get_current_user)`
- All Flutter HTTP calls use `ApiClient.headers()` and `ApiClient.errorDetail()`
- No print() statements in backend — clean them up if encountered
- Follow execution order in task files before writing code
