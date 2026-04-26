# Swasth — Completed Tasks

**Last Updated:** 2026-04-26
**75 tasks shipped across Modules A–G + Legal.**
**For pending work → see TASK_TRACKER_PENDING.md**

---

## MODULE A — Core Architecture + Auth + Profiles

| # | Task | Notes |
|---|------|-------|
| A2 | Multi-profile data model | profiles, profile_access, profile_invites tables. All 22 steps complete. |
| A3 | Profile creation | create_profile_screen.dart — name, age, gender, height, weight, blood group, conditions, medications. |
| A4 | Medication list | Current medications text field in profile creation + edit. |
| A5 | Add person without smartphone | Create profile for someone else → caller becomes owner. |
| A6 | Language toggle (Hindi / English) | Full gen-l10n: app_en.arb + app_hi.arb. Toggle chip in Profile → Settings. Language persisted via Riverpod. |
| A7 | Profile switcher | select_profile_screen.dart — lists all accessible profiles, tap to switch. |
| A11 | Access permissions | owner / viewer / editor levels via profile_access table. dependencies.py enforces access. |
| A13 | Remember me / saved credentials | Checkbox on login. Credentials in flutter_secure_storage (iOS Keychain). |
| A15 | Admin visual dashboard | HTML dashboard at /api/admin. KPI cards, charts, user management. 6-tab user detail modal. AI memory edit/reset. |
| A16 | Inline profile editing | Owners can edit age, height, weight, doctor details inline. Read-only for viewers. |

---

## MODULE B — Data Input: Photo + Manual + Sensors

| # | Task | Notes |
|---|------|-------|
| B1 | Photo capture — glucose | photo_scan_screen.dart + ocr_service.dart. ML Kit on-device OCR. Frame guide + flash toggle. |
| B2 | Photo capture — BP | Same photo_scan_screen.dart. Extracts systolic/diastolic/pulse. |
| B4 | Manual entry — glucose | reading_confirmation_screen.dart — pre-filled from OCR, editable. |
| B5 | Manual entry — BP | Same confirmation screen — systolic, diastolic, pulse fields. |
| B7 | Height input | Height field in create_profile_screen.dart and profile_screen.dart. |
| B8 | Confirmation screen | "We read X — correct?" with edit + save. |
| B9 | Log for someone else | Switch active profile before logging — readings go to active profile. |
| B10 | Phone pedometer | pedometer_service.dart + background_step_service.dart. pedometer:^4.0.2. Streams StepCount, stores locally, syncs to backend. |
| B13 | Blurry photo detection | Near-empty OCR result shows "Photo is blurry — retake" dialog. |
| B14 | Flash toggle | Flash on/off button via CameraController.setFlashMode(). |
| B15 | Meal context tag | Fasting / Before Meal / After Meal chips on confirmation screen. Stored in notes. |
| B16 | BLE auto-sync — glucometer | lib/ble/glucose_service.dart — full RACP protocol, SFLOAT decoding, auto-fetch historical records. |
| B17 | BLE auto-sync — BP monitor | lib/ble/bp_service.dart — Omron HEM-7140T, BPM characteristic 0x2A35, SFLOAT, pulse rate. |
| B20 | Direct manual entry | "Enter Manually" → ReadingConfirmationScreen with empty fields. Glucose + BP. |

---

## MODULE C — Dashboard + Visualization

| # | Task | Notes |
|---|------|-------|
| C1 | Today's summary card | _HealthScoreCard — today's glucose + BP, status icons, last logged time, health score ring. |
| C2 | Status badges (HIGH / NORMAL / LOW) | Color-coded badges in history_screen.dart. |
| C3 | BMI display | BMI tile on home screen. Color-coded WHO categories. Actionable tip (kg to lose/gain). |
| C4 | 7/30/90-day glucose trend chart | trend_chart_screen.dart — 3 tabs, glass card styling, adaptive dot radius. |
| C5 | 7/30/90-day BP trend chart | Systolic + diastolic lines, normal range bands, correlation overview. |
| C9 | 30/90-day trend charts | Same trend_chart_screen.dart — 7/30/90-day tabs. |
| C10 | Reading history | history_screen.dart — scrollable list, timestamp, type filter, delete, status badges. |
| C11 | Streak counter | Consecutive-days logic in GET /api/readings/health-score. Shown in gamification panel. |
| C12 | Empty states | Health score card empty/no-profile state. History "No readings yet". Null profileId handled. |
| C13 | Family view | Profile switching gives any profile's dashboard/history. |
| C14 | "Everything is okay" green signal | _StatusFlag shows Fit & Fine when score >= 70 and all readings NORMAL. Age-adjusted. |
| C15 | Pull-to-refresh | RefreshIndicator on select_profile + home screen health score card. |
| C18 | Health Score widget | 0-100 score ring (green/orange/red). Tappable → trend charts. |
| C19 | Streak counter on home screen | _GamificationPanel — fire N-day streak chip. |
| C20 | AI insight text (rule-based) | Plain-English tip from last 7 days. Pure rule engine. Stage 2 BP urgent tone. |
| C21 | Glucose x BP correlation chart | Both charts on same scrollable screen, 7/30-day tabs. |
| C22 | Glassmorphism visual theme | Sky-blue glassmorphism. GlassCard widget. Plus Jakarta Sans font. All screens migrated. |
| C23 | Dynamic health status flag | Four states: Fit & Fine / Caution / At Risk / Urgent. Age-adjusted thresholds. |
| C24 | Gamification — streak points | Points tiers (1d=10, 3d=100, 7d=300, 14d=700, 30d=1500). Weekly Winners placeholder. |
| C25 | Caregiver Wellness Hub dashboard | Behind FeatureFlags.caregiverDashboard. Wellness Hub header, messages, activity feed, care circle. |
| C26 | Care Circle widget | Family avatars with role badges, relationship, last active, Call/WhatsApp/Email. |
| C27 | Manage Access UX | "PROFILE SHARED WITH" header, empty state, colored initials, edit relationship dialog. PR #81. |
| C28 | BMI in vitals grid | BMI moved into 2x2 grid replacing SpO2. PR #74. |

