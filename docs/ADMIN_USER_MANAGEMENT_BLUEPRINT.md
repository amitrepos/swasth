# User Management & Admin Dashboard — Implementation Blueprint

> **Created:** 2026-04-09
> **Status:** APPROVED
> **Expert Reviews:** Dr. Rajesh (Doctor), Legal Advisor (DPDPA/NMC), Healthify (UX)
> **Scope:** Everything except server migration (LB-1 deferred)

---

## Architecture Decision

**Stay with enhanced server-side HTML** served from FastAPI backend.
- No Flutter admin screens (zero impact on patient app bundle)
- Independent deploy cycle from mobile app
- Laptop-first UX, mobile-responsive
- Left sidebar navigation with 6 sections

---

## Information Architecture

```
SWASTH ADMIN
├── Overview          -- KPI dashboard (enhanced current page)
├── Users             -- patient/caregiver management with search + filters
├── Doctors        (n) -- verification queue + active doctors (NEW)
├── Clinical          -- population health stats, aggregated (NEW)
├── Alerts         (n) -- proactive notification center (NEW)
└── System            -- API health, AI performance (NEW)
```

---

## Phase 1 — MUST HAVE (Pre-Pilot Launch)

### 1.1 Doctor Verification Queue

**Why:** NMC Act 2020 S29 — facilitating unregistered practice = platform liability. Dr. Rajesh's #1 priority. Bihar has historically had ghost doctors.

**Backend:**
```
POST /admin/doctors/{user_id}/verify
  body: { notes: string }
  action: sets is_verified=True, verified_at=now(), verified_by=admin_id
  audit: log to admin_audit_log

POST /admin/doctors/{user_id}/reject
  body: { reason: enum, notes: string }
  reason enum: INVALID_NMC | NAME_MISMATCH | SPECIALTY_MISMATCH | SUSPECTED_FRAUD | OTHER
  action: stores rejection reason, sends email to doctor via email_service
  audit: log to admin_audit_log

GET /admin/doctors
  params: ?verified=true|false|all&page=1&per_page=50
  returns: list of DoctorProfiles with user info, patient_count, last_access, time_in_queue
```

**UI:** Two-column layout (queue list left, review panel right).

Review panel shows:
- Doctor name, NMC number, specialty, clinic, doctor_code, signup date, time in queue
- Auto-constructed link to NMC India public registry for verification
- Verification checklist: NMC format valid, verified on registry, name matches, specialty matches
- Admin notes textarea
- Actions: [Approve] [Reject] [Flag for Review]

Reject requires reason selection (dropdown) + optional notes. Sends rejection email.

**Gate enforcement:** Modify `get_doctor_patient_access` in dependencies.py — unverified doctors can log in but cannot access any patient data. Return 403 "Your account is pending verification."

**SLA alert:** If any doctor sits unverified > 48 hours, surface in Alerts section.

### 1.2 Account Suspension

**Why:** Dr. Rajesh #5 (misuse prevention). Legal HR-3 (DPDPA S8 organizational measures).

**Backend:**
```
PATCH /admin/users/{user_id}/suspend
  body: { suspend: bool, reason: string, duration_days: int|null }
  action: sets is_active=True|False, stores reason
  audit: log to admin_audit_log
  blocked: cannot suspend yourself
```

**Enforcement:** Modify `get_current_user` in dependencies.py:
```python
if not user.is_active:
    raise HTTPException(403, "Your account has been suspended. Contact support.")
```

**UI:** Suspend/Reactivate button on user detail modal header. Mandatory reason field (dropdown + free text). Suspension log visible in user's Audit tab.

Suspended user sees: "Your account is temporarily restricted — contact support at [email]" (not a generic error).

### 1.3 Admin Audit Trail

**Why:** LEGAL BLOCKER — CERT-In Directions 2022 require 180-day access logs. DPDPA S8(5) requires processing records.

