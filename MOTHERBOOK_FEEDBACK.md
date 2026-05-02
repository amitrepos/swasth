# Swasth — Motherbook Feedback & Reference

> **Companion to `MOTHERBOOK.md`.** Houses everything that supports the strategy but isn't a phase or a pitch: vision long-form, moat, persona feedback, unit economics, kill list, validation questions, standards roadmap, change log.
> When this file disagrees with `MOTHERBOOK.md`, motherbook wins.
> Last updated: 2026-05-02

---

## 1. Long-form vision

**Public tagline:** *Add years. Live them.*

**Long form:**

Swasth is **India's first doctor-distributed AI Virtual Health Friend for chronic-disease elderly patients and their families abroad.**

Indian doctors prescribe Swasth to their hypertensive and diabetic patients. The patient gets a daily AI companion that turns their BP cuff, glucometer, and meal photos into small, achievable goals: *"Skip breakfast today, you're 4 days from 1 kg lost, your BP is down 8 points."* Their NRI son sees the streak from Frankfurt and pays a monthly subscription for visibility plus a doctor-signed quarterly preventive report.

**Three-sided market:** Doctor distributes. Patient adopts. Family pays.

The long arc: this becomes India's longevity coach — daily metrics → quarterly preventive reports → annual bloodwork → genetics → personalized longevity targets — built on a doctor-distributed, family-paid foundation no DTC or pure-B2B competitor can replicate in India. (The "longevity OS" framing is the destination, not the pitch — earned at Series A when Phases 4–6 are credible.)

---

## 2. The 5-layer moat

```
Swasth's moat = Doctor distribution
              + Indian chronic-disease longitudinal data
              + Hindi / Tier-2/3 elderly UX
              + Family-as-payer cultural arbitrage
              + Comorbidity-tuned coaching (not worried-well)
```

Each layer alone is replicable. The intersection of all five is uncopyable — no DTC longevity startup, no pharma player, and no foreign founder can stack all five.

**Defensibility test:** if a competitor raised $50M tomorrow to clone us, the doctor relationships and the Indian-cohort longitudinal data would still take them 24+ months to replicate. That's the moat clock.

### 6th moat layer (added 2026-04-29) — Standards-coded interoperability

Our data is portable, exportable, FHIR-native, and ABDM-registered from Day 1. Closed-stack competitors face a 12–18 month rebuild to match. Open-stack global competitors face the India distribution wall we own. The intersection: uncatchable.

---

## 3. Unit economics (locked at Phase 1 pricing)

### Per family / month

```
GROSS REVENUE                                  Rs 1,000
  Doctor professional fee                      (Rs   500)   50%
  Payment gateway + processing (~5%)           (Rs    50)
  AI compute + SMS + WhatsApp                  (Rs    30)
  Customer support (at scale)                  (Rs    30)
                                              ─────────
SWASTH NET CONTRIBUTION                        Rs   390     ~39%
```

### Per-doctor income (Tier-2/3 GP)

| Active patients per doctor | Monthly doctor income | Annual passive income |
|---:|---:|---:|
| 5 (early) | Rs 2,500 | Rs 30,000 |
| 15 (mature) | Rs 7,500 | Rs 90,000 |
| 30 (top-tier) | Rs 15,000 | Rs 1,80,000 |

For a Tier-2 GP earning Rs 50K/mo, this is +5% to +30% of income — meaningful enough to recruit, not so much it triggers ethical alarm.

### Scale projections (planning, not promises)

| Phase target | Doctors | Patients/doc | Paying families | Gross MRR | Doctor payouts | Swasth net MRR | ARR |
|---|---:|---:|---:|---:|---:|---:|---:|
| Phase 0 → 1 | 5 | 5 | 25 | Rs 25K | Rs 12.5K | Rs 10K | Rs 1.2L |
| Phase 1 exit | 10 | 5 | 50 | Rs 50K | Rs 25K | Rs 20K | Rs 2.4L |
| Phase 2 exit | 30 | 7 | 200 | Rs 2L (P2 price) | Rs 1.2L | Rs 60K | Rs 7.2L |
| Phase 3 exit | 100 | 10 | 1,000 | Rs 20L (bundled) | Rs 6L | Rs 8L | Rs 1 Cr |
| Phase 4+ | 1,000 | 10 | 10,000 | Rs 2.5 Cr | Rs 60L | Rs 1.2 Cr | Rs 14 Cr |

