# Anxiety-Aware Health Signal Logic

**Purpose:** Hide raw BP/glucose numbers from the patient. Show a smoothed, clinically-grounded traffic light (green/amber/red) based on rolling-window medians. Coach and doctor always see the raw truth.

**Why this exists:** Discovered 2026-05-02 — Amit's mother refused to measure BP/sugar due to fear of seeing the number on the device LCD ("Fear Of Finding Out"). Hiding the number in the app alone is insufficient when the device displays it. We solve this with: (a) opaque sticker over device LCD, (b) Bluetooth pairing, and (c) the smoothing logic in this document.

**Standards basis:**
- BP: ESH 2023 + HOPE Asia Network + ICMR IGH-IV (2019) → 7-day HBPM, twice daily, drop day 1, average days 2-7.
- Glucose: ADA 2025/26 → rolling 14-day Time-in-Range, fasting and post-meal bucketed separately.

---

## Universal Rules (apply to both BP and glucose)

1. **Patient never sees the raw number.** Sticker over device LCD; app receives data via Bluetooth; app filters before display.
2. **Coach/doctor always sees raw truth.** No filtering on the professional side.
3. **Bypass alerts are silent on the patient side.** Patient sees "doctor aapko call karenge" — not a number, not a flashing screen. Anxiety is the enemy.
4. **Use median, not mean.** Mean is skewed by one bad reading; median ignores it. Critical for FOFO design.
5. **Cold-start floor.** Don't classify until enough readings exist (BP: ≥5 valid days; glucose: ≥5 readings per bucket).
6. **Trend check is mandatory.** A green median can hide a slow creep. Compare current window vs prior window.
7. **Bucket glucose by context.** Fasting 110 ≠ post-meal 110 clinically. Never average across contexts.

---

## BP Signal Logic

### Worked example
Mom takes BP daily for 7 days: 145, 138, 142, 130, 135, 140, 138.
- Drop day 1 (145, white-coat / unfamiliarity per ESH).
- Median of remaining {130, 135, 138, 138, 140, 142} = **138.**
- 138 falls in 130-139 → **AMBER.**
- App shows yellow dot. No number visible to patient.

### Algorithm

**STEP 1 — Window:** All readings from last 7 calendar days.

**STEP 2 — Drop day 1.** Discard readings from the oldest day.

**STEP 3 — Cold start:** If valid days < 5 OR total readings < 8 → signal = `calibrating`. Patient sees: "Abhi data jama ho raha hai. 5 din rozana naapiye."

**STEP 4 — Median:** `median_sys` = median of remaining systolic; `median_dia` = median of remaining diastolic.

**STEP 5 — Classify (ESH thresholds):**
| Median systolic | Median diastolic | Signal |
|---|---|---|
| < 130 AND | < 80 | green |
| 130-139 OR | 80-89 | amber |
| ≥ 140 OR | ≥ 90 | red |

**STEP 6 — Trend check:** Compare `current_median_sys` vs `prior_median_sys` (days 8-14 ago, also dropping that window's day 1). If delta ≥ 10 mmHg → escalate signal one level + notify coach.

**STEP 7 — Single-reading clinical-red bypass:** For the most recent reading only:
- Systolic ≥ 180 OR diastolic ≥ 110 → silent alert to coach + family + doctor within 15 min.
- Systolic ≤ 90 OR diastolic ≤ 60 → same bypass (hypotension).
- Bypass is INDEPENDENT of median. Even if median is green, a single 200/120 fires.

**STEP 8 — Patient display:** Green/amber/red light only. No number.

---

## Glucose Signal Logic

### Worked example
Mom logs over 14 days:
- Fasting: 110, 115, 105, 112, 108 → median **110 → AMBER** (100-125 = pre-diabetic).
- Post-meal (2hr): 180, 220, 195, 210, 200 → median **200 → RED** (≥200).
- Combined patient signal = **RED** (worse bucket wins).
- App shows red dot. No number. Patient sees: "Coach aapko aaj call karenge."

### Algorithm

**STEP 1 — Bucket readings by context:**
- Bucket A: fasting (and bedtime, treated as fasting-equivalent).
- Bucket B: post-meal 2-hr.
- "Random" readings: log them but exclude from signal.

**STEP 2 — 14-day window per bucket.**

**STEP 3 — Cold start (per bucket):** If a bucket has < 5 readings in 14 days → bucket = `calibrating`. Overall signal = `calibrating` if EITHER bucket is calibrating. (A fasting-only signal misleads without post-meal context, and vice versa.)

**STEP 4 — Median per bucket:** `fasting_median`, `postmeal_median`.

**STEP 5 — Classify per bucket (ADA thresholds):**

| Bucket | green | amber | red |
|---|---|---|---|
| Fasting | < 100 | 100-125 | ≥ 126 |
| Post-meal 2hr | < 140 | 140-199 | ≥ 200 |

**STEP 6 — Combine:** Patient signal = WORSE of the two buckets. (Fasting green + post-meal red → patient is red. Hidden post-meal hyperglycemia is the most common Indian T2D pattern.)

**STEP 7 — Trend check (per bucket):** Current 14-day median vs prior 14-day median. If delta ≥ 15 mg/dL → escalate + notify coach.

**STEP 8 — Single-reading clinical-red bypass:**
- Any reading ≥ 250 mg/dL → silent alert (hyperglycemia).
- Any reading ≤ 70 mg/dL → silent alert (hypoglycemia — urgent; can cause unconsciousness in minutes).
- Any reading ≤ 54 mg/dL → emergency: coach calls patient/family within 5 min; ambulance protocol if no response.

**STEP 9 — Patient display:** One traffic light (combined). No number. If amber/red: "Coach aapko aaj call karenge. Ghabraiye mat."

---

## Cold-start patient copy (Hindi-first)

| State | Hindi | English fallback |
|---|---|---|
| Calibrating | "Abhi data jama ho raha hai. Rozana naapiye." | "Calibrating — keep logging." |
| Green | "Aaj sab theek hai, Maaji." | "All good today." |
| Amber | "Thoda dhyaan dijiye. Coach aapse baat karenge." | "Pay attention; coach will call." |
| Red | "Doctor aapko aaj call karenge. Ghabraiye mat." | "Doctor will call today." |
| Bypass | "Doctor abhi call karenge." | "Doctor calling now." |

---

## Out of scope (post-pilot)

- HbA1c integration (lab data) — adds 3-month rolling context for diabetes.
- CGM (Abbott FreeStyle Libre) — replaces SMBG buckets with continuous TIR.
- Whitelabel "no-display" device — Series A consideration; sticker hack works for pilot.
- AI-personalized thresholds (e.g., adjusting amber/red bands per patient comorbidity) — needs ≥100 patient-months of data first.

---

## Open clinical sign-offs needed before code ships

- [ ] Dr. Rajesh signs off on threshold tables (BP, glucose).
- [ ] Dr. Rajesh signs off on bypass thresholds + escalation latency (15 min / 5 min).
- [ ] Legal sign-off on patient copy (NMC disclaimer present, no diagnostic claim).
- [ ] PHI sign-off on coach-side raw-data display (audit log requirements).

---

**Tracked as:** `DEV1` (silent device + sticker hack, P0) and `DEV2` (this signal logic, P0) in `TASK_TRACKER_PENDING.md`.
