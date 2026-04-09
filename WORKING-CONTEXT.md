# Swasth — Working Context (Live Sprint Board)

> **Updated:** 2026-04-09 (end of day)
> **Sprint:** Bihar Pilot Prep
> **Branch:** `master` (all PRs merged)
> **Base:** `master`

---

## Current Focus
CI/CD pipeline fully operational. DEV + PROD auto-deploy working. All caregiver + doctor features merged. Next session: coverage gaps, then D7 alerts.

## Recently Merged PRs
| # | Title | Merged |
|---|-------|--------|
| 88 | fix(auth): route doctors to triage screen on login | 2026-04-09 |
| 87 | fix(ci): correct deploy action versions (ssh v1.2.5, scp v1.0.0) | 2026-04-09 |
| 86 | fix(ci): upgrade ssh/scp actions for Ed25519 key support | 2026-04-09 |
| 85 | test(coverage): boost backend coverage 86% → 89% | 2026-04-09 |
| 84 | fix(profile): add logout button to profile selector | 2026-04-09 |
| 82 | feat(doctor): doctor portal Flutter screens (triage + detail) | 2026-04-09 |
| 81 | feat(ux): manage access improvements + edit relationship | 2026-04-09 |
| 80 | fix(caregiver): access API for all members + full-width care circle | 2026-04-09 |
| 79 | feat(caregiver): Phase 2 — last active, edit relationship | 2026-04-09 |
| 78 | feat(doctor): doctor portal backend — models, routes, triage, notes | 2026-04-09 |
| 77 | feat(caregiver): care circle enhancements + Take Readings toggle | 2026-04-09 |

## Open PRs
None — all merged.

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
- **CI/CD:** GitHub Actions — DEV auto-deploys on master push, PROD via manual trigger
- **Deploy key:** `~/.ssh/swasth-deploy` (RSA 4096, added to GitHub secret `SSH_PRIVATE_KEY` via `gh secret set`)

## Test Status (2026-04-09)
- Backend: 488 tests pass, 89% coverage
- Flutter: 187 tests pass (82 E2E flow tests)
- Coverage gaps: routes_health.py (86%, needs 95%), routes_doctor.py (69%), routes_admin.py (93%)

## Tomorrow (2026-04-10) — Priority Order
1. **Coverage gaps** — routes_health.py 86% → 95% (Tier 1), routes_doctor.py 69% → 85% (Tier 3)
2. **Patient "Link Doctor" UI** — button to enter doctor code + consent screen
3. **Triage cache refresh** — recompute triage on new reading in routes_health.py
4. **Doctor registration screen** — Flutter UI for doctor signup (currently API-only)
5. **D7 — Critical value alerts** to family (safety critical P0)
6. **A9 — Offline mode** improvements