(GST treatment refined separately with CA before any pitch.)

---

## 4. Pricing & doctor revenue share — locked decisions

### Pricing ladder (Phase 1)

| Window | Customer pays | Doctor receives | Swasth gross | Notes |
|---|---:|---:|---:|---|
| Day 0–30 | Rs 1,000/mo | Rs 500/mo | Rs 500/mo | Full price proves intent |
| Day 31–90 | Rs 10/day (~Rs 300/mo) | Rs 500/mo | **negative Rs 200/mo** | Habit-formation window. **Swasth absorbs the gap.** |
| Day 91+ | Rs 1,000/mo | Rs 500/mo | Rs 500/mo | Full price resumes |

- **No free tier.** Coupon system replaces it.
- **Coupon types:** Sponsored (NRI "Sponsor a Bihar grandmother"), NGO partner, doctor goodwill, Swasth-funded for first-100 advocacy users.
- **Doctor share is flat Rs 500/mo throughout** — predictable, recruitable. Swasth eats the day-31-to-90 gap as a CAC investment.

### Phase pricing trajectory

- **Phase 1:** Rs 1,000/mo (with day-31–90 ladder). Doctor share: Rs 500/mo.
- **Phase 2:** Rs 1,500/mo. Doctor share: Rs 600/mo (40%).
- **Phase 3:** Rs 2,000/mo bundled (or Rs 1,500/mo + Rs 3,000 hardware). Doctor share: Rs 700/mo (35%).

### Two-tier alternative (added 2026-05-02 to disarm investor price objection)

| Tier | Price | What's included |
|---|---:|---|
| Care Lite | Rs 499/mo | Coach + WhatsApp summaries + alerts |
| Care Plus | Rs 1,499/mo | + weekly doctor review + family group + medication management |

Use the two-tier framing when investors compare to apps (Apple Fitness+, HealthifyMe). Single-tier Rs 1,000/mo remains the pilot default.

### Non-negotiable rules

- Revenue share is **professional service fee**, NOT referral. Service agreement with explicit deliverables. Doctor invoices and pays GST/income tax.
- No cash kickbacks. No commissions for prescribing. Ever.
- Day-91 churn is the bar metric for Phase 1 → Phase 2 progression. Track from week 1.

---

## 5. Persona validations (signed off 2026-04-29)

### Vikram Chakraborty — Health-tech VC

> "Three-sided market with doctor distribution is structurally different from every DTC longevity comp. Show Phase 1 numbers in 90 days and we have a seed conversation. The revenue share is the unlock — without it the doctor flywheel is theoretical."

**What he wants on the next deck:** clinical advisory board names, 1 doctor-payout screenshot, M3 retention curve, sub-Rs 200 CAC proof.

### Meera Krishnan — Ex-McKinsey strategist

> "Phase boundaries are clean — each phase introduces ONE new thing. Triggers must be 'count + retention,' not just count. The doctor flywheel was always the real moat; don't let the longevity-OS framing pull you off it."

**What she wants:** disciplined Phase 1 execution. Stop polishing decks. 10 doctors signed, 30 paying families, by day 90.

### Dr. Rajesh Verma — Indian physician + clinical/legal lens

> "Coaching framing is clinically defensible AND legally far cleaner than 'predict / avoid disease.' Doctor signing the quarterly report is the legal wrapper for the diagnostic-adjacent product. Service-fee structure (not referral) keeps NMC happy."

**Non-negotiable:** doctor dashboard must gate on "data reviewed" before they can sign the report. If it becomes rubber-stamping, the legal cover collapses.

### Sunita Devi — 55yo Ranchi patient persona (added 2026-05-02 FOFO panel)

> *"Beta, mujhe number nahi dekhna. Agar laal aa gaya to raat-bhar neend nahi aati. Agar phone pe sirf 'aaj theek hai' likha aaye, aur beti ya doctor saheb mujhe phone karke samjhaye, to main rozana naapungi."*

**Translation:** patient validates the FOFO solve — green/amber/red without a number, plus caregiver framing, will land with rural Indian elderly.

### Dr. Ram (personal lens, founder support — not a product reviewer)

Notes founder grief cycle (nervous → excited → rejected) after two investor no's in 48 hours. Reminder: "The pitch needs work" ≠ "you are not founder material." Walk first, slides second.

---