**New table: `admin_audit_log`**
```sql
CREATE TABLE admin_audit_log (
    id SERIAL PRIMARY KEY,
    admin_user_id INTEGER NOT NULL REFERENCES users(id),
    action_type VARCHAR(50) NOT NULL,
    target_user_id INTEGER REFERENCES users(id),
    target_profile_id INTEGER REFERENCES profiles(id),
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    ip_address VARCHAR(45),
    data_fields_accessed TEXT[],
    outcome VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',
    notes TEXT,
    session_id VARCHAR(64)
);

CREATE INDEX idx_audit_admin ON admin_audit_log(admin_user_id);
CREATE INDEX idx_audit_target ON admin_audit_log(target_user_id);
CREATE INDEX idx_audit_timestamp ON admin_audit_log(timestamp);
```

**Action types:** VIEW_USER_DETAIL, VIEW_HEALTH_READINGS, VIEW_CHAT_HISTORY, VIEW_AI_INSIGHTS, EDIT_USER, SUSPEND_USER, UNSUSPEND_USER, VERIFY_DOCTOR, REJECT_DOCTOR, CHANGE_ROLE, TOGGLE_ADMIN, EDIT_AI_MEMORY, RESET_AI_MEMORY, EXPORT_DATA, VIEW_AUDIT_LOG

**Rules:**
- Append-only (no UPDATE or DELETE)
- 180-day minimum retention (store 1 year to be safe)
- Exportable via `GET /admin/audit-log?from=&to=&admin_id=&action_type=`
- Every existing admin endpoint must be retrofitted to log

**Backend:**
```
GET /admin/audit-log
  params: ?from=date&to=date&admin_id=&action_type=&target_user_id=&page=1&per_page=50
  returns: paginated list of audit entries
  access: super_admin only
```

### 1.4 Alerts Center

**Why:** Dr. Rajesh #2-3 (patient safety). Healthify Sprint 1.

**Backend:**
```
GET /admin/alerts
  returns: list of computed alerts with severity, message, action_url, timestamp
  computed server-side from current DB state (no persistent alert storage for v1)
```

**Alert definitions:**

| Alert | Trigger | Severity | Action |
|-------|---------|----------|--------|
| Critical reading unaddressed | status_flag=CRITICAL + no doctor note in 24h | HIGH | View patient |
| Doctor pending > 48h | DoctorProfile.is_verified=False, created > 48h ago | MEDIUM | Go to verification |
| AI fallback spike | Fallback rate > 20% in last hour | HIGH | Check AI service |
| Patient inactive 7d (high-risk) | BP > 160 or glucose > 300, no reading in 7d | MEDIUM | View patient |
| Patient inactive 14d (any) | No reading in 14d, was previously active | LOW | Optional re-engage |
| New doctor signup | New DoctorProfile created today | INFO | Review in queue |

**UI:** Chronological list in dedicated Alerts section. Each alert: severity icon (colored), one-sentence description, timestamp, action button ("Review" / "Dismiss"). Dismissed alerts collapse, retrievable via "Show dismissed."

Sidebar badge shows unread HIGH + MEDIUM count.

Polling: check on page load + every 5 minutes. No websockets.

### 1.5 Consent Dashboard

**Why:** LEGAL BLOCKER — DPDPA S6 requires provable consent. Burden of proof is on platform.

**Backend:**
```
GET /admin/consent
  params: ?status=consented|pending|withdrawn&policy_version=&page=1&per_page=50
  returns: per-user consent records
```

**UI (within Users section or as sub-tab in Overview):**
- Per-user: consent_timestamp, app_version, language, policy_version
- Consent withdrawal mechanism (admin triggers on user request)
- Report: "all users who consented before policy version X"
- Consent changes audit-logged

### 1.6 Sidebar Navigation

Replace current single-page scroll with proper section routing. Left sidebar:

```
SWASTH ADMIN
Bihar Pilot v1
-----------------
Overview
Users
Doctors      (3)  <-- pending verification count
Clinical
Alerts       (2)  <-- unread HIGH/MEDIUM count
System
-----------------
admin@swasth.in
Logout
```

