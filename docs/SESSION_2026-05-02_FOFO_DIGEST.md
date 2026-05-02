# Session Digest — 2026-05-02 — FOFO Insight + Investor Feedback

**Founder:** Amit
**Trigger:** Mother refused to measure BP/sugar; second investor said no.
**Status:** Major product wedge discovered. Pitch broken. No code yet — validation phase.

---

## 1. The discovery (from Amit's mother)

- Asked mother to log BP/sugar. She refused.
- Reason: **"If the number is bad, I'll be stressed."** Fear of seeing the LCD reading on the device, not of the app.
- Named it: **FOFO — Fear Of Finding Out.**
- Dr. Rajesh confirms ~40% of elderly Indian patients hide their meter for this reason. It's protective avoidance, not denial.

## 2. Why this matters (likely #1 retention killer for 50+ ICP)

- Hiding the number in the app is useless — the device's own LCD lights up the moment the reading is taken.
- Bigger than any feature on the tracker. Almost no health-tech product names this; we can.

## 3. Solution path — software-only wedge (rejected custom hardware)

- **Hardware decision:** custom no-display device is a Series A move, not a pilot move. Capex hell, regulatory burden, MOQ 500, returns risk.
- **P0 path:** opaque sticker over Omron LCD + Bluetooth pairing → app receives data → app filters before display.
- **What patient sees:** a green/amber/red traffic light only. Never a number.
- **What coach/doctor sees:** raw truth, all readings, trends, alerts.

## 4. The signal-engine logic (locked, ready for dev once sign-offs land)

- **BP — per ESH 2023 + HOPE Asia + ICMR IGH-IV:**
  - Rolling 7-day median, drop day 1, ≥5 valid days for cold-start.
  - Trend escalation if current vs prior median delta ≥10 mmHg.
  - Single-reading clinical-red bypass: BP ≥180/110 OR ≤90/60 → silent doctor + family alert in 15 min, never shown to patient.
- **Glucose — per ADA 2025/26:**
  - Bucket fasting vs post-meal 2-hr; never average across.
  - Rolling 14-day median per bucket; worse-bucket wins.
  - Bypass: ≥250 or ≤70 → silent alert; ≤54 → emergency call within 5 min.
- **Universal:** median (not mean), cold-start floor, trend check, time-bucket separation, raw numbers hidden from patient.
- Full spec: `docs/HEALTH_SIGNAL_LOGIC.md`.

### Worked examples
- BP 7 days {145, 138, 142, 130, 135, 140, 138} → drop 145 → median 138 → AMBER.
- Sugar fasting {110, 115, 105, 112, 108} → 110 → AMBER. Post-meal {180, 220, 195, 210, 200} → 200 → RED. Combined → RED (worst wins).

## 5. Persona panel — Round 1 (FOFO solution)

- **Meera:** RED on building hardware now. GREEN on smoothing UX. Don't repivot company on N=1.
- **Vikram:** Software wedge fundable. Hardware capex unfundable at seed. Whitelabel partnership at Series A.
- **Sunita:** Won't use any device that shows number — even Bluetooth ones. Wants caregiver to operate + tell her "theek hai." Daughter on the other end has her own anxiety; coach must absorb both.
- **Dr. Rajesh:** Clinically endorses 7-day median + 14-day TIR. Hard guardrails: cold start ≥5 readings, clinical-red bypass non-negotiable, fasting/post-meal separation. Recommends "graduated exposure" — re-introduce numbers after 6 months of stable behavior.

## 6. Investor pushback — second NO this week

**Objections heard:**
1. "You're just aggregating data — Apple/Samsung watches do this."
2. "Rs 999/mo is too high."

**Honest read:** Two no's with the same objection = pitch broken, not idea broken.

**Counter-narrative for next deck:**
- **Buyer is the daughter, not the patient.** Apple Watch sells to wearer; we sell to the worried family member. Different willingness-to-pay.
- **Apple Watch shows the number.** That's the FOFO problem; Apple makes it worse, not better.
- **No human in Apple's loop.** No Hindi-speaking coach calling Maaji at 4pm. No doctor reviewing trends. Service > data.
- **70% of our users don't own smartphones, let alone Apple Watches.** Wearable thesis ≠ our market.
- **Cultural friction:** Indian parents won't grant watch data to child's iCloud. They trust WhatsApp.

