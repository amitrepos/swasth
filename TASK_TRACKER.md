# Swasth App — Phase 1 Task Tracker

**Last Updated:** 2026-03-27
**Sprint:** 4 weeks + buffer | **Target:** Bihar pilot

Legend: ✅ Done &nbsp;|&nbsp; 🔄 Partial &nbsp;|&nbsp; ❌ Not started

---

## MODULE A — Core Architecture + Auth + Profiles

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| A1 | Phone OTP login | 🔄 Partial | Implemented as email + password + JWT (not Firebase phone OTP). OTP used only for password reset. Architecture decision in CLAUDE.md. |
| A2 | Multi-profile data model | ✅ Done | Full backend: profiles, profile_access, profile_invites tables. All 22 steps complete. |
| A3 | Profile creation | ✅ Done | `create_profile_screen.dart` — name, age, gender, height, blood group, conditions, medications. |
| A4 | Medication list | ✅ Done | Current medications text field in profile creation + edit. |
| A5 | "Add person without smartphone" | ✅ Done | Create a profile for someone else → caller becomes "owner". `create_profile_screen.dart`. |
| A6 | Language toggle (Hindi / English) | ❌ Not started | No `.arb` files, no i18n setup, no toggle UI. `intl` package used only for date formatting. |
| A7 | Profile switcher | ✅ Done | `select_profile_screen.dart` — lists all accessible profiles, tap to switch active profile. |
| A8 | Cloud sync | 🔄 Partial | PostgreSQL + FastAPI backend (cloud-deployable). No real-time Firestore/Supabase sync or offline queue. |
| A9 | Local offline storage | ❌ Not started | No local caching, no sync queue. App requires network for all reads/writes. |
| A10 | Invite family via WhatsApp | 🔄 Partial | Invite system works (email-based, `pending_invites_screen.dart`). No WhatsApp deep link / share-to-install flow. |
| A11 | Access permissions | ✅ Done | owner / viewer / editor levels via `profile_access` table. `dependencies.py` enforces access. |
| A12 | First-time onboarding | ❌ Not started | No onboarding screens (welcome → create profile → how to photograph → invite family). |

---

## MODULE B — Data Input: Photo + Manual + Sensors

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| B1 | Photo capture — glucose | ✅ Done | `photo_scan_screen.dart` + `ocr_service.dart`. ML Kit on-device OCR. Frame guide + flash toggle. |
| B2 | Photo capture — BP | ✅ Done | Same `photo_scan_screen.dart`, `deviceType: 'blood_pressure'`. Extracts systolic/diastolic/pulse. |
| B3 | Photo capture — weight | ❌ Not started | No weight screen or OCR logic for weighing scales. |
| B4 | Manual entry — glucose | ✅ Done | `reading_confirmation_screen.dart` — text field pre-filled from OCR, fully editable. |
| B5 | Manual entry — BP | ✅ Done | Same confirmation screen — systolic, diastolic, pulse fields. |
| B6 | Manual entry — weight | ❌ Not started | No weight entry form. Weight field exists in profile (height) but not in readings. |
| B7 | Height input | ✅ Done | Height field in `create_profile_screen.dart` and `profile_screen.dart`. |
| B8 | Confirmation screen | ✅ Done | `reading_confirmation_screen.dart` — "We read X — correct?" with edit + save. |
| B9 | "Log for someone else" | ✅ Done | Switch active profile in `select_profile_screen.dart` before logging — all readings go to active profile. |
| B10 | Phone pedometer | ❌ Not started | No pedometer package, no step counting. |
| B11 | Reading reminders | ❌ Not started | No local notifications package, no reminder scheduling. |
| B12 | Weekly weight reminder | ❌ Not started | Depends on B11. |
| B13 | Blurry photo detection | ✅ Done | `photo_scan_screen.dart` — if OCR returns near-empty text, shows "Photo is blurry — retake" dialog. |
| B14 | Flash toggle | ✅ Done | `photo_scan_screen.dart` — flash on/off button in app bar, uses `CameraController.setFlashMode()`. |
| B15 | Meal context tag | ✅ Done | `reading_confirmation_screen.dart` — Fasting / Before Meal / After Meal chips. Stored in `notes` field. |
| B16 | BLE auto-sync — glucometer | 🔄 Partial | `scan_screen.dart` + `lib/ble/glucose_service.dart` — BLE scan + RACP protocol exists. Full sync reliability untested. |
| B17 | BLE auto-sync — BP monitor | 🔄 Partial | `lib/ble/bp_service.dart` — BLE scan + BP characteristic parsing exists. Untested end-to-end. |
| B18 | BLE auto-sync — health band | 🔄 Partial | Armband device type in `scan_screen.dart`. No J-STYLE SDK integration. |
| B19 | Device management screen | 🔄 Partial | `scan_screen.dart` lists discovered BLE devices. No persistent paired-device list or reconnect flow. |

---

