# Swasth Marketing Strategy — Working Document

**Created:** 2026-04-12
**Status:** Phase 1 decisions locked. Execution starts April 13.
**Reference:** Medvi blueprint (orchestration layer model), Vikram VC feedback

---

## Strategic Framework (Vikram's Verdict)

**Current fundability: 3/10. Target: 8/10 by September 2026.**

Three phases, in order. Do NOT skip ahead.

### Phase 1: NRI Waitlist Campaign (April–May)
- **Goal:** 200-500 waitlist sign-ups from NRIs abroad
- **Why:** Validates demand before Bihar landing. Gives a number for the pitch deck.
- **Budget:** ₹5,000-10,000 one-time test
- **Target audience:** Indians aged 28-50 living in Germany, Canada, Singapore, Dubai, US, UK — worried about parents' health back home
- **Creative needed:** One 60-second video ad (Script 1, English, family/caregiver angle) + landing page on swasth.health
- **Media buying:** Amit's friend (digital marketing). Fee estimated at 15-20% of ad spend.
- **Facebook targeting:** "Expats from India" audience, Hindi language filter, age 28-50, interests: India/Indian culture

### Phase 2: Bihar Organic Pilot (June–August)
- **Goal:** 100 patients logging readings 4+ days/week for 45+ days
- **Budget:** ₹0 ad spend. Organic only.
- **Method:** Doctor partnerships (in-clinic onboarding), compounder/pharmacy network, WhatsApp family viral loop
- **Key metric:** Week 4 retention > 40%
- **Devices:** Photo OCR first (zero hardware dependency). Bluetooth for patients who already own compatible devices.

### Phase 3: Paid Scale (August–September)
- **Goal:** Show investors you can scale the proven organic channel
- **Budget:** ₹30,000-60,000/month
- **Prerequisites:** Retention data from Phase 2, known CAC from Phase 1 waitlist, clinical signal from 5-10 patients
- **Creative:** All 4 video scripts (patient, family, doctor, investor) + static image ad variants
- **Platforms:** 80% Facebook/Instagram, 15% YouTube, 5% Google Search

---

## Video Scripts Status

| # | Script | Audience | Language | VO | Status |
|---|---|---|---|---|---|
| 1 | Family/Caregiver hook | NRI adult children | English | English (Sarvam AI or ElevenLabs) | v3 complete in `docs/VIDEO_SCRIPTS_AND_TEST_DATA.md`. Needs update for NRI waitlist CTA. |
| 2 | Patient direct | Patients in Bihar | Hindi | Hindi (Sarvam AI) | Not started |
| 3 | Doctor pitch | Bihar doctors/clinic owners | English | English | Not started |
| 4 | Investor | VCs, angels | English | English | Not started |

**Production model:** App walkthrough + AI-generated stills (Google Imagen/Banana). No live-action. Scripts in English, Script 2 translated to Hindi externally.

**Image generation:** Google Imagen ("Banana") via Google AI Studio. Detailed prompts (200+ words each) in VIDEO_SCRIPTS_AND_TEST_DATA.md.

**Voice:** Sarvam AI (Indian languages, to be evaluated) or ElevenLabs. Final Hindi VO: hire Bihari-accent voice artist on Fiverr (₹2-5K).

---

## Waitlist Landing Page (swasth.health)

**Domain:** swasth.health (purchased)
**Fields:**
1. Name
2. City (where they live)
3. Parent's city (where the parent lives)
4. "What health topics interest you?" — checkboxes: Diabetes management, Blood pressure monitoring, General wellness
   - (Rephrased from "does your parent have diabetes" per DPDPA legal review — avoids sensitive personal data classification)

**Required on page:**
- Privacy policy link (draft with Claude)
- Consent notice: "By signing up, you agree to receive updates from Swasth. We won't share your data."

**Design:** Single page, mobile-first, hero section with app demo video, one CTA ("Join the waitlist"), feature highlights below.

---

## Budget Summary

| Item | Phase 1 (Apr-May) | Phase 2 (Jun-Aug) | Phase 3 (Aug-Sep) | Total |
|---|---|---|---|---|
| Ad spend | ₹5,000-10,000 | ₹0 | ₹60,000-120,000 | ₹65,000-130,000 |
| Media buyer (20%) | ₹1,000-2,000 | ₹0 | ₹12,000-24,000 | ₹13,000-26,000 |
| Creative tools | ₹2,000 | ₹0 | ₹2,000 | ₹4,000 |
| Fiverr VO artist | ₹0 | ₹0 | ₹3,000-5,000 | ₹3,000-5,000 |
| **Total** | **₹8,000-14,000** | **₹0** | **₹77,000-151,000** | **₹85,000-165,000** |

---

## What Investors Need to See (Vikram's Checklist)

| Metric | Target | When |
|---|---|---|
| Daily active usage | 60+ patients, 4+ days/week | By August |
| Week 4 retention | > 40% | By mid-July (45 days after first onboarding) |
| Clinical signal | 5-10 patients with improved readings, doctor-attested | By August |
| Waitlist sign-ups | 200-500 NRIs | By May |
| Company registered | Pvt Ltd, PAN, bank account | By end of May |
| Co-founder agreement | Signed | By end of April |

---

## Key Decisions Log

| Date | Decision | Rationale |
|---|---|---|
| 2026-04-12 | NRI waitlist before Bihar pilot | Validates demand remotely. NRIs are the distribution channel (install on parent's phone). |
| 2026-04-12 | ₹0 ad spend for first 100 patients | Organic doctor/compounder channel proves product-market fit. Ads prove scale. |
| 2026-04-12 | Photo OCR first, devices in Phase 2 | Zero hardware dependency at launch. Expands addressable market. |
| 2026-04-12 | English for Scripts 1,3,4; Hindi for Script 2 only | NRIs and doctors comfortable in English. Only patient-direct video needs Hindi. |
| 2026-04-12 | Rephrase health question on waitlist | DPDPA compliance — "health topics interest you" vs "does parent have diabetes" |
| 2026-04-12 | Company registration by end of May | Vikram's advice — signals commitment, needed for bank account. Dormancy is cheap if things don't work. |

---

*Next session: Build Script 1 (NRI-focused), produce ad creative package, design swasth.health landing page.*
