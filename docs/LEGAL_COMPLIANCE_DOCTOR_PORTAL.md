# Swasth Doctor Portal — Legal Compliance Checklist

> **Version:** 1.0 | **Date:** 2026-04-09 | **Status:** DRAFT — Pending lawyer review
> **Prepared by:** AI Legal Advisor | **Review required by:** Licensed Indian lawyer
> **Context:** 100-patient, 90-day pilot with 5 doctors in Bihar

---

## 1. Executive Summary

This document covers all legal and regulatory obligations for launching the Swasth Doctor Portal — a feature that allows registered doctors to remotely monitor patient health data (BP, glucose, SpO2), add clinical notes, and communicate with patients via WhatsApp.

**Why this matters:** Adding a doctor-facing portal transforms Swasth from a consumer health app into a clinical decision-support platform. This significantly increases regulatory surface area across medical practice law, data protection, and potentially medical device regulations.

**Key risks identified:**
- Server currently in Germany — must migrate to India before launch
- No professional indemnity insurance — must obtain before launch
- Doctor Platform Agreement — must be drafted and signed before launch
- NMC telemedicine disclaimers — must be embedded in UI before launch
- SaMD classification — needs assessment within 90 days

**Estimated pre-launch legal cost:** Rs. 40,000–65,000 (one-time) + Rs. 3,000–5,000/month (server)

---

## 2. Regulatory Landscape

| # | Regulation | Governing Body | Relevance to Doctor Portal |
|---|-----------|---------------|---------------------------|
| 1 | **NMC Telemedicine Practice Guidelines 2020** (amended 2022) | National Medical Commission | Doctor viewing patient data remotely + sending health advice = telemedicine |
| 2 | **DPDPA 2023** (Digital Personal Data Protection Act) | Ministry of Electronics & IT | Health data sharing between patient and doctor requires explicit consent |
| 3 | **IT Act 2000** + IT Rules 2011 | MeitY | Sensitive personal data (health) handling, reasonable security practices |
| 4 | **Consumer Protection Act 2019** | Ministry of Consumer Affairs | Medical negligence claims can be brought against both doctor and platform |
| 5 | **IMC Regulations 2002** (Professional Conduct, Etiquette & Ethics) | NMC | Medical record retention, professional standards |
| 6 | **Medical Device Rules 2017** + SaMD Framework | CDSCO | AI triage scoring may classify as Software as Medical Device |
| 7 | **CERT-In Directions 2022** | CERT-In | Log retention, incident reporting, data residency |
| 8 | **DISHA** (Draft — not enacted) | MoHFW | Health data security standards (draft, signals legislative intent) |
| 9 | **ICMR Ethical Guidelines for AI in Healthcare 2023** | ICMR | AI-generated health insights must meet ethical standards |
| 10 | **WhatsApp Business API Terms** | Meta | Template approval, anti-spam, data processing obligations |
| 11 | **TRAI Regulations** (SMS/OTP) | TRAI | DLT registration required for sending OTPs via SMS |

---

## 3. Pre-Launch Checklist (MUST DO Before Pilot)

### 3.1 CRITICAL — Launch Blockers

| # | Action Item | Regulation | Risk | Est. Cost | Effort | Owner |
|---|------------|-----------|------|-----------|--------|-------|
| L1 | **Migrate server to India** (AWS Mumbai / DigitalOcean Bangalore) | DPDPA Sec 16, CERT-In, IT Act | CRITICAL | Rs. 3,000–5,000/mo | 1–2 days | Engineering |
| L2 | **Draft & sign Doctor Platform Use Agreement** with each pilot doctor | NMC Guidelines, CPA 2019 | CRITICAL | Rs. 10,000–15,000 (lawyer) | 1 week | Legal |
| L3 | **Obtain Professional Indemnity Insurance** (Rs. 25–50 lakh coverage) | CPA 2019, General Prudence | CRITICAL | Rs. 15,000–25,000/yr | 1 week | Business |
| L4 | **Add NMC disclaimers to all doctor notes and messages** (see Section 6) | NMC Telemedicine Guidelines 3.7 | CRITICAL | Rs. 0 | 2–3 hours | Engineering |
| L5 | **Update Patient Terms of Service** with platform liability clauses | CPA 2019, IT Act Sec 79 | HIGH | Rs. 0 (self-draft) or Rs. 5,000 (lawyer review) | 1 day | Legal |

