# PHASE 1 — App Feature List & Development Task Breakdown

**Last Updated:** March 26, 2026
**Framework:** Flutter (Android + iOS from one codebase)
**Team:** 4 developers (including founder)
**Sprint Duration:** 4 weeks (Week 5 = buffer/BLE prep)
**Target:** App ready for Bihar pilot with photo-based data input

---

## ARCHITECTURE OVERVIEW

### Single App, Multi-Profile Design

One app for everyone — patients, family members, and eventually doctors. No separate "patient app" or "family app."

```
┌─────────────────────────────────────────┐
│              HOME SCREEN                 │
│                                         │
│  [Papa's Health] [Mummy's Health] [+]   │
│                                         │
│           [My Own Health]               │
│                                         │
│  Tap any card → see full dashboard      │
└─────────────────────────────────────────┘
```

### Data Flow

```
Patient's Device (any glucometer/BP monitor)
        │
        ▼
┌──────────────────┐     ┌──────────────────┐
│  Photo Capture   │ OR  │  BLE Auto-Sync   │
│  (any device)    │     │  (OEM kit, later) │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         ▼                        ▼
┌──────────────────────────────────────────┐
│           AI OCR / BLE Parser            │
│         Extract: value + timestamp       │
└────────────────────┬─────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────┐
│            Patient Profile               │
│   (cloud-synced, accessible by family)   │
└────────────────────┬─────────────────────┘
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
    ┌──────────┐ ┌────────┐ ┌──────────┐
    │Dashboard │ │AI      │ │WhatsApp  │
    │+ Charts  │ │Insights│ │Notif to  │
    │          │ │Engine  │ │Family +  │
    │          │ │        │ │Doctor    │
    └──────────┘ └────────┘ └──────────┘
```

### Notification Strategy

| Channel | Role | Why |
|---------|------|-----|
| WhatsApp Business API | PRIMARY | 100% delivery in India, always read |
| Push Notifications | BACKUP | For in-app alerts, may be killed by Android battery optimization |
| SMS | FALLBACK | For patients without WhatsApp (rare but possible in rural Bihar) |

---

## COMPLETE FEATURE LIST

### MODULE A: Core Architecture + Auth + Profiles

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| A1 | Phone OTP login | Firebase Auth — phone number + OTP, no email/password | P0 |
| A2 | Multi-profile data model | User account → owns profiles → each profile has readings, insights, connections | P0 |
| A3 | Profile creation | Name, age, gender, height (one-time), conditions (diabetes/hypertension/both) | P0 |
| A4 | Medication list | Patient adds medicines: name, dosage, frequency — stored in profile | P0 |
| A5 | "Add person without smartphone" | Family member creates a profile for someone else on their own phone | P0 |
| A6 | Language toggle | Hindi / English — switchable anytime, stored per user | P0 |
| A7 | Profile switcher | Home screen shows all profiles user has access to — tap to switch | P0 |
| A8 | Cloud sync | Firestore or Supabase — profiles, readings, insights sync across devices | P0 |
| A9 | Local offline storage | App works offline — syncs when connection returns | P0 |
| A10 | Invite family via WhatsApp | Generate deep link → share via WhatsApp → recipient installs app → auto-connects to profile | P0 |
| A11 | Access permissions | Profile owner = full access. Family = view + log. Doctor = view only (later) | P0 |
| A12 | First-time onboarding | 3-4 screens: welcome → create profile → how to photograph glucometer → invite family | P0 |

