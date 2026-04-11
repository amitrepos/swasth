---
name: phi-compliance
description: "Health data (PHI) compliance audit — DPDPA, DISHA, encryption, audit trails"
model: opus
---

# PHI Compliance Audit — India Health-Tech

Audit the codebase for Protected Health Information (PHI) compliance under Indian regulations.

## Applicable Regulations
- **DPDPA 2023** — Digital Personal Data Protection Act (India)
- **DISHA** — Digital Information Security in Healthcare Act (India, draft)
- **IT Act 2000** — Information Technology Act, Section 43A (sensitive personal data)
- **NMC Guidelines** — National Medical Commission ethics guidelines

## PHI Classification
The following data types are PHI in this project:
- Glucose readings, BP readings, weight, BMI
- Health score, streak data, AI insights
- Medication lists, medical conditions
- Doctor details (name, specialty, WhatsApp)
- Profile data (age, gender, blood group)

## Audit Checklist

### 1. Data at Rest
- [ ] Health readings encrypted with AES-256-GCM in database
- [ ] Encryption keys stored in environment variables, not code
- [ ] Database backups encrypted
- [ ] No PHI in log files (`print()`, `logging.info()`, error messages)
- [ ] No PHI in client-side storage without encryption (SharedPreferences, etc.)

### 2. Data in Transit
- [ ] All API calls over HTTPS/TLS
- [ ] JWT tokens don't contain PHI in payload
- [ ] No PHI in URL query parameters (use POST body)
- [ ] WebSocket connections (if any) use WSS

### 3. Access Control
- [ ] Every health data endpoint requires authentication (`get_current_user`)
- [ ] Profile-level access control enforced (owner/editor/viewer)
- [ ] No endpoint returns another user's health data without authorization
- [ ] Admin endpoints have separate admin-level auth

### 4. Consent & Rights
- [ ] Consent screen shown before data collection (D18 — Done)
- [ ] Consent timestamp, app version, language recorded
- [ ] Right to deletion: user can request data deletion
- [ ] Right to access: user can export their data
- [ ] Data purpose limitation: data used only for stated purpose

### 5. Audit Trail
- [ ] AI insight calls logged to `ai_insight_logs` table
- [ ] Health data access logged (who accessed whose data, when)
- [ ] Data modifications logged (create, update, delete)
- [ ] Login attempts logged (success and failure)

### 6. Common Leak Vectors
- [ ] Error responses don't expose PHI (stack traces, debug info)
- [ ] Console/debug output doesn't contain PHI
- [ ] URL parameters don't contain PHI
- [ ] Browser storage (if web) doesn't store unencrypted PHI
- [ ] Screenshots/screen recording protection (if applicable)
- [ ] Third-party SDKs (analytics, crash reporting) don't capture PHI

### 7. AI-Specific
- [ ] Health data sent to LLM APIs is minimized (averages, not raw data)
- [ ] LLM responses don't get cached with identifiable patient info
- [ ] AI insight generation uses anonymized/aggregated data where possible
- [ ] Fallback chain (Gemini → DeepSeek → rule-based) handles each provider's data policy

## Instructions
1. Run `grep -r` for PHI data patterns in changed files
2. Check each item on the checklist
3. Report findings: **CRITICAL** (data breach risk) | **HIGH** (regulatory violation) | **MEDIUM** (best practice gap) | **LOW** (improvement)
4. For each finding: file:line, what's exposed, how to fix
5. End with: COMPLIANT, CONDITIONALLY COMPLIANT (medium only), or NON-COMPLIANT

$ARGUMENTS
5. End with: COMPLIANT, CONDITIONALLY COMPLIANT (medium only), or NON-COMPLIANT

## After the review

If your verdict is COMPLIANT or CONDITIONALLY COMPLIANT (no CRITICAL or HIGH findings), call this script to write the review marker so the pre-commit hook knows the PHI compliance check has passed for the current staged content:

```bash
.claude/scripts/write-review-marker.sh phi
```

If your verdict is NON-COMPLIANT (CRITICAL or HIGH findings), do NOT write the marker. The user needs to fix the violations first, restage, and re-run the review on the new staged content (which will have a new hash and invalidate all prior markers).

$ARGUMENTS
