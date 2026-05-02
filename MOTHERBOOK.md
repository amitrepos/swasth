# Swasth — Motherbook

> **Canonical strategy document. Single source of truth.**
> Last updated: 2026-05-02
> Owner: Amit Kumar Mishra
> Status: ACTIVE — supersedes any prior strategy framing
> Recovered: 2026-05-02 from a stash after the file was lost from disk during the markdown consolidation merge (was untracked when stashed; never committed to git).

This document is the spine. Everything else (decks, working-context, task-tracker, pitches, outreach) flows from here. When in doubt, this wins.

---

## 1. The vision (one paragraph)

**Public tagline:** *Add years. Live them.*

**Investor one-liner:** *Swasth is India's longevity coach for chronic-disease elderly — a doctor-distributed AI Virtual Health Friend that turns daily BP, glucose, and meal data into added healthy years. Indian doctors prescribe. Indian patients use. NRI families pay.*

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

---

## 3. Phase plan

The product evolves in discrete phases. Each phase introduces ONE new capability and has a measurable exit trigger. Don't promise Phase N to investors before Phase N-1 has hit its trigger.

### PHASE 0 — Current Swasth (in market today)

**What:** Free app. Daily logging of BP, sugar, weight, food. Basic AI insights. NRI dashboard view. Hindi + English.

**Goal:** Validate engagement and seed the first 5–10 doctor pilots (offered as a free clinical tool with branded reports).

**Exit trigger to Phase 1:**
- 5 doctors actively prescribing
- 50 patients logging weekly
- 30%+ of those patients have an NRI child willing to take a 15-min call

---

### PHASE 1 — Monetisation + Doctor Flywheel

**What:**
- **Pricing ladder (no free tier):**
  - **Day 0–30:** Rs 1,000/mo full price (proves intent — kills tire-kickers)
  - **Day 31–90:** Rs 10/day = Rs 300/mo (60-day habit-formation discount window)
  - **Day 91+:** Rs 1,000/mo full
  - **Coupon system replaces "free":** sponsored coupons (NGO, doctor, Swasth-funded, NRI "Sponsor a Bihar grandmother") for poor patients. Preserves dignity; avoids freeloader behaviour.
- **Doctor revenue share:** Rs 500/mo flat per active family — including the Rs 300/mo discount window. **Swasth absorbs the gap.** Doctor incentive must stay clean and predictable.
- **Doctor's deliverable:** review patient data + sign quarterly preventive report + 1 tele-consult/quarter (~5 hrs/yr/patient)
- Doctor dashboard with "data not yet reviewed" gating (enforces real clinical work, not rubber-stamping)

**Goal:** Prove paid unit economics + doctor revenue model + day-91 step-up retention.

**Exit trigger to Phase 2:**
- 50 paying NRI families
- M3 retention ≥ 50%
- **Day-91 step-up retention ≥ 60%** (the price-jump churn test)
- 10 doctors earning ≥ Rs 2K/mo each
- Net Promoter Score from at least 30 families

**Customer-facing message (simple version):** *"Rs 1,000/mo. Engaged users get a 60-day continuation discount at Rs 10/day after the first month."* Three-tier complexity stays internal; messaging stays simple.

**Legal frame:** Rs 500/mo is **professional service fee**, NOT a referral fee. Doctor signs a service agreement with explicit deliverables. Doctor invoices, pays GST, declares tax. Service agreement reviewed by health-tech lawyer before doctor #1.

---

### PHASE 2 — AI Nudge / Virtual Health Friend

**What:**
- Daily AI coach: notices, sets micro-goals, celebrates streaks
- Comorbidity-tuned (HTN module first, then T2DM)
- Lifestyle language only ("skip breakfast today" — never "you might have diabetes")
- Loneliness companion layer for elderly living alone
- Optional price bump to Rs 1,500/mo
- Doctor share scales with price (Rs 600 if price = Rs 1,500)

**Goal:** Daily-active retention, not just monthly. Differentiation from Noom / Levels / Lifeforce via comorbidity focus + Indian context + family layer.

**Exit trigger to Phase 3:**
- 200 paying families
- DAU/MAU ≥ 50% (real daily companion behaviour)
- M6 retention ≥ 50%
- Coaching engine has at least 3 measurable per-user behaviour change wins (e.g., +30% medication adherence, –1 kg avg weight in 60 days)

