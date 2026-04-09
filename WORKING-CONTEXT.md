# Swasth — Working Context (Live Sprint Board)

> **Updated:** 2026-04-09
> **Sprint:** Bihar Pilot Prep
> **Branch:** `master` (feature branches merged)
> **Base:** `master`

---

## Current Focus
Caregiver dashboard complete. Next: coverage gaps, D7 alerts, A9 offline.

## Recently Merged PRs
| # | Title | Merged |
|---|-------|--------|
| 81 | feat(ux): manage access improvements + edit relationship | 2026-04-09 |
| 80 | fix(caregiver): access API for all members + full-width care circle | 2026-04-09 |
| 79 | feat(caregiver): Phase 2 — last active, edit relationship | 2026-04-09 |
| 78 | feat(doctor): doctor portal backend | 2026-04-09 |
| 77 | feat(caregiver): care circle enhancements + Take Readings toggle | 2026-04-09 |
| 76 | feat(whatsapp): daily report scheduler | 2026-04-09 |
| 75 | feat(dashboard): caregiver Wellness Hub behind feature flag | 2026-04-09 |

## Active Constraints
- Bihar pilot launch imminent — stability over features
- Elderly users on budget Android phones — performance matters
- Hindi + English mandatory on all new UI strings
- No Firebase dependency (JWT auth only)
- **ALWAYS branch from master, deploy from master** (see CLAUDE.md deployment rules)

## Blockers
- **WhatsApp Business API** (D8) — being worked by another team member
- **Offline mode** (A9) — ~40% built, needs proper local DB

## Server Deployment
- **Frontend:** `https://65.109.226.36:8443` (Nginx + Flutter web)
- **Backend:** `http://65.109.226.36:8007` (uvicorn)
- **SSH:** `ssh -i ~/.ssh/new-server-key root@65.109.226.36`

## Test Status (2026-04-09)
- Backend: 488 tests pass, 86.23% coverage
- Flutter: 187 tests pass (82 E2E flow tests)
- Coverage gaps: routes_health.py (80%, needs 95%), routes_doctor.py (69%), routes_admin.py (68%)

## Next Up (Priority Order)
1. Fix coverage gaps (routes_health.py, routes_doctor.py)
2. D7 — Critical value alerts to family (safety critical)
3. A9 — Offline mode improvements
4. A12 — Onboarding flow
