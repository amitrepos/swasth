# Swasth — Pending Tasks (Active Working File)

**Last Updated:** 2026-04-30
**Source of truth for all incomplete work. Completed tasks → see TASK_TRACKER_COMPLETED.md.**

Legend: 🔴 POC Blocker | 🟡 POC Nice-to-Have | 🔵 Post-Pilot | ⚪ Future/Defer

---

## 🔴 POC BLOCKERS — Must complete before Bihar pilot launch

| # | Task | Notes |
|---|------|-------|
| TLS | Replace self-signed cert | Blocks Android APK for real users. Needs real domain + Let's Encrypt. See "Reference Notes → TLS cert" below. |
| SEC1 | Rotate Postgres `swasth_admin` password | HIGH. Prod `.env` on EC2 13.127.215.113 still uses placeholder `swasth_temp_change_me`. Steps: `ALTER USER swasth_admin WITH PASSWORD '<strong>'`, update prod `.env` + GH Actions `STAGING_DATABASE_URL`, restart backend, smoke-test. Discovered 2026-04-29 during teammate DB onboarding. |
| SEC2 | Restrict SSH ingress on `swasth-ec2-sg` | HIGH (not P0). SG `sg-0383cfbd2ca13f4f7` (ap-south-1) allows 22/tcp from `0.0.0.0/0` because GH Actions deploys from dynamic IPs. Mitigations: managed prefix list (Lambda), migrate to SSM, or CI-temporary-allow pattern. Discovered 2026-04-29. |
| L1 | AWS Mumbai migration | CRITICAL. Blocks Play Store production. Do AFTER current bug fixes. Architecture: (1) EC2 t3.small — FastAPI + Nginx + Flutter web build. (2) RDS t3.micro PostgreSQL — all patient data, encrypted at rest, automated backups, HIPAA-eligible. (3) S3 bucket Mumbai — OCR images (future). (4) AWS Elastic IP — permanent static IP, free when attached to running instance. Steps: provision EC2+RDS in ap-south-1, scp backend files, pg_dump Hetzner → restore RDS, point api.swasth.health DNS to Elastic IP, run certbot, remove _PilotHttpOverrides from main.dart, rebuild APK. |
| L2 | Doctor Platform Use Agreement | CRITICAL. Lawyer must draft. Liability, clinical responsibility, NMC compliance. Blocks doctor onboarding. |
| L3 | Professional Indemnity Insurance | CRITICAL. Rs 25-50L coverage. ~Rs 15-25K/yr. Blocks doctor onboarding. |
| L4 | NMC disclaimers in UI | CRITICAL. "Clinical observation, not prescription" on AI notes. "Yeh salah hai, nuskha nahi" in Hindi. ~2 hour fix. |
| L5 | Update Patient Terms of Service | HIGH. Add platform liability, doctor data sharing, AI disclaimers. |
| L6 | DLT registration for SMS OTP | HIGH. TRAI requirement for SMS. Free, 3-5 day approval. Needed for WhatsApp Business scale. |
| L7 | Update Privacy Policy | HIGH. Add doctor data sharing, clinical notes, WhatsApp messaging sections. |

---

## 🟡 POC NICE-TO-HAVE — Improves pilot quality, not blocking

| # | Task | Notes |
|---|------|-------|
| D15 | Doctor weekly WhatsApp summary | ~2 hrs. D8 + D14 both done. Send weekly summary to doctor_whatsapp on profile. High NRI value. |
| D23 | AI responses in Hindi | AI insight/tips return English even when Hindi selected. Need Gemini translation pass. Affects ai-insight, trend-summary, meal tips. |
| C6 | 7-day steps chart | B10 (pedometer) now done. Steps collected — just need chart UI on dashboard. |
| C8 | Weekly weight trend | Treat weight as reading_type:"weight" — reuses existing chart infra. No schema change. |
| B11 | Reading reminders | flutter_local_notifications. Daily reminder to log BP/glucose. Improves retention. |
| A10 | WhatsApp invite (full) | Email invite works. Add WhatsApp deep link + share-to-install flow. |
| D2 | Daily morning action tip | Backend scheduler. One tip per day. Depends on B11 or D8. |
| F1 | NRI landing page + waitlist | swasth.health — hero, waitlist form, demo video embed. NRI acquisition. |
| F2 | NRI/family video (Script 1) | v3 script exists. Record app walkthrough + assemble with VO. |
| F6 | Facebook ad copy (3 variants) | Headlines + CTAs for NRI targeting. Ready to write. |
| F7 | Run NRI waitlist campaign | Rs 5-10K, 7 days. Needs F1 + F2 first. |

---

## 🔵 POST-PILOT — After 100 DAU or Bihar cohort validated

