# FHIR R4 Aware Postgres Schema — Implementation Plan

## Context

Swasth needs to be "FHIR-aware" for investor pitches and future ABDM (Ayushman Bharat) integration. The goal is to structure the database so every health reading can be exported as a valid HL7 FHIR R4 Observation resource — without breaking the existing app, tests, or Flutter frontend.

A Gemini consultant suggested separate `patients`/`vitals` tables with UUID primary keys. **We reject that approach** — it would require 50-80 hours of refactoring across 363 tests and the entire Flutter frontend. Instead, we use a **"FHIR Facade"** pattern: add FHIR columns to existing tables + Postgres VIEWs that generate FHIR JSON on demand.

---

## Approach: FHIR Facade (Not Rewrite)

**Add columns to existing tables. Create Postgres VIEWs for FHIR JSON. Keep integer PKs. Add UUID as secondary identifier.**

| Decision | Choice | Rationale |
|---|---|---|
| Separate tables? | No — add columns | Avoids sync problems, zero app changes |
| UUID primary keys? | No — add `fhir_id UUID` alongside integer `id` | Keeps 363 tests + Flutter working |
| LOINC mapping? | Reference table `fhir_loinc_map` | Data not code, extensible |
| Auto-populate FHIR fields? | Postgres trigger on INSERT | Works for all data entry paths |
| FHIR JSON output? | Postgres VIEW `vitals_fhir_view` | Demo-ready, zero Python code |

---

## Current Schema → FHIR R4 Mapping

| Our Table/Column | FHIR R4 Resource/Field | Notes |
|---|---|---|
| `profiles` | **Patient** | name, gender, birthDate, identifier (ABHA) |
| `profiles.name` | Patient.name[0].text | Direct map |
| `profiles.gender` | Patient.gender | Map Male/Female/Other → male/female/other |
| `profiles.age` | Patient.birthDate | Derive from age |
| `profiles.abha_address` (new) | Patient.identifier[0] | system: `https://healthid.abdm.gov.in` |
| `profiles.abha_number` (new) | Patient.identifier[1] | system: `https://healthid.ndhm.gov.in` |
| `health_readings` (glucose) | **Observation** | Single valueQuantity |
| `health_readings` (BP) | **Observation** | Component array (systolic + diastolic) |
| `glucose_value` + `glucose_unit` | Observation.valueQuantity | quantity with UCUM unit mg/dL |
| `systolic` + `diastolic` | Observation.component[0,1] | BP is multi-component in FHIR |
| `pulse_rate` | Observation.component[2] | Heart rate component |
| `reading_type` | Observation.code | Maps to LOINC via lookup table |
| `reading_timestamp` | Observation.effectiveDateTime | Direct map |
| `status_flag` | Observation.interpretation | Map NORMAL/HIGH/CRITICAL to FHIR codes |
| `profile_id` | Observation.subject | Reference: `Patient/{fhir_id}` |
| `logged_by` | Observation.performer | Reference to user |
| `notes` | Observation.note[0].text | Optional narrative |
| `profiles.medical_conditions` | **Condition** | Future: separate Condition resources |
| `profiles.current_medications` | **MedicationStatement** | Future: separate resources |
| `profiles.doctor_*` | **Practitioner** | Future: separate resource |
| `profile_access` | **CareTeam** | Future: participant roles |

---

## LOINC Code Mappings

| Reading Type | LOINC Code | Display Name | UCUM Unit | Category |
|---|---|---|---|---|
| glucose | 2339-0 | Glucose [Mass/volume] in Blood | mg/dL | vital-signs |
| blood_pressure (panel) | 85354-9 | Blood pressure panel | mm[Hg] | vital-signs |
| systolic (component) | 8480-6 | Systolic blood pressure | mm[Hg] | vital-signs |
| diastolic (component) | 8462-4 | Diastolic blood pressure | mm[Hg] | vital-signs |
| pulse_rate (component) | 8867-4 | Heart rate | /min | vital-signs |

---

## New Columns to Add

### On `profiles` table:
| Column | Type | Default | Purpose |
|---|---|---|---|
| `fhir_id` | UUID (stored as String(36)) | `gen_random_uuid()` | Stable FHIR resource identifier |
| `abha_address` | VARCHAR(255) | NULL | e.g. `ramesh@abdm` |
| `abha_number` | VARCHAR(14) | NULL | 14-digit ABHA Health ID |
| `fhir_meta` | JSONB / Text | NULL | Extensible FHIR metadata |

### On `health_readings` table:
| Column | Type | Default | Purpose |
|---|---|---|---|
| `fhir_id` | UUID (stored as String(36)) | `gen_random_uuid()` | Stable FHIR Observation identifier |
| `loinc_code` | VARCHAR(20) | NULL (auto-populated by trigger) | e.g. "2339-0" |
| `loinc_display` | VARCHAR(255) | NULL (auto-populated by trigger) | e.g. "Glucose [Mass/volume] in Blood" |
| `fhir_status` | VARCHAR(20) | 'final' | preliminary, final, corrected, entered-in-error |
| `effective_at` | TIMESTAMPTZ | NULL (copied from reading_timestamp) | FHIR effectiveDateTime |