### MODULE B: Data Input — Photo + Manual + Sensors

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| B1 | Photo capture — glucose | Camera → frame guide overlay → capture → AI OCR → extract mg/dL value → confirm | P0 |
| B2 | Photo capture — BP | Camera → frame guide → capture → OCR → extract systolic/diastolic/pulse → confirm | P0 |
| B3 | Photo capture — weight | Camera → frame guide → capture → OCR → extract kg value → confirm | P0 |
| B4 | Manual entry — glucose | Simple number input field, used as fallback if OCR fails | P0 |
| B5 | Manual entry — BP | Three fields: systolic, diastolic, pulse | P0 |
| B6 | Manual entry — weight | Simple number input with kg/lbs toggle | P0 |
| B7 | Height input | One-time during profile setup, manual entry (cm or ft/in) | P0 |
| B8 | Confirmation screen | "We read 153 mg/dL — is this correct?" with edit option + save button | P0 |
| B9 | "Log for someone else" | Before capture, select which profile to save to (if user has multiple) | P0 |
| B10 | Phone pedometer | Background step counting via Android/iOS sensor API | P0 |
| B11 | Reading reminders | Configurable scheduled local notifications ("Time to check morning sugar") | P0 |
| B12 | Weekly weight reminder | Sunday morning reminder: "Time for your weekly weigh-in" | P1 |
| B13 | Blurry photo detection | If photo quality too low, prompt: "Photo is blurry, please retake" | P0 |
| B14 | Flash toggle | Camera flash on/off for photographing device screens in low light | P0 |
| B15 | Meal context tag | After logging glucose, optional: "Before meal" / "After meal" / "Fasting" | P0 |
| B16 | BLE auto-sync — glucometer | Pair via Bluetooth, auto-receive readings (Transtek SDK) | P1 (when hardware arrives) |
| B17 | BLE auto-sync — BP monitor | Pair via Bluetooth, auto-receive readings (Transtek SDK) | P1 |
| B18 | BLE auto-sync — health band | Continuous HR streaming (J-STYLE SDK) | P1 |
| B19 | Device management screen | List paired devices — add/remove/reconnect | P1 |

### MODULE C: Dashboard + Visualization

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| C1 | Today's summary card | Latest glucose, BP, weight, heart rate, steps — one screen overview | P0 |
| C2 | Status badges | HIGH (red) / NORMAL (green) / LOW (yellow) for each reading | P0 |
| C3 | BMI display | Auto-calculated from height + weight, shown with category badge (Normal/Overweight/Obese) | P0 |
| C4 | 7-day glucose trend chart | Line chart with normal range band highlighted | P0 |
| C5 | 7-day BP trend chart | Two lines — systolic and diastolic — with normal range band | P0 |
| C6 | 7-day steps chart | Bar chart — daily steps with goal line | P0 |
| C7 | 7-day heart rate chart | Line chart (when band data available) | P1 |
| C8 | Weekly weight trend | Line chart showing weight over weeks | P0 |
| C9 | 30-day trend charts | All metrics — monthly view | P1 |
| C10 | Reading history | Scrollable list: timestamp + value + who logged it + meal context + HIGH/NORMAL/LOW badge | P0 |
| C11 | Streak counter | "Checked sugar for 23 days in a row" with visual flame/star indicator | P0 |
| C12 | Empty states | Friendly messages when no data yet: "No readings yet. Tap + to log your first reading" | P0 |
| C13 | Family view | Same dashboard components but viewing someone else's profile (read-only badge shown) | P0 |
| C14 | "Everything is okay" signal | Green checkmark on family home screen when all today's readings are normal | P0 |
| C15 | Pull-to-refresh | Refresh data from cloud | P0 |
| C16 | Offline mode | Show cached data with "last synced X minutes ago" indicator | P0 |
| C17 | Large text accessibility | Larger fonts for elderly users — auto-detect or manual setting | P1 |