### Auth & Profiles
| # | Task | Notes |
|---|------|-------|
| A1 | Phone OTP login | Email/password works for pilot. Add Firebase/Gupshup OTP post-pilot. |
| A14 | Google OAuth | google_sign_in package. ~3 hrs. |
| A18 | Alembic DB migrations | Replace 10 hand-written migrate scripts. One-time ~30 min setup. |

### Data Input
| # | Task | Notes |
|---|------|-------|
| B3 | Photo capture — weight | OCR extension. Manual entry sufficient for now. |
| B6 | Manual entry — weight | Weight entry form. Unlocks C8 + D4 + D5. |
| B19 | Device management | Persistent paired-device list + auto-reconnect. |
| B21 | Store photo with reading | Save OCR image to server for audit trail. |

### Notifications
| # | Task | Notes |
|---|------|-------|
| D9 | Per-profile notification preferences | UI for notification opt-in/out. |
| D10 | Daily WhatsApp summary | D8 done. Schedule daily digest to patient. |
| D12 | Alert WhatsApp to doctor (direct) | Doctor gets direct reading alert (separate from family). |
| D13 | Push notifications (FCM) | firebase_messaging. Backup to WhatsApp. |
| D16 | Streak notifications | Alert on streak milestone or break. |

### AI / Insights
| # | Task | Notes |
|---|------|-------|
| D3 | Pattern detection (algorithmic) | Peaks, cycles, regression on 7+ day data. Currently visual-only. |
| D4 | BMI-to-glucose insight | Needs B6 first. |
| D5 | Weight-glucose correlation | Needs B6. |
| D6 | Weekly summary card | Avg/min/max summary card on dashboard. WhatsApp version already ships via report_service. |

### Doctor Portal (Module E) — Full feature set
| # | Task | Notes |
|---|------|-------|
| E1 | Doctor role model | UserRole enum, DoctorProfile table. Foundation for all E tasks. |
| E2 | Doctor registration + phone OTP | Gupshup SMS, NMC number, admin approval. |
| E3 | Doctor-patient linking | Doctor code system. Hindi consent screen. Revocable. |
| E4 | Doctor triage dashboard | Patients sorted by criticality. Web-first Flutter. |
| E5 | Doctor patient detail view | 2-column layout: profile+stats left, trends+readings right. |
| E6 | Doctor clinical notes | Private notes. 5-year NMC retention. |
| E7 | Doctor WhatsApp messaging | Hindi templates via Gupshup. |
| E8 | Doctor alert system | Critical alerts <5 min via WhatsApp. |
| E9 | Doctor follow-up flags | Flag patient for review in N days. |
| E10 | Doctor access audit trail | doctor_access_log table. DPDPA. |
| E11 | Doctor routes (backend) | routes_doctor.py. |

### Legal (Medium)
| # | Task | Notes |
|---|------|-------|
| L8 | SaMD Class A assessment | Due 90 days after launch. Engage regulatory consultant. |
| L9 | DPA with Gupshup | Standard Data Processing Agreement. Due 30 days post-launch. |
| L10 | Clinical notes retention policy | 5-year retention. Anonymize on patient deletion. |

### Admin Polish (key items only)
| # | Task | Notes |
|---|------|-------|
| G6a | Destructive action confirmation | Suspend/Reject needs proper modal + reason field. |
| G6b | Doctor verification checklist | Pre-approval checklist before approve button enables. |
| G6o | Session timeout warning | DPDPA PHI compliance. Auto-logout after inactivity. |
| G7 | Role management | Unify is_admin + role enum. |
| G8 | User search + filters + pagination | Essential at 50+ users. |
| G22 | Grievance redressal queue | DPDPA S13. 30-day SLA. |
| G23 | Minor user protections | DPDPA S9. Age flag, parental consent. |

### Marketing & Growth
| # | Task | Notes |
|---|------|-------|
| F8 | Script 2 — Patient Hindi video | After Bihar landing. |
| F9 | Script 3 — Doctor pitch video | For doctor onboarding push. |
| F13 | Company registration (Pvt Ltd) | Target end of May. Rs 15K. |
| F11 | NRI Facebook group organic posts | Join NRI groups when F1 page is live. |

---

## Partial / In-Progress

| # | Task | What's done | What's missing |
|---|------|-------------|----------------|
| A8 | Cloud sync | PostgreSQL + FastAPI, offline sync queue | Offline-first local cache (rolled back) |
| A10 | Family WhatsApp invite | Email invite + relationship dropdown | WhatsApp deep link + share-to-install |
| B18 | BLE health band | Device type detection in scan screen | Actual armband characteristic parsing (HR, steps) |
| B19 | Device management | Scan + list + connect | Persistent paired-device list, auto-reconnect |
| D1 | Cross-data insights | Glucose + BP cross-analysis | Activity + sleep (need health band / Health Connect) |
| D3 | Pattern detection | Visual 7/30/90 day charts | Algorithmic: peaks, cycles, regression |
| D6 | Weekly summary | WhatsApp report sends via report_service | Dashboard summary card (avg/min/max) |

