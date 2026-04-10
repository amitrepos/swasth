# Swasth — Working Context (Live Sprint Board)

> **Updated:** 2026-04-10 (end of day)
> **Sprint:** Bihar Pilot Prep
> **Branch:** `master` (all Session A PRs merged; Session B still has branches in flight)
> **Base:** `master`

---

## Current Focus
D7 critical alerts shipped and verified at dispatch level. Email delivery blocked on Brevo sender verification (see blockers). Next session: unblock email delivery, fix local Flutter SDK, then either A9 offline mode or pilot-launch readiness.

## Recently Merged PRs
| # | Title | Merged |
|---|-------|--------|
| 105 | test(d7): manual end-to-end test script for critical alert dispatch | 2026-04-10 |
| 104 | feat: WhatsApp daily reports (Session B) | 2026-04-10 |
| 103 | feat(d7): critical alert dispatch service with email+whatsapp+sms fanout | 2026-04-10 |
| 102 | feat(patient): My Linked Doctors list with DPDPA revoke path | 2026-04-10 |
| 101 | feat(nav): wire LinkDoctor, DoctorRegistration, AdminCreateUser | 2026-04-10 |
| 100 | feat(doctor,admin): link-doctor + doctor-register + admin-create-patient | 2026-04-10 |
| 99 | feat: history fixed when connected through bluetooth | 2026-04-10 |
| 98 | test(coverage): boost routes_health 86→96% and routes_doctor 81→95% | 2026-04-10 |
| 97 | feature/fixed history | 2026-04-10 |
| 95 | feat(admin): Make Admin / Remove Admin toggle button | 2026-04-10 |
| 94 | fix(ci): use HTTPS nginx proxy URLs for frontend deploy | 2026-04-10 |
| 93 | feat(admin): Phase 1 — user management, doctor verification, audit trail | 2026-04-10 |

## Open PRs
- **Session B still has `feat/doctor-picker-and-unified-care-team` in the main working tree with uncommitted/committed changes (`fff01d1 feat(doctor): doctor picker + unified "My Doctors" section`). Not yet pushed as a PR at session close.

## Active Constraints
- Bihar pilot launch imminent — stability over features
- Elderly users on budget Android phones — performance matters
- Hindi + English mandatory on all new UI strings
- No Firebase dependency (JWT auth only)
- **ALWAYS branch from master, deploy from master** (see CLAUDE.md deployment rules)
- **Parallel sessions MUST use git worktrees** — two shared-working-tree accidents on 2026-04-10 cost ~30 min of recovery. Always `git worktree add ../swasth_session_X <branch>` before starting a parallel session.

## Blockers
- **Brevo sender email not verified** — `BREVO_SENDER_EMAIL=a6124a001@smtp-brevo.com` is Brevo's raw SMTP login address, not a real sender. Gmail silently filters messages. Fix: verify a sender address or domain at https://app.brevo.com → Senders & IPs, update `backend/.env`, restart backend. Until fixed, D7 email alerts will be queued by Brevo but not delivered to recipient inboxes. **Priority: before pilot launch.**
- **Local Flutter SDK broken** — reports version `0.0.0-unknown`. Blocks `flutter pub get` / `flutter analyze` / `flutter test` in pre-push hook. Fix: `cd $(dirname $(which flutter))/.. && git fetch --unshallow && git checkout stable` or reinstall Flutter. Until fixed, any `git push` from this machine will fail the pre-push hook's Flutter step.
- **WhatsApp Business API** (D8) — being worked by another team member (now partially unblocked via Twilio WhatsApp sandbox for D7)
- **WhatsApp sandbox opt-in expiry** — recipient must re-send `join <code>` every 24h of inactivity. Production needs a verified WhatsApp Business number instead of sandbox.
- **Offline mode** (A9) — ~40% built, needs proper local DB

## Server Deployment
- **Frontend:** `https://65.109.226.36:8443` (Nginx + Flutter web)
- **Backend:** `http://65.109.226.36:8007` (uvicorn)
- **SSH:** `ssh -i ~/.ssh/new-server-key root@65.109.226.36`
- **CI/CD:** GitHub Actions — DEV auto-deploys on master push, PROD via manual trigger
- **Deploy key:** `~/.ssh/swasth-deploy` (RSA 4096, added to GitHub secret `SSH_PRIVATE_KEY` via `gh secret set`)
- **D7 requires server-side env vars:** `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_WHATSAPP_NUMBER`, `BREVO_SMTP_LOGIN`, `BREVO_SMTP_PASSWORD` — verify these are loaded on Hetzner before relying on the feature in production
- **D7 requires a new migration on server:** `critical_alert_logs` table. `Base.metadata.create_all` will create it on next restart, or run manually: `python3 -c "from database import Base, engine; import models; Base.metadata.create_all(bind=engine)"`
- **Local DB schema drift:** 8 columns had to be ALTER-added on local Postgres to match the ORM models (users.role/timezone, profiles.weight, health_readings.spo2_*/steps_*/seq). Team members with fresh DBs are fine; team members with older local DBs may need the same ALTERs.

## Test Status (2026-04-10)
- Backend: **614 tests pass**
- Coverage: **routes_health.py 96%**, **routes_doctor.py 95%** (both Tier targets exceeded)
- Other coverage: routes_admin.py 93%, overall ~92%
- Flutter: 187 tests pass (82 E2E flow tests)
- D7 specific: 29 new tests in `test_alert_service.py` covering full fanout, dedupe, kill switch, SMS stub

## Manual tests available
- `backend/test_whatsapp_report.py` — daily WhatsApp reports (existing)
- `backend/test_critical_alerts.py` — D7 critical alerts live end-to-end (new this session). Usage: `python test_critical_alerts.py <email> <phone>`. Reuses existing user if email matches, creates throwaway test rows, dispatches via real Twilio+Brevo, cleans up on exit.

## Legal items deferred (see docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md section 11)
9 open questions for lawyer review before pilot launch:
- Q11.1: Implicit vs explicit emergency-contact consent under DPDPA
- Q11.2: Cross-border WhatsApp data transfer (Meta servers)
- Q11.3: Data minimization in alert body (name + value vs. generic)
- Q11.4: Rate-limit dedupe window vs medical liability
- Q11.5: Multilingual requirements for safety-critical notifications
- Q11.6: Delivery failure liability and patient disclosure
- Q11.7: Clinical threshold provenance (NMC telemedicine)
- Q11.8: Minor / guardian / adult family proxy notification
- Q11.9: CriticalAlertLog retention rules and PHI classification

## Next Session — Priority Order
1. **Unblock Brevo email delivery** — verify sender address or domain in Brevo dashboard, update `BREVO_SENDER_EMAIL` in `.env` (local + server), re-run `test_critical_alerts.py` to confirm Gmail inbox delivery
2. **Fix local Flutter SDK** — so pre-push hook stops blocking pushes
3. **Deploy D7 to Hetzner** — scp the new files (`alert_service.py`, `sms_service.py`, updated `models.py`/`routes_health.py`/`email_service.py`/`twilio_service.py`/`config.py`), run `Base.metadata.create_all`, restart backend, verify `TWILIO_*` + `BREVO_*` env vars loaded, smoke-test with real reading
4. **Lawyer review** of section 11 questions before pilot launch
5. **A9 — Offline mode** improvements (deferred from this session)
6. **WhatsApp Business production number** — graduate from Twilio sandbox to verified business number for pilot
7. **Generate proper DB migration** for the ORM changes (CriticalAlertLog + the 8 schema-drift columns) — Alembic or similar, so team members don't hit `column does not exist` errors on pull