---

### PHASE 3 — Hardware Integration

**What:**
- Branded BP cuff + glucometer + smart scale, Bluetooth auto-sync
- Sold or bundled into subscription (Rs 2,000/mo bundled or Rs 1,500/mo + Rs 3,000 hardware one-time)
- CDSCO + BIS certification (start paperwork in Phase 2 — 3–6 month lead time)
- Replaces manual logging gaps

**Goal:** Data moat (no logging gaps) + retention lock-in (hardware in the home = stickier than software).

**Exit trigger to Phase 4:**
- 1,000 paying families
- Hardware attach-rate > 60%
- Gross margin ≥ 35%
- Hardware return rate < 5%

---

### PHASE 4+ — Layered later, gated by prior phase's retention + margin proof

| Phase | Capability | Pricing notch | Notes |
|------:|---|---|---|
| 4 | Annual bloodwork + AI longevity report | Rs 2,500/mo | Lab partnership (Thyrocare / Redcliffe). Doctor-signed. |
| 5 | One-time genetic test + personalized longevity targets | Rs 3,500 one-time + ongoing sub | APOE, T2DM PRS, CVD PRS. Coaching tuned to genes. |
| 6 | Insurance / employer B2B2C distribution | Reimbursement-priced | Senior plans bundled with HDFC ERGO, ManipalCigna, Star Health. |

**Each phase gates on the prior phase's retention + margin proof. We don't build Phase 5 until Phase 4 sticks.**

---

## 4. Unit economics (locked at Phase 1 pricing)

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

## 5. Pricing & doctor revenue share — locked decisions

### Pricing ladder (Phase 1)

| Window | Customer pays | Doctor receives | Swasth gross | Notes |
|---|---:|---:|---:|---|
| Day 0–30 | Rs 1,000/mo | Rs 500/mo | Rs 500/mo | Full price proves intent |
| Day 31–90 | Rs 10/day (~Rs 300/mo) | Rs 500/mo | **negative Rs 200/mo** | Habit-formation window. **Swasth absorbs the gap.** |
| Day 91+ | Rs 1,000/mo | Rs 500/mo | Rs 500/mo | Full price resumes |

- **No free tier.** Coupon system replaces it.
- **Coupon types:** Sponsored (NRI "Sponsor a Bihar grandmother"), NGO partner, doctor goodwill, Swasth-funded for first-100 advocacy users.
- **Doctor share is flat Rs 500/mo throughout** — predictable, recruitable. Swasth eats the day-31-to-90 gap as a CAC investment.
- The "Sponsor a parent" coupon flow is a quiet superpower: brand + community moat + soft CAC tool. Add to Phase 1 spec.

### Phase pricing trajectory

- **Phase 1:** Rs 1,000/mo (with day-31–90 ladder). Doctor share: Rs 500/mo.
- **Phase 2:** Rs 1,500/mo. Doctor share: Rs 600/mo (40%).
- **Phase 3:** Rs 2,000/mo bundled (or Rs 1,500/mo + Rs 3,000 hardware). Doctor share: Rs 700/mo (35%).

### Non-negotiable rules

- Revenue share is **professional service fee**, NOT referral. Service agreement with explicit deliverables. Doctor invoices and pays GST/income tax.
- No cash kickbacks. No commissions for prescribing. Ever.
- Day-91 churn is the bar metric for Phase 1 → Phase 2 progression. Track from week 1.

---

## 6. Persona validations (signed off)

### Vikram Chakraborty — Health-tech VC

> "Three-sided market with doctor distribution is structurally different from every DTC longevity comp. Show Phase 1 numbers in 90 days and we have a seed conversation. The revenue share is the unlock — without it the doctor flywheel is theoretical."

**What he wants on the next deck:** clinical advisory board names, 1 doctor-payout screenshot, M3 retention curve, sub-Rs 200 CAC proof.

### Meera Krishnan — Ex-McKinsey strategist

> "Phase boundaries are clean — each phase introduces ONE new thing. Triggers must be 'count + retention,' not just count. The doctor flywheel was always the real moat; don't let the longevity-OS framing pull you off it."

**What she wants:** disciplined Phase 1 execution. Stop polishing decks. 10 doctors signed, 30 paying families, by day 90.

### Dr. Rajesh Verma — Indian physician + clinical/legal lens

