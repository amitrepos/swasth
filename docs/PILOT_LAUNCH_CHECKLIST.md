# Swasth — Pilot Launch Mandatory Checklist

**Date created:** 2026-04-23
**Pilot start target:** 2026-05-01
**Duration:** 90 days
**Scope:** 3 doctors, each onboarding their own patients

---

## Context

This is a **product pilot**, not a clinical study.

- No research protocol
- No Ethics Committee / CTRI
- No publication of outcomes
- No lawyer-drafted contracts
- Doctors continue their normal clinical workflow; Swasth is a tool they use

The items below are the **minimum** required to stay compliant with DPDPA 2023 + maintain basic patient safety, without slowing the pilot or scaring doctors/patients with legal paperwork.

Anything NOT on this list is explicitly deferred until we scale past this pilot (see "Out of scope" section).

---

## Mandatory — before first patient is onboarded

| # | Item | Why it matters | Owner | Effort | Status |
|---|------|----------------|-------|--------|--------|
| P1 | **Migrate backend to Indian server** (AWS Mumbai or DigitalOcean Bangalore) | DPDPA Sec 16 — health data on foreign servers is the single biggest legal exposure. Non-optional even for 3 patients. | Eng | 1–2 days, ~₹3k/month | ❌ |
| P2 | **Verify NMC registration** for each of the 3 doctors — search nmc.org.in, save screenshot of the search result | NMC Telemedicine Guideline 3.1. Proves due diligence if anything is ever questioned. | Amit | 15 min total | ❌ |
| P3 | **Doctor onboarding WhatsApp message** — each doctor replies "confirmed" to a short acknowledgment (sample below). Save the screenshots. | Allocates clinical responsibility to the doctor, positions Swasth as a tool not a provider. No PDF, no signature. | Amit | 30 min | ❌ |
| P4 | **Audit in-app patient consent screen** — already exists at `lib/screens/consent_screen.dart`. Confirm the Hindi + English text: names the doctor, lists what data is shared, says "stop sharing anytime in Settings". | DPDPA Sec 6 (notice) + Sec 7 (consent). This IS the legal consent — no external PDF needed. | Eng | 1 hr audit | 🔄 Exists, needs final audit |
| P5 | **Doctor referral code per doctor** (e.g. `RAJESH01`, `PRIYA02`) — only patients entering a code are treated as pilot participants | Clean boundary between "pilot patients" and "random Play Store downloads". No legal form needed to scope the pilot. | Eng + Amit | 2–4 hrs | ❌ |
| P6 | **Confirm critical alerts deliver to family on email + WhatsApp** — send one live test from each doctor's first patient account | If a CRITICAL glucose reading fires and family isn't notified, that's a safety failure and the one thing that turns a pilot into a lawsuit. | Eng | 30 min | 🔄 Brevo email confirmed; retest WhatsApp end-to-end |
| P7 | **Confirm SPDI encryption is ON in production** (`ENCRYPTION_KEY` env var set on the India server) | Health values (glucose/BP/SpO2/weight/notes) are already encrypted at rest via `backend/encryption_service.py` + `_enc` columns in `routes_health.py:100-112` and `routes_profiles.py:112`. Just verify the key is loaded on the new server after migration. | Eng | 15 min | 🔄 Code ✅, verify on prod after P1 |
| P8 | **PII encryption — ship Task E17 PRs 1–3 (dual-write)** | **Current gap:** patient name, phone, email, DOB + doctor name/NMC are plaintext in Postgres (`TASK_TRACKER.md` Task E17). For the pilot, ship just PRs 1–3 so new patient signups write encrypted PII from day 1. Defer PRs 4–6 (backfill legacy + drop plaintext) until after the pilot to avoid a risky production backfill. | Eng | 3–4 days | ❌ |

---

## Doctor acknowledgment message template (for P3)

Send to each of the 3 doctors on WhatsApp. Wait for a "confirmed" reply. Save the screenshot in a shared drive folder.

> Hi Dr. [Name], thanks for piloting Swasth.
>
> Quick confirmation before we start — please reply **'confirmed'** if you agree:
>
> 1. Swasth is a monitoring tool. All clinical decisions remain yours.
> 2. You'll use clinical judgment before acting on any reading, AI note, or alert.
> 3. You have valid NMC / State Medical Council registration (number: _____).
> 4. You can exit the pilot anytime — just let us know.
> 5. Swasth will not share your patients' data with anyone outside your own care.
>
> Patients you want to enroll will enter code **[RAJESH01]** during signup. You can add or stop patients anytime.