### MODULE D: AI Insights + Notifications + Doctor

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| D1 | Cross-data insights | Connect glucose to activity, sleep, weight: "Sugar was 165 — you walked only 800 steps and slept 4.5 hrs" | P0 |
| D2 | Daily morning action tip | One specific recommendation shown in app and sent via WhatsApp: "Walk 20 min after lunch today" | P0 |
| D3 | Pattern detection | "Your sugar is consistently high on days you walk less than 2,000 steps" (needs 7+ days of data) | P0 |
| D4 | BMI-to-glucose insight | "Your BMI is 28.4. Losing 3 kg could reduce your fasting sugar by 10-15 mg/dL" | P0 |
| D5 | Weight-glucose correlation | "You lost 1.5 kg this month — your avg sugar also dropped 12 mg/dL. Keep going." | P0 |
| D6 | Weekly summary | "This week: 5/7 days normal sugar, BP stable, avg 3,200 steps, weight down 0.5 kg" | P0 |
| D7 | Abnormal value alert | IMMEDIATE notification when reading is dangerously high or low | P0 |
| D8 | WhatsApp Business API integration | Primary notification channel for all messages | P0 |
| D9 | Per-profile notification preferences | Each family member chooses per profile: real-time / daily summary / weekly summary / alerts only / off | P0 |
| D10 | Daily WhatsApp summary | Morning message to family: "Papa yesterday: Sugar 138 (Normal), BP 128/82 (Normal), 3,200 steps" | P0 |
| D11 | Weekly WhatsApp summary | Monday morning message with week's averages and trends | P0 |
| D12 | Alert WhatsApp message | "⚠️ Papa's BP was 172/98 — HIGH. Consider calling." | P0 |
| D13 | Push notifications (backup) | Same messages via push for users who also want in-app notifications | P1 |
| D14 | Doctor referral code | Doctor gets a unique code — patient enters during onboarding to link to their doctor | P1 |
| D15 | Doctor weekly WhatsApp summary | Auto-generated: "Dr. Sharma: 20 patients this week. 3 with high sugar. 2 with rising BP. 15 stable." | P1 |
| D16 | Streak notifications | "Papa has checked his sugar for 30 days straight! 🔥" sent to family via WhatsApp | P0 |

---

## EXPLICITLY NOT IN PHASE 1

| Feature | Why not now | When |
|---------|-----------|------|
| Food photo AI | Needs massive training data for Indian dishes | Phase 2 (Month 8+) |
| Pharmacy/medicine ordering | Needs partnerships | Phase 2 |
| Doctor web portal | WhatsApp summary is enough for pilot | Phase 2 (Month 5-6) |
| Doctor approves/rejects AI recommendations | Medical liability questions | Phase 3 |
| Health Vault (OCR lab reports) | Nice to have, not core hypothesis | Phase 2 |
| Subscription/payment | Free during pilot | Month 6-7 |
| Video/voice health coach | Expensive, unscalable | Phase 3 |
| Calorie tracking / diet plans | Overbuilding — weight + BMI is enough for now | Phase 2 |
| ML-based AI model | Rule-based v1 is enough — train ML when you have 1000+ patient-days of data | Phase 2 |

---

## DEVELOPMENT TASK BREAKDOWN — 4 WEEKS, 4 DEVELOPERS

### DEV 1: Core Architecture + Auth + Profiles (Architect/Lead)

**Owns:** Data model, authentication, profile management, invite system. This is the foundation — everything depends on it.

| Week | Task | Est. Days | Dependency |
|------|------|-----------|------------|
| **W1** | | | |
| | Firebase project setup + OTP auth flow + phone login screens | 2 | None |
| | Multi-profile data model design — users, profiles, readings, access permissions | 2 | None |
| | Cloud backend setup (Firestore/Supabase) — collections, security rules, sync logic | 1 | None |
| **W2** | | | |
| | Profile creation flow — onboarding screens, condition selection, medication list entry | 2 | W1 data model |
| | Height input during profile setup | 0.5 | W1 data model |
| | "Add person without smartphone" flow | 1 | W1 data model |
| | Language toggle — Hindi/English string localization framework | 1 | None |
| | Share data model docs with all devs, answer integration questions | 0.5 | — |
| **W3** | | | |
| | Invite link generation — create unique deep link per profile | 1.5 | W1 auth |
| | Deep link handling — WhatsApp share → app opens → auto-connect to profile | 1.5 | W3 invite link |
| | Profile switcher on home screen — card layout, tap to switch active profile | 1 | W1 data model |
| | Offline mode — local storage + sync queue when online | 1 | W1 cloud sync |
| **W4** | | | |
| | End-to-end integration testing with all modules | 3 | All modules |
| | Bug fixes from integration | 2 | — |

### DEV 2: Data Input — Photo Capture + Manual + Sensors

