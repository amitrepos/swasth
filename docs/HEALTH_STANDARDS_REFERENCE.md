# Health Standards Reference — Swasth Knowledge Base

A practical reference for the global health data standards Swasth follows (or plans to follow).
Using these standards signals credibility to hospitals, investors, and ABDM partners.

---

## 1. FHIR R4 — Data Exchange Standard

**What:** HL7's REST+JSON standard for exchanging health data between systems.
**India relevance:** ABDM (Ayushman Bharat) uses FHIR R4. Any hospital integration requires it.
**Our plan:** FHIR Facade pattern — see `docs/FHIR_R4_IMPLEMENTATION_PLAN.md`.

**Sample Observation resource (glucose reading):**
```json
{
  "resourceType": "Observation",
  "status": "final",
  "code": { "coding": [{ "system": "http://loinc.org", "code": "2339-0", "display": "Glucose" }] },
  "subject": { "reference": "Patient/profile-uuid-123" },
  "effectiveDateTime": "2026-04-26T08:30:00+05:30",
  "valueQuantity": { "value": 180, "unit": "mg/dL", "system": "http://unitsofmeasure.org" }
}
```

**Key FHIR Resources we use:**
| Resource | Maps to |
|---|---|
| `Patient` | `profiles` table |
| `Observation` | `health_readings` table |
| `MedicationRequest` | future prescriptions |
| `Encounter` | future doctor visits |

---

## 2. LOINC — Lab & Measurement Codes

**What:** 100,000+ codes for every measurable clinical concept (labs, vitals, surveys).
**Publisher:** Regenstrief Institute. Free download at `loinc.org`.
**Rule:** LOINC codes identify *what was measured*, not *what disease*.

**Our key LOINC codes:**
| Measurement | LOINC Code |
|---|---|
| Systolic BP | `8480-6` |
| Diastolic BP | `8462-4` |
| Glucose (random) | `2339-0` |
| Glucose (fasting) | `76629-5` |
| HbA1c | `4548-4` |
| Body weight | `29463-7` |
| BMI | `39156-5` |
| SpO2 | `59408-5` |
| Heart rate | `8867-4` |
| Steps (daily) | `55423-8` |

**When to use in Swasth:**
- Now: reference table `fhir_loinc_map` (see FHIR_R4_IMPLEMENTATION_PLAN.md)
- Future: lab report PDF parsing → map free-text ("FBS", "RBS") to LOINC codes via NLP

---

## 3. ICD-10 — Diagnosis Codes

**What:** International Classification of Diseases, 10th edition. Used for billing, reporting, referrals.
**Publisher:** WHO. India uses ICD-10 (some states moving to ICD-11).
**Rule:** ICD-10 codes identify *diagnoses*, not measurements.

**Common codes for our patient population:**
| Condition | ICD-10 Code |
|---|---|
| Type 2 Diabetes (unspecified) | `E11.9` |
| Type 2 Diabetes with kidney complication | `E11.65` |
| Essential Hypertension | `I10` |
| Hypertensive heart disease | `I11.9` |
| Obesity | `E66.9` |
| Hypothyroidism | `E03.9` |
| Chronic kidney disease, stage 3 | `N18.3` |

**When to use in Swasth:**
- Doctor portal: doctor tags patient's conditions for referral letters and insurance.
- AI insights: map `medical_conditions` free-text → ICD-10 for structured reasoning.

---

## 4. SNOMED CT — Clinical Terminology

**What:** Rich clinical concept library with relationships between concepts.
**Publisher:** SNOMED International. India is a member — free to use.
**India reference sets:** Published by NRCeS (`nrces.in`).
**Rule:** SNOMED covers diagnoses, procedures, body structures, organisms — richer than ICD-10.

**Key difference from ICD-10:**
- ICD-10 = flat code for billing
- SNOMED = concept graph with relationships ("T2DM *is-a* Diabetes *is-a* Metabolic disorder")

**Sample codes:**
| Concept | SNOMED Code |
|---|---|
| Type 2 Diabetes | `44054006` |
| Hypertensive disorder | `38341003` |
| Obesity | `414916001` |
| Chronic kidney disease | `709044004` |
| Hypothyroidism | `40930008` |

**When to use in Swasth:**
- AI reasoning layer: "patient has `44054006` → monitor glucose + HbA1c + kidney markers"
- ABDM interoperability: SNOMED codes required in FHIR resources for clinical concepts

---

## 5. ABDM (Ayushman Bharat Digital Mission) — India's Digital Health Stack

**What:** Government's federated health data backbone. Not a central DB — consent-based exchange.
**Run by:** National Health Authority (NHA). Developer portal: `abdm.gov.in`.

**Core components:**
| Component | What it is |
|---|---|
| ABHA | 14-digit citizen health ID (Aadhaar-linked) |
| HPR | Healthcare Professional Registry — doctor verification |
| HFR | Health Facility Registry — clinic/hospital IDs |
| HIU | Health Information User — apps that *read* patient data (we become this) |
| HIP | Health Information Provider — clinics that *share* patient data |

**Our integration plan:**
- Phase 1 (pilot): none — manual doctor entry, NMC number stored
- Phase 2 (scale): HPR verification for doctor onboarding, ABHA ID linkage for patients
- Phase 3 (hospital partnerships): full HIU registration, FHIR-based data pull

---

## 6. Other Standards to Watch

| Standard | What | When relevant |
|---|---|---|
| `HL7 v2` | Older hospital messaging (still in most Indian labs) | Lab report integration |
| `DICOM` | Medical imaging (X-rays, MRI, CT) | If we ever add imaging |
| `openEHR` | Archetype-based EHR (used by some Indian state govts) | State govt partnerships |
| `NHCX` | National Health Claims Exchange — insurance claims | Insurance tie-ups |
| `DPDPA 2023` | India's data protection law — governs all PHI we store | NOW — already implementing |

---

## 7. Standards Maturity Roadmap for Swasth

| Phase | What we implement | Signal to market |
|---|---|---|
| **Pilot (now)** | LOINC codes in `fhir_loinc_map` table, FHIR Facade schema | "FHIR-aware architecture" |
| **Scale (post-100 DAU)** | FHIR R4 export endpoint, ICD-10 in doctor portal | "ABDM-ready" |
| **Hospital partnerships** | Full HIU registration, ABHA linkage, SNOMED clinical terms | "Interoperable EHR" |

---

*Last updated: 2026-04-26*
*Reference: Health Meetup Keywords doc — `docs/swasth-project-keywords.md.pdf`*