## 6. The kill list — what we are NOT doing

- ❌ "Predict and avoid disease" framing — replaced with coaching language
- ❌ TAM-stacking slide ($40-50B longevity market) — pick ONE bucket, prove the first $1M of it
- ❌ Phased platform pitch on slide 2 — phases live in motherbook, not the deck
- ❌ Tier-2/3-first / NRI-second sequencing — flipped: NRI funds the company, Tier-2/3 makes the product good
- ❌ DTC consumer pivot for healthy worried-well users — Phase 6+, not now
- ❌ Doctor-as-customer monitoring app (Apr 2026 hypothesis) — doctor is the channel, not the buyer
- ❌ Hardware before nudge engine — software differentiation first, CapEx later
- ❌ Bloodwork before retention proof — earn it
- ❌ Chinese-style health super-app — narrow knife edge wins, breadth dies
- ❌ "Data aggregator" framing (added 2026-05-02) — investors round us off to dead competitors
- ❌ "Anxiety cure" marketing for FOFO (added 2026-05-02) — frame as adherence improvement; NMC will demand evidence otherwise
- ❌ Custom no-display device at P0 (added 2026-05-02) — stickered Omron + software does the FOFO job. Whitelabel partnership at Series A only.

---

## 7. NRI validation questions (Mom Test compliant)

Run on every NRI conversation. Past behaviour, not hypothetical intent.

```
1. PAST BEHAVIOUR — real money
   "When did you last pay out-of-pocket for your parent's
   health in India? What was it? How much?"

2. STORY ELICITATION — real fear
   "Walk me through the last health scare with your parent —
   who did you call, what did you do?"

3. EXISTING SUBSCRIPTIONS — willingness to commit
   "Do you currently pay for any health subscription for
   yourself or your family? Which? Why?"

4. ANCHORED-TO-DOCTOR — legal-safe value pitch
   "If your parent's doctor handed you a quarterly written
   risk report — heart, kidney, diabetes — would you read it?
   Would you pay Rs 1,000/mo for it?"

5. PRE-SELL TEST — the only real signal
   "I'm building this. Rs 1,000/mo. First 10 families pay
   Rs 500 today and lock Rs 1,000/mo for life. Are you in?"

If question 5 converts <30% among warm contacts → willingness
is theatre. If 50%+ say yes AND ≥3 actually transfer Rs 500
→ you have a business.
```

**Discount friend group "yes I'd pay!" by 70%. Weight referrals at 100%.**

---

## 8. Founder edge — to be filled in by Amit

The investor heuristic both Vikram and Meera hammered:

> *"What monopoly will exist that wouldn't without you?"*

Candidate angles (Amit picks one and owns it):
- Operational scar tissue (built X to scale at Y)
- Distribution edge (network, brand, audience)
- Clinical/regulatory edge (co-founder, license)
- Capital edge (can self-fund pre-seed runway)
- Persona edge (you ARE the NRI son — first-hand pain)

**One sentence. One source. Locked into the deck. Without this, the strategy is sound but the pitch isn't.**

---

## 9. Open questions and homework

These are not yet answered. Track them; resolve before Series A pitch.