Responsive: full sidebar > 1024px, icon-only 768-1024px, bottom nav < 768px.

---

## Phase 2 — Should Have (Month 1 Post-Launch)

### 2.1 Role Management & Segregation

**Why:** Legal HR-3 (DPDPA S8 + ISO 27001 least-privilege). Dr. Rajesh #7.

**Unify role system:** Currently `is_admin` boolean and `role` enum are inconsistent. Fix:
- `role=admin` automatically sets `is_admin=True`
- `role=patient|doctor` sets `is_admin=False`
- Deprecate direct `is_admin` toggle

**Backend:**
```
PATCH /admin/users/{user_id}/role
  body: { role: "patient"|"doctor"|"admin" }
  validation: cannot demote yourself, changing to doctor requires NMC verification
  audit: log to admin_audit_log
```

**Admin role tiers (future, design now):**

| Tier | Can See | Cannot See |
|------|---------|------------|
| Super Admin | Everything + audit logs | Cannot delete audit logs |
| Ops Admin | User list, verification queue, erasure queue | Cannot view health readings |
| Clinical Admin | Anonymized aggregate health data only | Cannot see PII |
| Support Admin | User account details (name, email, status) | Cannot view readings or chat |

**For pilot:** Single admin tier is acceptable. Design the audit log to support future segregation.

**UI:** Role change dialog with contextual warnings:
- Changing to Doctor → "Requires NMC verification. Doctor will be placed in pending queue."
- Changing to Admin → "Grants full data access to all users."
- Safety gate: type user's email to confirm

### 2.2 Search + Filters on User Table

**Why:** Essential at 50+ users (Healthify). Current endpoint returns all users with no pagination.

**Backend enhancement:**
```
GET /admin/users
  params: ?search=name_or_email&role=patient|doctor|admin&status=active|suspended
          &last_active=7d|30d|inactive_30&has_readings=true|false
          &page=1&per_page=50
  returns: paginated results with total_count
```

Add index: `CREATE INDEX idx_users_fullname ON users USING gin(to_tsvector('english', full_name));`

**UI columns (default):**

| Name + Email | Role | Profiles | Readings | Last Active | Status | Actions |
|---|---|---|---|---|---|---|

Hidden columns (via picker): Phone, Signup Date, AI Consent, Total Chats.

Filters: collapsible filter bar above table. Search: full-width, debounce 300ms.

Row actions (... menu): View Detail, Change Role, Suspend/Reactivate, Reset AI Memory.

### 2.3 Right to Erasure Workflow

**Why:** LEGAL BLOCKER — DPDPA S12(b). Must support within 72 hours of request.

**New table: `erasure_requests`**
```sql
CREATE TABLE erasure_requests (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    requested_at TIMESTAMP NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    completed_at TIMESTAMP,
    processed_by INTEGER REFERENCES users(id),
    notes TEXT
);
```

**Tiered anonymization on approval:**

| Data Type | Action | Legal Basis |
|-----------|--------|-------------|
| PII (name, email, phone, address) | Hard delete within 72 hours | DPDPA S12(b) |
| Health readings (BP, glucose, BMI) | Anonymize — strip patient_id, retain aggregate | NMC retention |
| AI chat history | Hard delete | DPDPA S12(b) |
| Doctor consultation notes | Retain anonymized 3 years | NMC S1.3.1 |
| Consent records | Retain 5 years after last processing | DPDPA S6(6) evidence |
| Audit logs | Cannot be erased | CERT-In 180 days |

**Backend:**
```
POST /admin/erasure-requests
  body: { user_id: int }
  action: creates erasure request, starts 72-hour SLA timer

GET /admin/erasure-requests
  params: ?status=pending|completed|rejected&page=1&per_page=50

POST /admin/erasure-requests/{id}/process
  body: { action: "approve"|"reject", notes: string }
  action: if approve, executes tiered anonymization
  audit: logged
```