**Pricing reframe:**
| Comparable | Price/mo |
|---|---|
| Apple Fitness+ | Rs 299 (no human) |
| HealthifyMe Smart | Rs 800-2000 (coach) |
| Cult.fit Live | Rs 999-2999 |
| 1mg Care | Rs 1500-3000 |
| Practo single consult | Rs 500-1500 (one-shot) |
| **Swasth Rs 999** | Coach + weekly doctor + family WhatsApp + alerts |

Rs 999/mo is *cheaper than one Practo consult* for a month of monitored care. Underpriced, not overpriced.

**Two-tier pricing to disarm the objection:**
- **Care Lite Rs 499/mo** — coach + WhatsApp summaries + alerts.
- **Care Plus Rs 1499/mo** — adds weekly doctor review + family group + medication management.

## 7. Persona panel — Round 2 (investor pushback)

- **Meera:** Two no's with the same objection = pitch broken. Rewrite slides 1-5 with daughter as hero, FOFO as wedge, in 7 days. Test on 3 fresh investors.
- **Vikram:** Investor pattern-matched to the 50 dead "data aggregator" health apps. Open with: "We sell guilt-relief to NRI daughters at Rs 1000/mo." If he's debating price, he's interested — push back, don't capitulate.
- **Sunita:** Investor compared Apple Watch — neither she nor her daughter owns one. Investor is not your customer.
- **Dr. Ram (personal lens):** Two no's in 48hrs hit different. Don't conclude "I am not founder material" — conclude "the pitch needs work." Walk first, slides second.

## 8. Decisions taken

- ✅ FOFO is the wedge. Worth repositioning around.
- ✅ Software-only path. No custom hardware until Series A.
- ✅ Patient sees traffic light only. Coach/doctor see raw truth.
- ✅ Pitch needs full rewrite. Daughter as hero, not data.
- ✅ Add two-tier pricing (Rs 499 / Rs 1499).
- ❌ Do NOT code DEV2 signal engine until clinical sign-offs (Dr. Rajesh + Legal + PHI).
- ❌ Do NOT pivot motherbook spine — FOFO fits inside coaching+doctor+family, doesn't replace it.

## 9. Tasks created in this session

- `EV0` — AI safety smoke test (5 cases, ~1 hr) — 🔴 P0
- `EV1` — AI disclaimer regex audit (~30 min) — 🔴 P0
- `EV2` — Full eval harness (post-100-DAU) — 🔵 Post-pilot
- `DEV1` — Stickered Omron + software wedge (FOFO solve) — 🔴 P0
- `DEV2` — Anxiety-aware signal engine (rolling median + bypass) — 🔴 P0

## 10. Next 7 days (validation, not coding)

1. Walk + sleep on it. Don't reread the rejection email tonight.
2. Call mother — ask what would have made her say yes (as son, not founder).
3. **5 NRI daughter calls + 5 Ranchi auntie calls** by Friday.
4. **Razorpay test landing page** by Sunday — Rs 999/mo, "anxiety-free monitoring for your parent." Track signups.
5. Rewrite slides 1-5 with daughter-as-hero framing.
6. Re-pitch on 3 fresh investors with new deck.
7. **Reconvene Monday 2026-05-09.** If signals hold → reposition. If not → keep motherbook spine and treat FOFO as a feature, not a wedge.

## 11. Open items

- ❗ **MOTHERBOOK.md missing from repo root.** Memory says it was locked 2026-04-29 as canonical strategy, but the file was never committed to git and is no longer on disk. Skeleton survives in `~/.claude/.../memory/project_swasth_motherbook.md`. Needs reconstruction.
- ❗ Clinical sign-offs needed before DEV2 code: Dr. Rajesh (thresholds), Legal (patient copy), PHI (coach-side raw display audit).
- ❗ Investor #3 deck rewrite — daughter hero, FOFO wedge, two-tier pricing.

## 12. References saved this session

- `reference_evals_hamel.md` (memory) — Hamel Husain 3-level eval framework.
- `project_fofo_silent_device.md` (memory) — FOFO retention-barrier insight.
- `docs/HEALTH_SIGNAL_LOGIC.md` (repo) — full BP/glucose signal spec.
- This file — session digest.