**Owns:** Camera, OCR, manual entry, pedometer, reading reminders. The hero feature of Phase 1.

| Week | Task | Est. Days | Dependency |
|------|------|-----------|------------|
| **W1** | | | |
| | Camera screen UI — frame guide overlay ("center device screen here") | 1 | None |
| | Flash toggle button on camera screen | 0.5 | W1 camera UI |
| | Google ML Kit / Cloud Vision API integration — send photo → get text | 2 | None |
| | OCR parsing logic — extract glucose value (mg/dL) from recognized text | 1 | W1 Vision API |
| | OCR parsing logic — extract BP values (systolic/diastolic/pulse) | 0.5 | W1 Vision API |
| **W2** | | | |
| | OCR parsing logic — extract weight (kg) from weighing scale photo | 0.5 | W1 Vision API |
| | Confirmation screen — "We read 153 mg/dL — correct?" + edit option + save | 1 | W1 OCR |
| | Manual entry fallback — glucose, BP (3 fields), weight — simple form | 1 | None |
| | Meal context tag — "Fasting" / "Before meal" / "After meal" selection after glucose | 0.5 | W2 confirmation |
| | "Log for someone else" — profile selector before capture | 1 | Dev 1 W1 data model |
| | Phone pedometer — background step counting integration | 1 | None |
| **W3** | | | |
| | Reading reminders — configurable scheduled local notifications | 1.5 | None |
| | Weekly weight reminder (Sunday morning) | 0.5 | W3 reminders |
| | Blurry photo detection — analyze image quality, prompt retake if too low | 1 | W1 camera |
| | Edge case handling — different device screen formats, LCD vs OLED, angled photos | 2 | W1 OCR |
| **W4** | | | |
| | Test with 10+ real glucometer/BP/weight devices: Dr. Morepen, Accu-Chek, Omron, OneTouch, generic scales | 3 | Physical devices |
| | Fix OCR failures per device model | 2 | W4 testing |

**Devices to test OCR with:**
- Dr. Morepen BG-03 glucometer (₹650 — cheapest, worst LCD)
- Accu-Chek Active (non-BT) glucometer
- Accu-Chek Instant (BT) glucometer
- OneTouch Select Plus glucometer
- Omron HEM-7120 BP monitor (non-BT, basic)
- Omron HEM-7143T1A BP monitor (BT)
- Dr. Morepen BP monitor
- Any basic digital weighing scale (₹500-1000)

### DEV 3: Dashboard + Visualization + Streaks

**Owns:** All display screens, charts, trends, family view. Must be clean and readable for 55+ year old eyes.

**Design Principles:**
- Minimum font size: 16sp for body, 24sp for reading values
- High contrast colors: dark text on white, bright colors for badges
- Big tap targets: minimum 48dp touch area for buttons
- Simple navigation: bottom tab bar with 3-4 tabs max

| Week | Task | Est. Days | Dependency |
|------|------|-----------|------------|
| **W1** | | | |
| | Today's summary card — latest reading per metric type | 2 | Dev 1 W1 data model |
| | Status badges — HIGH (red) / NORMAL (green) / LOW (yellow) with thresholds | 1 | W1 summary card |
| | BMI auto-calculation + category badge display | 0.5 | Dev 1 W2 profile |
| | Reading history list — scrollable, timestamp + value + who logged + meal context + badge | 1.5 | Dev 1 W1 data model |
| **W2** | | | |
| | 7-day glucose trend chart (fl_chart package — line chart with normal range band) | 1.5 | Dev 1 W1 data model |
| | 7-day BP trend chart (two lines — systolic/diastolic + normal range) | 1 | W2 glucose chart (reuse component) |
| | 7-day steps bar chart with daily goal line | 1 | Dev 2 W2 pedometer |
| | Weekly weight trend line chart | 1 | Dev 2 W2 weight input |
| | Streak counter — visual flame/star + day count | 0.5 | Dev 1 W1 data model |
| **W3** | | | |
| | "Everything is okay" green checkmark on family home screen | 1 | Dev 1 W3 profile switcher |
| | Family view — same dashboard but viewing another profile (read-only indicator shown) | 1 | Dev 1 W3 profile switcher |
| | 30-day trend charts (extended view of same chart components) | 1.5 | W2 charts |
| | Empty states for all screens — friendly messages + action prompts | 1 | — |
| | Pull-to-refresh + loading states | 0.5 | Dev 1 W1 cloud sync |
| **W4** | | | |
| | Offline mode display — "last synced X min ago" indicator | 1 | Dev 1 W3 offline |
| | Large text accessibility option in settings | 1 | — |
| | Visual polish — consistent spacing, colors, shadows | 1.5 | — |
| | Cross-device testing (different screen sizes, Android 9+) | 1.5 | — |

