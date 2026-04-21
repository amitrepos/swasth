# 07 — Security & Compliance

**Applies to:** All engineers touching auth, PHI, consent, or doctor-portal code.
**Authoritative legal reference:** `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md`.

---

## 1. Regulatory surface

Swasth handles health data of Indian residents. We are subject to:

| Regulation | Scope | What it demands |
|---|---|---|
| **DPDPA 2023** (Digital Personal Data Protection Act) | All personal data | Explicit consent, purpose limitation, Right to Erasure, Right to Portability, breach notification |
| **SPDI Rules 2011** (IT Act) | Sensitive Personal Data — health data qualifies | "Reasonable security practices" (ISO 27001 or equivalent), encryption at rest + transit |
| **NMC 2020 Telemedicine Guidelines** | Doctor-patient interactions | Registered doctor only (NMC verification), documented examination before advice, clear doctor-patient relationship |
| **DISHA / EHR Standards** (aspirational) | Health record interoperability | FHIR R4 alignment (planned; see `docs/FHIR_R4_IMPLEMENTATION_PLAN.md`) |
| **CERT-In Directive 2022** | All entities handling IT infrastructure | Incident reporting within 6 hours, 180-day log retention |

This document focuses on the engineering controls that satisfy these.

---

## 2. Authentication

### 2.1 JWT (HS256)

- Library: `python-jose`
- Algorithm: **HS256** (symmetric). `SECRET_KEY` env var is required and must be ≥ 32 chars.
- Claims: `{ "sub": <email>, "exp": <unix_ts> }`. No user_id, no role, no PII beyond email.
- Expiry: 30 minutes default (`ACCESS_TOKEN_EXPIRE_MINUTES`).
- Refresh: currently re-login. Token refresh endpoint is a planned addition (see `KNOWN_ISSUES.md`).

### 2.2 Passwords

- Hashing: **bcrypt** (12 rounds) via `passlib`.
- Minimum strength: 8 chars, 1 letter, 1 digit, 1 special. Enforced client-side (registration form) and server-side (`schemas.py → PasswordStr`).
- Stored: `password_hash` column, never the plaintext. Plaintext is discarded after bcrypt.

### 2.3 OTPs