> "Coaching framing is clinically defensible AND legally far cleaner than 'predict / avoid disease.' Doctor signing the quarterly report is the legal wrapper for the diagnostic-adjacent product. Service-fee structure (not referral) keeps NMC happy."

**Non-negotiable:** doctor dashboard must gate on "data reviewed" before they can sign the report. If it becomes rubber-stamping, the legal cover collapses.

---

## 7. The kill list — what we are NOT doing

These distractions will be politely declined:

- ❌ "Predict and avoid disease" framing — replaced with coaching language
- ❌ TAM-stacking slide ($40-50B longevity market) — pick ONE bucket, prove the first $1M of it
- ❌ Phased platform pitch on slide 2 — phases live in this doc, not the deck
- ❌ Tier-2/3-first / NRI-second sequencing — flipped: NRI funds the company, Tier-2/3 makes the product good
- ❌ DTC consumer pivot for healthy worried-well users — that's Phase 6+, not now
- ❌ Doctor-as-customer monitoring app (Apr 2026 hypothesis, not chosen) — doctor is the channel, not the buyer
- ❌ Hardware before nudge engine — software differentiation first, CapEx later
- ❌ Bloodwork before retention proof — earn it
- ❌ Chinese-style health super-app — narrow knife edge wins, breadth dies

---

## 8. NRI validation questions (Mom Test compliant)

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

## 9. Doctor onboarding pitch (use exactly)

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

---

## 10. Founder edge — to be filled in by Amit

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

## 11. Open questions and homework

These are not yet answered. Track them; resolve before Series A pitch.

