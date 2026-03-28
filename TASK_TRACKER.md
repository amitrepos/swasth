# Swasth App — Phase 1 Task Tracker

**Last Updated:** 2026-03-28
**Sprint:** 4 weeks + buffer | **Target:** Bihar pilot

Legend: ✅ Done &nbsp;|&nbsp; 🔄 Partial &nbsp;|&nbsp; ❌ Not started

---

## MODULE A — Core Architecture + Auth + Profiles

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| A1 | Phone OTP login | 🔄 Partial | Email + password + JWT only. Phone number collected at registration but unused for auth. OTP used only for password reset. No Firebase phone OTP. |
| A2 | Multi-profile data model | ✅ Done | Full backend: profiles, profile_access, profile_invites tables. All 22 steps complete. |
| A3 | Profile creation | ✅ Done | `create_profile_screen.dart` — name, age, gender, height, blood group, conditions, medications. |
| A4 | Medication list | ✅ Done | Current medications text field in profile creation + edit. |
| A5 | "Add person without smartphone" | ✅ Done | Create profile for someone else → caller becomes "owner". `create_profile_screen.dart`. |
| A6 | Language toggle (Hindi / English) | ✅ Done | Full gen-l10n: `app_en.arb` + `app_hi.arb`, all UI strings via `AppLocalizations`. Toggle chip in Profile → Settings section. Language persisted via `languageProvider` (Riverpod). |
| A7 | Profile switcher | ✅ Done | `select_profile_screen.dart` — lists all accessible profiles, tap to switch active profile. |
| A8 | Cloud sync | 🔄 Partial | PostgreSQL + FastAPI (cloud-deployable). No real-time sync or offline queue. |
| A9 | Local offline storage | ❌ Not started | `flutter_secure_storage` stores auth token, profile ID, language — not health readings. No hive/sqflite cache for readings. App requires network for all health data reads/writes. |
| A10 | Invite family via WhatsApp | 🔄 Partial | Email-based invite works (`pending_invites_screen.dart`). No `share_plus`, no WhatsApp deep link or share-to-install flow. |
| A11 | Access permissions | ✅ Done | owner / viewer / editor levels via `profile_access` table. `dependencies.py` enforces access. |
| A12 | First-time onboarding | ❌ Not started | Registration screen collects health info during signup but there are no dedicated onboarding/welcome carousel screens (welcome → how to photograph → invite family flow). |

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
| C3 | BMI display | ❌ Not started | Height in profile; no weight readings table; no BMI calculation anywhere in codebase. |
| C4 | 7-day glucose trend chart | ✅ Done | `trend_chart_screen.dart` — LineChart, normal range band (70–130), color-coded dots, stats row. |
| C5 | 7-day BP trend chart | ✅ Done | Same screen — systolic (rose) + diastolic lines, normal range bands, avg/normal% stats. |
| C6 | 7-day steps chart | ❌ Not started | Depends on B10 (pedometer). |
| C7 | 7-day heart rate chart | ❌ Not started | Depends on B18 (health band). |
| C8 | Weekly weight trend | ❌ Not started | Depends on B3/B6. |
| C9 | 30-day trend charts | ✅ Done | `trend_chart_screen.dart` — 7-day / 30-day tab toggle on both glucose and BP charts. |
| C10 | Reading history | ✅ Done | `history_screen.dart` — scrollable list, timestamp, type filter, delete, status badges. |
| C11 | Streak counter | ✅ Done | Backend: consecutive-days logic in `GET /api/readings/health-score`. Shown in gamification panel. |
| C12 | Empty states | ✅ Done | Health score card has empty/no-profile state. History has "No readings yet". Home screen handles null profileId. |
| C13 | Family view | ✅ Done | Profile switching gives any profile's dashboard/history. Shared profiles work via A2. |
| C14 | "Everything is okay" green signal | ✅ Done | `_StatusFlag` widget shows 🟢 "Fit & Fine" when score ≥ 70 and all readings NORMAL. Age-adjusted. |
| C15 | Pull-to-refresh | ✅ Done | `select_profile_screen.dart` — `RefreshIndicator`. Home screen has refresh on health score card + `RouteAware.didPopNext`. |
| C16 | Offline mode / "last synced" | ❌ Not started | Depends on A9. No cache layer for health readings. |
| C17 | Large text accessibility | ❌ Not started | No `MediaQuery.textScaleFactor` usage. All font sizes hardcoded. |
| C18 | Health Score widget (home screen) | ✅ Done | 0–100 score ring (green/orange/red), `GET /api/readings/health-score`. Tappable → trend charts. |
| C19 | Streak counter on home screen | ✅ Done | Shown in `_GamificationPanel` — "🔥 N-day streak" chip. |
| C20 | AI insight text (rule-based) | ✅ Done | Plain-English tip from last 7 days. Pure rule engine. Differentiates Stage 2 BP with urgent messaging. |
| C21 | Glucose × BP correlation chart | ✅ Done | `trend_chart_screen.dart` — both charts on same scrollable screen, 7/30-day tabs. |
| C22 | Design3 visual theme | ✅ Done | Full Design3 palette: glucose=#34D399, BP=#FB7185, accent=#7B61FF, dark navy. All screens migrated. |
| C23 | Dynamic health status flag | ✅ Done | `_StatusFlag` widget in health score card header. Four states: 🟢 Fit & Fine / 🟡 Caution / 🟠 At Risk / 🚨 Urgent. Age-adjusted thresholds (strict <30, lenient 60+). |
| C24 | Gamification — streak points + leaderboard | ✅ Done | `_GamificationPanel`: points tiers (1d=10, 3d=100, 7d=300, 14d=700, 30d=1500), Weekly Winners placeholder with 3 avatar chips (coming soon). |

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
| D14 | Doctor referral code | ❌ Not started | No user role for doctor, no referral generation or assignment logic. |
| D15 | Doctor weekly WhatsApp summary | ❌ Not started | Depends on D8 + D14. |
| D16 | Streak notifications | ❌ Not started | Streak calculated and shown visually. No push/WhatsApp alert when streak is broken or reached. |
| D17 | AI Doctor card (Gemini 1.5 Flash) | ✅ Done | `GET /api/readings/ai-insight` — 7-day readings + profile → age-aware Gemini prompt → 1-2 sentence recommendation. Daily cache per profile, invalidated on new reading save. Urgent tone for Stage 2 BP / CRITICAL. Rule-based fallback. `_AIDoctorCard` widget with shimmer + `RouteAware` refresh. |

---

## PROGRESS SUMMARY

| Module | Done | Partial | Not Started | Total |
|--------|------|---------|-------------|-------|
| A — Auth + Profiles | 7 | 3 | 2 | 12 |
| B — Data Input | 12 | 2 | 6 | 20 |
| C — Dashboard | 19 | 0 | 5 | 24 |
| D — AI + Notifications | 1 | 3 | 13 | 17 |
| **Total** | **39** | **8** | **26** | **73** |

---

## BLOCKING GAPS (multiple features depend on these)

| Blocker | Blocks |
|---|---|
| No notification infrastructure (`flutter_local_notifications`, FCM) | D2, D7, D9, D13, D16 |
| No WhatsApp API (Twilio/Gupshup) | D8, D10, D11, D12, D15 |
| No weight tracking (B3, B6) | C8, D4, D5, D6 (full) |
| No pedometer (B10) | C6, D1 (full), D2 |
| No doctor/referral system | D14, D15 |

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