That's it. No contract. No legal review. A "confirmed" WhatsApp reply is legally sufficient at this scale.

---

## Explicitly OUT of scope for the pilot

We are **deliberately skipping** these. Add later only if the pilot succeeds and we scale.

| Item | Why we're skipping | Reopen when |
|------|--------------------|-------------|
| Ethics Committee / CTRI registration | Not research — no protocol, no publication, no primary endpoint | Only if we publish outcomes |
| Formal 15-page Doctor Platform Agreement | WhatsApp confirmation is legally sufficient at 3 doctors | Before ~10 doctors or commercial launch |
| Professional indemnity insurance | Low exposure at 3 doctors / <50 patients | Before ~50 patients or first external PR/press |
| SaMD CDSCO registration | Pre-commercial; pilot is allowed as product investigation | Before commercial launch |
| Formal study protocol / informed-consent PDF | Pilot, not study. In-app consent covers DPDPA. | Only if converting to research |
| Lawyer review of 9 open DPDPA questions (Q11.1–Q11.9 in `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md`) | Revisit with real pilot learnings, not hypotheticals | Before commercial launch or 50+ patients |
| ABDM / Ayushman Bharat integration | Not needed for pilot | Post-pilot |

---

## Weekly check-ins during the 90 days

- **Week 1, Week 4, Week 8, Week 12** — 20-minute call with each of the 3 doctors. Capture: patient count, any safety incidents, what's working, what's breaking, retention.
- **Adverse event channel** — if any doctor flags a patient who was harmed or missed an alert, treat as P0: stop onboarding new patients, investigate, fix, then resume.
- **Data review** — weekly SQL: `SELECT count(*), doctor_id FROM DoctorPatientLink WHERE status='active' GROUP BY doctor_id` + critical-alert delivery rate. Below 95% delivery is a fix-this-week item.

---

## FAQ — share with team and doctors if asked

**Q: Is patient data encrypted?**
**Health values are** (glucose, BP, SpO2, weight, notes) — AES-256-GCM at rest via `backend/encryption_service.py`. TLS in transit for everything.
**Patient identity (name, phone, email, DOB) is NOT yet** in the current production DB — this is tracked as Task E17 in `TASK_TRACKER.md` and is the one real compliance gap we're closing before pilot (item P8 above). For the pilot, new signups will be encrypted from day 1 via the E17 PRs 1–3 dual-write path.

**Q: Where is the server?**
Moving to India before pilot start (item P1). Today it's in Germany; migrating to AWS Mumbai or DigitalOcean Bangalore.

**Q: What happens to patient data after the pilot ends?**
Patients keep their accounts. Doctor access can be revoked anytime via Settings → Connected Doctors → Stop Sharing.

**Q: Can a patient leave the pilot mid-way?**
Yes — Settings → Connected Doctors → Stop Sharing. Immediate effect. Doctor loses access, audit row written.

**Q: What if a doctor leaves the pilot?**
All active links for that doctor are set to `is_active=False`. Patient data remains with the patient.

**Q: Do patients need to sign a consent form?**
No paper form. The in-app consent screen (`consent_screen.dart`) names the specific doctor, lists data shared, explains how to revoke. That IS the DPDPA-compliant consent.

**Q: What does "NMC verification" mean?**
We look up each doctor on the National Medical Commission's public register (nmc.org.in) and confirm their registration is valid. Screenshot saved as due-diligence evidence.

---

## Quick launch timeline

| Day | Action |
|-----|--------|
| T-8 (now, 2026-04-23) | Start P1 (server migration) **and** P8 (E17 PRs 1–3) in parallel — these are the two long poles |
| T-6 | Complete P1, migrate data, update all app/env references |
| T-5 | P8 code complete + merged; `PII_ENCRYPTION_KEY` set as GitHub secret |
| T-4 | P2 (NMC checks) + P5 (referral codes in app) |
| T-3 | P3 (send doctor WhatsApps, collect "confirmed" replies) |
| T-2 | P4 audit + P6 live alert test + P7 SPDI encryption verify on prod + P8 smoke-test encrypted writes |
| T-1 | Dress rehearsal — onboard one test patient per doctor, verify full flow incl. PII is encrypted in DB |
| T-0 (2026-05-01) | Real patients start |

---

## Single-source rule

This file is the **only** pilot launch reference. If any discussion surfaces a new mandatory item, it goes here. If someone proposes adding something from the "out of scope" list, push back — the whole point of this checklist is to keep the pilot lightweight.

Questions? Ping Amit.