- [ ] Founder-edge sentence (Amit, by next pitch)
- [ ] Clinical advisory board (3–5 senior Indian physicians, equity, by Phase 1 doctor #1)
- [ ] Service agreement legal draft (health-tech lawyer, before doctor #1)
- [ ] Phase 1 retention curve target — confirm 50% M3 is right for chronic-disease subscription (compare to Livongo, Omada benchmarks)
- [ ] Hardware unit cost target by Phase 3 — quote 3 OEMs (BPL, Omron, Dr. Morepen)
- [ ] CDSCO / BIS pathway — start at Phase 2 (3–6 month runway)
- [ ] Insurance partnership conversations — open at Phase 2; revenue starts Phase 6

---

## 12. Standards integration roadmap

Each phase introduces ONE standard that unlocks the next business layer. Standards are not features — they are plumbing that opens doors. Reference: `docs/HEALTH_STANDARDS_REFERENCE.md`.

| Phase | Standard added | Business door it opens |
|---|---|---|
| **Phase 0 (now)** | LOINC codes in `fhir_loinc_map` · FHIR Facade schema · DPDPA encryption + audit logs | Table-stakes hygiene; signals "FHIR-aware architecture" |
| **Phase 1** | ABDM HPR (doctor verification) · ICD-10 in preventive report · DPDPA explicit consent flow · SNOMED basic concepts (T2DM, HTN, CKD) | "Clinical infrastructure from Day 1" — kills "is this doctor real?" objection · DPDPA-clean for any audit |
| **Phase 2** | FHIR R4 export endpoint · ABDM **HIU registration** · ABHA mandatory for new patients · SNOMED CT for AI reasoning | India regulatory moat — hospitals start sharing data INTO Swasth via consent · SNOMED-driven AI = real ML moat (not prompt-engineering) |
| **Phase 3** | BIS + CDSCO hardware certification · HL7 v2 lab ingestion · DICOM-ready architecture | Legal sale of medical devices in India · zero-cost lab partnerships |
| **Phase 4** | Full FHIR R4 round-trip with labs (Thyrocare, Redcliffe, Dr Lal) · LOINC on every imported value · ICD-10 risk-stratification | Lab partnerships at scale (every Indian lab will report in FHIR/LOINC by 2027 mandate) · AI longevity report becomes legally defensible |
| **Phase 5** | FHIR Genomics module · polygenic risk scores tied to SNOMED · DISHA full audit compliance | Same data structure as Function Health and Galleri — interoperable, exportable, uncopyable on closed-stack codebase |
| **Phase 6** | **NHCX** (National Health Claims Exchange) · ABDM HIP registration · risk-stratified cohort export to insurers | Insurance reimbursement REQUIRES NHCX — without it no insurer can pay you. With it, every Indian health insurer is a potential channel |

### Why standards are part of the moat (not just compliance)

- **Standards-coded data = exit-multiple compounding.** A standards-compliant longevity stack commands 2–3× the multiple of a closed-stack clone (Apollo / Manipal / Teladoc / global health-tech bidders pay for portable interoperable data, not feature parity).
- **Standards = global story.** FHIR + LOINC + SNOMED is the same vocabulary Function Health, Galleri, and every serious global longevity player uses. Investors hear "this works in any market," not "Indian niche."
- **Standards = regulatory tailwind.** ABDM compliance becomes mandatory for insurance bundling. Hospitals integrating with us require FHIR. Labs reporting to us by 2027 will require LOINC. Building these in now turns future regulation from a tax into a moat.

### The 6th moat layer (add to slide 8)

> **Standards-coded interoperability** = our data is portable, exportable, FHIR-native, and ABDM-registered from Day 1. Closed-stack competitors face a 12–18 month rebuild to match. Open-stack global competitors face the India distribution wall we own. The intersection: uncatchable.

---

## 13. Source-of-truth mapping

When other docs disagree with this one, **this one wins** until updated. Other docs should reference this:

- `WORKING-CONTEXT.md` — sprint board (mirrors current phase milestone)
- `TASK_TRACKER_PENDING.md` — tactical work items per phase
- `RULES.md` — engineering invariants (language, l10n, auth, etc.)
- `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` — legal requirements
- `KNOWN_ISSUES.md` — security + technical debt
- Pitch deck, outreach drafts, founder-pitch — all derive from sections 1, 2, 6, 9, 10 above

When this doc changes, **bump the date at the top and note the change reason inline.**

---

## Change log

- **2026-04-29 (initial):** Motherbook created. Synthesised from full strategy session: longevity-OS reframe → doctor flywheel locked as moat → user's 5-phase plan validated by Vikram + Meera + Dr. Rajesh → Rs 1,000/Rs 500 split locked → unit economics modelled → kill list and Mom-Test questions documented.
- **2026-04-29 (update 1):** Public tagline locked: *"Add years. Live them."* Investor one-liner locked: *"India's longevity coach for chronic-disease elderly — doctor-distributed, family-paid."* Pricing ladder locked: day-0–30 Rs 1,000 / day-31–90 Rs 10/day / day-91+ Rs 1,000. Coupon system replaces free tier. Doctor share stays flat Rs 500/mo; Swasth absorbs the discount-window gap. "Sponsor a parent" coupon flow added as Phase 1 feature. Day-91 step-up retention added as Phase 1 → Phase 2 exit trigger.
- **2026-04-29 (update 2):** Section 12 added — Standards integration roadmap. Each phase mapped to a specific standard (LOINC/FHIR/HPR/SNOMED/HIU/ABHA/CDSCO/HL7v2/NHCX/HIP) and the business door it unlocks. 6th moat layer (standards-coded interoperability) defined. Investor pitch slide 8 to reflect this update.
- **2026-05-02 (recovery + FOFO update):** File recovered from stash after disappearing during markdown consolidation. NEW: FOFO (Fear Of Finding Out) wedge added based on session discovery — patients refuse to measure due to fear of seeing the device LCD reading; ~40% of elderly Indians hide their meter (Dr. Rajesh confirmed). Software-only solve at P0 — stickered Omron + Bluetooth pairing + rolling-median signal engine (per ESH 2023 + HOPE Asia + ICMR IGH-IV for BP; ADA 2025 for glucose). Patient sees green/amber/red only; coach + doctor see raw truth. Single-reading clinical-red bypass for safety. Full clinical spec: `docs/HEALTH_SIGNAL_LOGIC.md`. NEW: investor-pushback pitch rewrite (two no's, same "Apple Watch / Rs 999 too high" objection) — daughter-as-hero positioning, Apple Watch teardown slide, two-tier pricing offer (Rs 499 Care Lite / Rs 1499 Care Plus) to disarm price objection. None of this changes phase boundaries or exit triggers; FOFO is a Phase 1 feature inside the existing spine. Validation gate before any DEV2 code: 5 NRI daughter calls + Razorpay test page + Dr. Rajesh/Legal/PHI sign-offs. See `docs/SESSION_2026-05-02_FOFO_DIGEST.md` for persona panels and full reasoning.
