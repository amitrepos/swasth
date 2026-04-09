# Swasth App — Phase 1 Task Tracker

**Last Updated:** 2026-04-09
**Sprint:** 4 weeks + buffer | **Target:** Bihar pilot

Legend: ✅ Done &nbsp;|&nbsp; 🔄 Partial &nbsp;|&nbsp; ❌ Not started

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
| B10 | Phone pedometer | ❌ Not started | No `pedometer` package in `pubspec.yaml`. No step counting. |
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
| D7 | Abnormal value alert (immediate) | ❌ Not started | Backend detects CRITICAL status in `routes_health.py` but no push notification or WhatsApp trigger. No FCM. |
| D8 | WhatsApp Business API integration | ❌ Not started | No Twilio/Gupshup in backend. `email_service.py` is for password reset only. No `share_plus` package. |
| D9 | Per-profile notification preferences | ❌ Not started | No notification preference UI or storage. Depends on D7/D8. |
| D10 | Daily WhatsApp summary | ❌ Not started | Depends on D8. |
| D11 | Weekly WhatsApp summary | ❌ Not started | Depends on D8. |
| D12 | Alert WhatsApp message | ❌ Not started | Depends on D8. |
| D13 | Push notifications (FCM backup) | ❌ Not started | `firebase_messaging` not in `pubspec.yaml`. No FCM config. |
| D14 | Doctor referral code | ✅ Done | `doctor_name`, `doctor_specialty`, `doctor_whatsapp` columns on `profiles` table. "Doctor Details" section on profile screen (owner-only). Edit dialog with save via `updateProfile`. Ready for D15 WhatsApp sending. |
| D15 | Doctor weekly WhatsApp summary | ❌ Not started | Depends on D8 + D14. |
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

---

## MODULE E — Security, Performance & Tech Debt

| # | Feature | Priority | Status | Notes |
|---|---------|----------|--------|-------|
| E1 | CORS: restrict allowed origins | CRITICAL | Not started | `backend/main.py:25` — `allow_origins=["*"]` must be whitelist. Any website can make authenticated requests on behalf of users. |
| E2 | Move SMTP credentials out of tracked files | CRITICAL | Not started | `backend/.env` committed to repo. Inject via CI/CD secrets or `.env.local` in `.gitignore`. Rotate exposed credentials. |
| E3 | Rate limiting on auth & OTP endpoints | HIGH | Not started | `POST /api/auth/login`, `/register`, `/forgot-password`, `/verify-otp`. No limit = trivial brute-force. Use `slowapi`. |
| E4 | Hash OTP before storing in DB | HIGH | Not started | `backend/models.py:67` — OTP stored plain text. Store `sha256(otp).hexdigest()` and compare hashes. |
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

---

## MODULE G — Admin Dashboard & User Management

> **Blueprint:** `docs/ADMIN_USER_MANAGEMENT_BLUEPRINT.md`
> **Expert Reviews:** Dr. Rajesh, Legal Advisor (DPDPA/NMC), Healthify UX

### Phase 1 — Pre-Pilot Launch

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| G1 | Doctor verification queue (backend + UI) | ❌ Not started | NMC Act S29 blocker. POST verify/reject endpoints, two-column queue UI, NMC registry link, rejection email. |
| G2 | Account suspension | ❌ Not started | PATCH suspend endpoint, enforce in get_current_user, mandatory reason, audit-logged. |
| G3 | Admin audit trail | ❌ Not started | CERT-In 180-day legal blocker. New admin_audit_log table, append-only, all admin actions logged. |
| G4 | Alerts center | ❌ Not started | GET /admin/alerts — critical readings, pending doctors, AI fallback, patient inactivity. Polling-based. |
| G5 | Consent dashboard | ❌ Not started | DPDPA S6 legal blocker. Per-user consent records, withdrawal mechanism, policy version tracking. |
| G6 | Sidebar navigation | ❌ Not started | 6-section IA: Overview, Users, Doctors, Clinical, Alerts, System. Responsive sidebar. |

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
