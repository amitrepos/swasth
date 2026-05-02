# Swasth Motherbook — Canonical Strategy

**Status:** Source of truth. When other docs disagree, motherbook wins.
**Locked:** 2026-04-29
**Recovered:** 2026-05-02 from memory after the original was lost (never committed to git). Extended with FOFO insight from this session.
**Sign-off (2026-04-29):** Vikram (VC), Meera (ex-McKinsey), Dr. Rajesh (clinical/legal).

---

## 1. Positioning (locked — do not soften without panel sign-off)

- **Public tagline:** *Add years. Live them.*
- **Investor one-liner:** *India's longevity coach for chronic-disease elderly — doctor-distributed, family-paid.*
- **Updated buyer-led one-liner (post-FOFO, 2026-05-02):** *We sell guilt-relief to NRI daughters at Rs 999/mo. Mother is the user, daughter is the buyer, doctor is the channel.*

**NOT** "longevity OS" — earned at Series A.
**NOT** "predict / avoid disease" — replaced with coaching language.
**NOT** "data aggregator" — that's how investors round us off to dead competitors.

---

## 2. The 5-layer moat (uncopyable intersection)

1. **Doctor distribution** — physicians refer patients in; CAC near zero.
2. **Indian chronic-disease longitudinal data** — comorbidity patterns no global player has.
3. **Hindi/Tier-2/3 elderly UX** — Sunita-grade comprehension; no competitor can copy without 18 months of field work.
4. **Family-as-payer cultural arbitrage** — daughter pays, mother uses. Three-sided market unlocks Rs 1000+/mo ARPU on a Rs 8K Redmi.
5. **Comorbidity-tuned coaching** — BP + sugar + meds + meals interact; coach knows the whole picture.

Apple/Samsung/Google compete on layer 1 (data). They cannot copy layers 2-5 without becoming Indian operations companies. They won't.

---

## 3. Three-sided market

- **Doctor distributes.** Refers patient. Earns Rs 500/mo professional service fee for reviewing data + signing quarterly preventive report + 1 tele-consult/quarter.
- **Patient adopts.** Uses the app, logs readings (or has caregiver log via stickered Bluetooth device), receives coach calls in Hindi.
- **Family pays.** Daughter (often NRI) on Rs 999-1499/mo plan. Removes guilt, gets weekly WhatsApp summary, peace of mind.

The buyer is NOT the patient. This is the cultural arbitrage.

---

## 4. The FOFO wedge (added 2026-05-02)

**Discovery:** Amit's mother refused to measure her BP/sugar. Reason: *"If the number is bad, I'll be stressed."* Fear Of Finding Out. Dr. Rajesh confirms ~40% of elderly Indian patients hide their meter.

**Why it matters:** This is likely the #1 retention killer for our 50+ ICP. No competitor names this problem. Apple Watch makes it worse — it shows the number to the wearer.

**Solution:**
- Stickered BP cuff (opaque sticker over LCD) + Bluetooth pairing.
- Patient sees green/amber/red traffic light only. Never a number.
- Coach + doctor see raw truth.
- Reading is computed via rolling-median smoothing (BP: 7-day per ESH/HOPE Asia; glucose: 14-day per ADA, fasting/post-meal bucketed). Single-reading clinical-red bypasses smoothing for safety.
- Full spec: `docs/HEALTH_SIGNAL_LOGIC.md`.

**Why this is fundable:** "We sell to the patient who's afraid to know" is a memorable wedge investors haven't seen. Apple/Samsung optimize for the patient who wants data; we optimize for the family that wants peace.

---

## 5. Phase plan (each phase introduces ONE thing)

Each phase has explicit exit criteria. Don't advance until met.

### P0 (now)
- Free measurement app, 5 doctor pilots, 50 patients logging.
- FOFO wedge: stickered Omron + signal engine (DEV1 + DEV2 in TASK_TRACKER_PENDING.md).
- AI safety floor: EV0 + EV1 (smoke test + disclaimer audit).
- **Validation gate before P1:** 5 NRI daughter calls + Razorpay test page; ≥2/10 daughters say yes OR ≥3 paid signups.

### P1
- Rs 1,000/mo paid (doctor signs reports).
- Pricing ladder: day 0-30 Rs 1,000 → day 31-90 Rs 10/day → day 91+ Rs 1,000.
- **Updated 2026-05-02 — two-tier pricing to disarm investor objection:**
  - **Care Lite Rs 499/mo** — coach + WhatsApp summaries + alerts.
  - **Care Plus Rs 1499/mo** — adds weekly doctor review + family group + medication management.
- Coupon replaces "free" — removes free anchoring.
- Doctor gets Rs 500/mo flat throughout (Swasth absorbs the gap during the discount window).
- **Exit:** 50 paying / M3 retention 50% / day-91 step-up retention 60%.