### DEV 4: AI Insights + WhatsApp Notifications + Doctor

**Owns:** The intelligence layer and all external communications. This is what makes the app more than a data logger.

**AI Insights v1 — Rule-Based Engine:**
Use clinical guidelines, not ML. Simple if/then rules:
```
IF fasting_glucose > 140 AND steps_yesterday < 2000
  → "Your fasting sugar was high. Try a 20-minute walk after lunch today."

IF weight_this_month < weight_last_month AND avg_glucose_this_month < avg_glucose_last_month  
  → "You lost X kg this month and your sugar dropped too. The correlation is real."

IF bp_systolic > 140 for 3+ consecutive readings
  → ALERT: "BP has been high for 3 days. Please consult your doctor."

IF streak_days >= 7
  → "Amazing! 7-day streak of checking your sugar. Keep it going."

IF bmi > 25 AND fasting_glucose > 130
  → "Your BMI is X. Losing 2-3 kg could reduce sugar by 10-15 mg/dL."
```

| Week | Task | Est. Days | Dependency |
|------|------|-----------|------------|
| **W1** | | | |
| | WhatsApp Business API setup — register business number, apply for API access | 1 | None (start ASAP — Meta approval takes 2-5 days) |
| | WhatsApp message template creation + submit for Meta approval | 1 | W1 API setup |
| | Templates needed: daily summary, weekly summary, abnormal alert, streak celebration, doctor summary | | |
| | Notification preference settings screen — per-profile: real-time / daily / weekly / alerts only / off | 2 | Dev 1 W1 data model |
| | Backend notification scheduler — cron jobs for daily (8 AM) and weekly (Monday 8 AM) summaries | 1 | W1 API setup |
| **W2** | | | |
| | Abnormal value alert system — triggers on reading save | 1 | Dev 2 W2 save reading |
| | Alert sends WhatsApp to patient + all connected family members | 1 | W1 WhatsApp API |
| | Daily summary generator — compile yesterday's readings into one message | 1.5 | Dev 1 W1 data model |
| | Daily morning action tip — one specific recommendation based on recent data | 1.5 | W2 summary generator |
| **W3** | | | |
| | AI insights engine — rule-based v1 (10-15 rules covering glucose, BP, steps, weight, BMI correlations) | 3 | Dev 1 W1 data model |
| | Display insights in app — card format on dashboard ("Today's Insight") | 1 | W3 AI engine |
| | Streak notifications via WhatsApp — "Papa has checked sugar 30 days straight!" | 1 | Dev 1 W1 data model |
| **W4** | | | |
| | Weekly summary generator + WhatsApp delivery | 1 | W3 AI engine |
| | Doctor referral code system — generate code, patient enters during onboarding | 1 | Dev 1 W2 profile |
| | Doctor weekly WhatsApp summary — auto-generated flagged patient report | 1.5 | W3 AI engine |
| | Edge case testing — no readings this week, family notifications off, doctor has 0 patients | 1.5 | — |

---

## PARALLEL TRACK GANTT VIEW

