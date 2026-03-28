# Swasth Health App — Claude Code Instructions

## Project Overview
Flutter + FastAPI health monitoring app. Target: Bihar pilot.
Backend: Python/FastAPI + PostgreSQL. Frontend: Flutter (web + mobile).

## Key Directories
- `backend/` — FastAPI backend (Python)
- `lib/` — Flutter frontend (Dart)
- `lib/theme/app_theme.dart` — AppColors (iOS system color palette)
- `lib/screens/trend_chart_screen.dart` — 7/30-day glucose + BP charts
- `TASK_TRACKER.md` — full feature status across all modules (A–D)
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

## Active Branch
`feature/phase1-dashboard-complete` — Phase 1 dashboard pushed to GitHub (2026-03-28).

## Completed Milestones (do not re-implement)
- **A2** — Multi-profile + cross-user sharing (all 22 steps done)
- **A6** — Hindi/English language toggle (gen-l10n, `.arb` files, toggle in settings)
- **B20** — Direct manual entry for glucose + BP (no camera/BLE required)
- **C4/C5/C21** — 7/30-day glucose + BP trend charts with correlation (`fl_chart`)
- **C18/C19/C20** — Health score ring, streak counter, AI insight on home screen
- **C22** — Apple Health-inspired visual theme (`AppColors` in `lib/theme/app_theme.dart`)

## Next Priorities (Bihar Pilot Blockers)
- **D7** — Abnormal value alert: when a reading is CRITICAL, notify family (safety critical)
- **D8** — WhatsApp Business API: needs Meta approval — start ASAP (2–5 day wait)
- **A6** — Language toggle already implemented; verify end-to-end on device
- **A12** — First-time onboarding screens (welcome → create profile → how to photograph → invite)
- **A9** — Offline mode: add local cache (`hive` or `sqflite`) + sync queue

## Architecture Decisions (do not change without discussion)
- Auth: email + password + JWT (no Firebase for PoC)
- DB: PostgreSQL via SQLAlchemy
- Auth dependency: `backend/dependencies.py → get_current_user`
- Shared HTTP utils: `lib/services/api_client.dart → ApiClient`
- Theme: all colors via `AppColors` in `lib/theme/app_theme.dart` — never hardcode colors
- Localization: Flutter gen-l10n — strings in `lib/l10n/app_en.arb` + `app_hi.arb`; never hardcode UI strings
- Secrets never committed — `backend/.env` is gitignored

## Code Rules
- Never copy-paste auth boilerplate — use `Depends(get_current_user)`
- All Flutter HTTP calls use `ApiClient.headers()` and `ApiClient.errorDetail()`
- No print() statements in backend — clean them up if encountered
- All colors via `AppColors.*` — never use raw `Colors.*` for semantic UI elements
- All user-facing strings via `AppLocalizations.of(context).*` — never hardcode
- Follow `TASK_TRACKER.md` for feature status before starting any new work