## MODULE C — Dashboard + Visualization

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| C1 | Today's summary card | 🔄 Partial | `dashboard_screen.dart` exists but shows BLE connection status. No health summary card (latest glucose, BP, steps). |
| C2 | Status badges (HIGH / NORMAL / LOW) | ✅ Done | `history_screen.dart` — color-coded badges. `_glucoseStatus()` and `_bpStatus()` helpers in confirmation screen. |
| C3 | BMI display | ❌ Not started | Height stored in profile; no weight readings table; no BMI calculation shown anywhere. |
| C4 | 7-day glucose trend chart | ❌ Not started | `fl_chart` package is installed but not used anywhere yet. |
| C5 | 7-day BP trend chart | ❌ Not started | Same — `fl_chart` ready, no chart screens built. |
| C6 | 7-day steps chart | ❌ Not started | Depends on B10 (pedometer). |
| C7 | 7-day heart rate chart | ❌ Not started | P1. Depends on B18 (health band). |
| C8 | Weekly weight trend | ❌ Not started | Depends on B3/B6 (weight input). |
| C9 | 30-day trend charts | ❌ Not started | P1. Depends on C4/C5. |
| C10 | Reading history | ✅ Done | `history_screen.dart` — scrollable list with timestamp, value, type filter, delete, status badges. |
| C11 | Streak counter | ❌ Not started | No streak logic on backend or frontend. |
| C12 | Empty states | 🔄 Partial | `history_screen.dart` has "No readings yet" empty state. Other screens may not. |
| C13 | Family view | ✅ Done | Profile switching gives any profile's dashboard/history. Shared profiles work via A2. |
| C14 | "Everything is okay" green signal | ❌ Not started | No cross-reading summary logic for family home screen. |
| C15 | Pull-to-refresh | 🔄 Partial | `history_screen.dart` may support it. No explicit RefreshIndicator confirmed across all screens. |
| C16 | Offline mode / "last synced" | ❌ Not started | Depends on A9. No cache layer. |
| C17 | Large text accessibility | ❌ Not started | P1. No font scaling or settings screen. |

---

## MODULE D — AI Insights + WhatsApp Notifications + Doctor

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| D1 | Cross-data insights (glucose × activity × sleep) | ❌ Not started | Rule engine not built. |
| D2 | Daily morning action tip | ❌ Not started | |
| D3 | Pattern detection (7+ day trends) | ❌ Not started | |
| D4 | BMI-to-glucose insight | ❌ Not started | Depends on C3. |
| D5 | Weight-glucose correlation | ❌ Not started | Depends on B3/B6. |
| D6 | Weekly summary | ❌ Not started | |
| D7 | Abnormal value alert (immediate) | ❌ Not started | Status flags exist in data; no push/WhatsApp trigger. |
| D8 | WhatsApp Business API integration | ❌ Not started | No Twilio/Gupshup setup. |
| D9 | Per-profile notification preferences | ❌ Not started | |
| D10 | Daily WhatsApp summary | ❌ Not started | Depends on D8. |
| D11 | Weekly WhatsApp summary | ❌ Not started | Depends on D8. |
| D12 | Alert WhatsApp message | ❌ Not started | Depends on D8. |
| D13 | Push notifications (backup) | ❌ Not started | P1. No FCM setup. |
| D14 | Doctor referral code | ❌ Not started | P1. |
| D15 | Doctor weekly WhatsApp summary | ❌ Not started | P1. |
| D16 | Streak notifications | ❌ Not started | Depends on C11. |

---

## PROGRESS SUMMARY

| Module | Done | Partial | Not Started | Total |
|--------|------|---------|-------------|-------|
| A — Auth + Profiles | 6 | 3 | 3 | 12 |
| B — Data Input | 9 | 4 | 6 | 19 |
| C — Dashboard | 4 | 4 | 9 | 17 |
| D — AI + Notifications | 0 | 0 | 16 | 16 |
| **Total** | **19** | **11** | **34** | **64** |

---

## NEXT PRIORITIES (P0 items not yet started)

### Short (< 1 day each)
- **C3** — BMI display: height is in profile, add weight to readings + auto-calculate BMI
- **C4/C5** — 7-day glucose + BP charts: `fl_chart` already installed, just needs chart screens
- **C11** — Streak counter: backend count of consecutive days with readings
- **C14** — "Everything is okay" signal: query today's readings, check all NORMAL

### Medium (1–2 days each)
- **A6** — Hindi/English toggle: add `.arb` files + `flutter_localizations`
- **A12** — First-time onboarding: 3-4 welcome screens
- **B10/B11** — Pedometer + reading reminders: add `pedometer` + `flutter_local_notifications` packages
- **B3/B6** — Weight photo + manual entry
- **A9** — Offline mode: add `hive` or `sqflite` local cache

### Blockers for Bihar Pilot
- **D7** — Abnormal value alert: critical safety feature — when a reading is CRITICAL, notify family
- **D8** — WhatsApp Business API: needs Meta approval (start ASAP — 2–5 day wait)
- **A6** — Language toggle: Hindi is essential for Bihar patients