```
         Week 1          Week 2          Week 3          Week 4         Week 5 (Buffer)
DEV 1:  [Auth+OTP      ][Profiles+Lang ][Invite+Offline ][Integration   ][BLE Prep     ]
         [Data Model    ][Height+NoPhone][ProfileSwitch  ][Bug Fixes     ][OEM SDK Study]
         [Cloud Setup   ][Share w/ team ][                                              ]

DEV 2:  [Camera UI     ][Confirm+Manual][Reminders      ][Device Testing][BLE Glucomtr ]
         [Vision API    ][Weight Photo  ][Blurry Detect  ][OCR Fixes     ][BLE BP       ]
         [OCR Glucose   ][Meal Tag      ][Edge Cases     ][              ][             ]
         [OCR BP        ][Pedometer     ][               ][              ][             ]

DEV 3:  [Summary Card  ][Glucose Chart ][OK Signal      ][Offline UI    ][Polish       ]
         [Status Badges ][BP Chart      ][Family View    ][Large Text    ][             ]
         [BMI Display   ][Steps Chart   ][30-day Charts  ][Visual Polish ][             ]
         [History List  ][Weight Chart  ][Empty States   ][Cross-device  ][             ]
         [              ][Streak Counter][Pull-refresh   ][              ][             ]

DEV 4:  [WhatsApp API  ][Abnormal Alert][AI Engine Rules][Weekly Summary][Doctor Portal]
         [Templates     ][Daily Summary ][Insight Cards  ][Doctor Code   ][Planning     ]
         [Notif Prefs   ][Action Tip    ][Streak Notif   ][Doctor Summary][             ]
         [Scheduler     ][              ][               ][Edge Cases    ][             ]
```

---

## INTEGRATION POINTS — Where Devs Must Coordinate

| When | What | From → To | Action Required |
|------|------|-----------|-----------------|
| End of W1 | Data model finalized | Dev 1 → ALL | Dev 1 shares Firestore schema doc. All devs use same structure. |
| W2 Day 1 | Reading save function | Dev 2 → Dev 4 | When a reading is saved, trigger notification check in Dev 4's module |
| W2 Day 1 | Dashboard data source | Dev 1 → Dev 3 | Dev 3 reads from Dev 1's data model to populate charts |
| W2 | Profile linkage | Dev 1 → Dev 2 | Dev 2's "log for someone else" uses Dev 1's profile switcher |
| W3 | AI needs reading history | Dev 4 → Dev 1 | Dev 4's insight engine queries Dev 1's data model for patterns |
| W3 | Family view | Dev 3 → Dev 1 | Dev 3's dashboard components render for any profile via Dev 1's switcher |
| W3 | Streak data | Dev 3 + Dev 4 → Dev 1 | Both need streak count from Dev 1's data model |
| W4 | Everything connected | ALL | Full end-to-end test: photo → save → dashboard → insight → WhatsApp |

**Daily standup recommended (15 min):** Each dev shares what they built yesterday, what they're building today, and any blockers. Critical during weeks 3-4 when integration happens.

---

## TECHNICAL DECISIONS

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Framework | Flutter | Android + iOS from one codebase |
| Auth | Firebase Auth (phone OTP) | Free tier covers pilot, reliable in India |
| Database | Cloud Firestore | Real-time sync, offline support, scales easily |
| OCR | Google ML Kit (on-device) + Cloud Vision API (fallback) | ML Kit = free, fast, works offline. Cloud Vision = more accurate for difficult screens. |
| Charts | fl_chart package | Lightweight, customizable, well-maintained |
| BLE (Phase 1.5) | flutter_blue_plus package | Best maintained Flutter BLE library |
| WhatsApp | WhatsApp Business API (via provider like Twilio/Gupshup) | Gupshup is cheaper for India. ~₹0.50-1.00 per template message. |
| Notifications | Firebase Cloud Messaging (push) + WhatsApp (primary) | FCM for in-app, WhatsApp for guaranteed delivery |
| State Management | Riverpod or BLoC | Team preference — either works |
| Localization | Flutter intl / arb files | Standard approach for Hindi/English |

---

## AI INSIGHTS — RULE ENGINE v1

### Clinical Thresholds