---

## MODULE D — AI Insights + WhatsApp + Notifications

| # | Task | Notes |
|---|------|-------|
| D7 | Abnormal value alert (immediate) | alert_service.py — dispatch_critical_alert() fans out to all family via Twilio WhatsApp. Dedup window. Logged to critical_alert_logs. |
| D8 | WhatsApp Business API | twilio_service.py — send_whatsapp(), send_whatsapp_template(), send_critical_alert_whatsapp(). |
| D11 | Weekly WhatsApp summary (family/NRI) | report_service.py — send_weekly_reports() sends consolidated weekly to profile owner. AI insight included. |
| D14 | Doctor referral details | doctor_name, doctor_specialty, doctor_whatsapp on profiles table. Doctor Details section on profile screen. |
| D17 | AI Doctor card (multi-model) | GET /api/readings/ai-insight. Gemini 2.5 Flash → DeepSeek V3 → rule-based fallback. Smart DB cache. Logged to ai_insight_logs. |
| D18 | Consent & Privacy notice | Scroll-to-accept consent screen after registration. Stores consent_timestamp, app_version, language. EN + HI. |
| D19 | Relationship on profile sharing | Dropdown (father/mother/spouse/etc.) on invite. Shown on Select Profile + Manage Access. |
| D20 | Demo seed data | seed_demo_data.py — 3 users (Ramesh/Sunita/Arjun), 45 days of readings. Realistic patterns. |
| D21 | CI/CD pipeline | GitHub Actions: CI + DEV auto-deploy on master push + PROD manual trigger. RSA deploy key. |
| D22 | Home screen refactor | 1,635 → 367 lines. 7 extracted widgets + utils/health_helpers.dart. |
| D24 | Food Photo Classification | All 6 steps. Backend: model, API, 5 insight rules. Frontend: Quick Select, Food Photo, Meal Result. 55 tests, 100% coverage. |

---

## MODULE E — Security / Compliance (shipped tasks)

| # | Task | Notes |
|---|------|-------|
| E4 (OTP) | Hash OTP before storing | sha256 otp_hash columns on password_reset_otps, email_verification_otps, phone_otps. Batched into E17. |
| E17 | PII encryption at rest | PR #165. Migration 0007_pii_encryption_batch.py. AES-256-GCM on all PII across users, profiles, profile_invites, otps, doctor_profiles, doctor_patient_links. Dual-key: ENCRYPTION_KEY (SPDI) + PII_ENCRYPTION_KEY (PII). |

---

## MODULE G — Admin Dashboard

| # | Task | Notes |
|---|------|-------|
| G1 | Doctor verification queue | PR #90. POST verify/reject endpoints, doctor cards, NMC filter. |
| G2 | Account suspension | PR #90. PATCH suspend, enforced in get_current_user (403), mandatory reason, audit-logged. |
| G3 | Admin audit trail | PR #90. AdminAuditLog table, append-only. CERT-In 180-day retention. |
| G4 | Alerts center | PR #90. GET /admin/alerts — critical readings, pending doctors, AI fallback, inactivity. |
| G5 | Consent dashboard | PR #90. Per-user consent records, consented vs not-consented KPIs + table. |
| G6 | Sidebar navigation + admin toggle | PR #90, #95. 6-section sidebar, Make Admin/Remove Admin, responsive. |

---

## Notable PRs (key milestones)

| PR | What shipped |
|---|---|
| #165 | PII encryption (E17) — AES-256-GCM on all patient PII. DPDPA compliant. |
| #168 | Registration fixes — removed auto-send OTP |
| #166 | Redirect to profile selection after first manual BP entry |
| #112 | Doctor/history/admin bug fixes + 16 integration tests. Backend at 653 tests, 88% coverage. |
| #90 | Full admin dashboard — verification, suspension, audit trail, alerts, consent. |
| #86/#87 | CI/CD pipeline — GitHub Actions. |
| #81 | Manage Access UX. |
| #79/#80 | Care Circle widget. |
| #75/#77 | Caregiver Wellness Hub. |
| #74 | BMI grid. |
| #65 | Food Photo Classification (all 6 steps). |

## Verified Completed (2026-04-26 audit)

| # | Task | Notes |
|---|------|-------|
| A17 | Email verification | routes.py:319 — send_email_verification_otp() + /verify-email endpoint. OTP sent on request, verified before login gating. |
| G9 | Right to erasure (DPDPA S12) | routes.py:546 delete_account() — full cascade delete: readings, AI logs, profiles, invites, WhatsApp logs. DPDP Act compliant. |
