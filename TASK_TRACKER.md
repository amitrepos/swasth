# Swasth App — Phase 1 Task Tracker

**Last Updated:** 2026-04-11
**Sprint:** 4 weeks + buffer | **Target:** Bihar pilot

Legend: ✅ Done &nbsp;|&nbsp; 🔄 Partial &nbsp;|&nbsp; ❌ Not started

---

## Pre-release blocker — replace self-signed TLS cert on pilot backend

**Backend at `65.109.226.36:8443` currently uses a self-signed certificate.** Browsers let users click past the warning, but `dart:io` on Android/iOS hard-rejects with `CERTIFICATE_VERIFY_FAILED: self signed certificate`, breaking every API call from native mobile builds.

**Temporary workaround (2026-04-11):** `lib/main.dart` installs a `_PilotHttpOverrides` class that trusts self-signed certs **only** for host `65.109.226.36` (other hosts still use normal TLS trust chain, web builds unaffected via `kIsWeb` guard). This unblocks the APK for pilot device testing.

**Must remove before public release:**
1. Point a real domain at the backend (or the server's IP if Let's Encrypt allows — it doesn't; needs a domain).
2. Provision a Let's Encrypt cert via certbot on the server.
3. Update nginx / uvicorn TLS config to use the real cert.
4. Delete `_PilotHttpOverrides` from `lib/main.dart` and its `HttpOverrides.global` install in `main()`.
5. Delete the `dart:io` imports that became unused.
6. Rebuild APK and verify handshake succeeds without the override.

**Why this is a hard blocker:** Shipping a cert-bypass in a public release means anyone on the patient's Wi-Fi can MITM every API call (tokens, health data, meal logs). It's scoped to one IP today, but "pilot-only" code has a way of surviving into GA if it's not tracked.

---

## Known data issue — pilot meals logged before 2026-04-11

**Meals logged before the slot-tap fix (PR landing 2026-04-11) may have the wrong `meal_type` in the database.** `quick_select_screen.dart` was hardcoding `mealType: detectMealType()` (wall-clock time), so any patient who tapped a specific slot ("Breakfast" / "Lunch" / "Snack" / "Dinner") had their saved `meal_type` overwritten with whatever slot the current hour matched. Fix plumbs the tapped slot type through `MealSummaryCard → home_screen → modal → QuickSelectScreen`.

**Impact**: anyone running `SELECT meal_type, count(*) FROM meal_logs GROUP BY meal_type` on pilot data will see a skew. If you need clean aggregate analytics on historical pilot data, EXCLUDE meals logged before the PR landed OR recompute `meal_type` from `created_at` using the old time-based rule for the pre-fix window only.

**Not backfilling**: per Dr. Rajesh's review, rewriting history has its own integrity risks (a patient's 4pm Breakfast would get relabelled to Snack if we retroactively ran the old rule, which is MORE wrong than leaving it alone). Small pilot N, no clinical decisions yet ride on historical `meal_type`. Revisit if/when pilot volume grows.

---

## Task E17 — PII Encryption at Rest (DPDPA-gap)

**Priority:** HIGH &nbsp;|&nbsp; **Status:** ✅ DONE — merged to master via **PR #165** (2026-04-24). Migration `0007_pii_encryption_batch.py` batches E17 + E4 (OTP hash) + DoctorProfile contact cols + DoctorPatientLink.is_primary; encrypts `users` (email/full_name/phone), `profiles` (name, relationship, gender, age, height, blood_group, medical_conditions, other_medical_condition, current_medications, doctor_name/specialty/whatsapp, phone), `profile_invites` (invited_email, relationship), `password_reset_otps` + `email_verification_otps` + `phone_otps` (email/phone + OTP hashed), `doctor_profiles` (nmc_number, phone, whatsapp). Dual-key split: `ENCRYPTION_KEY` (SPDI) + `PII_ENCRYPTION_KEY` (PII) in `backend/encryption_service.py`. Runbook: `docs/runbooks/PII_ENCRYPTION_BATCH.md`. &nbsp;|&nbsp; **Owner:** Amit &nbsp;|&nbsp; **Opened:** 2026-04-23 &nbsp;|&nbsp; **Completed:** 2026-04-24. &nbsp;|&nbsp; **Remaining:** verify `PII_ENCRYPTION_KEY` is set on India server after P1 (server migration).

### Why this exists
Current encryption at rest covers **SPDI (health values only)** — AES-256-GCM on glucose/BP/SpO2/weight/notes via `backend/encryption_service.py`, wired in `routes_health.py:100-112` and `routes_profiles.py:112`. **Patient PII is still plaintext** in Postgres. Under DPDPA 2023 a name + phone + email + DOB of a patient is "personal data" and, combined with health readings, "sensitive personal data." A DB dump, backup leak, or compromised read-replica today exposes identifiable patient records. This is the single biggest compliance gap before Play Store Production / doctor portal / NRI paid rollout.

### Exact gap (audit on master @ 538f4c7, 2026-04-23)

**User table** (`backend/models.py:19-22`) — plaintext:
- `email`, `full_name`, `phone_number`
  (password_hash is hashed — fine, do not touch.)

**Profile table** (`backend/models.py:44-56`) — plaintext:
- `name`, `relationship`, `gender`, `age`, `height`, `blood_group`
- `medical_conditions` (ARRAY), `other_medical_condition`, `current_medications`
- `doctor_name`, `doctor_specialty`, `doctor_whatsapp`

**ProfileInvite table** (`backend/models.py:84,86`) — plaintext:
- `invited_email`, `relationship`

**OTP / phone verification table** (check `backend/models.py` verification model) — plaintext phone number stored alongside OTP.

**DoctorProfile table** (`backend/models.py:293-307`) — verify in implementation: doctor full name, registration number, specialty. Doctor PII also falls under DPDPA.

### Scope of this task

**In scope:**
1. Add `_enc` columns (Text, nullable) for every PII field listed above.
2. Dual-write on every INSERT / UPDATE path that touches these fields (registration, login flows that update `last_login_at`, profile create/update, invite creation, doctor registration).
3. Backfill script that iterates existing rows, encrypts current plaintext, writes into `_enc` columns. Idempotent, resumable, dry-run flag. Model after `backend/migrate_encrypt_readings.py`.
4. Read-path: update every SELECT site to prefer `_enc` → decrypt → fallback to plaintext column while backfill is in flight. After backfill completes and soak passes, flip the fallback off behind a feature flag.
5. Drop plaintext columns in a second Alembic migration once soak + monitoring confirms zero fallback reads for N days (N = 7 recommended).
6. Blind-index (HMAC-SHA256 with a separate key) for **email** and **phone_number** so `/api/auth/login` lookup by email and OTP lookup by phone still work without decrypting every row. Store `email_hash` / `phone_hash` columns, indexed. Login flow: HMAC the supplied email/phone → lookup by hash → decrypt the row → proceed.
7. Unit tests for every encrypt/decrypt round-trip + integration tests for login, register, profile CRUD, invite accept, doctor register with encryption ON and with the key missing (graceful fail).
8. Key management: `ENCRYPTION_KEY` already exists for health data — **generate a separate `PII_ENCRYPTION_KEY`** so PII and SPDI have independent blast radii (compromise of one does not compromise the other). Both 32-byte hex. Update `backend/encryption_service.py` to accept a key parameter or split into `encrypt_spdi` / `encrypt_pii`.
9. Update `docs/specs/07-SECURITY-AND-COMPLIANCE.md` + `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` with the new control.

**Out of scope (track separately):**
- KMS / HashiCorp Vault integration — stays on env vars for pilot, KMS is a separate task pre-Production-release.
- Field-level access logging (audit trail of who decrypted which record). Ties into DISHA readiness.
- Re-encryption / key rotation tooling. Separate task.

### Implementation plan (6 PRs, small & reviewable)

**PR 1 — encryption_service split + PII key wiring (~0.5 day)**
- Add `PII_ENCRYPTION_KEY` to `config.py` / `Settings`, `.env.example`, deployment secret.
- Refactor `encryption_service.py` to parameterize the key, or add `encrypt_pii()` / `decrypt_pii()` wrappers that use the PII key. Keep `encrypt()` / `encrypt_float()` pointing at `ENCRYPTION_KEY` for SPDI.
- Unit tests: round-trip, wrong-key → None, missing-key → None, tamper → None (InvalidTag).
- Required experts: **Security**, **PHI**, Daniel.

**PR 2 — add `_enc` + `_hash` columns (Alembic migration, NOT YET used) (~0.5 day)**
- Alembic migration `0005_pii_encryption_columns.py`: ADD COLUMN for every `_enc` (Text nullable) + `email_hash` / `phone_hash` (String indexed).
- Update `models.py` with the new columns.
- Must hit CI `migration-check.yml` green.
- Required experts: **Legal**, **PHI**, **Priya**, Daniel.

**PR 3 — dual-write on all INSERT / UPDATE paths (~1 day)**
- `routes.py` (register), `routes_profiles.py` (profile CRUD), `routes.py` (OTP flows), invite endpoints, doctor registration.
- Every write: set the plaintext column AND the `_enc` column AND the hash column if applicable.
- Integration test matrix: register → DB row has both plaintext + enc populated + hash populated; profile update → enc re-encrypted with new value; invite create → invited_email_enc + invited_email_hash set.
- Do NOT yet change read paths. Dual-write only.
- Required experts: **Legal**, **PHI**, **Priya**, **Security**, Daniel.

**PR 4 — backfill script + runbook (~0.5 day)**
- `backend/migrate_encrypt_pii.py` modelled on `migrate_encrypt_readings.py`. Flags: `--dry-run`, `--batch-size`, `--table`, `--resume-from-id`.
- Idempotent: skip rows where `_enc IS NOT NULL` unless `--force`.
- Runbook in `docs/runbooks/PII_ENCRYPTION_BACKFILL.md`: dev → pre-prod → prod sequence, rollback steps (just truncate the `_enc` columns, plaintext is still the source of truth).
- SSH to `65.109.226.36`, run against both `swasth_db` (dev, port 8007) and `swasth_prod` (port 8009) per the topology in the REL-PROD section above.
- Required experts: **PHI**, **Priya**, Daniel.

**PR 5 — flip read paths to `_enc` with plaintext fallback (~1 day)**
- `backend/auth.py` (login), `routes.py` (me, user detail), `routes_profiles.py` (list/get profiles), invite acceptance, doctor login/list.
- Login flow specifically: `SELECT * FROM users WHERE email_hash = HMAC(input_email)` → decrypt the row → check password. Falls back to the old `WHERE email = plaintext` path only if `email_hash IS NULL` (pre-backfill rows — should be zero after PR 4).
- Add `PII_FALLBACK_READ_METRIC` counter that increments every time the plaintext fallback fires. Scrape it for N days. Success = counter stays at 0.
- Required experts: **Security**, **Legal**, **PHI**, **Priya**, Daniel.

**PR 6 — drop plaintext columns (~0.5 day, AFTER 7-day soak with zero fallbacks)**
- Alembic migration `0006_drop_plaintext_pii.py`: DROP COLUMN for every plaintext PII column replaced by `_enc`.
- Delete fallback branches in read paths.
- Required experts: **Legal**, **PHI**, **Priya**, Daniel.