- [ ] Founder-edge sentence (Amit, by next pitch)
- [ ] Clinical advisory board (3–5 senior Indian physicians, equity, by Phase 1 doctor #1)
- [ ] Service agreement legal draft (health-tech lawyer, before doctor #1)
- [ ] Phase 1 retention curve target — confirm 50% M3 is right for chronic-disease subscription (compare to Livongo, Omada benchmarks)
- [ ] Hardware unit cost target by Phase 3 — quote 3 OEMs (BPL, Omron, Dr. Morepen)
- [ ] CDSCO / BIS pathway — start at Phase 2 (3–6 month runway)
- [ ] Insurance partnership conversations — open at Phase 2; revenue starts Phase 6
- [ ] FOFO validation: 5 NRI daughter calls + 5 Ranchi auntie calls + Razorpay test landing (added 2026-05-02; due 2026-05-09)
- [ ] Clinical sign-offs before DEV2 signal-engine code: Dr. Rajesh thresholds + Legal patient copy + PHI coach-side raw display

---

## 10. Standards integration roadmap

Each phase introduces ONE standard that unlocks the next business layer. Standards are not features — they are plumbing that opens doors. Reference: `docs/HEALTH_STANDARDS_REFERENCE.md`.

| Phase | Standard added | Business door it opens |
|---|---|---|
| **Phase 0 (now)** | LOINC codes in `fhir_loinc_map` · FHIR Facade schema · DPDPA encryption + audit logs | Table-stakes hygiene; signals "FHIR-aware architecture" |
| **Phase 1** | ABDM HPR (doctor verification) · ICD-10 in preventive report · DPDPA explicit consent flow · SNOMED basic concepts (T2DM, HTN, CKD) | "Clinical infrastructure from Day 1" — kills "is this doctor real?" objection · DPDPA-clean for any audit |
| **Phase 2** | FHIR R4 export endpoint · ABDM **HIU registration** · ABHA mandatory for new patients · SNOMED CT for AI reasoning | India regulatory moat — hospitals start sharing data INTO Swasth via consent · SNOMED-driven AI = real ML moat |
| **Phase 3** | BIS + CDSCO hardware certification · HL7 v2 lab ingestion · DICOM-ready architecture | Legal sale of medical devices in India · zero-cost lab partnerships |
| **Phase 4** | Full FHIR R4 round-trip with labs (Thyrocare, Redcliffe, Dr Lal) · LOINC on every imported value · ICD-10 risk-stratification | Lab partnerships at scale (every Indian lab will report in FHIR/LOINC by 2027 mandate) · AI longevity report becomes legally defensible |
| **Phase 5** | FHIR Genomics module · polygenic risk scores tied to SNOMED · DISHA full audit compliance | Same data structure as Function Health and Galleri — interoperable, exportable, uncopyable on closed-stack codebase |
| **Phase 6** | **NHCX** (National Health Claims Exchange) · ABDM HIP registration · risk-stratified cohort export to insurers | Insurance reimbursement REQUIRES NHCX — without it no insurer can pay you. With it, every Indian health insurer is a potential channel |

### Why standards are part of the moat (not just compliance)

- **Standards-coded data = exit-multiple compounding.** A standards-compliant longevity stack commands 2–3× the multiple of a closed-stack clone.
- **Standards = global story.** FHIR + LOINC + SNOMED is the same vocabulary Function Health, Galleri, and every serious global longevity player uses. Investors hear "this works in any market," not "Indian niche."
- **Standards = regulatory tailwind.** ABDM compliance becomes mandatory for insurance bundling. Hospitals integrating with us require FHIR. Labs reporting to us by 2027 will require LOINC. Building these in now turns future regulation from a tax into a moat.

---

## 11. FOFO wedge (added 2026-05-02)

**Discovery:** Amit's mother refused to measure BP/sugar — not laziness or denial, but **Fear Of Finding Out**. The trigger is the device LCD, not the app. Dr. Rajesh confirms ~40% of elderly Indian patients hide their meter for the same reason.

**Why it matters:** likely the #1 retention killer for our 50+ ICP. No competitor names this problem. Apple Watch makes it worse — it shows the number to the wearer.

**Solution (P1, no custom hardware):**
- Stickered BP cuff (opaque sticker over LCD) + Bluetooth pairing.
- Patient sees green/amber/red traffic light only. Never a number.
- Coach + doctor see raw truth.
- Reading is computed via rolling-median smoothing (BP: 7-day per ESH/HOPE Asia; glucose: 14-day per ADA, fasting/post-meal bucketed).
- Single-reading clinical-red bypass for safety.
- **Full clinical spec:** `docs/HEALTH_SIGNAL_LOGIC.md`.

**Why this is fundable:** "We sell to the patient who's afraid to know" is a memorable wedge investors haven't seen. Apple/Samsung optimize for the patient who wants data; we optimize for the family that wants peace.

**Validation gate before any DEV2 implementation:**
- 5 NRI daughter calls + 5 Ranchi auntie calls (by 2026-05-08)
- Razorpay test landing page, Rs 999/mo, "anxiety-free monitoring" (by 2026-05-04)
- Clinical sign-offs from Dr. Rajesh (thresholds), Legal (patient copy), PHI (coach-side raw display)

---

## 12. Investor pushback (2026-05-02)

Two investor no's in one week, same objections:
1. *"You're just aggregating data — Apple/Samsung Watch does this."*
2. *"Rs 999/mo is too high."*

**Diagnosis:** pitch is broken, not idea. Investors pattern-match to dead "data aggregator" health apps because the pitch leads with the WHAT (data) instead of the WHO (NRI daughter buyer) and HOW MUCH (LTV).

**Counter-narrative for next deck (rewrite by 2026-05-09):**
- Slide 1 hook: *"We sell guilt-relief to NRI daughters at Rs 999/mo. Mother is the user, daughter is the buyer, doctor is the channel."*
- Apple Watch teardown slide: wrong buyer (sells to wearer, not family), wrong device for our user (Bihar mother has Rs 8K Redmi, not Rs 25K Watch), shows the number to the wearer (FOFO trigger), no human in loop.
- Pricing comparison: Rs 999/mo cheaper than ONE Practo consult; Cult.fit / HealthifyMe / 1mg charge Rs 999–3000/mo for less.
- Two-tier offer (Care Lite Rs 499 / Care Plus Rs 1499) to disarm price objection without dropping the Rs 1,000 anchor.

---

## 13. Source-of-truth mapping

When other docs disagree with `MOTHERBOOK.md`, motherbook wins.

- `MOTHERBOOK.md` — phases + triggers + 2-min pitches (the spine)
- `MOTHERBOOK_FEEDBACK.md` — this file (everything that supports the spine)
- `WORKING-CONTEXT.md` — sprint board (mirrors current phase milestone)
- `TASK_TRACKER_PENDING.md` — tactical work items per phase
- `RULES.md` — engineering invariants (language, l10n, auth, etc.)
- `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` — legal requirements
- `docs/HEALTH_SIGNAL_LOGIC.md` — clinical spec for the FOFO signal engine
- `docs/SESSION_2026-05-02_FOFO_DIGEST.md` — full FOFO session digest with persona panels
- `docs/INVESTOR_3YR_MODEL.md` — locked 3-year financial model (conservative 8-city). Use when investor asks revenue, expenses, ROI, break-even.
- Pitch deck, outreach drafts, founder-pitch — all derive from sections of this file + the motherbook

---

## 14. Doctor onboarding pitch (long form — for in-clinic recruiting)

```
"Prescribe Swasth to your hypertensive and diabetic patients.

For your patients: a daily AI health coach that motivates
medication adherence and lifestyle change.

For their families abroad: visibility into their parent's
health, so they call you less and trust you more.

For you: Rs 500/mo per active patient as your professional
fee for reviewing the patient's data and signing the
quarterly preventive report.

10 patients = Rs 5,000/mo passive.
30 patients = Rs 15,000/mo passive.

Free to start. Service agreement, not a referral agreement.
Invoiced and taxable as professional income."
```

(The 2-min compressed version is in `MOTHERBOOK.md` Section 2.)

---

## Change log

- **2026-04-29 (initial):** Motherbook created. Synthesised from full strategy session: longevity-OS reframe → doctor flywheel locked as moat → 5-phase plan validated by Vikram + Meera + Dr. Rajesh → Rs 1,000/Rs 500 split locked → unit economics modelled → kill list and Mom-Test questions documented.
- **2026-04-29 (update 1):** Public tagline locked: *"Add years. Live them."* Investor one-liner locked. Pricing ladder locked: day-0–30 Rs 1,000 / day-31–90 Rs 10/day / day-91+ Rs 1,000. Coupon system replaces free tier. Doctor share stays flat Rs 500/mo; Swasth absorbs the discount-window gap. "Sponsor a parent" coupon flow added as Phase 1 feature. Day-91 step-up retention added as Phase 1 → Phase 2 exit trigger.
- **2026-04-29 (update 2):** Section added — Standards integration roadmap. Each phase mapped to a specific standard (LOINC/FHIR/HPR/SNOMED/HIU/ABHA/CDSCO/HL7v2/NHCX/HIP) and the business door it unlocks. 6th moat layer (standards-coded interoperability) defined.
- **2026-05-02 (recovery + FOFO + restructure):** File recovered from stash after disappearing during markdown consolidation. NEW: FOFO wedge (Section 11). NEW: investor pushback rewrite (Section 12). NEW: Sunita + Dr. Ram persona entries (Section 5). NEW: two-tier pricing (Section 4). NEW: kill list additions (Section 6) — "data aggregator" framing, "anxiety cure" marketing, custom hardware at P0.
- **2026-05-02 (restructure):** Motherbook split into two files at user request. `MOTHERBOOK.md` is now minimal: phases + exit triggers + 2-min pitches only. Everything else moved here.