### 3.2 HIGH — Should Complete Before Launch

| # | Action Item | Regulation | Risk | Est. Cost | Effort | Owner |
|---|------------|-----------|------|-----------|--------|-------|
| L6 | **DLT registration for SMS OTP** (sender ID + template) | TRAI DLT Regulations | HIGH | Rs. 0 (registration free) | 3–5 days (approval) | Engineering |
| L7 | **Update Privacy Policy** with doctor data sharing section | DPDPA Sec 6, IT Rules 2011 | HIGH | Rs. 0–5,000 | 1 day | Legal |
| L8 | **Implement consent authorization checkbox** for family members granting doctor access on behalf of patients | DPDPA Sec 9 | HIGH | Rs. 0 | 2–3 hours | Engineering |
| L9 | **Add "Data shared with" visibility** in patient app showing all connected doctors | DPDPA Sec 11 (Right to Information) | HIGH | Rs. 0 | 4–6 hours | Engineering |
| L10 | **Implement audit trail** — log every doctor access to patient data | DPDPA Sec 8, NMC Guidelines 3.8 | HIGH | Rs. 0 | 1 day | Engineering |

### 3.3 MEDIUM — Best Practice

| # | Action Item | Regulation | Risk | Est. Cost | Effort | Owner |
|---|------------|-----------|------|-----------|--------|-------|
| L11 | **Data breach notification process** documented (72-hour to CERT-In) | CERT-In Directions 2022 | MEDIUM | Rs. 0 | 2 hours | Engineering |
| L12 | **Doctor identity verification process** (NMC register cross-check) | NMC Guidelines 3.1 | MEDIUM | Rs. 0 | 4 hours | Engineering |
| L13 | **WhatsApp template pre-approval** submitted to Meta via Gupshup | WhatsApp Business API Terms | MEDIUM | Rs. 0 | 1–3 days (approval wait) | Engineering |

**Total Pre-Launch Cost Estimate: Rs. 28,000–50,000 (one-time) + Rs. 3,000–5,000/month (server)**

---

## 4. Post-Launch / Within 90 Days

| # | Action Item | Regulation | Risk | Effort | Deadline |
|---|------------|-----------|------|--------|----------|
| L14 | **SaMD Class A assessment** — engage regulatory consultant | CDSCO MDR 2017 | MEDIUM | 1 week + 3–6 months process | Day 30 |
| L15 | **SaMD registration application** filed with CDSCO | CDSCO MDR 2017 | MEDIUM | Rs. 50,000–1,00,000 | Day 90 |
| L16 | **Clinical accuracy documentation** for triage algorithm (sensitivity/specificity) | CDSCO, ICMR | MEDIUM | 1–2 weeks | Day 60 |
| L17 | **Data Processing Agreement (DPA)** signed with Gupshup | DPDPA Sec 8 | MEDIUM | Rs. 0 (standard) | Day 30 |
| L18 | **Consent Manager registration** (when DPDPA rules notified) | DPDPA Sec 9 | LOW | TBD | When rules published |
| L19 | **ABDM (Ayushman Bharat Digital Mission) integration assessment** | ABDM Guidelines | LOW | 1 week | Day 90 |
| L20 | **Doctor note export feature** (doctors must be able to export their clinical records) | IMC Regulations 2002, 1.3 | MEDIUM | 1 day | Day 60 |
| L21 | **Patient data access request flow** (patient requests copy of all their data) | DPDPA Sec 11 | MEDIUM | 2 days | Day 60 |