### Acceptance criteria

- [ ] `psql -c "SELECT email, full_name, phone_number FROM users LIMIT 1"` returns ciphertext (or the column no longer exists after PR 6).
- [ ] `psql -c "SELECT name, doctor_whatsapp, medical_conditions FROM profiles LIMIT 1"` returns ciphertext (or columns dropped).
- [ ] Login with correct credentials works in < 500ms against a DB with 10k users (hash index verified).
- [ ] `/api/auth/login` with wrong email returns 401 (not 500) — lookup by hash must not crash on unknown input.
- [ ] Startup fails fast with clear error if `PII_ENCRYPTION_KEY` is missing in production (`ENVIRONMENT=prod`).
- [ ] Key rotation path documented even if not automated (manual re-encrypt script sketched in runbook).
- [ ] Backend test coverage on `auth.py`, `routes_profiles.py`, `encryption_service.py` stays ≥ Tier-2 target (90%).
- [ ] All existing E2E flow tests pass unchanged (Flutter client is agnostic — it always sees plaintext in JSON responses).
- [ ] Meera (`/reality-check`), PHI (`/phi-compliance`), Legal (`/legal-check`), Security (`/security-audit`), Daniel (`/daniel-review`) — all PASS on each of the 6 PRs.

### Deployment sequence (per PR)

1. Merge to master → GitHub Actions runs `migration-check.yml` + test suite.
2. Dev server (`:8443`, DB `swasth_db`): CI auto-deploys backend, `alembic upgrade head` runs automatically per PR #111.
3. Manual backfill run on dev first (PR 4): `ssh … "cd /var/www/swasth/backend && source venv/bin/activate && python migrate_encrypt_pii.py --dry-run"` then without dry-run.
4. Soak on dev for 48h minimum — watch `PII_FALLBACK_READ_METRIC` + smoke the app.
5. Repeat for prod (`:8444`, DB `swasth_prod`).
6. Observe for 7 days before PR 6 (drop plaintext).

### Rollback

- PRs 1, 2, 3, 4: safe — plaintext is still source of truth, `_enc` is additive.
- PR 5: rollback = revert the PR; fallback path is still there until the soak passes.
- PR 6: irreversible once plaintext columns dropped. **Only merge after explicit Amit sign-off + prod DB backup verified restorable.**

### Risks / things the implementer must NOT get wrong

1. **Login latency** — without a hash index on `email`, every login becomes O(N) full-table-scan decrypt. Hash column + btree index is mandatory.
2. **Case sensitivity** — hash the lowercased+trimmed email, not the raw input. Otherwise `Amit@x.com` and `amit@x.com` register twice.
3. **Phone format** — normalize to E.164 before hashing (`+917001234567`). Mismatched country-code padding will split the same user into two hash buckets.
4. **medical_conditions ARRAY** — cryptography operates on strings. Pattern: JSON-encode the array → encrypt the JSON string → store in a Text `_enc`. Do NOT try to encrypt element-by-element.
5. **password_hash DOES NOT get encrypted** — it's already a one-way hash. Re-encrypting would break login. Leave it.
6. **Do NOT encrypt foreign keys** (`user_id`, `profile_id`) or timestamps. Only PII.
7. **OTP column** (plaintext OTP, `models.py` verification) — separate pre-existing gap E4 in Module E table. Do NOT conflate. OTP gets hashed (E4), PII gets encrypted (this task). Different primitives.
8. **Key material in logs** — ensure `encryption_service.py` never logs the key, the plaintext, or the token in cleartext. Existing service already does this; preserve.
9. **.env discipline** — `PII_ENCRYPTION_KEY` goes in deployment secrets via `gh secret set` per memory rule on GitHub Secrets. Never committed.

### References

- `backend/encryption_service.py` — existing SPDI encryption implementation, pattern to extend.
- `backend/migrate_encrypt_readings.py` — existing backfill script, pattern to extend for PII.
- `backend/models.py:17-34` (User), `:40-58` (Profile), `:77-89` (ProfileInvite), `:293-307` (DoctorProfile).
- `backend/routes.py` (register / login / OTP), `backend/routes_profiles.py`, `backend/auth.py`.
- `docs/specs/07-SECURITY-AND-COMPLIANCE.md` — update after PR 6.
- `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` — update after PR 6.
- DPDPA 2023, §§ 8–10 (security safeguards), § 8(5) (breach notification — raises the bar if breach IS notifiable, encryption reduces the blast radius).
- NIST SP 800-38D (AES-GCM) — already followed by existing service.

---

## Session Log — 2026-04-11

### Shipped today
- **PR #111** ✅ merged — `fix(ci): hard-reset deploy target + auto-run migrations`. Replaces silently-failing `git pull` with `git fetch + git reset --hard`, adds `set -e`, auto-runs migrations, applies to both dev.yml and prod.yml.
- **PR #112** ✅ merged — `fix(doctor,history,admin): bug fixes + end-to-end integration tests`. Fixes History empty-state error snackbar, Admin Overview blank KPIs, and doctor directory picker "verification pending" regression. Adds 16 new backend integration tests (`test_doctor_integration.py` + `test_patient_flows_integration.py`) covering doctor happy-path, decline/withdraw, directory filtering, meal logging roundtrip, health score seeded + empty, multi-profile scoping, account deletion cascade, history pagination/filter. Backend at 653 tests, 88% coverage.
- **PR #113** ✅ merged — `chore(hooks): recover review-chain infrastructure + install 4 branch-hygiene gates`. Recovers 4 orphaned hook commits from `fix/admin-toggle-button` (the 2026-04-10 incident where PR #95 shipped but 4 follow-up commits stayed local-only). Adds: `.githooks/pre-commit` (merged-PR block + domain expert review chain), `.githooks/pre-push` (no-open-PR block, reads stdin per githooks(5)), `.claude/scripts/orphan-scan.sh` (SessionStart warning, single gh call + jq filter), `.github/workflows/branch-hygiene.yml` (CI mirror). New skills: `aditya`, `sunita`, marker-writing instructions on `daniel-review`/`doctor-feedback`/`legal-check`/`phi-compliance`/`security-audit`/`qa-review`/`ship`. Updated CLAUDE.md Branch Hygiene section and Domain Expert Review Matrix.
- **PR #114** ✅ merged — `fix(ci): move venv activation after cd backend in deploy workflows`. Root-caused why PR #111 and #112 deploys showed green on GitHub but the backend process never restarted: `source venv/bin/activate` ran with cwd `/var/www/swasth` but the venv is at `backend/venv`. Silent before `set -e`, hard fail after. Two-line fix in both workflows. Also manually restarted `pm2 swasth-backend` on dev server (PID 3677756) so PR #112 code took effect before the CI fix itself could ship.

### Orphan branches cleaned up
Ran `orphan-scan.sh` which detected 7 stale local branches with commits whose content was already on master via different SHAs (admin Phase 1 duplicates, care-circle duplicates, admin button duplicates, etc.). All 9 local branches deleted after per-SHA forensic verification: `fix/admin-toggle-button`, `fix/doctor-triage-ux-v1`, `feat/doctor-triage-reason`, `feature/doctor-portal-backend`, `feat/link-doctor-and-admin-create-user`, `feature/admin-user-management-phase1`, `feature/doctor-portal-frontend`, `chore/review-hooks-recovery-and-guardrails`, `fix/doctor-flow-bugs`. Orphan scan is now silent at session start.

### Paused / open work — RESUME FROM HERE

**1. Unified history timeline (meals + glucose) — Stage 1 of meal-correlation feature**

- **Status**: ✅ Shipped 2026-04-11 as PR `feat/meals-history-and-caregiver-dashboard`. History screen renders meals interleaved with BP/glucose readings sorted desc, with a "Meals Only" filter, color-blind-safe carb-load pills (icon + text + neutral palette), and a disclaimer banner at the top of the list when meals are visible. Caregiver dashboard now shows today's meals (read-only — caregivers must use the act-as-patient toggle to log) and meals appear in the activity feed alongside readings. New `dashboard_caregiver_*` widget invariant test mirrors the owner test from PR #115. Reviewed by Sunita, Aditya, Dr. Rajesh, Priya, Daniel — all PASS after one round of fixes (Dr. Rajesh: rename `glucoseImpactX` → `mealCarbLoadX` and drop `statusCritical` red because "impact" is causal language and red equates meals with abnormal vitals; Aditya: add color-blind icons + Semantics labels + caregiver discoverability hint; Sunita: neutralize Hindi wording — "मीठा भोजन" not "बहुत अधिक प्रभाव").
- **Follow-ups deferred** (track separately, not blocking pilot):
  - **Localize raw English meal categories**: backend stores categories as English strings (`rice_curry`, `roti_dal`, etc.). Currently displayed verbatim with underscores replaced. ~50 category strings need l10n keys + Hindi translations. Sunita explicitly flagged this as her remaining grievance.
  - **Naming consistency**: `history_screen.dart` uses `_carbLoadColor` / `_localizedCarbLoad` / `_carbLoadIcon` (post-rename), but `activity_feed_card.dart::_ActivityMealItem` kept the old `_impactColor` name. Behaviour identical, palette rule preserved. Align in a follow-up.
  - **Pre-existing UX polish (Aditya)**: meal slot label `fontSize: 7` in `meal_summary_card.dart` is below any reasonable accessibility floor — not introduced by this PR but worth fixing before pilot. Activity feed timestamp at 11sp is also below the 12sp floor.
  - **Stage 2** (rule-based summary, requires `/legal-check` + `/doctor-feedback`): introduce post-meal glucose comparison with explicit clinical-claim language reviewed by NMC-savvy advisor.
  - **Stage 3** (AI insight text, requires `/legal-check` + `/doctor-feedback`): natural-language correlation summary; clinical claim, full Stage 3 review.
  - **Test gaps** (Priya should-fix): filter toggle round-trip ("Meals Only" → "All"), `userCorrectedCategory` display, caregiver `editor` access level path, midnight-boundary mock timestamp robustness, scroll behaviour with 20+ readings + 20+ meals.

**2. Dashboard doctor section — migration from legacy `profile.doctor_name` to `DoctorPatientLink`**

