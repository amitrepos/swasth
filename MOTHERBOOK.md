# Swasth — Motherbook

> **Source of truth.** Phases + triggers + 2-min pitches only.
> Everything else (personas, unit economics, kill list, validation questions, standards roadmap, change log) → `MOTHERBOOK_FEEDBACK.md`.
> Last updated: 2026-05-02

---

## 1. Phase plan + exit triggers

Each phase introduces ONE new capability and gates on a measurable trigger. Don't promise Phase N to anyone before Phase N-1 has hit its trigger.

### PHASE 0 — Current Swasth (in market today)

**What:** Free app. Daily logging of BP, sugar, weight, food. Basic AI insights. NRI dashboard view. Hindi + English.

**Exit trigger to Phase 1:**
- 5 doctors actively prescribing
- 50 patients logging weekly
- 30%+ of those patients have an NRI child willing to take a 15-min call

---

### PHASE 1 — Monetisation + Doctor Flywheel

**What:**
- **Pricing ladder (no free tier):** Day 0–30 Rs 1,000/mo full price → Day 31–90 Rs 10/day (~Rs 300/mo) habit-formation discount → Day 91+ Rs 1,000/mo full.
- **Coupon system replaces "free"** (sponsored, NGO, doctor goodwill, NRI "Sponsor a Bihar grandmother").
- **Doctor revenue share:** Rs 500/mo flat per active family — including the discount window. **Swasth absorbs the gap.**
- **Doctor's deliverable:** review patient data + sign quarterly preventive report + 1 tele-consult/quarter (~5 hrs/yr/patient).
- **FOFO solve (added 2026-05-02):** stickered Omron + Bluetooth + rolling-median signal engine. Patient sees green/amber/red only. Spec: `docs/HEALTH_SIGNAL_LOGIC.md`.

**Exit trigger to Phase 2:**
- 50 paying NRI families
- M3 retention ≥ 50%
- **Day-91 step-up retention ≥ 60%** (the price-jump churn test)
- 10 doctors earning ≥ Rs 2K/mo each
- NPS from at least 30 families

---

### PHASE 2 — AI Nudge / Virtual Health Friend

**What:**
- Daily AI coach: notices, sets micro-goals, celebrates streaks.
- Comorbidity-tuned (HTN module first, then T2DM).
- Lifestyle language only ("skip breakfast today" — never "you might have diabetes").
- Loneliness companion layer for elderly living alone.
- Price: Rs 1,500/mo. Doctor share: Rs 600/mo (40%).

**Exit trigger to Phase 3:**
- 200 paying families
- DAU/MAU ≥ 50%
- M6 retention ≥ 50%
- ≥3 measurable per-user behaviour change wins (e.g., +30% medication adherence, –1 kg avg weight in 60 days)

---

### PHASE 3 — Hardware Integration

**What:**
- Branded BP cuff + glucometer + smart scale, Bluetooth auto-sync.
- Bundled into subscription (Rs 2,000/mo bundled, OR Rs 1,500/mo + Rs 3,000 hardware one-time).
- CDSCO + BIS certification (paperwork started in Phase 2).
- Doctor share: Rs 700/mo (35%).

**Exit trigger to Phase 4:**
- 1,000 paying families
- Hardware attach-rate > 60%
- Gross margin ≥ 35%
- Hardware return rate < 5%

---

### PHASE 4+ — Layered later, gated by prior phase's retention + margin proof

| Phase | Capability | Pricing notch | Exit gate |
|------:|---|---|---|
| 4 | Annual bloodwork + AI longevity report | Rs 2,500/mo | Lab partnership live + report in market 6 months |
| 5 | One-time genetic test + personalized longevity targets | Rs 3,500 one-time + ongoing sub | Genetic flow shipped + 100+ tests sold |
| 6 | Insurance / employer B2B2C distribution | Reimbursement-priced | First insurer reimbursement contract signed |

**Each phase gates on the prior phase's retention + margin proof. We don't build Phase 5 until Phase 4 sticks.**

---

## 2. Two-minute pitches (1-2 lines each)

### Investor (2 min)
> *Swasth is India's longevity coach for chronic-disease elderly — doctor-distributed, family-paid. Indian doctors prescribe the app to hypertensive and diabetic patients; NRI children pay Rs 1,000/mo to see Mom's vitals from abroad and get a doctor-signed quarterly preventive report. Three-sided market — doctor distributes, patient adopts, family pays — gives us a structural moat no DTC longevity comp can replicate in India.*

### Patient (2 min, Hindi-leading)
> *"Maaji/Babuji, yeh aapke doctor saheb ka diya hua app hai. Rozana BP aur sugar machine pe naapiye — phone mein apne aap chala jaayega. Aapko number nahi dekhna; bas yeh dekhna ki aaj hara, peela, ya laal hai. Beti/beta videsh se aapki sehat dekh sakte hain. Doctor saheb teen mahine mein ek baar aapki report sign karte hain. Roz 5 minute, aur saal-bhar tandurusti."*

### Doctor (2 min)
> *"Apne hypertensive aur diabetic mareezon ke liye Swasth prescribe kijiye. Mareez rozana BP, sugar, khana log karenge — aapko ek dashboard milega. Aapka kaam: hafte mein patient data review karna + quarterly preventive report sign karna + ek tele-consult per quarter (~5 ghante saal mein per patient). Rs 500/mo per active mareez — professional service fee, NOT referral. 10 mareez = Rs 5,000/mo passive. Service agreement, NMC clean, GST taxable. Free shuru kijiye."*

---

**End of motherbook.** When in doubt, this file wins. When you change strategy, change this file first.