### New reference table: `fhir_loinc_map`
| Column | Type | Purpose |
|---|---|---|
| `reading_type` | VARCHAR (PK) | Matches health_readings.reading_type |
| `loinc_code` | VARCHAR | LOINC code |
| `loinc_display` | VARCHAR | Human-readable name |
| `ucum_unit` | VARCHAR | UCUM unit code |
| `fhir_category` | VARCHAR | 'vital-signs' |

---

## Postgres Trigger for Auto-Population

A `BEFORE INSERT` trigger on `health_readings` automatically populates FHIR fields:

```
ON INSERT:
  fhir_id      ← gen_random_uuid() if NULL
  effective_at  ← reading_timestamp if NULL
  fhir_status   ← 'final' if NULL
  loinc_code    ← lookup from fhir_loinc_map by reading_type
  loinc_display ← lookup from fhir_loinc_map by reading_type
```

**Why trigger instead of Python code:**
- Works for ALL data entry paths (API, seed scripts, manual SQL, bulk import)
- Zero Python code changes
- Flutter app and API contracts remain unchanged

---

## Postgres VIEWs for FHIR JSON

### `vitals_fhir_view` — FHIR R4 Observation

Produces valid FHIR R4 Observation JSON using `jsonb_build_object()`. Example output:

```json
{
  "resourceType": "Observation",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "final",
  "category": [{
    "coding": [{"system": "http://terminology.hl7.org/CodeSystem/observation-category", "code": "vital-signs"}]
  }],
  "code": {
    "coding": [{"system": "http://loinc.org", "code": "2339-0", "display": "Glucose [Mass/volume] in Blood"}]
  },
  "subject": {"reference": "Patient/660e8400-a29b-41d4-b716-556655440000"},
  "effectiveDateTime": "2026-04-01T08:30:00+05:30",
  "valueQuantity": {"value": 120.0, "unit": "mg/dL", "system": "http://unitsofmeasure.org", "code": "mg/dL"}
}
```

For BP readings, uses `component` array with systolic, diastolic, and pulse rate.

### `patient_fhir_view` — FHIR R4 Patient

```json
{
  "resourceType": "Patient",
  "id": "660e8400-a29b-41d4-b716-556655440000",
  "identifier": [
    {"system": "https://healthid.abdm.gov.in", "value": "ramesh@abdm"},
    {"system": "https://healthid.ndhm.gov.in", "value": "12345678901234"}
  ],
  "name": [{"text": "Ramesh Kumar"}],
  "gender": "male"
}
```

---

## Implementation Steps

| Step | What | Effort | Risk |
|---|---|---|---|
| 1 | Add FHIR columns to `models.py` (Profile + HealthReading) | 0.5 hr | Very low — all nullable |
| 2 | Create `migrate_fhir_awareness.py` (DDL + trigger + LOINC seed + VIEWs) | 2-3 hr | Low — follows existing pattern |
| 3 | Run existing 363 tests — verify nothing breaks | 0.5 hr | Very low — no behavior change |
| 4 | Run migration on dev server | 0.5 hr | Low — idempotent script |
| 5 | Demo: `SELECT fhir_json FROM vitals_fhir_view LIMIT 3` | 0.5 hr | None |
| **Total** | | **4-5 hours** | |

---

## What We DON'T Change

| Item | Why not |
|---|---|
| Integer primary keys | Breaking 363 tests + Flutter frontend (50-80 hrs refactoring) |
| Pydantic schemas | Flutter doesn't need FHIR fields |
| `routes_health.py` save_reading() | Trigger handles population, not Python |
| Flutter frontend | Zero changes needed |
| Test infrastructure | New columns are nullable, tests unaffected |

---

## Investor Pitch Demo

After migration, open terminal and run:

```sql
-- Show FHIR-compliant Observation
SELECT fhir_json FROM vitals_fhir_view WHERE profile_id = 1 LIMIT 3;

-- Show FHIR-compliant Patient
SELECT fhir_json FROM patient_fhir_view WHERE id = 1;
```

**Pitch script:**
> "Our backend is natively interoperable. We don't just store '140 sugar' — we store LOINC 2339-0 in a format that the National Health Stack accepts. Here is the FHIR bundle my system generated just now. When ABDM integration opens, we flip a switch — not rewrite the database."

---

## Future Extensions (Not in This Phase)

| Extension | When | Effort |
|---|---|---|
| FHIR API endpoints (`/fhir/Observation`, `/fhir/Patient`) | When connecting to hospitals | 1-2 days |
| ABDM HIP registration | When government portal opens | 1-2 weeks + approval |
| ABHA ID linking in app UI | After FHIR API is built | 1 day |
| Condition + MedicationStatement resources | When needed for clinical handoff | 1 day each |
| FHIR Bundle export (full patient record) | For hospital transfers | 1 day |

---

## Files Involved

| File | Action |
|---|---|
| `backend/models.py` | Modify — add FHIR columns |
| `backend/migrate_fhir_awareness.py` | Create — migration script |
| `backend/tests/conftest.py` | May need minor JSONB→JSON patch for SQLite |
| `docs/FHIR_R4_IMPLEMENTATION_PLAN.md` | This document |