| Metric | LOW | NORMAL | HIGH | CRITICAL |
|--------|-----|--------|------|----------|
| Fasting glucose | <70 mg/dL | 70-130 mg/dL | 131-180 mg/dL | >180 mg/dL |
| Post-meal glucose | <70 mg/dL | 70-140 mg/dL | 141-200 mg/dL | >200 mg/dL |
| Systolic BP | <90 mmHg | 90-130 mmHg | 131-140 mmHg | >140 mmHg |
| Diastolic BP | <60 mmHg | 60-85 mmHg | 86-90 mmHg | >90 mmHg |
| BMI | <18.5 | 18.5-22.9 | 23-27.5 | >27.5 |
| Resting HR | <50 bpm | 50-100 bpm | — | >100 bpm |
| Daily steps | — | >5,000 | — | <1,000 |

Note: BMI thresholds use Asian/Indian standards (lower than Western standards).

### Rule Examples (implement 10-15 rules for v1)

```
RULE: glucose_activity_correlation
  IF avg_glucose_on_active_days < avg_glucose_on_sedentary_days
  AND difference > 10 mg/dL
  → "On days you walk 3,000+ steps, your sugar averages [X] vs [Y] on inactive days. Walking works for you."

RULE: weight_glucose_trend
  IF weight_change_30d < 0 (losing weight)
  AND avg_glucose_change_30d < 0 (sugar improving)
  → "You lost [X] kg this month and your sugar dropped [Y] mg/dL. Keep going!"

RULE: bmi_recommendation
  IF bmi > 25 AND fasting_glucose > 130
  → "Your BMI is [X]. Losing [Y] kg would bring you to normal BMI. Patients at normal BMI typically see sugar drop 10-20 mg/dL."

RULE: bp_consistency
  IF bp_systolic within 90-130 for 5+ consecutive readings
  → "Your BP has been stable for [X] days. Whatever you're doing, keep it up."

RULE: bp_trending_up
  IF bp_systolic increasing for 3+ consecutive readings
  → ALERT to patient + family + doctor: "BP has been rising for [X] days. Please consult your doctor."

RULE: missed_reading_nudge
  IF no glucose reading today AND time > 10 AM
  → "You haven't checked your sugar yet today. A quick check helps your AI coach learn your patterns."

RULE: streak_celebration
  IF consecutive_days_with_reading >= 7 (multiples of 7)
  → "[X]-day streak! Consistent monitoring is the #1 predictor of better health outcomes."

RULE: fasting_timing
  IF fasting_glucose readings mostly taken after 9 AM
  → "Try checking your fasting sugar before 8 AM — earlier readings are more accurate for fasting levels."

RULE: meal_impact
  IF post_meal_glucose - pre_meal_glucose > 50 mg/dL (frequent)
  → "Your sugar spikes significantly after meals. Try a 15-minute walk right after eating."

RULE: morning_tip
  Every morning at 7 AM, pick the most relevant insight from the rules engine
  → Send as daily WhatsApp tip + show as "Today's Insight" card in app
```

---

## WHATSAPP MESSAGE TEMPLATES (submit to Meta for approval)

### Template 1: Daily Summary
```
Good morning! Here's {{patient_name}}'s health update for {{date}}:

🩸 Sugar: {{glucose_value}} mg/dL — {{glucose_status}}
💓 BP: {{bp_value}} mmHg — {{bp_status}}
🚶 Steps: {{step_count}}

💡 Tip: {{daily_tip}}

Open app for details: {{app_link}}
```

### Template 2: Weekly Summary
```
{{patient_name}}'s weekly health report ({{week_dates}}):

🩸 Avg Sugar: {{avg_glucose}} mg/dL ({{glucose_trend}})
💓 Avg BP: {{avg_bp}} mmHg ({{bp_trend}})
🚶 Avg Steps: {{avg_steps}}/day
⚖️ Weight: {{weight}} kg ({{weight_change}})
🔥 Streak: {{streak_days}} days

{{weekly_insight}}
```

### Template 3: Abnormal Alert
```
⚠️ Alert for {{patient_name}}:

{{metric_name}}: {{value}} — {{status}}

{{recommendation}}

Please check on them.
```