---

## ⚪ FUTURE / DEFER — Post-seed or clear trigger required

| # | Task | Trigger to build |
|---|------|-----------------|
| A9 / C16 | Offline storage | Rural Bihar users reporting sync failures |
| B12 | Weekly weight reminder | After B11 + B6 done |
| B22 / C29 | Health Connect / Google Fit | NRI tier launch or doctor requests HR/sleep |
| B23 | Voice AI conversation | After B11 infra + STT validated |
| C7 | 7-day heart rate chart | After B18 health band is real (currently placeholder) |
| C17 | Large text accessibility | Before Play Store public release |
| D27 | AI eval harness (200 Indian cases) | Before fine-tuning MedGemma or custom clinical logic |
| D28 | Ambient ASR (MedASR) | After E6 (doctor notes) live + 5 doctors using portal |
| G10-G21 | Advanced admin features | Population health, cohort segmentation, breach tooling |
| F10 | Investor video | Phase 3 — pitch meetings |
| TD1 | Move `FoodClassificationResult` to `lib/models/` | Currently in `lib/screens/meal_result_screen.dart`. `NutritionAnalysisResult` is correctly in `lib/models/`. Low priority, no functional impact. |

---

## Reference Notes

### TLS cert (linked to 🔴 TLS row above)

Backend at `65.109.226.36:8443` currently uses a self-signed certificate. Browsers let users click past the warning, but `dart:io` on Android/iOS hard-rejects with `CERTIFICATE_VERIFY_FAILED: self signed certificate`, breaking every API call from native mobile builds.

**Temporary workaround (2026-04-11):** `lib/main.dart` installs a `_PilotHttpOverrides` class that trusts self-signed certs **only** for host `65.109.226.36` (other hosts still use normal TLS trust chain, web builds unaffected via `kIsWeb` guard). This unblocks the APK for pilot device testing.

**Must remove before public release:**
1. Point a real domain at the backend (or the server's IP if Let's Encrypt allows — it doesn't; needs a domain).
2. Provision a Let's Encrypt cert via certbot on the server.
3. Update nginx / uvicorn TLS config to use the real cert.
4. Delete `_PilotHttpOverrides` from `lib/main.dart` and its `HttpOverrides.global` install in `main()`.
5. Delete the `dart:io` imports that became unused.
6. Rebuild APK and verify handshake succeeds without the override.

**Why this is a hard blocker:** Shipping a cert-bypass in a public release means anyone on the patient's Wi-Fi can MITM every API call (tokens, health data, meal logs). It's scoped to one IP today, but "pilot-only" code has a way of surviving into GA if it's not tracked.

### Pilot data note — meals logged before 2026-04-11

Meals logged before the slot-tap fix (PR landing 2026-04-11) may have the wrong `meal_type` in the database. `quick_select_screen.dart` was hardcoding `mealType: detectMealType()` (wall-clock time), so any patient who tapped a specific slot ("Breakfast" / "Lunch" / "Snack" / "Dinner") had their saved `meal_type` overwritten with whatever slot the current hour matched. Fix plumbs the tapped slot type through `MealSummaryCard → home_screen → modal → QuickSelectScreen`.

**Impact:** anyone running `SELECT meal_type, count(*) FROM meal_logs GROUP BY meal_type` on pilot data will see a skew. If you need clean aggregate analytics on historical pilot data, EXCLUDE meals logged before the PR landed OR recompute `meal_type` from `created_at` using the old time-based rule for the pre-fix window only.

**Not backfilling:** per Dr. Rajesh's review, rewriting history has its own integrity risks (a patient's 4pm Breakfast would get relabelled to Snack if we retroactively ran the old rule, which is MORE wrong than leaving it alone). Small pilot N, no clinical decisions yet ride on historical `meal_type`. Revisit if/when pilot volume grows.

---

## Dependency Map

```
B6 (weight entry)    -> C8, D4, D5, B12
B11 (reminders)      -> D2, D16, B12
B18 real (health band) -> C7
D8 done              -> D10, D12, D15, D16, E7
E1 -> E2 -> E3 -> E4-E11 (sequential)
L1 (India server)    -> Play Store Production
L2 + L3              -> Doctor onboarding
F1 (landing page)    -> F7 (ad campaign)
TLS cert             -> Android APK for real users
```