- **Status**: ✅ Shipped 2026-04-11 as PR `fix/dashboard-doctor-section-and-widget-invariant`. New `LinkedDoctorsCard` widget (always renders: filled / pending / empty-state CTA), `_loadLinkedDoctors` wired into `home_screen.dart`, both render sites updated, regression test `dashboard_widgets_present_test.dart` enforces the widget invariant via stable `Key('dashboard_*')` keys for both full-data and empty-data scenarios. Reviewed by Sunita, Aditya, Dr. Rajesh, Priya, Daniel — all PASS after one Aditya iteration on accessibility (CTA tap target, status icons, font sizes).
- **Follow-ups deferred** (track separately, not blocking pilot):
  - **Schema-level "primary doctor" enforcement (Option B)**: today "primary" is a convention — most-recently-linked active row wins. When users start accumulating multiple active links, add `is_primary` boolean to `DoctorPatientLink` + uniqueness constraint `at_most_one_is_primary_per_profile_id` + auto-demote-old-primary on new link. Required before the dashboard card becomes the routing target for "message my doctor" / alert delivery (clinical risk: wrong doctor receives the patient's contact attempt).
  - **Caregivers card**: when 2+ active doctors are linked, surface the non-primary ones as caregivers in a separate card. Currently `_pickPrimary` returns one and the rest are silently dropped from the dashboard.
  - **Caregiver dashboard widget invariant test**: mirror `dashboard_widgets_present_test.dart` for the `access_level: 'caregiver'` render path (different widget set: `ActivityFeedCard`, `CareCircleCard`). Without it the same class of regression could land on the caregiver dashboard undetected.
  - **`LinkedDoctorsCard` typed model**: `List<Map<String, dynamic>>` is fragile; introduce a `LinkedDoctor` model class.
  - **`_loadLinkedDoctors` retry affordance**: today swallows errors silently (graceful degradation to empty state). For persistent backend 500s, consider a "Tap to retry" affordance with a `_linkedDoctorsLoadFailed` flag.
  - **Pending-only scenario in widget invariant test**: add a third scenario where the only linked doctor is `status='pending_doctor_accept'`; the test should verify the amber pending badge renders.

**3. Legacy doctor fields on `profiles` table — tech-debt note (NOT P0)**

- **Status**: Investigated 2026-04-11. Documented, deliberately not fixing. Doesn't block any current pilot functionality. User decision: live with it, revisit when it actually blocks something.
- **What exists**: Two completely disconnected "doctor" systems in the codebase.
  - **LEGACY**: `profiles.doctor_name`, `profiles.doctor_specialty`, `profiles.doctor_whatsapp` — free-text columns the user types into the "Edit Doctor Details" form on `profile_screen.dart`. No verification, no consent, no doctor side.
  - **NEW (NMC-compliant)**: `DoctorPatientLink` table — populated via Link-a-Doctor flow with `doctor_code` lookup, doctor acceptance, `status='active'`. Read by `LinkedDoctorsCard` (PR #115).
- **The data model blocker**: `DoctorProfile` table at `backend/models.py:293-307` has no `phone_number` / `whatsapp_number` column. Doctor registration doesn't collect contact info. So the new system literally cannot make a phone call — `list_linked_doctors` has nothing to return. This means we CANNOT fully migrate "Priority Call" / WhatsApp / `_callDoctor` flows off the legacy field until we add doctor contact data.
- **Current visible symptom**: Dashboard "Priority Call" button (`home_screen.dart:679-716`) and the urgent-state "Call Doctor" button inside `HealthScoreRing` (`health_score_ring.dart:282`) only render if the user has typed a phone number into the legacy form. Pratika linked Dr. Omisha via the new consent flow but never typed a number into the legacy form, so neither button appears for her. Workaround: the patient types Dr. Omisha's WhatsApp into the "Edit Doctor Details" form on their profile screen.
- **Surface area if we ever migrate**:
  - **Backend (7 files)**: `models.py:52-54` (the columns), `schemas.py:234,275,311` (3 schemas), `routes_profiles.py:38,118` (build/update), `routes_admin.py:357` (admin export), `seed_demo_data.py`, doctor route tests.
  - **Flutter (9 files, 5 duplicate guard sites)**: `profile_model.dart:12-14`, `profile_screen.dart:48-49,720-740,883-933` (form + display), `home_screen.dart:458,541,679,744,789` (5 separate `_activeProfile?.doctorWhatsapp?.isNotEmpty` guards — should consolidate to one `_primaryDoctorPhone` getter when migrating), `physician_card.dart:21,53-72`, `health_score_ring.dart:21,282`, 3 l10n files.
  - **`profile_model.dart:66`**: `toJson()` does NOT serialize the doctor fields back — possible latent bug for profile updates round-tripping these fields. Worth checking when we touch this code next.
- **3-PR migration plan when it becomes P0** (Option C — hybrid):
  - **PR 1 (1 day)**: Add `whatsapp_number` (and optionally `phone_number`) to `DoctorProfile` + Alembic migration + doctor registration form (Flutter + backend). Extend `list_linked_doctors` response to return the new field. Required experts: Legal (NMC + DPDPA on doctor PII), PHI, Daniel.
  - **PR 2 (~2 hours)**: Add a single `String? get _primaryDoctorPhone` derived getter on `_HomeScreenState` that prefers the linked-doctor phone, falls back to legacy. Replace all 5 guard sites and all 5 `_callDoctor(_activeProfile!.doctorWhatsapp!)` calls with the getter. Pratika's Priority Call works.
  - **PR 3 (later, optional)**: Hide the "Edit Doctor Details" form for new profiles, show read-only legacy data + "Re-link via Doctor Code" CTA for existing legacy users, eventually drop the columns once the at-risk count is 0.
- **SQL queries to run on the dev DB when we want concrete numbers** (counts of legacy-only profiles, profiles with both, etc.) — captured in the 2026-04-11 Explore agent's report; rerun the agent or grep for "doctor_name IS NOT NULL" if needed.
- **Why this is not P0**: pilot users so far enter doctor details via the legacy form (it's the documented path), so Priority Call works for them. The bug only surfaces for users who use the *new* Link-a-Doctor flow without also typing into the legacy form — currently a small overlap. PR #115 fixed the silent-disappearance bug on the dashboard's primary card, which was the user-visible regression.

**Original investigation (kept for context):**
- **Status**: Bug diagnosed, code gap identified, fix approach sketched, waiting on one design decision from user.
- **Bug report**: Pratika logs in as `pratika@gmail.com` (user id in DB: has profile 44 "Pratika" as own, profile 2 "My Health" as shared-with-her). On her own profile (44) she confirmed Omisha (doctor_code `DROMI19`, status `active`). Dashboard shows no doctor section at all. On shared profile 2 she correctly sees "Dr Vishal" (profile-owner's legacy free-text value). The shared profile rendering is correct — user clarified it and asked us not to focus on it.
- **DB verified**: `SELECT` on `doctor_patient_links` joined via `profile_access` confirms profile 44 is linked to `DROMI19` with `status=active, is_active=true`. Profile 2 has `doctor_name="Dr Vishal"` legacy field AND two linked doctors (`DRDRR18`, `DRAMI35`) which are currently invisible on dashboard.
- **Root cause — exact code locations**:
  - `lib/screens/home_screen.dart:484` and `:711` — both `PhysicianCard` render sites are guarded by `if (_activeProfile?.doctorName?.isNotEmpty == true)`. `doctorName` is the legacy free-text column on `profiles` table, not the new `doctor_patient_links` join. When the new Link-a-Doctor flow creates a row in `doctor_patient_links` it does NOT populate `profiles.doctor_name` — the two systems are disconnected.
  - `lib/widgets/home/physician_card.dart:9`, `:21`, `:53`, `:60` — the widget takes `ProfileModel profile` and reads `profile.doctorName` / `profile.doctorWhatsapp` / `profile.doctorSpecialty` directly. Has no field for a list of linked doctors from the DoctorPatientLink system. Architecturally it is "one profile owns one free-text doctor".
  - `home_screen.dart` does not import `DoctorService` anywhere. No code path on the dashboard calls `getLinkedDoctors(token, profileId)`, even though that method exists on `lib/services/doctor_service.dart:289` and is used by `my_linked_doctors_screen.dart`.
  - No `else` branch for empty state — when the guard fails the widget tree simply omits the section (no heading, no card, no CTA).
- **Fix approach (sketched for user approval, NOT implemented)**:
  1. Add `List<Map<String,dynamic>> _linkedDoctors = []` + `_loadLinkedDoctors()` state to `home_screen.dart`, wired into the same lifecycle as `_loadAccessLevel`/`_loadReadings` (fires on profile change via `didUpdateWidget`).
  2. Leave `PhysicianCard` alone for backward compatibility with profiles that still use the legacy free-text path (e.g. shared profile 2 "Dr Vishal"). Build a NEW `LinkedDoctorsCard` widget that renders the DoctorPatientLink data.
  3. Dashboard chooses: if `_linkedDoctors.isNotEmpty` → render `LinkedDoctorsCard`; else if `profile.doctorName?.isNotEmpty` → render existing `PhysicianCard`; else → render an **always-visible empty state** card with "PRIMARY PHYSICIAN / No doctor linked yet / [Link a doctor →]" CTA that deep-links to `link_doctor_screen.dart`. This satisfies the user's request that the section be visible even when blank.
- **Open design question (needs user answer before coding)**: should dashboard show ALL linked doctors for the active profile (profile could have 3–4 over time), or just the most-recent / primary one with a subtle "+N more" expander? User has the pilot context to decide. My instinct leans toward "most-recent active as primary card, tap to expand list".
- **Expected review chain on commit**: Sunita + Aditya + Dr. Rajesh + Daniel (new widget + screen edit under `lib/screens/` and `lib/widgets/home/`), plus Priya (new widget test + flow test).

---

## MODULE A — Core Architecture + Auth + Profiles

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| A1 | Phone OTP login | 🔄 Partial | Email + password + JWT only. Phone number collected at registration but unused for auth. OTP used only for password reset. No Firebase phone OTP. |
| A2 | Multi-profile data model | ✅ Done | Full backend: profiles, profile_access, profile_invites tables. All 22 steps complete. |
| A3 | Profile creation | ✅ Done | `create_profile_screen.dart` — name, age, gender, height, weight, blood group, conditions, medications. Weight added 2026-04-03. |
| A4 | Medication list | ✅ Done | Current medications text field in profile creation + edit. |
| A5 | "Add person without smartphone" | ✅ Done | Create profile for someone else → caller becomes "owner". `create_profile_screen.dart`. |
| A6 | Language toggle (Hindi / English) | ✅ Done | Full gen-l10n: `app_en.arb` + `app_hi.arb`, all UI strings via `AppLocalizations`. Toggle chip in Profile → Settings section. Language persisted via `languageProvider` (Riverpod). |
| A7 | Profile switcher | ✅ Done | `select_profile_screen.dart` — lists all accessible profiles, tap to switch active profile. |
| A8 | Cloud sync | 🔄 Partial | PostgreSQL + FastAPI (cloud-deployable). Offline sync queue for readings. |
| A9 | Local offline storage | ❌ Not started | Rolled back 2026-03-31. Hive caching was implemented but reverted to stabilize app for testing. Deferred to post-pilot. |
| A10 | Invite family via WhatsApp | 🔄 Partial | Email-based invite works with relationship dropdown (father/mother/spouse/etc.). No WhatsApp deep link or share-to-install flow. |
| A11 | Access permissions | ✅ Done | owner / viewer / editor levels via `profile_access` table. `dependencies.py` enforces access. |
| A12 | First-time onboarding | ❌ Deferred | Replaced with YouTube tutorial video link. App is self-intuitive. Add "How to use" link on empty state that opens YouTube video. No in-app onboarding screens needed. |
| A13 | Remember me / saved credentials | ✅ Done | "Remember me" checkbox on login screen. Credentials stored in `flutter_secure_storage` (iOS Keychain). Pre-fills email + password on next open. Cleared on logout or when checkbox unticked. |
| A14 | Google OAuth login | ❌ Not started | Add "Sign in with Google" option. Use `google_sign_in` Flutter package + backend token verification. ~3 hours. Needs Google Cloud OAuth client IDs (web + iOS + Android). Existing email/password login stays as fallback. |
| A15 | Admin visual dashboard (Phase 2) | ✅ Done | HTML dashboard at `/api/admin` with KPI cards, charts, user management. User detail modal with 6 tabs (Overview, Profiles, Readings, Chats, Insights, AI Memory). AI memory edit/reset. Served by backend. |
| A16 | Inline profile editing | ✅ Done | Profile screen: owners can edit age, height, weight, doctor details inline with single Save button. Read-only for viewers. Added 2026-04-03. |
| A17 | Email verification (OTP) | ❌ Not started | Phase 1: soft nudge (banner + skip). Phase 2: hard block (one-line change). Blueprint: `docs/blueprints/email-verification.md`. Pre-pilot priority. |
| A18 | Alembic DB migrations | ❌ Not started | Replace 10 hand-written `migrate_*.py` scripts with Alembic. One-time ~30min setup. Post-pilot. |

---

## MODULE B — Data Input: Photo + Manual + Sensors

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| B1 | Photo capture — glucose | ✅ Done | `photo_scan_screen.dart` + `ocr_service.dart`. ML Kit on-device OCR. Frame guide + flash toggle. |
| B2 | Photo capture — BP | ✅ Done | Same `photo_scan_screen.dart`, `deviceType: 'blood_pressure'`. Extracts systolic/diastolic/pulse. |
| B3 | Photo capture — weight | ❌ Not started | OCR service handles glucose/BP only. No weight OCR screen. |
| B4 | Manual entry — glucose | ✅ Done | `reading_confirmation_screen.dart` — text field pre-filled from OCR, fully editable. |
| B5 | Manual entry — BP | ✅ Done | Same confirmation screen — systolic, diastolic, pulse fields. |
| B6 | Manual entry — weight | ❌ Not started | Confirmation screen covers glucose/BP only. No weight entry form. |
| B7 | Height input | ✅ Done | Height field in `create_profile_screen.dart` and `profile_screen.dart`. |
| B8 | Confirmation screen | ✅ Done | `reading_confirmation_screen.dart` — "We read X — correct?" with edit + save. |
| B9 | "Log for someone else" | ✅ Done | Switch active profile in `select_profile_screen.dart` before logging — all readings go to active profile. |
| B10 | Phone pedometer | ✅ Done | `pedometer_service.dart` + `background_step_service.dart`. `pedometer: ^4.0.2` in pubspec. Requests activity recognition permission, streams StepCount, stores daily steps locally, syncs to backend. |
| B11 | Reading reminders | ❌ Not started | No `flutter_local_notifications` in `pubspec.yaml`. No reminder scheduling. |
| B12 | Weekly weight reminder | ❌ Not started | Depends on B11. |
| B13 | Blurry photo detection | ✅ Done | `photo_scan_screen.dart` — near-empty OCR result shows "Photo is blurry — retake" dialog. |
| B21 | Store device photo with reading | ❌ Not started | Currently images are discarded after OCR. Should save to server filesystem (`/uploads/{profile_id}/{reading_id}.jpg`) and add `image_path` column to `health_readings` table. Provides audit trail, dispute resolution, and ability to re-process with better AI models later. |
| B22 | Pull data from Apple Health / Google Health Connect | ❌ Not started | Use `health` Flutter package to read steps, heart rate, sleep, weight from device health APIs. Requires user permission. Enables cross-data AI insights (glucose × activity × sleep). See plan below. |
| B23 | Voice conversation with AI | ❌ Not started | Phase 2. Use phone keyboard's built-in voice-to-text for now (zero cost). Full voice would need STT + TTS APIs (~$50-100/mo at scale). Architecture doesn't change — voice input feeds same chat + memory system. |
| B14 | Flash toggle | ✅ Done | `photo_scan_screen.dart` — flash on/off button, uses `CameraController.setFlashMode()`. |
| B15 | Meal context tag | ✅ Done | `reading_confirmation_screen.dart` — Fasting / Before Meal / After Meal chips. Stored in `notes`. |
| B16 | BLE auto-sync — glucometer | ✅ Done | `lib/ble/glucose_service.dart` — full RACP protocol, SFLOAT decoding, timestamp, sample type/location, auto-fetches historical records. Integrated into `dashboard_screen.dart`. |
| B17 | BLE auto-sync — BP monitor | ✅ Done | `lib/ble/bp_service.dart` — Omron HEM-7140T and similar, BPM characteristic (0x2A35), intermediate cuff (0x2A36), SFLOAT, pulse rate, measurement status. |
| B18 | BLE auto-sync — health band | 🔄 Partial | Armband device type in `scan_screen.dart` + `home_screen.dart`. No actual armband characteristic parsing or step/heart rate extraction. Placeholder only. |
| B19 | Device management screen | 🔄 Partial | `scan_screen.dart` — scan, list discovered devices with RSSI, type detection, connect. No persistent paired-device list or automatic reconnect flow. |
| B20 | Direct manual entry (no camera/BLE) | ✅ Done | "Enter Manually" in home screen modal → `ReadingConfirmationScreen` with empty fields. Glucose + BP. |

---

## MODULE C — Dashboard + Visualization

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| C1 | Today's summary card | ✅ Done | `_HealthScoreCard` on home screen — shows today's glucose + BP values, status icons, last logged time, and health score ring. |
| C2 | Status badges (HIGH / NORMAL / LOW) | ✅ Done | `history_screen.dart` — color-coded badges. `_glucoseStatus()` and `_bpStatus()` helpers in confirmation screen. |
| C3 | BMI display | ✅ Done | BMI tile on home screen (replaces Armband). Color-coded WHO categories. Actionable tip shows kg to lose/gain. Weight field added to Profile model. |
| C4 | 7/30/90-day glucose trend chart | ✅ Done | `trend_chart_screen.dart` — 3 tabs (7/30/90 days), glass card styling, adaptive dot radius, smart X-axis labels. |
| C5 | 7/30/90-day BP trend chart | ✅ Done | Same screen — systolic (rose) + diastolic lines, normal range bands, correlation overview card. |
| C6 | 7-day steps chart | ❌ Not started | Depends on B10 (pedometer). |
| C7 | 7-day heart rate chart | ❌ Not started | Depends on B18 (health band). |
| C8 | Weekly weight trend | ❌ Not started | Plan: treat weight as a `reading_type: "weight"` in health_readings table. Reuses existing trend charts, history, streak system. Track weight changes over time for BMI trends. No longer depends on B3/B6. |
| C9 | 30/90-day trend charts | ✅ Done | `trend_chart_screen.dart` — 7/30/90-day tabs with glassmorphism cards. |
| C10 | Reading history | ✅ Done | `history_screen.dart` — scrollable list, timestamp, type filter, delete, status badges. |
| C11 | Streak counter | ✅ Done | Backend: consecutive-days logic in `GET /api/readings/health-score`. Shown in gamification panel. |
| C12 | Empty states | ✅ Done | Health score card has empty/no-profile state. History has "No readings yet". Home screen handles null profileId. |
| C13 | Family view | ✅ Done | Profile switching gives any profile's dashboard/history. Shared profiles work via A2. |
| C14 | "Everything is okay" green signal | ✅ Done | `_StatusFlag` widget shows 🟢 "Fit & Fine" when score ≥ 70 and all readings NORMAL. Age-adjusted. |
| C15 | Pull-to-refresh | ✅ Done | `select_profile_screen.dart` — `RefreshIndicator`. Home screen has refresh on health score card + `RouteAware.didPopNext`. |
| C16 | Offline mode / "last synced" | ❌ Not started | Rolled back with A9 on 2026-03-31. Deferred to post-pilot. |
| C17 | Large text accessibility | ❌ Not started | No `MediaQuery.textScaleFactor` usage. All font sizes hardcoded. |
| C18 | Health Score widget (home screen) | ✅ Done | 0–100 score ring (green/orange/red), `GET /api/readings/health-score`. Tappable → trend charts. |
| C19 | Streak counter on home screen | ✅ Done | Shown in `_GamificationPanel` — "🔥 N-day streak" chip. |
| C20 | AI insight text (rule-based) | ✅ Done | Plain-English tip from last 7 days. Pure rule engine. Differentiates Stage 2 BP with urgent messaging. |
| C21 | Glucose × BP correlation chart | ✅ Done | `trend_chart_screen.dart` — both charts on same scrollable screen, 7/30-day tabs. |
| C22 | Glassmorphism visual theme | ✅ Done | Sky-blue glassmorphism theme (Phase 1-4). GlassCard widget, Plus Jakarta Sans font. All screens migrated. |
| C23 | Dynamic health status flag | ✅ Done | `_StatusFlag` widget in health score card header. Four states: 🟢 Fit & Fine / 🟡 Caution / 🟠 At Risk / 🚨 Urgent. Age-adjusted thresholds (strict <30, lenient 60+). |
| C24 | Gamification — streak points + leaderboard | ✅ Done | `_GamificationPanel`: points tiers (1d=10, 3d=100, 7d=300, 14d=700, 30d=1500), Weekly Winners placeholder with 3 avatar chips (coming soon). |
| C25 | Caregiver Wellness Hub dashboard | ✅ Done | Behind `FeatureFlags.caregiverDashboard`. Shows when viewing shared profile. Wellness Hub header, personalized messages, activity feed, care circle, priority call. "Take Readings" toggle. PRs #75, #77, #79. |
| C26 | Care Circle widget | ✅ Done | Family avatars with role badges (Owner/Editor/Viewer), relationship, last active, Call/WhatsApp/Email. Full-width. Both dashboards. PRs #77, #79, #80. |
| C27 | Manage Access UX | ✅ Done | "PROFILE SHARED WITH" header, empty state, colored initials, edit relationship dialog. PR #81. |
| C28 | BMI in vitals grid | ✅ Done | Moved BMI from full-width row into 2x2 grid replacing SpO2. PR #74. |
| C29 | Health Connect integration (Android) | ❌ Future | Post-pilot / NRI tier. Replace `pedometer` package with `health` Flutter plugin (wraps Android Health Connect + iOS HealthKit). Auto-reads HR, sleep, glucose, BP from Mi Band/Fitbit/glucometers. **Trigger:** when NRI tier launches or a doctor requests HR/sleep trends. No new UI surfaces until then — empty data cards are worse than no cards. Learn: Health Connect SDK + permission model first. |

---

## MODULE D — AI Insights + WhatsApp Notifications + Doctor

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| D1 | Cross-data insights (glucose × activity × sleep) | 🔄 Partial | Glucose + BP cross-analysis in health score endpoint. No activity (pedometer) or sleep data — those sensors not implemented. |
| D2 | Daily morning action tip | ❌ Not started | No scheduled task, no notification system. Requires `flutter_local_notifications` + backend scheduler. |
| D3 | Pattern detection (7+ day trends) | 🔄 Partial | Trend chart screen shows 7/30-day raw data visually. No algorithmic pattern detection (peaks, cycles, regression). |
| D4 | BMI-to-glucose insight | ❌ Not started | Depends on C3 (BMI). |
| D5 | Weight-glucose correlation | ❌ Not started | No weight tracking (B3/B6). |
| D6 | Weekly summary | 🔄 Partial | Trend chart provides 7-day view. No aggregated weekly report (avg/min/max summary card or export). |
| D7 | Abnormal value alert (immediate) | ✅ Done | `alert_service.py` — `dispatch_critical_alert()` fans out CRITICAL/HIGH-STAGE-2 alerts to all family members via Twilio WhatsApp. Deduplication window prevents spam. Logged to `critical_alert_logs` for audit. Wired in `routes_health.py:123-163`. |
| D8 | WhatsApp Business API integration | ✅ Done | `twilio_service.py` — Twilio client with `send_whatsapp()`, `send_whatsapp_template()`, `send_critical_alert_whatsapp()`. Used by `alert_service.py` + `report_service.py`. |
| D9 | Per-profile notification preferences | ❌ Not started | No notification preference UI or storage. Depends on D7/D8. |
| D10 | Daily WhatsApp summary | ❌ Not started | Depends on D8. |
| D11 | Weekly WhatsApp summary (family/NRI) | ✅ Done | `report_service.py` — `send_weekly_reports()` sends consolidated weekly health summary to profile owner via Twilio WhatsApp. Grouped by recipient. AI-generated insight included. Scheduled task. |
| D12 | Alert WhatsApp message | ❌ Not started | Depends on D8. |
| D13 | Push notifications (FCM backup) | ❌ Not started | `firebase_messaging` not in `pubspec.yaml`. No FCM config. |
| D14 | Doctor referral code | ✅ Done | `doctor_name`, `doctor_specialty`, `doctor_whatsapp` columns on `profiles` table. "Doctor Details" section on profile screen (owner-only). Edit dialog with save via `updateProfile`. Ready for D15 WhatsApp sending. |
| D15 | Doctor weekly WhatsApp summary | ❌ Not started | D8 ✅ done. D14 ✅ done. Still needs implementation: send weekly patient summary to `doctor_whatsapp` number on profile. ~2 hours. |
| D16 | Streak notifications | ❌ Not started | Streak calculated and shown visually. No push/WhatsApp alert when streak is broken or reached. |
| D17 | AI Doctor card (multi-model) | ✅ Done | `GET /api/readings/ai-insight` — compact prompt (averages+ranges). Gemini 2.5 Flash → DeepSeek V3 → rule-based fallback. Smart DB cache (only calls LLM on new readings). All calls logged to `ai_insight_logs` table for audit. Urgent tone for Stage 2 BP / CRITICAL. |
| D18 | Consent & Privacy notice | ✅ Done | Scroll-to-accept consent screen shown after registration. Stores consent_timestamp, app_version, language in users table. EN + HI. |
| D19 | Relationship on profile sharing | ✅ Done | Dropdown (father/mother/spouse/son/daughter/etc.) on invite. Carried to ProfileAccess on accept. Shown on Select Profile + Manage Access screens. |
| D20 | Demo seed data | ✅ Done | `seed_demo_data.py` — 3 users (Ramesh/Sunita/Arjun) with 45 days of glucose + BP readings. Realistic patterns (diabetic/improving/healthy). |
| D21 | CI/CD pipeline | ✅ Done | GitHub Actions: CI (pytest + flutter analyze + test), DEV auto-deploy on master push, PROD manual trigger. RSA deploy key. Pre-push git hook. PRs #86, #87. |
| D22 | Home screen refactor | ✅ Done | 1,635 → 367 lines. 7 extracted widgets + utils/health_helpers.dart. |
| D23 | AI responses in user's selected language | ❌ Not started | AI insight, trend summary, and health tips return English even when Hindi is selected. Need translation service (Google Translate API or Gemini) to convert AI-generated text to user's locale before displaying. Affects: ai-insight endpoint, trend-summary, meal tips. |
| D24 | Food Photo Classification | ✅ Done | All 6 steps complete. Backend: model, API, 5 insight rules. Frontend: Quick Select, Food Photo, Meal Result, dashboard integration. 55 tests, 100% coverage on health_utils. PR #65. |
| D25 | E2E integration tests (pre-prod gate) | ❌ Not started | Flutter integration_test: register → log reading → log meal → see insight. Network failure → offline queue → sync. Language switch mid-flow. Blocks production deployment. Use `integration_test` package. |
| D26 | Boundary value tests for health classifications | ❌ Not started | classify_bp at 131/132 systolic, 86/87 diastolic boundaries. classify_glucose at 70, 130, 180 exact boundaries. carb_glucose_correlation timezone-aware vs naive datetime. |
| D27 | AI eval harness — Indian clinical cases | ❌ Future | Pre-scale gate. Build 200-500 golden test cases (T2DM, hypertension, hypothyroid) to measure ai_service.py accuracy, hallucination rate, refusal behavior. Trigger: before fine-tuning MedGemma or custom clinical decision logic. Not needed while ai_service.py calls Gemini/DeepSeek with rule-based prompts. Learn: MedQA benchmarks, LLM-as-judge. |
| D28 | Ambient ASR — doctor consultation auto-notes | ❌ Future | Post Module E (doctor portal). Doctor opens consultation → mic records → MedASR (Google, open-source, HuggingFace) transcribes clinical audio → LLM extracts diagnosis (ICD-10), medications, LOINC observations → auto-fills doctor notes (E6). Use IndicWhisper for Hindi/Hinglish accuracy. Self-host on Hetzner (zero per-call cost). Trigger: after E6 (doctor clinical notes) is live and 5+ doctors actively using portal. |

---

## MODULE E — Security, Performance & Tech Debt

| # | Feature | Priority | Status | Notes |
|---|---------|----------|--------|-------|
| E1 | CORS: restrict allowed origins | CRITICAL | Not started | `backend/main.py:25` — `allow_origins=["*"]` must be whitelist. Any website can make authenticated requests on behalf of users. |
| E2 | Move SMTP credentials out of tracked files | CRITICAL | Not started | `backend/.env` committed to repo. Inject via CI/CD secrets or `.env.local` in `.gitignore`. Rotate exposed credentials. |
| E3 | Rate limiting on auth & OTP endpoints | HIGH | Not started | `POST /api/auth/login`, `/register`, `/forgot-password`, `/verify-otp`. No limit = trivial brute-force. Use `slowapi`. |
| E4 | Hash OTP before storing in DB | HIGH | ✅ Done (batched into E17, 2026-04-24) | `otp_hash` (sha256) columns on `password_reset_otps`, `email_verification_otps`, `phone_otps` in migration `0007_pii_encryption_batch.py`. Plaintext `otp` columns dropped. |
| E5 | Implement token refresh (refresh tokens) | HIGH | Not started | `backend/auth.py` — only 30-min access tokens. Users silently logged out. Add refresh token + `/api/auth/refresh` endpoint. |
| E6 | Database connection pool config | MEDIUM | Not started | `backend/database.py:7` — `create_engine()` has no pool settings. Add `pool_pre_ping=True, pool_size=10, max_overflow=20`. |
| E7 | Add index on `(user_id, reading_timestamp)` | MEDIUM | Not started | `backend/models.py` — no composite index on health readings. Queries will slow as data grows. |
| E8 | Fix N+1 queries in `/readings/stats/summary` | MEDIUM | Not started | `backend/routes_health.py` — runs 4 separate DB queries. Replace with single aggregation query. |
| E9 | BLE packet bounds checking | MEDIUM | Not started | `lib/ble/glucose_service.dart:57-118`, `bp_service.dart:116-186` — field accesses inside loop have no bounds guards. Malformed packet = crash. |
| E10 | Cancel BLE subscriptions on screen disposal | MEDIUM | Not started | `lib/screens/dashboard_screen.dart` — `onValueReceived.listen()` never cancelled. Memory leaks + stale callbacks. |
| E11 | Add HTTP request timeouts in Flutter | MEDIUM | Not started | `lib/services/api_service.dart`, `health_reading_service.dart` — no timeout on any HTTP call. Slow server = frozen UI. |
| E12 | Wire up Riverpod for shared state | LOW | Not started | `flutter_riverpod` in `pubspec.yaml` but unused. All screens use local state. Required before adding more screens. |
| E13 | Add soft delete for users | LOW | Not started | `backend/models.py` — no `deleted_at` field. Hard delete breaks foreign key references on `health_readings`. |
| E14 | Make `ApiService` a singleton | LOW | Not started | `ApiService()` instantiated per screen. Use top-level instance or Riverpod provider. |
| E15 | Remove `ignore_for_file` suppressions | LOW | Not started | `lib/screens/registration_screen.dart:2` — suppressed deprecation warnings hide future breakage. |
| E16 | Add BLE reconnection logic | LOW | Not started | No auto-reconnect when BLE device disconnects mid-session. Users must manually reconnect. |
| E17 | PII encryption at rest (DPDPA gap) | HIGH | ✅ Done (PR #165, 2026-04-24) | Migration `0007_pii_encryption_batch.py` encrypts PII across `users`, `profiles`, `profile_invites`, `*_otps`, `doctor_profiles`, `doctor_patient_links`. Dual-key AES-256-GCM (`ENCRYPTION_KEY` SPDI / `PII_ENCRYPTION_KEY` PII). E4 (OTP hash) batched in. Remaining: verify `PII_ENCRYPTION_KEY` env on India server post-P1. |

---

## MODULE G — Admin Dashboard & User Management

> **Blueprint:** `docs/ADMIN_USER_MANAGEMENT_BLUEPRINT.md`
> **Expert Reviews:** Dr. Rajesh, Legal Advisor (DPDPA/NMC), Healthify UX

### Phase 1 — Pre-Pilot Launch

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| G1 | Doctor verification queue (backend + UI) | ✅ Done | PR #90. POST verify/reject endpoints, doctor cards with Approve/Reject, NMC filter. |
| G2 | Account suspension | ✅ Done | PR #90. PATCH suspend endpoint, enforced in get_current_user (403), mandatory reason, audit-logged. |
| G3 | Admin audit trail | ✅ Done | PR #90. AdminAuditLog table, append-only, all admin actions logged. CERT-In 180-day. |
| G4 | Alerts center | ✅ Done | PR #90. GET /admin/alerts — critical readings, pending doctors, AI fallback, inactivity. |
| G5 | Consent dashboard | ✅ Done | PR #90. Per-user consent records, consented vs not-consented KPIs + table. |
| G6 | Sidebar navigation + admin toggle | ✅ Done | PR #90, #95. 6-section sidebar, Make Admin/Remove Admin button, responsive. |

### Healthify UX Review Fixes (from 2026-04-10 review)

**Must Fix:**

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| G6a | Destructive actions need confirmation modal + reason | ❌ Not started | Suspend/Reject use prompt() — need proper modal with required reason field, preset dropdown for rejections, 1-sec delay on confirm. |
| G6b | Doctor verification needs pre-approval checklist | ❌ Not started | Expandable checklist (NMC registry link, license doc, clinic proof, no duplicates). Approve disabled until all checked. |
| G6c | Consent "Not Consented" needs action path | ❌ Not started | "Send Consent Reminder" per-row, bulk reminder, "Last Reminder Sent" column. Clickable KPI card to filter. |

**Should Fix:**

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| G6d | Alerts need resolution workflow | ❌ Not started | New/Acknowledged/Resolved states, filter bar, auto-resolve on reading addressed. Needs alert_state backend table. |
| G6e | KPI cards need trend indicators | ❌ Not started | Sparkline or delta indicator (up/down % vs last week) under each KPI number. |
| G6f | Users table needs bulk actions | ❌ Not started | Checkbox column, sticky action bar (Export CSV, Suspend Selected). |
| G6g | Collapsed sidebar needs icons | ❌ Not started | Icon-only mode for tablet (60px sidebar currently blank). Add Material/SVG icons. |
| G6h | Badge color simplification | ❌ Not started | Role badges → neutral grey tones. Reserve red/amber/green for severity only. Color-blind safe. |
| G6i | AI Memory edits need version history | ❌ Not started | Show "Last modified by/when", keep 1 previous snapshot, revert option. |
| G6j | Audit Log needs filter + export | ❌ Not started | Date range picker, admin filter, action type checkboxes, Export CSV button. |

**Nice to Have:**

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| G6k | Chart drill-down interactivity | ❌ Not started | Click chart bar → filter Users table to that cohort. |
| G6l | Global search (Cmd+K) | ❌ Not started | Spotlight search by name/email/NMC across all sections. |
| G6m | Empty states with illustrations | ❌ Not started | SVG + explanation + action button for zero-data sections. |
| G6n | Critical Readings KPI → Alerts link | ❌ Not started | Click "Critical Readings" card → navigate to Alerts filtered to HIGH. |
| G6o | Session timeout warning | ❌ Not started | Auto-logout after inactivity, "Session expires in 5 min" banner. DPDPA PHI compliance. |

### Phase 2 — Month 1 Post-Launch

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| G7 | Role management + segregation | ❌ Not started | Unify is_admin + role enum. PATCH /role endpoint. Contextual warnings. Future: tiered admin roles. |
| G8 | User search + filters + pagination | ❌ Not started | Search name/email, filter role/status/activity, paginate. Essential at 50+ users. |
| G9 | Right to erasure workflow | ❌ Not started | DPDPA S12 legal blocker. Tiered anonymization, 72-hour SLA, erasure_requests table. |
| G10 | Clinical overview section | ❌ Not started | Population health stats (aggregated, no PII). Condition profile, glycemic/BP control, engagement by age. |
| G11 | Purpose limitation controls | ❌ Not started | DPDPA S4. Hide PHI by default, require reason to view, elevated audit logging. |

### Phase 3 — Sprint 4+

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| G12 | Doctor performance metrics | ❌ Not started | Patient count, active sessions, critical reading response time. |
| G13 | Caregiver linkage visibility | ❌ Not started | Per-patient caregiver info, "no caregiver" filter flag. |
| G14 | Patient-to-doctor assignment | ❌ Not started | Admin assign/reassign, bulk reassignment for doctor leave. |
| G15 | Bulk SMS/notification tool | ❌ Not started | Cohort selection, Hindi templates, re-engagement campaigns. |
| G16 | Pilot cohort segmentation | ❌ Not started | Tag patients into groups, filter all metrics by cohort. |
| G17 | Data export (CSV/PDF) | ❌ Not started | Non-PHI admin exports, doctor panel exports, audit-logged. |
| G18 | Breach notification tooling | ❌ Not started | CERT-In 6-hour reporting, incident log, affected users report. |
| G19 | Duplicate account detection | ❌ Not started | Same phone/NMC alert, manual review. |
| G20 | System health section | ❌ Not started | AI latency, fallback rate, model usage, data volume. |
| G21 | Admin mobile read-only view | ❌ Not started | Morning KPIs, critical count, pending doctors. Read-only. |
| G22 | Grievance redressal queue | ❌ Not started | DPDPA S13. Grievance Officer designation, 30-day SLA. |
| G23 | Minor user protections | ❌ Not started | DPDPA S9. Age flag, parental consent, block AI profiling for minors. |

---

## MODULE F — Doctor Portal + Legal Compliance

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| E1 | Doctor role model (UserRole enum + DoctorProfile table) | ❌ Not started | Enum: patient/doctor/admin. DoctorProfile: NMC number, specialty, clinic, doctor_code, is_verified. Replaces is_admin boolean. See `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md`. |
| E2 | Doctor registration + phone OTP login | ❌ Not started | Phone OTP via Gupshup SMS (TRAI DLT registration needed). NMC number verification (manual admin approval for pilot). 8-hour JWT for doctors. |
| E3 | Doctor-patient linking (consent flow) | ❌ Not started | New `doctor_patient_links` table. Doctor code system ("DRRAJ52"). Patient enters code → Hindi consent screen → data shared. Revocable anytime. |
| E4 | Doctor triage dashboard | ❌ Not started | Main screen: patients sorted by criticality (critical/attention/stable). Card-based layout. Cached triage columns on link table, async recompute on new reading. Web-first (responsive Flutter). |
| E5 | Doctor patient detail view | ❌ Not started | 2-column layout: profile+stats left, trends+readings right. Quick stats (7d), trend chart (30d), reading history, medications, AI insights (not chats). |
| E6 | Doctor clinical notes | ❌ Not started | Private notes on specific readings. Separate `doctor_notes` table. Patient cannot see unless doctor shares. 5-year retention per NMC. |
| E7 | Doctor WhatsApp messaging | ❌ Not started | Hindi templates via Gupshup WhatsApp Business API. Pre-approved templates with variable substitution. Depends on D8. |
| E8 | Doctor alert system | ❌ Not started | Critical alerts via WhatsApp (<5 min). Daily digest in-app. Weekly summary via WhatsApp+email. Depends on D8. |
| E9 | Doctor follow-up flags | ❌ Not started | Flag patient for review in N days. Reminder in alert center. Auto-nudge patient if no reading by follow-up date. |
| E10 | Doctor access audit trail | ❌ Not started | `doctor_access_log` table. Log every doctor access (who, what patient, what endpoint, when). DPDPA requirement. |
| E11 | Doctor routes (backend) | ❌ Not started | `routes_doctor.py` — all doctor API endpoints. Separate from patient endpoints. Never joins with chat tables. |

### Legal & Compliance (Pre-Launch Blockers)

| # | Item | Status | Notes |
|---|------|--------|-------|
| L1 | **Server migration to India** | ❌ Not started | CRITICAL. Current: Hetzner Germany. Target: AWS Mumbai or DigitalOcean Bangalore. DPDPA Sec 16, CERT-In. Est. Rs. 3,000–5,000/mo. 1–2 day effort. |
| L2 | **Doctor Platform Use Agreement** | ❌ Not started | CRITICAL. Lawyer must draft. Liability allocation, clinical responsibility, data terms. Est. Rs. 10,000–15,000. |
| L3 | **Professional Indemnity Insurance** | ❌ Not started | CRITICAL. Rs. 25–50 lakh coverage. Est. Rs. 15,000–25,000/year. Covers data breach + negligence claims. |
| L4 | **NMC disclaimers in UI** | ❌ Not started | CRITICAL. "Clinical observation, not prescription" on notes. "Yeh salah hai, prescription nahi" on WhatsApp. Engineering task, 2–3 hours. |
| L5 | **Update Patient Terms of Service** | ❌ Not started | HIGH. Add platform liability, doctor data sharing, AI disclaimers. Self-draft or Rs. 5,000 lawyer review. |
| L6 | **DLT registration for SMS OTP** | ❌ Not started | HIGH. TRAI requirement. Free registration, 3–5 day approval. Needed before phone OTP works. |
| L7 | **Update Privacy Policy** | ❌ Not started | HIGH. Add doctor data sharing, clinical notes, WhatsApp messaging sections. |
| L8 | **SaMD Class A assessment** | ❌ Not started | MEDIUM. Due within 90 days of launch. Engage regulatory consultant (Rs. 50,000–1,00,000). Triage = "inform" only, not "diagnose". |
| L9 | **Data Processing Agreement with Gupshup** | ❌ Not started | MEDIUM. Standard DPA. Due within 30 days of launch. Free (Gupshup provides). |
| L10 | **Clinical notes retention policy** | ❌ Not started | MEDIUM. 5-year retention. Anonymize on patient deletion (DPDPA vs NMC conflict — needs lawyer opinion). |

> **Full legal details:** `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` — share with lawyer for review.

---

## PROGRESS SUMMARY

| Module | Done | Partial | Not Started | Total |
|--------|------|---------|-------------|-------|
| A — Auth + Profiles | 8 | 2 | 3 | 13 |
| B — Data Input | 12 | 2 | 6 | 20 |
| C — Dashboard | 23 | 0 | 5 | 28 |
| D — AI + Notifications | 8 | 3 | 12 | 23 |
| F — Doctor Portal + Legal | 0 | 0 | 21 | 21 |
| G — Admin & User Mgmt | 0 | 0 | 23 | 23 |
| **Total** | **51** | **7** | **70** | **128** |

---

## BLOCKING GAPS (multiple features depend on these)

| Blocker | Blocks |
|---|---|
| No notification infrastructure (`flutter_local_notifications`, FCM) | D2, D7, D9, D13, D16 |
| No WhatsApp API (Twilio/Gupshup) | D8, D10, D11, D12, D15, F7, F8 |
| No weight tracking (B3, B6) | C8, D4, D5, D6 (full) |
| No pedometer (B10) | C6, D1 (full), D2 |
| No WhatsApp Business API (D8) | D15, F7, F8 — doctor_whatsapp field is ready |
| **Server in Germany** | L1 — blocks doctor portal launch (DPDPA data localization) |
| **No Doctor Platform Agreement** | L2 — blocks onboarding pilot doctors |
| **No Professional Indemnity Insurance** | L3 — blocks doctor portal launch |
| **No TRAI DLT registration** | L6 — blocks phone OTP for doctor login (E2) |

---

## Module F — Marketing & Growth

> **Strategy doc:** [`docs/MARKETING_STRATEGY.md`](docs/MARKETING_STRATEGY.md)
> **Video scripts:** [`docs/VIDEO_SCRIPTS_AND_TEST_DATA.md`](docs/VIDEO_SCRIPTS_AND_TEST_DATA.md)
> **VC feedback:** Vikram Chakraborty skill (`/vc-investor`). Current fundability: 3/10. Target: 8/10 by Sep 2026.

| ID | Task | Status | Owner | Notes |
|----|------|--------|-------|-------|
| F1 | **Build swasth.health landing page + NRI waitlist** | ❌ | **Assignee: TBD** | See detailed breakdown below (F1.1–F1.12) |
| F2 | Script 1 — NRI/family caregiver video (60s, English) | 🔄 | Amit + Claude | v3 exists in VIDEO_SCRIPTS doc. Needs NRI waitlist CTA update. |
| F3 | Generate Imagen stills for Script 1 (3 images) | ❌ | Amit | Prompts ready in VIDEO_SCRIPTS doc. Use Google AI Studio / Banana. |
| F4 | Record app walkthrough for Script 1 | ❌ | Amit | Demo data seeded on dev server (Ramesh Kumar persona). Login: ramesh.demo@swasth.app |
| F5 | Assemble Script 1 video (images + walkthrough + VO) | ❌ | Amit | CapCut or DaVinci Resolve. ElevenLabs or Sarvam AI for VO. |
| F6 | Facebook ad copy variants (3 versions) | ❌ | Claude | Headlines, descriptions, CTAs for A/B testing. |
| F7 | Run NRI waitlist campaign (₹5-10K, 7 days) | ❌ | Friend (media buyer) | Target: NRI expats from India, age 28-50, Germany/Canada/Singapore/Dubai/US/UK. |
| F8 | Script 2 — Patient direct video (60s, Hindi) | ❌ | Amit + Claude | Phase 2 — after Bihar landing. |
| F9 | Script 3 — Doctor pitch video (90s, English) | ❌ | Amit + Claude | Phase 2 — for doctor onboarding. |
| F10 | Script 4 — Investor video (90s, English) | ❌ | Amit + Claude | Phase 3 — for pitch meetings. |
| F11 | Organic NRI Facebook group posts | ❌ | Interns | Join NRI groups (Berlin, Singapore, Dubai, Canada, US). Post waitlist link organically. |
| F12 | Evaluate Sarvam AI for Hindi VO | ❌ | Amit + Claude | Alternative to ElevenLabs for Hindi voice. Need to check access + quality. |
| F13 | Company registration (Pvt Ltd) | ❌ | Amit | Target: end of May. ₹15,000. PAN + bank account. |

---

### F1 — Detailed Breakdown: swasth.health Website + Interest Form

**Objective:** Build a single-page landing site at `swasth.health` that collects NRI waitlist sign-ups for the Swasth health monitoring app. This is Phase 1 of the marketing strategy — goal is 200-500 sign-ups by end of May 2026.

**Domain:** `swasth.health` (already purchased by Amit)

**Design direction:** Single-page, mobile-first, clean and modern. Hero section with app demo, one clear CTA ("Join the Waitlist"), feature highlights, trust signals.

#### Sub-tasks

| ID | Task | Description | Estimate | Status | Dependencies |
|----|------|-------------|----------|--------|--------------|
| F1.1 | **Tech stack decision** | Decide: static HTML/CSS/JS, Next.js, or hosted (Carrd/Framer). Recommend static or Next.js on Vercel for speed + free hosting. | 1 hr | ❌ | None |
| F1.2 | **Hosting & DNS setup** | Point `swasth.health` DNS to hosting provider (Vercel recommended — free tier, auto-SSL). Configure DNS A/CNAME records. Verify HTTPS works. | 2 hrs | ❌ | F1.1 |
| F1.3 | **Page layout & wireframe** | Design wireframe with these sections: (1) Hero — headline + subheadline + CTA button, (2) App demo section — screenshot or embedded video, (3) Features — 3-4 key value props with icons, (4) Interest form, (5) Footer — privacy policy link + contact. Mobile-first. | 3 hrs | ❌ | F1.1 |
| F1.4 | **Hero section** | Build hero with: **Headline:** "Keep your parents healthy — from anywhere in the world" (or similar NRI-focused). **Subheadline:** "AI-powered health monitoring that connects families across borders." **CTA button:** "Join the Waitlist" (scrolls to form). Background: gradient or app screenshot. | 3 hrs | ❌ | F1.3 |
| F1.5 | **Feature highlights section** | 3-4 cards/columns: (1) "Daily health tracking" — BP, glucose, meals logged in seconds, (2) "AI health insights" — personalized tips in Hindi & English, (3) "Family dashboard" — see parent's readings from abroad, (4) "Doctor-ready reports" — share history with any doctor. Icons or illustrations for each. | 3 hrs | ❌ | F1.3 |
| F1.6 | **Interest/waitlist form** | Form fields: (1) **Name** — text, required, (2) **Email** — email, required, validated, (3) **City you live in** — text, required (NRI's current city, e.g. Berlin, Toronto), (4) **Parent's city in India** — text, required (e.g. Patna, Ranchi), (5) **Health topics that interest you** — checkboxes: ☐ Diabetes management, ☐ Blood pressure monitoring, ☐ General wellness. Submit button: "Join the Waitlist". Success message: "Thank you! We'll notify you when Swasth launches in your parent's area." | 4 hrs | ❌ | F1.3 |
| F1.7 | **Form backend (data storage)** | Options (pick one): (a) Google Sheets via Apps Script (simplest, free), (b) Supabase free tier (PostgreSQL), (c) Simple API endpoint on our FastAPI backend. **Recommended: Google Sheets** — zero cost, Amit can view sign-ups directly, no backend maintenance. Store: name, email, city, parent_city, interests, timestamp. | 3 hrs | ❌ | F1.6 |
| F1.8 | **Email confirmation (optional but recommended)** | On form submit, send a simple confirmation email: "Thanks for joining the Swasth waitlist! We'll keep you posted." Use Resend (free tier: 100 emails/day) or EmailJS. | 3 hrs | ❌ | F1.7 |
| F1.9 | **Privacy policy page** | Separate page or modal with privacy policy. Must include: what data we collect (name, email, city, health interests), how we use it (waitlist communication only), that we don't share it, how to request deletion, contact email. Draft with Claude, Amit reviews. **DPDPA compliant** — health interest checkboxes are phrased as "topics that interest you", NOT "does your parent have diabetes" (avoids sensitive personal data classification). | 2 hrs | ❌ | None |
| F1.10 | **Consent notice on form** | Below submit button: "By signing up, you agree to receive updates from Swasth. We won't share your data. [Privacy Policy]" — must be visible before user submits. | 30 min | ❌ | F1.9 |
| F1.11 | **App demo section** | Either: (a) Embedded video placeholder (for Script 1 when ready — F2-F5), or (b) 2-3 app screenshots showing dashboard, health readings, family view. Use actual app screenshots from dev server (Ramesh Kumar demo account). | 2 hrs | ❌ | F1.3 |
| F1.12 | **Analytics** | Add Google Analytics 4 (or Plausible for privacy-friendly alternative). Track: page views, form submissions, scroll depth, CTA clicks. Set up conversion event for form submit. | 1 hr | ❌ | F1.2 |

**Total estimated effort:** ~27 hours (~3-4 days for one person)

#### Acceptance Criteria
1. Site loads at `https://swasth.health` with valid SSL (no cert warnings)
2. Page is mobile-responsive (test on iPhone SE, Pixel 5, iPad)
3. Form submits successfully and data appears in Google Sheets (or chosen backend)
4. Privacy policy is accessible from the form
5. Consent notice is visible before submit
6. Page loads in < 3 seconds on 3G connection (lighthouse score > 80)
7. Analytics tracking fires on page load and form submit
8. Health interest checkboxes use DPDPA-safe phrasing ("topics that interest you")

#### Important Notes for Assignee
- **DO NOT** ask "Does your parent have diabetes?" — this triggers DPDPA sensitive personal data requirements. Use "What health topics interest you?" with checkboxes instead.
- **Domain is already purchased** — Amit has access to the DNS settings.
- **Video will come later** — use a placeholder or app screenshots for now (F2-F5 are separate tasks).
- **Target audience is NRIs** — Indians living abroad, aged 28-50, worried about parents' health. Tone should be warm, family-focused, not clinical.
- **Reference docs:** `docs/MARKETING_STRATEGY.md` (full strategy), `docs/VIDEO_SCRIPTS_AND_TEST_DATA.md` (video script for tone reference)

---

## NEXT PRIORITIES (Bihar Pilot)

### P0 — Safety Critical
- **D7** — Abnormal value alert: when CRITICAL reading saved, immediately notify family (WhatsApp or push)
- **D8** — WhatsApp Business API: register with Meta/Twilio — 2–5 day approval wait, start NOW

### P0 — Usability
- **A12** — First-time onboarding: welcome → create profile → how to photograph → invite family
- **A9** — Offline mode: `hive` or `sqflite` cache for health readings + sync queue (Bihar connectivity)

### P1 — Quick wins (< 1 day each)
- **C3** — BMI: height in profile already, add weight reading + display BMI on profile screen
- **B11** — Reading reminders: `flutter_local_notifications` — daily nudge if no reading by 8pm
- **D2** — Morning tip: extend AI Doctor to time-gate a morning recommendation

### P1 — Medium effort
- **B18** — Armband: implement actual step/heart rate BLE parsing
- **A12** — Onboarding carousel (3–4 screens)
- **D13** — FCM setup for push alerts (prerequisite for D7 fallback)

---

## Play Store Release — Deferred Follow-ups (opened 2026-04-18)

Context: Play Store app entry created (`health.swasth.app`, ID "Swasth — Health Tracker"). Privacy policy temporarily deployed to Cloudflare Worker at `https://swasth-privacy.swasth-admin.workers.dev/privacy` with `swasth.admin@gmail.com` as the grievance email (interim — `swasth.app` domain doesn't exist, `swasth.health` domain owned but DNS not configured yet). Below are the cleanup items to do after the Bangalore doctor pilot is live.

### P0 — Before public Production release (do within 2 weeks)

- **REL-1** — **Set up `swasth.health` as the canonical domain.** Move nameservers to Cloudflare (the Swasth CF account under `swasth.admin@gmail.com`), verify DNS resolves. ~15 min work + DNS propagation wait. Blocker for REL-2 and REL-3.
- **REL-2** — **Configure Cloudflare Email Routing**: `support@swasth.health` → `swasth.admin@gmail.com`. Free, ~10 min once REL-1 is done. Send a test email to confirm delivery.
- **REL-3** — **Swap grievance email back to `support@swasth.health`** in 4 places:
  - `docs/legal/privacy.html` line 116 (both `href` and visible text)
  - `docs/PLAY_STORE_LISTING.md` × 3 places (`Questions, feedback...` line, Contact details line, Release notes footer)
  - Re-deploy Cloudflare Worker with updated HTML (drag-and-drop to existing `swasth-privacy` project — don't create a new one)
  - Update Play Console: Data Safety form, App Content → Privacy policy, Main Store Listing contact email
- **REL-4** — **Point `swasth.health/privacy` at the Cloudflare Worker** once REL-1 is done. Options: (a) custom domain on the Worker itself, or (b) subdomain `privacy.swasth.health` via CNAME. Then edit Play Console privacy URL — no re-review needed.

### P0 — Deployment pipeline gaps (drift incident 2026-04-18)

**Incident:** User tried to save weight reading on production via the newly-deployed frontend. Got `"Invalid reading type. Must be one of: blood_pressure, glucose, spo2, steps"`. Root cause: production backend was running **April 12 code** (commit `11cd7cd`, PR #122), 11 commits behind master. PR #133 (weight tracking) + PR #132 (step count) + PR #124 (weekly reports) were never deployed to prod because `prod.yml` is `workflow_dispatch`-only. Fixed 2026-04-18 by `rsync`ing backend/*.py to `/var/www/swasth_prod/backend/`, running `migrate_add_weight_to_readings.py` (added 19 weight readings from legacy Profile.weight), and `pm2 restart swasth-prod`. CI tests were green because they run against fresh-checkout master, not live prod.

- **REL-DEPLOY-1** — **Change `.github/workflows/prod.yml` from manual-dispatch to auto-deploy on master push.** Currently `on: [workflow_dispatch]` means master merges sit in prod limbo until someone clicks "Run workflow." Alternative: keep manual but add a scheduled check that alerts if master is >3 commits ahead of prod's HEAD.
- **REL-DEPLOY-2** — **Add post-deploy smoke tests against live production URL.** Dedicated smoke-test user (`smoke.test@swasth.com`). One test per resource endpoint: POST every supported `reading_type` (bp, glucose, spo2, steps, weight) and assert 201. Run in CI after every successful prod deploy — would have caught this incident instantly. File: `backend/tests/smoke/test_prod_canary.py`.
- **REL-DEPLOY-3** — **Add frontend version-compatibility check.** When the Flutter app boots, call `GET /api/version` and compare server capability flags to what the app expects. If mismatch (e.g., client knows `weight` but server doesn't), show "App needs update" banner instead of cryptic backend error. Requires a new backend endpoint returning supported reading_types + min-app-version.

### P0 — Internal Testing rollout plan

- **REL-INT-1** — **Phase A (team QA, no doctor needed):** Add 2-3 emails controlled by Amit to tester list `Swasth Internal QA`. Upload AAB (after `flutter clean && flutter build appbundle --flavor production --target lib/main_production.dart --release` to bake new icon). Install on own Android device, smoke-test: login as `test.user@swasth.com` / `Test@1234`, verify home screen, trend chart, language toggle, icon is heart-pulse (not Flutter default). Fix any bugs before Phase B.
- **REL-INT-2** — **Phase B (doctor pilot, after Phase A is green):** Edit tester email list to add Bangalore doctor + 15-20 patient emails as doctor recruits. No new release needed — tester list edits are instant. Same opt-in URL works for all. Share URL via WhatsApp using template at `docs/DOCTOR_INVITE_TEMPLATE.md`.

### P0 — Finish Play Console setup (do in parallel with pilot)

Ordered by dependency. All of these are forms inside Play Console → "Finish setting up your app":

1. **REL-5** — Set privacy policy URL → DONE (using interim Cloudflare URL)
2. **REL-6** — App access → describe how testers log in (email+password, no premium gate for pilot)
3. **REL-7** — Ads → No
4. **REL-8** — Content rating → questionnaire, answers in `docs/PLAY_STORE_LISTING.md` Content rating section
5. **REL-9** — Target audience → 18+ only
6. **REL-10** — Data safety form → copy from `docs/PLAY_STORE_LISTING.md` Data Safety section
7. **REL-11** — Misc declarations (News apps: No, COVID-19: No, Government apps: No, Financial features: No, Health apps: Yes)
8. **REL-12** — Advertising ID → we don't use it, declare No
9. **REL-13** — Select app category → Medical
10. **REL-14** — Main store listing → requires icon (512×512), feature graphic (1024×500), 2–8 screenshots — see `docs/PLAY_STORE_LISTING.md` shot-list

### P0 — Production demo accounts for Play Store review

**Server topology clarification (learned 2026-04-18):** two Swasth backends run on `65.109.226.36`:
- `/var/www/swasth/` → internal port 8007 → connects to DB `swasth_db` (**DEV / pre-prod**) — nginx proxies this at `:8443`
- `/var/www/swasth_prod/` → internal port 8009 → connects to DB `swasth_prod` (**PROD**) — nginx proxies this at `:8444`

All Play Store traffic goes to prod (`:8444` → port 8009 backend → `swasth_prod` DB). **Do NOT confuse demo accounts between the two DBs — they have completely different user rows.**

- **REL-PROD-1** — 🔄 PARTIALLY DONE. Earlier verification used the WRONG database (`swasth_db` / dev) — credentials `ramesh.demo@swasth.app` exist on dev, NOT on prod. Correct prod demo account is `test.user@swasth.com` (533 readings, 0 meals, 0 doctor links, 5 profiles). Password not yet verified — either confirm with Amit or reset via `/api/auth/forgot-password`.
- **REL-PROD-2** — ❌ NOT DONE. Production DB `swasth_prod` has only 18 total users and only 2 demo-like accounts (`test.user@swasth.com`, `testdoc@gmail.com`). No seeded meal_logs, no seeded doctor_patient_links. For proper Play Store Production review (not Internal Testing), seed a rich demo account on prod mirroring `ramesh.demo@swasth.app` from dev: ~50 BP readings, ~30 glucose readings, ~20 meals, 1 active linked doctor, 1 caregiver profile_access entry. Run before submitting for Production access (after closed test phase).
- **REL-PROD-3** — ✅ DONE 2026-04-18. Password confirmed as `Test@1234` — returns HTTP 200 + JWT from `/api/auth/login` on prod (port 8009). Credentials in Play Console App Access: `test.user@swasth.com` / `Test@1234`.

### P1 — Production server migration to India (4–6 weeks out, post-pilot)

- **REL-15** — **Migrate backend from Hetzner (EU) to Indian hosting.** Reasons: DISHA-readiness, doctor/NMC perception, latency for Bihar mobile networks, investor optics. Options to evaluate: AWS Mumbai, Azure Central India, DigitalOcean Bangalore, E2E Networks, Netmagic. 2–3 day project including DB migration + SSL cert + secrets rotation + backup re-verification + doctor demo account re-creation. **Do not attempt before Bangalore doctor pilot is stable — risk of breaking the thing that's working during validation window.**
- **REL-16** — **Replace self-signed TLS cert with Let's Encrypt** once real domain (`swasth.health` or `api.swasth.health`) is pointed at the Indian server. This also lets us remove `_PilotHttpOverrides` from `lib/main.dart` (see "Pre-release blocker" at top of this file — linked work item).
- **REL-17** — **Update privacy policy data-location language** after migration: change any mention of EU/Germany data storage to India. Also update `docs/PLAY_STORE_LISTING.md` "servers in India" claim (currently aspirational) to factual.

### P0 — Brand identity (Flutter default icon is still the launcher icon, learned 2026-04-18)

- **REL-BRAND-1** — ✅ DONE 2026-04-18. Replaced Flutter default launcher icons with Swasth heart+pulse icon (coral heart #F43F5E with white ECG pulse line, off-white rounded-square background, 100px corner radius). Updated: Android (10 files across mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi × ic_launcher + ic_launcher_round), iOS (15 files in AppIcon.appiconset, alpha flattened), web (Icon-192/512 + maskable + favicon), Play Store upload icon at ~/Desktop/swasth-app-icon-512.png. Source variant: `v2-red-heart-white-pulse` from `~/Desktop/swasth-icon-samples-v4/`. macOS Runner AppIcon NOT yet updated — low priority since macOS builds aren't shipped. **Rebuild AAB before next tester release** to bake icons into the binary.
- **REL-BRAND-2** — Before Production release: commission a proper brand identity. Fiverr ($30-100) or 99designs ($200-500). Deliverables needed: full icon suite across platforms, wordmark, brand guidelines document, color palette confirmation. Replace REL-BRAND-1 temporary icon once delivered.

### P2 — Branding + asset polish (do anytime before 1,000 users)

- **REL-18** — ✅ DONE 2026-04-18. Feature graphic 1024×500 at `~/Desktop/swasth-feature-graphic/feature-graphic-final.png`. Sky-blue gradient, "Swasth" wordmark, tagline "Track your health. In your language.", heart-pulse icon on right, decorative ECG line at bottom. Bilingual version attempted but abandoned due to PIL Devanagari rendering limitations — English-only is sufficient for the Play Store listing's primary language (en-US). When a proper designer is engaged (REL-BRAND-2), request a redesigned feature graphic with Hindi localization using a text engine that supports Devanagari shaping.
- **REL-19** — ✅ DONE 2026-04-18 (phone screenshots). Phone screenshots captured and uploaded to Play Console Main Store Listing. Tablet screenshots (7-inch + 10-inch) deliberately left empty — Play Console showed them with asterisk but accepted the save. Internal Testing does not require them.
- **REL-19b** — ⚠️ Before Production release submission: add tablet screenshots (7-inch min 320px/side, 10-inch min 1080px/side, both 16:9 or 9:16 aspect). Google has been enforcing tablet screenshots on new-app Production listings since late 2024. Option: capture on a tablet emulator (Pixel Tablet profile in Android Studio) OR use a tablet-mockup service (previewed.app) to wrap phone screenshots in a tablet frame. Not blocking for Internal Testing.
- **REL-20** — Buy `swasth.app` domain defensively? Current cost: ~$15/yr. Reason: prevents a squatter from using it against you later. Not urgent. Discussion only.

---

## Claude Code Harness Upgrades — Pilot vs Live Evaluation (opened 2026-04-24)

Context: evaluated `shanraisshan/claude-code-best-practice` features for fit with Swasth's pilot-first posture. Primary lens: **token efficiency + pilot readiness**. Items below are deferred to post-pilot unless tagged PILOT NOW.

### PILOT NOW (adopt before May 1 — immediate token/DX wins)
- **CCH-1 — Auto Mode** (`--permission-mode auto`, `Shift+Tab`). Replaces the 138-entry Bash allowlist + per-prompt approval round-trips. Anthropic's safety classifier decides; blocks prompt injection. **Token impact: HIGH save** (each approval round-trip burns 2–5k tokens of re-sent context). Requires Opus 4.7. Action: enable on next session, monitor for false-blocks for 1 week.
- **CCH-2 — Output Styles**. Codify the 100-word bullet rule + "Want an elaborative answer?" offer as a named output style in `~/.claude/output-styles/`, referenced from `settings.json`. Replaces the prose block currently duplicated in `CLAUDE.md` (~80 words reloaded every turn). **Token impact: MEDIUM save** (~80 words × every turn). Complements the UserPromptSubmit hook built today.
- **CCH-3 — Statusline context %**. Add `/statusline` showing context usage, model, cost. **Token impact: INDIRECT save** — lets us trigger `/compact-now` before auto-compaction wastes tokens re-summarizing. Free, zero-risk.

### LIVE ONLY (post-pilot, after May 1 launch)
- **CCH-4 — Routines / `/schedule`** (cloud cron on Anthropic infra). Candidates post-launch: nightly orphan-branch scan, weekly CVE check on `pubspec.yaml`/`requirements.txt`, monthly PHI-compliance sweep, daily smoke-test against prod. Replaces today's manual `/loop` polling. Skip pre-pilot (nothing recurring yet). Target: 2 weeks after pilot is live, pick top 3 recurring chores.
- **CCH-5 — Ultrareview** (`/ultrareview`, $5–20/run, 5–10 min, multi-agent cloud PR review). Do NOT wire into every PR — cost blows up. Reserve for: (a) DB migration PRs, (b) auth/encryption changes, (c) pre-prod release audits. Daniel-review stays the default. Add a pre-merge checklist item post-pilot: "if PR touches `models.py`/`encryption_service.py` → run `/ultrareview` once before merge."
- **CCH-6 — Channels (beta)** — Telegram/Discord → running session. Useful only after pilot goes live and we need push-based prod monitoring (alert from PagerDuty → session fixes config). Pre-pilot: noise. Revisit at 50+ DAU.
- **CCH-7 — Plugin bundling** — package Sunita/Meera/Daniel/Aditya personas + review chains as a distributable plugin. Zero internal token benefit. Value is external: (a) hiring signal, (b) open-source play if we spin out. Do only if we decide to open-source the harness. Park behind "100 DAU" gate.

### EVALUATED AND REJECTED
- Nothing rejected outright. All 7 have a fit window — just not the pilot window.