### P2
- AI nudge / virtual health friend at Rs 1,500/mo (Care Plus tier).
- **Exit:** 200 paying / DAU/MAU 50% / M6 retention 50%.

### P3
- Hardware bundle (BP/glucose/scale) at Rs 2,000/mo.
- **Note (2026-05-02):** rejecting custom no-display device for now. Stickered Omron + software does the FOFO job. Whitelabel partnership at Series A, not own SKU.
- **Exit:** 1,000 paying / 60% attach / 35% gross margin.

### P4+
- Bloodwork → genetics → insurance B2B2C.
- Each gates on prior phase retention + margin.

---

## 6. Doctor revenue share — legal frame

- Rs 500/mo is a **professional service fee**, NOT a referral fee.
- Doctor deliverables (explicit in service agreement):
  - Reviews patient data weekly.
  - Signs quarterly preventive report.
  - One tele-consult per quarter.
  - ~5 hrs/yr/patient total.
- Doctor invoices Swasth, pays GST on the income. Swasth issues 1099-equivalent.
- **No cash kickbacks. No referral payments. NMC clean.**

---

## 7. Investor pitch — what to say (and not say)

### Slide 1 hook (post-2026-05-02 rewrite)
> "We sell guilt-relief to NRI daughters at Rs 999/mo. The mother is the user, the daughter is the buyer, the doctor is the channel. CAC near zero via doctor referral. Rs 24K LTV over 24 months. Apple Watch has 0% market share with our buyer."

### Apple Watch teardown (mandatory slide, post-2026-05-02)
- **Wrong buyer:** Apple sells to the wearer; we sell to the worried family member.
- **Wrong device for our user:** Bihar mother owns a Rs 8K Redmi, not a Rs 25K Watch.
- **Shows the number to the wearer:** that's the FOFO trigger; Apple makes it worse.
- **No human in loop:** no Hindi coach, no doctor reviewing trends, no WhatsApp alerts.

### Pricing comparison (mandatory slide)
| Service | Price/mo | What's included |
|---|---|---|
| Apple Fitness+ | Rs 299 | Workout videos |
| HealthifyMe Smart | Rs 800-2000 | Coach + AI |
| Cult.fit Live | Rs 999-2999 | Live classes |
| 1mg Care | Rs 1500-3000 | Doctor consults |
| Practo single consult | Rs 500-1500 | One-time |
| **Swasth Care Lite Rs 499** | | Coach + WhatsApp + alerts |
| **Swasth Care Plus Rs 1499** | | + weekly doctor + family group + meds |

### Founder edge — UNRESOLVED (homework for Amit)
Investor heuristic: *"What monopoly will exist that wouldn't without you?"* Amit must own ONE sentence — operational scar tissue / distribution edge / clinical edge / capital edge / persona edge. The strategy is sound; the founder narrative isn't yet locked.

---

## 8. Kill list (do NOT pitch — these draw the wrong investor reaction)

- ❌ TAM stacking ("$40-50B longevity market...")
- ❌ Phased platform pitch on slide 2 (sounds like roadmap, not product)
- ❌ Tier-2/3-first / NRI-second sequencing (NRI is the buyer; lead with her)
- ❌ DTC consumer pivot for healthy users (P6+, not now)
- ❌ Doctor-as-customer monitoring app (rejected hypothesis — doctors won't pay; they distribute)
- ❌ Hardware before nudge engine
- ❌ "Predict and avoid disease" framing (NMC will demand evidence)
- ❌ "Data aggregator" framing (added 2026-05-02 — investors round us to dead competitors)
- ❌ "Anxiety cure" marketing (NMC issue — frame as adherence improvement instead)

---

## 9. Open commitments / homework

- **Amit's founder-edge sentence** — unresolved since 2026-04-29. Without it, the pitch isn't fundable, no matter how good the strategy.
- **5 NRI daughter calls + 5 Ranchi auntie calls** — by Friday 2026-05-08.
- **Razorpay test landing page** — Rs 999/mo, "anxiety-free monitoring for your parent" — by Sunday 2026-05-04.
- **Deck rewrite** — daughter-as-hero, FOFO wedge, two-tier pricing, Apple Watch teardown — by 2026-05-09.
- **Clinical sign-offs before DEV2 code:** Dr. Rajesh (thresholds), Legal (patient copy), PHI (coach-side raw display audit).
- **MOTHERBOOK.md commit + protect** — this file. Add to git, never let it disappear again.

---

## 10. Decision log (chronological)

- **2026-04-29:** Motherbook v1 locked. Vikram + Meera + Dr. Rajesh signed off.
- **2026-05-02:** FOFO insight discovered (Amit's mother). Software-only wedge confirmed (no custom hardware). Investor rejection #2 → pitch broken; rewrite scheduled. Two-tier pricing added. Original MOTHERBOOK.md found missing from disk; recovered + extended (this version).

---

**End of motherbook.** When in doubt, this file wins. When you change strategy, change this file first.