**UI:** Erasure request queue with SLA countdown timer. One-click approve (executes anonymization). Reject with documented reason (NMC retention applies).

### 2.4 Clinical Overview Section

**Why:** Investors, Bihar health officials need population-level outcomes. Healthify Section 6.

**Backend:**
```
GET /admin/clinical
  returns: aggregated population health stats (NO individual PHI)
```

**Subsections:**
- **Condition Profile:** Bar chart — diabetes vs hypertension vs both vs neither (from Profile.medical_conditions)
- **Glycemic Control:** % readings in normal range (70-140 mg/dL fasting), distribution chart, 30-day trend
- **BP Control:** % at target (<130/80), distribution, trend
- **Engagement by Condition:** "Diabetic patients log 4.2 readings/week vs 1.1/week for healthy"
- **Compliance by Age Group:** <40, 40-50, 50-60, 60-70, 70+ engagement rates

**Privacy rule:** If any category has < 5 individuals, show "< 5" instead of count (DPDPA data minimization).

All charts have "Download as PNG" button (Chart.js built-in). Health officials need these for presentations.

### 2.5 Purpose Limitation Controls

**Why:** Legal HR-4 — DPDPA S4(1)(b). Admin viewing chat history exceeds operational necessity.

**Changes:**
- Default admin view hides chat content — shows only metadata (message count, last activity)
- Viewing chat/reading content requires explicit click → triggers elevated audit log entry
- Admin must select a reason before viewing PHI: "Support ticket", "Legal hold", "Breach investigation", "Clinical review"

---

## Phase 3 — Nice to Have (Sprint 4+)

### 3.1 Doctor Performance Metrics (Dr. Rajesh #9)
- Patient count per doctor, 7-day active sessions, critical reading acknowledgment rate
- Average response time to critical readings
- Overloaded doctor detection (> 30 patients, < 2 sessions/week)

### 3.2 Caregiver Linkage Visibility (Dr. Rajesh #6)
- Per patient: caregiver name, relationship, last login, linked date
- Filter: "patients with no caregiver" (higher-risk in Bihar elderly context)
- Caregiver activity metric: readings reviewed count

### 3.3 Patient-to-Doctor Assignment (Dr. Rajesh #7)
- Admin can assign/reassign patients to doctors
- Bulk reassignment when a doctor goes on leave
- Doctor detail page shows full patient list with reassign capability

### 3.4 Bulk SMS/Notification Tool (Dr. Rajesh #10)
- Select cohort (inactive > 14d, high-risk, etc.)
- Pre-written Hindi templates: "Namaste, aapka swasth record 7 din se update nahi hua hai..."
- Must have by week 4 of pilot for re-engagement

### 3.5 Pilot Cohort Segmentation (Dr. Rajesh #11)
- Tag patients: "Patna cohort A", "caregiver-linked", "high-risk hypertensive"
- Filter all dashboard metrics by cohort
- Essential for pilot outcome reporting

### 3.6 Doctor Onboarding Tracker (Dr. Rajesh #12)
- Post-verification checklist: profile complete -> first patient -> first reading reviewed -> first note
- Identify where doctors drop off in adoption funnel

### 3.7 Data Export (Dr. Rajesh #13)
- CSV/PDF export for doctor's patient panel (last 30/60/90 days)
- Non-PHI fields only for admin exports
- All exports audit-logged with recipient identity
- NMC compliance: doctors must maintain patient records

### 3.8 Breach Notification Tooling (Legal HR-2)
- CERT-In requires 6-hour breach reporting
- Incident log with discovery timestamp
- Affected users report generator
- Pre-filled CERT-In report template
- 6-hour countdown timer (visible to admin)

### 3.9 Duplicate Account Detection (Dr. Rajesh #15)
- Alert when same phone number, NMC number, or similar names detected
- Flagged for manual review, not auto-merged
- Bihar context: phone numbers get recycled, names are common