- Password reset and email verification OTPs are **6 digits**, 10-minute TTL.
- Stored as bcrypt hashes in `password_reset_otps` / `email_verification_otps` (we don't keep plaintext even transiently).
- Single-use — consumed on validation.
- Delivered via Brevo SMTP.

### 2.4 Session invalidation

- Suspension: `User.is_active=false` → next `get_current_user` call raises 401.
- Password change: existing tokens remain valid until expiry (known limitation; acceptable for 30-min windows).
- Account deletion: cascades all data; token becomes invalid at next request.

---

## 3. Authorization model

### 3.1 Three-axis access control

Any protected operation is gated on:

1. **User role** — `patient`, `doctor`, `admin` (column on `users`).
2. **Profile access** — `owner`, `editor`, `viewer` (rows in `profile_access`).
3. **Doctor-patient link** — `active` status in `doctor_patient_links`.

### 3.2 Reference guards

All in `backend/dependencies.py`:

```python
def get_current_user(...) -> User:
    """Extracts JWT, returns User, raises 401 on invalid/inactive."""

def get_profile_access_or_403(profile_id, user, db) -> ProfileAccess:
    """Any access level (owner/editor/viewer) — for READs."""

def get_profile_editor_or_403(profile_id, user, db) -> ProfileAccess:
    """Owner OR editor — for WRITEs."""

def get_profile_owner_or_403(profile_id, user, db) -> ProfileAccess:
    """Owner only — for profile deletion, access management."""

def get_doctor_patient_access(profile_id, doctor, db) -> DoctorPatientLink:
    """Active doctor-patient link only. Logs to doctor_access_log."""

def require_admin(user: User = Depends(get_current_user)) -> User:
    """is_admin check + audit log entry."""
```

### 3.3 Applying them

Pick the **strictest** guard the operation needs. A READ should use `get_profile_access_or_403`; a DELETE on the profile itself should use `get_profile_owner_or_403`. There is no "just check role" shortcut — role alone doesn't establish authorization.

```python
@router.post("/readings")
def create_reading(
    data: HealthReadingCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    access = get_profile_editor_or_403(data.profile_id, current_user, db)
    # ... proceed
```

---

## 4. Encryption

### 4.1 In transit

- All non-local deployments are HTTPS-only (Let's Encrypt + Nginx).
- Flutter web: served over HTTPS. API base URL hardcoded to HTTPS in production flavor.
- Flutter Android: network security config allows cleartext only for localhost (dev). Production builds reject cleartext.

### 4.2 At rest — field-level PHI encryption

`backend/encryption_service.py` implements AES-256-GCM.

- **Key:** `ENCRYPTION_KEY` env var. Exactly 64 hex chars (32 bytes).
- **Nonce:** 12 bytes, randomly generated per-encrypt.
- **Tag:** 16 bytes GCM MAC.
- **Stored format:** `base64(nonce || ciphertext || tag)`.

**Encrypted columns** (on `health_readings`):

```
glucose_value_enc
systolic_enc
diastolic_enc
pulse_rate_enc
weight_value_enc
notes_enc
```

The plaintext columns (`glucose_value`, etc.) still exist for a migration window. New reads should prefer `*_enc` when present. The goal is plaintext-column removal in a future release; see `KNOWN_ISSUES.md`.

### 4.3 Key rotation

- Procedure documented in `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md`.
- Requires a planned downtime window: generate new key → bulk re-encrypt → swap env var → restart.
- Two-key overlap not implemented yet — single-key model simplifies operational risk.

### 4.4 What is NOT encrypted at rest

- User email (needed for auth lookup).
- User full name, phone (low-sensitivity PII; consider encrypting later).
- Profile name, age, gender, blood group (low-sensitivity).
- Meal categories (non-medical).
- Chat messages (known gap — see below).

These are deliberate trade-offs to keep queries efficient. When in doubt, encrypt.

### 4.5 Known gap — chat PHI

Chat messages can contain PHI ("my blood sugar was 180 this morning"). They are currently stored plaintext in `chat_messages`. Tracked in `KNOWN_ISSUES.md` for encryption before production launch.

---

## 5. Consent model

### 5.1 Capture

On registration, we record:

- `consent_timestamp` — when T&Cs accepted
- `consent_app_version` — app version at consent
- `consent_language` — `en` or `hi` (what they actually saw)
- `ai_consent` — separate opt-in for AI features (required before AI endpoints return content)
- `ai_consent_timestamp`

Versioning matters: when T&Cs change materially, we bump the version and re-prompt users whose `consent_app_version` is below the new floor.

### 5.2 Granularity

Consent is captured at **three levels**:

1. **Account-level** — using the app at all (`users.consent_*`).
2. **Feature-level** — AI features (`users.ai_consent`).
3. **Share-level** — profile sharing (`profile_access` is itself a consent record; each row includes `access_level` and implicit relationship).
4. **Doctor-level** — `doctor_patient_links` with `consent_granted_at`, `consent_granted_by`, `consent_type`.

### 5.3 Revocation

- **AI consent**: `POST /auth/ai-consent {"ai_consent": false}` — AI endpoints stop returning AI-generated content.
- **Profile sharing**: `DELETE /profiles/{id}/access/{user_id}` — revokes at any time.
- **Doctor link**: `DELETE /doctor/link/{profile_id}` — patient-initiated revocation.
- **Account**: `DELETE /auth/account` — cascades all data. DPDPA Right to Erasure.

### 5.4 Audit

The `admin_audit_log` table records consent-related admin actions. User-initiated consent changes are captured in the `users` table (timestamps) or as `profile_access` / `doctor_patient_links` row changes.

---

## 6. Audit logging

### 6.1 `admin_audit_log`

Every admin-initiated action. Retention: **180 days minimum** (CERT-In).

Captured: `action_type`, `admin_user_id`, `target_user_id`/`target_profile_id`/`target_doctor_id`, `details` (JSONB), `outcome`, `error_message`, `ip_address`, `user_agent`, `created_at`.

**Policy:** immutable. No UPDATE or DELETE on this table.

### 6.2 `doctor_access_log`

Every doctor read of patient data. Retention: **2 years**.

Captured: `doctor_id`, `profile_id`, `link_id`, `action` (`read_readings` / `read_summary` / `view_profile` / `add_note`), `accessed_at`, `ip_address`, `user_agent`.

**Why:** NMC telemedicine guidelines require documented access. A doctor who views a patient's data without an active examined link triggers compliance review.

### 6.3 `critical_alert_logs`

Every critical-severity reading and its fanout outcome. Retention: **90 days**.

Captured: `profile_id`, `reading_id`, `recipient_user_id`, `channel` (email / whatsapp / sms), `status` (sent / failed / skipped), `error`, `severity`.

**Why:** if a family member was supposed to get alerted and didn't, we need to prove it — both for debugging and for clinical liability.

### 6.4 `ai_insight_logs`

Every AI call. Retention: **1 year**.

Captured: `user_id`, `profile_id`, `use_case`, `model_used`, `prompt_hash` (not the prompt, since prompts may contain PHI), `response_text`, `tokens_used`, `latency_ms`, `succeeded`, `error`.

**Why:** hallucination debugging, clinical audit trail, cost reporting.

---

## 7. Input validation

All request bodies go through Pydantic v2 schemas in `backend/schemas.py`. Pydantic enforces:

- Type coercion (int, float, datetime).
- Required vs optional fields.
- String formats (email, URL).
- Custom validators (password strength, phone E.164, OTP format).

**Rule:** never accept a `dict` into a route handler. Always type it as a schema.

```python
# Bad
@router.post("/readings")
def create_reading(data: dict, ...):
    ...  # whatever's in `data` — no validation

# Good
@router.post("/readings")
def create_reading(data: HealthReadingCreate, ...):
    ...  # pydantic validated everything
```

### 7.1 SQL injection

SQLAlchemy parameterizes all queries. Never use string concatenation or `f-strings` in SQL. `text("...")` with `.params(...)` is fine. Raw cursors are forbidden.

### 7.2 XSS

- Flutter: widgets escape content by default. No `dangerouslySetInnerHTML` equivalents used.
- Admin dashboard HTML: static template, no user-generated content rendered without escaping.

### 7.3 CSRF

JWT-in-header auth is not cookie-based, so CSRF is not a standard concern. The admin dashboard, which does use server-rendered forms, should add CSRF tokens — tracked in `KNOWN_ISSUES.md`.

---

## 8. Secrets management

### 8.1 Local dev

`backend/.env` — gitignored. Generated from `.env.example`.

### 8.2 Production

`gh secret set` via CLI. Never via the GitHub UI (PEM keys get corrupted). Secrets injected into the environment at deploy time.

| Secret | Used by |
|---|---|
| `SECRET_KEY` | JWT signing |
| `ENCRYPTION_KEY` | AES-256-GCM |
| `DATABASE_URL` | Postgres |
| `GEMINI_API_KEY` / `GEMINI_API_KEYS` | AI |
| `DEEPSEEK_API_KEY` | AI fallback |
| `GROQ_API_KEY` | Vision fallback |
| `BREVO_API_KEY` / `BREVO_SMTP_*` | Email |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_WHATSAPP_NUMBER` / `TWILIO_SMS_NUMBER` | SMS/WhatsApp |

### 8.3 Never

- Commit `.env`.
- Paste a real key into a test file.
- Log a key (even accidentally — no `logging.info(settings.GEMINI_API_KEY[:5])` — no partial keys).
- Print a key to the screen (no `print()` anyway per the code rules).

The repo uses pre-commit hooks to scan for secret-like strings; CI re-runs the scan.

---

## 9. OWASP Top 10 posture

| # | Threat | Status | Where enforced |
|---|---|---|---|
| 01 | Broken access control | ✅ | `dependencies.py` guards on every route |
| 02 | Cryptographic failures | ✅ | AES-256-GCM PHI; bcrypt passwords; HTTPS everywhere |
| 03 | Injection | ✅ | SQLAlchemy parameterization; pydantic validation |
| 04 | Insecure design | ⚠️ | Reviewed per feature via `/security-audit` skill |
| 05 | Security misconfiguration | ✅ | `.env` gitignored; CORS whitelist; Nginx hardening |
| 06 | Vulnerable components | ⚠️ | `requirements.txt` pinned; Dependabot enabled; manual review of major upgrades |
| 07 | Identification & auth failures | ✅ | bcrypt + JWT + OTP with TTL; rate limits on auth endpoints |
| 08 | Software & data integrity | ✅ | Alembic migration enforcement; signed APK; CI verifies hash of deployed artifacts |
| 09 | Logging & monitoring failures | ✅ | Four audit tables + 180-day retention |
| 10 | SSRF | ✅ | No user-controlled URL fetching in server code |

Run `/security-audit` on changed files before every merge. It's the formal gate.

---

## 10. Incident response

### 10.1 Detection

- Backend errors: logs go to systemd journal. On repeated 5xx, oncall gets a Telegram / email alert (planned — not yet wired).
- Alert fanout failures: visible in `admin_audit_log` → the dashboard has a "recent alerts" panel.

### 10.2 CERT-In obligations

If a security incident occurs (data breach, unauthorized access, service outage exploited), we must:

1. **Report to CERT-In within 6 hours** of detection (email: `incident@cert-in.org.in`).
2. **Preserve logs for 180 days minimum** (already in place via `admin_audit_log`).
3. **Notify affected users** under DPDPA § 25 (breach notification obligation).

Template and process in `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md § Incident Response`.

### 10.3 If you find a vulnerability

Do not open a public GitHub issue. Email `amitkumarmishra@gmail.com` directly. A private security advisory will be opened and a fix shipped before disclosure.

---

## 11. Pre-merge security checklist

Use this list whenever you touch auth / PHI / consent / doctor code:

- [ ] `/security-audit` run, no CRITICAL or HIGH findings.
- [ ] `/phi-compliance` run if any health data file changed.
- [ ] All new API routes use `Depends(get_current_user)` or explicitly justify public access.
- [ ] All profile access uses `get_profile_*_or_403`, not ad-hoc checks.
- [ ] All doctor access uses `get_doctor_patient_access`.
- [ ] All admin actions log to `admin_audit_log` via the standard helper.
- [ ] New PHI fields have `*_enc` counterparts and go through `encryption_service`.
- [ ] New user input is validated by a pydantic schema, not accepted as `dict`.
- [ ] No new secrets hardcoded; added to `config.py` + `.env.example` instead.
- [ ] No new third-party API called without `ai_insight_logs`-style audit.
- [ ] Tests cover the denial path (403 for missing access), not just happy path.
- [ ] `/legal-check` run if touching consent / sharing / AI advice / new data collection.

---

## 12. Further reading

- `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` — full legal checklist (NMC, DPDPA, SaMD).
- `docs/FHIR_R4_IMPLEMENTATION_PLAN.md` — interoperability roadmap.
- `RULES.md` — coding rules (security-adjacent ones flagged).
- `.claude/scripts/check-required-reviewers.sh` — which domain experts must review security-sensitive changes.

---

Next: [08 — Testing & Deployment](08-TESTING-AND-DEPLOYMENT.md)