---

## 5. Consent & Privacy Requirements

### 5.1 Patient Consent to Share Data with Doctor

**When triggered:** Patient enters doctor code in app to link with a doctor.

**Consent screen MUST include (DPDPA Sec 6):**

1. Doctor's full name and NMC registration number
2. Specific data being shared (readings, trends, profile, AI health insights)
3. Data NOT shared (AI chat history, family members' data)
4. Purpose: "Health monitoring and clinical guidance"
5. How to revoke (Settings -> Doctor -> Remove)
6. NMC checkbox (see below)

**Hindi consent text (required for Bihar pilot):**

```
🩺 Doctor Se Judein

Dr. [Doctor Name] ([NMC Number])
[Specialty] — [Clinic Name]

Aap yeh share karenge:
  ✓ Health readings (BP, sugar, SpO2)
  ✓ Health trends aur score
  ✓ Profile jaankari (age, medications, conditions)
  ✓ AI health insights

Yeh share NAHI hoga:
  ✗ AI Doctor se aapki chat
  ✗ Parivaar ke doosre logon ka data

☐ Main is vyakti ki ore se sahmat hoon aur mujhe iska adhikaar hai
  (I consent on behalf of this person and am authorized to do so)
  [Only shown when family member is granting consent]

☐ Dr. [Name] ne meri jaanch ki hai (clinic mein ya video se)
  (Dr. [Name] has examined me in person or via video consultation)
  [Required — NMC Telemedicine Guidelines 3.4]

ℹ️ Aap kabhi bhi sharing band kar sakte hain:
   Settings → Doctor → Share Band Karein

[Haan, Share Karein ✓]     [Abhi Nahi]
```

**English equivalent must also be available (language toggle).**

### 5.2 Family Member Consent on Behalf of Patient

**Legal basis:** DPDPA Sec 9 covers minors. For adults, the Data Principal should consent themselves. However, Bihar reality requires family members to act on behalf of elderly/non-literate patients.

**Safeguards required:**
- Only users with "editor" or "owner" access to the profile can grant doctor consent
- Authorization checkbox: "I am authorized to share this person's health data"
- Record `consent_granted_by` (user ID of person who consented)
- Record relationship (daughter, son, spouse, etc.)
- Terms of Service: "Users granting consent on behalf of others represent they have authority"

**Risk note for lawyer:** This is a known grey area. No DPDPA precedent for elderly adult proxy consent. Our documentation approach (recording who consented + their authorization assertion) is defensible but should be reviewed.

### 5.3 Consent Revocation

**Patient or authorized family member can revoke at any time:**
- Settings -> Connected Doctors -> [Doctor Name] -> Share Band Karein (Stop Sharing)
- Confirmation dialog in Hindi
- Immediate effect: doctor loses access, `is_active = False` on link
- Record kept for audit: `revoked_at` timestamp
- Doctor's clinical notes are NOT deleted (see Section 5.4)

### 5.4 Data Deletion vs. Medical Record Retention (CONFLICT)

**The conflict:** DPDPA gives patients right to erasure (Sec 12). NMC requires doctors to retain medical records for 3 years (IMC Regulations 2002, Ch. 1.3).

**Resolution:** Sectoral regulations (NMC) prevail for the regulated activity (medical practice). When a patient deletes their account:
- All patient health data: **DELETED** (DPDPA compliance)
- Doctor's clinical notes: **ANONYMIZED and RETAINED** for 5 years (NMC compliance)
  - Remove: patient name, phone, email, profile ID
  - Retain: note text, date, doctor ID, anonymized reading values
- Document this in Privacy Policy: "Clinical notes made by your doctor are retained in anonymized form as medical records per NMC regulations"

**Ask your lawyer:** Is anonymization sufficient, or must we retain identifiable records? The NMC guideline says "medical records pertaining to patients" which implies identifiable. But DPDPA erasure is mandatory. This tension needs legal opinion.

---

## 6. NMC Telemedicine Compliance

### 6.1 Classification of Swasth Doctor Portal Activities

| Activity | NMC Classification | Guideline Section |
|----------|-------------------|-------------------|
| Doctor views patient readings remotely | Remote Patient Monitoring | Permitted under 3.4 |
| Doctor sends general health advice via WhatsApp | Telemedicine Consultation (text) | 3.3, 3.7 |
| Doctor adds clinical note ("increase medication X") | Telemedicine Follow-up | 3.4, 3.7 |
| AI triage scoring (critical/attention/stable) | Clinical Decision Support | Not directly addressed; classify as tool, not diagnosis |
| AI health insights shown to doctor | Clinical Decision Support | Doctor responsibility to verify |

### 6.2 Mandatory Requirements

| # | Requirement | NMC Guideline | Implementation |
|---|------------|---------------|----------------|
| T1 | Doctor must have valid State Medical Council registration | 3.1 | NMC number verification at registration |
| T2 | First consultation must be in-person or video | 3.4 | Consent checkbox: "Doctor ne meri jaanch ki hai" |
| T3 | Doctor must maintain records of telemedicine interactions | 3.8 | Audit trail + clinical notes stored 5 years |
| T4 | Patient identity must be verified | 3.5 | Consent-based linking with profile data |
| T5 | Only List O medications in first teleconsultation | 3.7.4 | UI: "Clinical observation, not prescription" label |
| T6 | Doctor must be physically in India during consultation | 3.2 | Terms of Use clause (not technically enforced) |
| T7 | Informed consent of patient | 3.6 | Explicit consent screen (see Section 5.1) |

### 6.3 Required UI Disclaimers

**On every doctor note (clinical notes section):**
```
ℹ️ Clinical Observation — NMC Telemedicine Guidelines ke anusaar yeh prescription nahi hai
(Clinical Observation — This is not a prescription per NMC Telemedicine Guidelines)
```

**On every WhatsApp message sent by doctor:**
```
🩺 Dr. [Name] ka sandesh:
[Message content]

⚠️ Yeh salah hai, prescription nahi. Dawai mein koi badlav karne se pehle doctor se milein.
(This is advice, not a prescription. Consult your doctor before changing any medication.)
```

**On triage board:**
```
ℹ️ Clinical Decision Support — Independently verify before acting
(Swatantra roop se verify karein — yeh automatic classification hai)
```

**On AI health insights (when shown to doctor):**
```
🤖 AI-generated insight — Doctor's clinical judgment takes precedence
(AI dwara banaya gaya — Doctor ka clinical nirnay sarvopari hai)
```

---

## 7. Data Localization & Security

### 7.1 Server Migration (CRITICAL)

**Current:** Hetzner, Germany (65.109.226.36)
**Required:** Indian data center

| Option | Provider | Location | Est. Cost/Month | Migration Effort |
|--------|---------|----------|-----------------|-----------------|
| A | AWS EC2 (ap-south-1) | Mumbai | Rs. 3,000–5,000 | 1–2 days |
| B | DigitalOcean | Bangalore | Rs. 2,000–3,000 | 1–2 days |
| C | Linode (Akamai) | Mumbai | Rs. 2,500–4,000 | 1–2 days |

**Recommendation:** AWS Mumbai — best reliability, compliance certifications (SOC 2, ISO 27001), easy to show auditors.

**Why this is CRITICAL:**
- DPDPA Sec 16: Government can restrict cross-border transfer of personal data
- CERT-In Directions 2022: Logs must be maintained in India for 180 days
- Health data is "sensitive personal data" under IT Rules 2011
- Adding a doctor portal increases regulatory scrutiny — German server is indefensible
- A competitor or disgruntled doctor could file complaint with MeitY

### 7.2 Encryption Requirements

| Layer | Current State | Requirement | Status |
|-------|-------------- |-------------|--------|
| Data at rest (health readings) | AES-256-GCM | IT Rules 2011 — "reasonable security practices" | Compliant |
| Data in transit | TLS 1.2+ (HTTPS) | Industry standard | Compliant |
| Doctor's clinical notes | Must encrypt at rest | Same as health readings | Implement |
| WhatsApp messages | End-to-end encrypted (Meta) | Acceptable for messages | Compliant |
| OTP codes | Stored hashed, 10-min expiry | Industry standard | Compliant |
| Audit logs | Must not be tamperable | CERT-In, DPDPA | Implement append-only log |

### 7.3 Data Breach Response Plan

**Required by:** CERT-In Directions 2022

| Step | Action | Timeline |
|------|--------|----------|
| 1 | Detect breach (monitoring, user report, or discovery) | Immediate |
| 2 | Contain — isolate affected systems, revoke compromised credentials | Within 1 hour |
| 3 | Assess — determine scope (how many patients, what data) | Within 6 hours |
| 4 | Report to CERT-In (incident@cert-in.org.in) | Within 6 hours (CERT-In mandate) |
| 5 | Notify affected users | Within 72 hours |
| 6 | Notify affected doctors | Within 72 hours |
| 7 | Post-incident review | Within 2 weeks |

**Template incident report format:** Available from CERT-In website.

---

## 8. Platform Liability Framework

### 8.1 Liability Scenarios

| Scenario | Primary Liable | Secondary Liable | Mitigation |
|----------|---------------|-----------------|------------|
| Doctor gives wrong clinical advice via WhatsApp | **Doctor** (medical negligence, CPA 2019) | **Platform** (facilitated communication) | Doctor Platform Agreement + disclaimers |
| AI triage scores patient "stable" who is actually critical; doctor doesn't check | **Doctor** (clinical judgment) | **Platform** (if algorithm is negligent) | "Decision support, not diagnosis" disclaimers + accuracy documentation |
| Platform delays critical alert, patient harmed | **Platform** (assumed delivery responsibility) | Doctor (if didn't have alternate monitoring) | SLA terms in agreement; no guaranteed delivery time in ToS |
| Data breach exposes patient health data | **Platform** (data fiduciary, DPDPA) | None | Insurance, encryption, breach response plan |
| Doctor sends message to wrong patient (software bug) | **Platform** (data integrity is platform's responsibility) | None | QA testing, insurance |
| Family member grants consent without patient's knowledge | **Platform** (inadequate verification) | Family member (misrepresentation) | Authorization checkbox, ToS clause |

### 8.2 IT Act Section 79 Safe Harbor Analysis

**Does Section 79 (intermediary safe harbor) protect Swasth?**

**Probably NOT fully.** Section 79 protects passive intermediaries. Swasth actively:
- Computes triage scores (content creation)
- Generates AI health insights (content creation)
- Routes critical alerts (active decision-making)
- Formats and sends WhatsApp messages (active participation)

**Partial protection** may apply for doctor-authored clinical notes (Swasth is just hosting/transmitting). But for AI-generated content and triage scoring, Swasth is an active participant, not an intermediary.

**Mitigation:** Professional indemnity insurance (covers platform liability claims).

### 8.3 Key Contractual Protections

**In Doctor Platform Agreement:**
1. Doctor solely responsible for clinical decisions
2. Platform provides tools, not medical advice
3. Triage scores are automated decision support
4. Doctor must independently verify before acting
5. Doctor indemnifies platform for clinical negligence claims
6. Platform indemnifies doctor for data breach / platform failure claims
7. Mutual arbitration clause (Patna seat)

**In Patient Terms of Service:**
1. Swasth is a health monitoring tool, not a healthcare provider
2. Medical advice from doctors is the doctor's responsibility
3. AI insights are informational, not diagnostic
4. Triage indicators are automated and may not reflect actual clinical status
5. Patient acknowledges voluntary data sharing with doctor

---

## 9. Document Templates Needed

| # | Document | Purpose | Estimated Cost | Priority |
|---|----------|---------|---------------|----------|
| D1 | **Doctor Platform Use Agreement** | Doctor's rights, obligations, liability allocation, data access terms | Rs. 10,000–15,000 (lawyer draft) | CRITICAL — before pilot |
| D2 | **Updated Patient Terms of Service** | Add doctor portal, liability, data sharing clauses | Rs. 0–5,000 | CRITICAL — before pilot |
| D3 | **Updated Privacy Policy** | Add doctor data sharing, clinical notes, WhatsApp messaging | Rs. 0–5,000 | HIGH — before pilot |
| D4 | **Patient Consent Form** (Doctor Linking) | In-app consent screen text (Hindi + English) | Rs. 0 (self-draft, lawyer review) | CRITICAL — before pilot |
| D5 | **Data Processing Agreement** with Gupshup | Standard DPA for WhatsApp message processing | Rs. 0 (Gupshup provides standard) | MEDIUM — within 30 days |
| D6 | **Data Breach Notification Template** | CERT-In reporting format | Rs. 0 (self-draft) | MEDIUM — within 30 days |
| D7 | **Doctor NMC Verification SOP** | Internal process for verifying NMC numbers | Rs. 0 (self-draft) | MEDIUM — before pilot |
| D8 | **Clinical Notes Retention Policy** | Internal policy on note storage and anonymization | Rs. 0 (self-draft) | MEDIUM — within 60 days |
| D9 | **SaMD Clinical Evidence Report** | Triage algorithm accuracy documentation | Rs. 25,000–50,000 (consultant) | MEDIUM — within 90 days |
| D10 | **WhatsApp Template Submissions** | Pre-approved Hindi message templates for Meta | Rs. 0 | MEDIUM — before WhatsApp launch |

**Total document drafting cost: Rs. 10,000–25,000 (lawyer) + Rs. 25,000–50,000 (SaMD consultant, later)**

---

## 10. Appendix: Regulatory References

### 10.1 Primary Legislation

| Regulation | Citation | Link/Reference |
|-----------|----------|---------------|
| NMC Telemedicine Practice Guidelines 2020 | Gazette Notification, 25 March 2020 | nmc.org.in → Telemedicine Guidelines |
| DPDPA 2023 | Act No. 22 of 2023 | meity.gov.in → DPDP Act |
| IT Act 2000 | Act No. 21 of 2000 | indiacode.nic.in |
| IT (Reasonable Security) Rules 2011 | GSR 313(E), 11 April 2011 | meity.gov.in |
| Consumer Protection Act 2019 | Act No. 35 of 2019 | consumeraffairs.nic.in |
| IMC Regulations 2002 | Gazette, 6 April 2002 | nmc.org.in → Ethics |
| Medical Devices Rules 2017 | GSR 78(E), 31 Jan 2017 | cdsco.gov.in |
| CERT-In Directions 2022 | 28 April 2022 | cert-in.org.in |
| ICMR AI Ethics 2023 | ICMR-DBT Guidelines | icmr.gov.in |
| DISHA (Draft) | 2018 Draft Bill | mohfw.gov.in |

### 10.2 Key Court Precedents

| Case | Citation | Relevance |
|------|----------|-----------|
| *Samira Kohli v. Dr. Prabha Manchanda* | (2008) 2 SCC 1 | Informed consent in medical procedures — sets standard for consent quality |
| *Martin D'Souza v. Mohammed Ishfaq* | (2009) 3 SCC 1 | Patient's right to medical records; doctor's duty of care standard |
| *Indian Medical Association v. V.P. Shantha* | (1995) 6 SCC 651 | Medical services are "services" under Consumer Protection Act — doctors can be sued |
| *Puttaswamy v. Union of India* | (2017) 10 SCC 1 | Right to privacy is fundamental right — informs all health data handling |

### 10.3 SaMD Classification Framework

Under IMDRF (International Medical Device Regulators Forum) + CDSCO adaptation:

| SaMD Category | Significance of Decision | State of Healthcare |
|---------------|------------------------|-------------------|
| Class A (lowest) | Inform or guide | Non-serious condition |
| Class B | Inform or guide | Serious condition |
| Class C | Diagnose or treat | Non-serious condition |
| Class D (highest) | Diagnose or treat | Serious condition |

**Swasth triage scoring:** Likely **Class A** (informs doctor, does not diagnose). If triage is used to directly trigger emergency protocols without doctor review, could be **Class B**.

**Recommendation:** Design triage as "inform" only (doctor decides action). This keeps classification at Class A (lowest regulatory burden).

---

## Summary Checklist for Lawyer Review

**Please review and advise on:**

- [ ] L1: Is German server a blocking legal risk, or acceptable during pilot?
- [ ] L2: Doctor Platform Agreement — draft or review our self-draft?
- [ ] L3: Professional indemnity insurance — recommended provider and coverage amount?
- [ ] L5: Updated Terms of Service — sufficient platform liability protection?
- [ ] Section 5.2: Family member proxy consent — defensible under DPDPA?
- [ ] Section 5.4: Data deletion vs. medical record retention — how to resolve the DPDPA/NMC conflict?
- [ ] Section 6: Are NMC telemedicine guidelines satisfied by our approach?
- [ ] Section 8.2: IT Act Section 79 applicability — do we qualify as intermediary for any activities?
- [ ] Section 10.3: SaMD Class A classification — do we need CDSCO registration before pilot or can we pilot as "clinical investigation"?
- [ ] Overall: Any missing regulations or risks not identified?

---

## 11. Critical Value Alerts to Family (Feature D7)

*Added: 2026-04-10 — implementation of backend alert dispatch for CRITICAL and HIGH-STAGE-2 readings.*

### 11.1 What the feature does

When a patient's reading is classified CRITICAL or HIGH-STAGE-2 (e.g. glucose <70 or >300 mg/dL, BP systolic >180, SpO2 dangerously low), the backend fans out an alert notification to every family member listed in `ProfileAccess` for that profile (excluding the person who logged the reading).

Channels: **email (Brevo SMTP)** + **WhatsApp (Twilio)**. SMS is architecturally provisioned but disabled pending API keys.

Alert body contains: patient's name, reading type, reading value, severity flag, and a call to action.

### 11.2 Legal questions to resolve before pilot launch

- [ ] **Q11.1 — Implicit vs. explicit consent for emergency notifications.** `ProfileAccess` currently grants a family member permission to *view* a patient's readings. Does sharing a critical reading *proactively* via email/WhatsApp (without the family member initiating the query) require a separate explicit opt-in under DPDPA 2023 Section 6 (notice) and Section 7 (consent)? Our position: the act of granting ProfileAccess implies consent to receive safety-critical notifications about that profile, but a lawyer should confirm whether a dedicated "Emergency contact — notify me" toggle is required before pilot.
- [ ] **Q11.2 — Cross-border WhatsApp delivery.** Twilio's WhatsApp Business API routes messages through Meta infrastructure located outside India. DPDPA 2023 restricts cross-border transfer of personal data unless the destination is whitelisted by the Central Government. Patient name + health reading value sent via WhatsApp Business transits via Meta servers. Is this a cross-border transfer that needs Rule 6 compliance, or does Twilio's India-regional endpoint (if available) avoid the issue?
- [ ] **Q11.3 — Data minimization in the alert body.** Our alert currently reads *"Ramesh's glucose is 400 mg/dL (CRITICAL). Please check on them immediately."* This discloses the patient's name + exact numeric health value via unencrypted email/WhatsApp. Is this DPDPA-compliant under the "purpose limitation" and "data minimization" principles? Alternatives: (a) send only *"Ramesh needs medical attention. Open the Swasth app for details."* and force family to open the app (more private, less actionable), or (b) keep current form (more actionable, potentially over-discloses).
- [ ] **Q11.4 — Rate limiting vs. safety.** To avoid spamming family with repeat alerts during a single clinical event, we plan a 30-minute dedupe window per profile (only one alert per channel per 30 min). Does silencing potentially-distinct critical events during that window create medical liability if a second unnoticed event causes harm? Should the dedupe window be shorter (15 min) or removed entirely for CRITICAL-level alerts?
- [ ] **Q11.5 — Language and comprehension.** Alert body is bilingual (English + Hindi) to ensure the recipient can act. Is there NMC or DPDPA guidance on mandatory languages for safety-critical notifications in multilingual markets like Bihar? Should we also support regional languages (Bhojpuri, Maithili) for pilot?
- [ ] **Q11.6 — Alert delivery failure liability.** If Twilio WhatsApp or Brevo SMTP is down when a critical reading fires, the family isn't notified. We log every attempt in `CriticalAlertLog` for audit, but patients/families are not told the alert failed to deliver. Does the platform incur liability for undelivered critical alerts? Should we surface a "we tried to notify your family, delivery status: FAILED" state in the Flutter app so the patient knows to call manually?
- [ ] **Q11.7 — NMC telemedicine guidelines on alert triggering.** The critical threshold (glucose <70 / >300, etc.) is built into code by our clinical advisor Dr. Rajesh. NMC Telemedicine Practice Guidelines require algorithms making clinical suggestions to have documented provenance. Do we need to publish the clinical basis for our CRITICAL thresholds (peer-reviewed paper? ICMR diabetes guidelines?) before pilot?
- [ ] **Q11.8 — Minors and proxy access.** If the patient is a minor (<18), the family member receiving the alert is a legal guardian. If the patient is an adult whose family has viewer access (e.g. son monitoring mother), is proactive notification to the son legally different from granting him view access? Section 5.2 of this document already flags family proxy consent for doctor access — extend that analysis to cover alert dispatch.
- [ ] **Q11.9 — Audit log retention and PHI in CriticalAlertLog.** The `CriticalAlertLog` table stores recipient_user_id, channel, status, and timestamp for every alert attempt. It does not store the message body to minimize PHI. Is user_id + profile_id + timestamp still considered PHI and subject to the 3-year DPDPA retention limit? Or is this audit metadata exempt?

### 11.3 Implementation decisions deferred pending legal answers

Until Q11.1–Q11.3 are resolved, the D7 implementation will:
1. Ship with bilingual (EN + HI) alert bodies including patient name and reading value (i.e. not data-minimized).
2. Rely on implicit consent via `ProfileAccess` (no separate opt-in UI).
3. Dispatch via Twilio's default global WhatsApp endpoint (no India-regional routing).
4. Apply a 30-minute per-profile dedupe window.
5. Log every attempt to `CriticalAlertLog` for audit trail.

If legal review flags any of these as non-compliant, the fix is a config change + message template swap — no database migration or API surface change required. The `alert_service.dispatch_critical_alert` function is the single swap point.

### 11.4 Review checklist for lawyer

- [ ] Q11.1: Implicit vs explicit emergency-contact consent under DPDPA
- [ ] Q11.2: Cross-border WhatsApp data transfer analysis
- [ ] Q11.3: Data minimization in alert body (name + value vs. generic "open app")
- [ ] Q11.4: Rate-limit dedupe window and medical liability tradeoff
- [ ] Q11.5: Language requirements for safety-critical notifications
- [ ] Q11.6: Delivery failure liability and patient disclosure
- [ ] Q11.7: Clinical threshold provenance (NMC telemedicine compliance)
- [ ] Q11.8: Minor / guardian / adult family proxy notification distinction
- [ ] Q11.9: CriticalAlertLog retention rules and PHI classification

---

*This document is AI-generated legal analysis, not legal advice. All items should be reviewed by a licensed Indian lawyer before implementation.*