### 3.10 System Health Section (Healthify)
- AI latency (from AiInsightLog.latency_ms), fallback rate
- Model usage distribution (Gemini vs DeepSeek vs rule-based)
- Readings per day sparkline, total data volume
- Failed logins (if logged)

### 3.11 Admin Mobile Read-Only View (Dr. Rajesh #14)
- Simplified mobile view: today's active users, critical count, pending doctors
- Read-only — no management actions on mobile (too risky for accidental taps)

### 3.12 Grievance Redressal Queue (Legal MR-1)
- DPDPA S13 requires designated Grievance Officer
- Patient submits complaint -> admin tracks -> auto-escalate at 25 days -> resolve within 30 days
- Officer name + email published in Privacy Policy

### 3.13 Minor/Vulnerable User Protections (Legal MR-3)
- Flag accounts for age < 18
- Parental consent record linked to minor's account
- Block AI profiling for flagged minors
- Report: "all minor accounts without verified parental consent"

---

## New Database Tables Summary

```sql
-- Phase 1
admin_audit_log (id, admin_user_id, action_type, target_user_id,
    target_profile_id, timestamp, ip_address, data_fields_accessed,
    outcome, notes, session_id)

-- Phase 2
erasure_requests (id, user_id, requested_at, status, completed_at,
    processed_by, notes)

-- Phase 3 (future)
admin_alerts (id, alert_type, severity, message, target_user_id,
    created_at, dismissed_at, dismissed_by)  -- if we want persistent alerts
grievance_tickets (id, user_id, subject, description, status,
    assigned_to, created_at, resolved_at, resolution_notes)
```

---

## New API Endpoints Summary

### Phase 1
```
POST   /admin/doctors/{user_id}/verify     -- approve doctor NMC
POST   /admin/doctors/{user_id}/reject      -- reject with reason + email
GET    /admin/doctors                        -- list doctors (filter verified)
PATCH  /admin/users/{user_id}/suspend        -- suspend/reactivate
GET    /admin/alerts                         -- computed alerts
GET    /admin/consent                        -- consent status dashboard
GET    /admin/audit-log                      -- admin action history
```

### Phase 2
```
PATCH  /admin/users/{user_id}/role           -- change user role
GET    /admin/users (enhanced)               -- search, filter, pagination
POST   /admin/erasure-requests               -- create erasure request
GET    /admin/erasure-requests               -- list erasure requests
POST   /admin/erasure-requests/{id}/process  -- approve/reject erasure
GET    /admin/clinical                       -- aggregated population stats
```

### Phase 3
```
GET    /admin/doctors/{user_id}/metrics      -- doctor performance
POST   /admin/notifications/bulk             -- bulk SMS to cohort
GET    /admin/system/health                  -- API + AI performance
POST   /admin/breach-reports                 -- CERT-In incident log
GET    /admin/grievances                     -- grievance ticket queue
```

---

## Effort Estimates

| Phase | Items | Backend | Frontend (HTML) | Tests |
|-------|-------|---------|-----------------|-------|
| Phase 1 | 6 items | ~400 lines new routes + models | ~800 lines HTML/JS (sidebar + 3 new sections) | ~60 tests |
| Phase 2 | 5 items | ~300 lines (search, erasure, clinical, role) | ~600 lines HTML/JS | ~40 tests |
| Phase 3 | 13 items | ~500 lines | ~1000 lines | ~50 tests |

---

## Expert Verdicts

**Dr. Rajesh:** "Fix the doctor verification workflow first. If unverified doctors are active in the system, every piece of clinical data they touch is compromised."

**Legal Advisor:** "The four legal blockers (audit trail, erasure, consent, doctor verification) are non-negotiable even for a closed pilot with 50 users. DPDPA applies from day one — there is no pilot exemption."

**Healthify UX:** "The current dashboard is a solid foundation. The three gaps that matter for launch are: doctor verification workflow, account suspension, and search on the user table."