### Template 4: Streak Celebration
```
🎉 {{patient_name}} has checked their health for {{streak_days}} days in a row!

Consistent monitoring is the best thing for managing {{condition}}. Keep encouraging them!
```

### Template 5: Doctor Weekly Summary
```
Dr. {{doctor_name}}, your weekly patient summary:

Total patients: {{count}}
⚠️ Needs attention: {{flagged_count}}
{{flagged_patient_list}}

✅ Stable: {{stable_count}} patients

Full details: {{portal_link}}
```

---

## TESTING CHECKLIST — BEFORE BIHAR PILOT

### Functional Testing
- [ ] New user can sign up with phone OTP and create profile
- [ ] User can photograph glucometer screen and get correct reading
- [ ] User can photograph BP monitor screen and get correct reading
- [ ] User can photograph weighing scale and get correct reading
- [ ] Manual entry works as fallback for all three
- [ ] Readings appear on dashboard with correct status badges
- [ ] 7-day charts display correctly with multiple data points
- [ ] BMI calculates correctly and shows proper category
- [ ] Streaks count correctly and reset on missed days
- [ ] Family invite link works via WhatsApp share
- [ ] Family member can view patient's dashboard after accepting invite
- [ ] Family member can log a reading for the patient
- [ ] WhatsApp daily summary arrives at correct time
- [ ] WhatsApp alert triggers on abnormal reading
- [ ] Notification preferences respected per profile
- [ ] Hindi language displays correctly on all screens
- [ ] App works offline and syncs when back online

### Device Compatibility Testing
- [ ] Budget Android phone (₹8,000-12,000 range, 2-3 GB RAM)
- [ ] Android 9, 10, 11, 12, 13
- [ ] Different screen sizes (5.5", 6.1", 6.5")
- [ ] iOS 14+ (for family members on iPhone)
- [ ] Low-light camera conditions (for photo capture)
- [ ] Slow internet (2G/3G — common in rural Bihar)

### OCR Accuracy Testing
- [ ] Dr. Morepen BG-03 (cheapest glucometer — worst LCD)
- [ ] Accu-Chek Active (popular in India)
- [ ] Accu-Chek Instant
- [ ] OneTouch Select Plus
- [ ] Omron HEM-7120 (basic BP)
- [ ] Omron HEM-7143T1A (Bluetooth BP — test OCR on its screen too)
- [ ] Generic digital weighing scale
- [ ] Each device tested in: daylight, indoor light, low light with flash

---

## WEEK 5 PRIORITIES (Buffer / BLE Prep)

If core features ship in 4 weeks, use Week 5 for:

| Task | Developer | Days |
|------|-----------|------|
| End-to-end testing with 5 real family members | All | 2 |
| Bug fixes from real-world testing | All | 2 |
| Study Transtek OEM SDK documentation | Dev 2 | 2 |
| Study J-STYLE OEM SDK documentation | Dev 2 | 1 |
| BLE pairing proof-of-concept with OEM devices (if arrived) | Dev 2 | 2 |
| App performance optimization (startup time, memory, battery) | Dev 1 | 2 |
| Doctor onboarding materials (WhatsApp guide for doctors) | Dev 4 | 1 |

---

## COST ESTIMATES

| Item | Cost | Frequency |
|------|------|-----------|
| Firebase (Spark → Blaze plan) | Free → ~₹2,000/month at pilot scale | Monthly |
| Google Cloud Vision API | Free first 1,000 calls/month, then $1.50/1000 | Per usage |
| WhatsApp Business API (via Gupshup) | ~₹0.50-1.00/message | Per message |
| WhatsApp at pilot scale (300 msgs/day) | ~₹4,500-9,000/month | Monthly |
| Apple Developer Account | $99/year (~₹8,300) | Annual |
| Google Play Developer Account | $25 one-time (~₹2,100) | One-time |
| **Total monthly tech cost at pilot** | **~₹10,000-15,000/month** | |

---

*This document is the dev team's bible for the next 4-5 weeks. Print it. Pin it on the wall. Check off tasks daily. Ship weekly.*
