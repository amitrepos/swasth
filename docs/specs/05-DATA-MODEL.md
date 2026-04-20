# 05 — Data Model

**Database:** PostgreSQL 14 · **ORM:** SQLAlchemy 2.0 · **Migrations:** Alembic
**Source of truth:** `backend/models.py` · **Migrations:** `backend/migrations/versions/`

This document describes the schema at a conceptual level. The canonical schema is always `models.py`. Run `alembic current` on a live DB to see which revision is applied.

---

## 1. Entity relationship overview

```
                    ┌──────────────┐
                    │    users     │ (identity + auth)
                    └──────┬───────┘
                           │ 1:N
       ┌───────────────────┼──────────────────────┐
       │                   │                      │
       ▼                   ▼                      ▼
 ┌────────────┐    ┌────────────────┐    ┌──────────────────┐
 │  profiles  │◄──►│ profile_access │    │ doctor_profiles  │
 └──────┬─────┘    └────────────────┘    └────────┬─────────┘
        │ 1:N                                     │ 1:N
        │                                         │
        ▼                                         ▼
 ┌────────────────┐                      ┌──────────────────────┐
 │ health_readings│                      │ doctor_patient_links │◄── references profiles
 │  meal_logs     │                      │ doctor_notes         │
 │  chat_messages │                      │ doctor_access_log    │
 └────────────────┘                      └──────────────────────┘
        │
        ▼
 ┌──────────────────────┐
 │ critical_alert_logs  │
 │ ai_insight_logs      │
 │ trend_summary_cache  │
 └──────────────────────┘
```

---

## 2. Core tables

### 2.1 `users` — identity

| Column | Type | Notes |
|---|---|---|
| `id` | BIGSERIAL PK | |
| `email` | VARCHAR UNIQUE NOT NULL | lowercase; auth handle |
| `password_hash` | VARCHAR NOT NULL | bcrypt |
| `full_name` | VARCHAR | |
| `phone_number` | VARCHAR | E.164 format |
| `role` | VARCHAR DEFAULT `'patient'` | `patient` · `doctor` · `admin` |
| `is_active` | BOOLEAN DEFAULT true | suspension flag |
| `is_admin` | BOOLEAN DEFAULT false | back-office access |
| `timezone` | VARCHAR DEFAULT `'Asia/Kolkata'` | IANA tz |
| `consent_timestamp` | TIMESTAMPTZ | when T&Cs accepted |
| `consent_app_version` | VARCHAR | app version at consent |
| `consent_language` | VARCHAR DEFAULT `'en'` | which locale shown |
| `ai_consent` | BOOLEAN DEFAULT false | opt-in for AI features |
| `ai_consent_timestamp` | TIMESTAMPTZ | |
| `email_verified` | BOOLEAN DEFAULT false | |
| `email_verified_at` | TIMESTAMPTZ | |
| `last_login_at` | TIMESTAMPTZ | |
| `created_at` · `updated_at` | TIMESTAMPTZ | `server_default=now()` |

**Relationships:** `users` 1:N `profile_access` · 1:1 `doctor_profiles` (nullable) · 1:N `admin_audit_log` (as admin).

### 2.2 `profiles` — health identity

A `profile` represents a person whose health is being tracked. The user who created the profile is always an `owner` in `profile_access`.

| Column | Type | Notes |
|---|---|---|
| `id` | BIGSERIAL PK | |
| `name` | VARCHAR NOT NULL | |
| `relationship` | VARCHAR | e.g., `self`, `mother`, `father`, `spouse` |
| `age` | INT | |
| `date_of_birth` | DATE | preferred over `age` when known |
| `gender` | VARCHAR | |
| `height_cm` | NUMERIC | |
| `weight_kg` | NUMERIC | starting weight (see `health_readings` for history) |
| `blood_group` | VARCHAR | |
| `medical_conditions` | TEXT[] | array |
| `other_medical_condition` | TEXT | |
| `current_medications` | TEXT | |
| `doctor_name` · `doctor_specialty` · `doctor_whatsapp` | VARCHAR | informal — not the linked doctor |
| `created_at` · `updated_at` | TIMESTAMPTZ | |

### 2.3 `profile_access` — permission matrix

| Column | Notes |
|---|---|
| `id`, `user_id` (FK users), `profile_id` (FK profiles) | |
| `access_level` | `owner` · `editor` · `viewer` |
| `relationship` | how `user_id` is related to the profile person |
| UNIQUE(`user_id`, `profile_id`) | one row per (user, profile) pair |

Enforced in code by `get_profile_access_or_403`, `get_profile_editor_or_403`, `get_profile_owner_or_403` in `dependencies.py`.

### 2.4 `profile_invites`

Pending family-member invitations.

| Column | Notes |
|---|---|
| `id`, `profile_id`, `invited_email`, `invited_by_user_id` | |
| `access_level` | requested level (editor or viewer; never owner) |
| `status` | `pending` · `accepted` · `rejected` · `expired` |
| `token` | one-time accept token |
| `expires_at` | 7 days default |
| `created_at`, `accepted_at` | |

---

## 3. Health data

### 3.1 `health_readings`

Time-series health data. **This is the most sensitive table.** Several columns have encrypted counterparts (`_enc`). All reads pass through `encryption_service.decrypt()`.

| Column | Type | Notes |
|---|---|---|
| `id` | BIGSERIAL PK | |
| `profile_id` | FK profiles NOT NULL | |
| `logged_by` | FK users | who entered it |
| `reading_type` | VARCHAR NOT NULL | `glucose` · `blood_pressure` · `spo2` · `steps` · `weight` |
| `reading_timestamp` | TIMESTAMPTZ NOT NULL | when the measurement was taken |
| `seq` | BIGINT | device dedup sequence |
| `glucose_value` · `glucose_value_enc` | NUMERIC · VARCHAR | plaintext (legacy) + AES-256-GCM |
| `glucose_unit` | VARCHAR | `mg/dL` default |
| `sample_type` | VARCHAR | `fasting` · `random` · `post_meal` · `2hr_post` |
| `systolic` · `systolic_enc` | INT · VARCHAR | |
| `diastolic` · `diastolic_enc` | INT · VARCHAR | |
| `pulse_rate` · `pulse_rate_enc` | INT · VARCHAR | |
| `mean_arterial_pressure` | NUMERIC | derived |
| `spo2_value` | NUMERIC | |
| `spo2_unit` | VARCHAR | `%` default |
| `steps_count` · `steps_goal` | INT | |
| `weight_value` · `weight_value_enc` | NUMERIC · VARCHAR | |
| `weight_unit` | VARCHAR | `kg` default |
| `value_numeric` | NUMERIC | normalized for queries |
| `unit_display` | VARCHAR | for UI |
| `status_flag` | VARCHAR | `NORMAL` · `WATCH` · `HIGH-STAGE-1` · `HIGH-STAGE-2` · `CRITICAL` |
| `notes` · `notes_enc` | TEXT · TEXT | |
| `created_at` · `updated_at` | TIMESTAMPTZ | |

**Indexes:**
- `(profile_id, reading_timestamp DESC)` — the query hotpath for history views
- `(profile_id, reading_type, reading_timestamp DESC)` — filtered history

**Classification:** `status_flag` is computed by `health_utils.py` at insert time. When `status_flag in {'HIGH-STAGE-2', 'CRITICAL'}`, `alert_service.dispatch_critical_alert()` fires.

### 3.2 `meal_logs`

| Column | Notes |
|---|---|
| `id`, `profile_id`, `logged_by`, `timestamp` | |
| `category` | `HIGH_CARB` · `MODERATE_CARB` · `LOW_CARB` · `HIGH_PROTEIN` · `SWEETS` |
| `glucose_impact` | `VERY_HIGH` · `HIGH` · `MODERATE` · `LOW` |
| `tip_en` · `tip_hi` | localized Gemini health tip |
| `meal_type` | `BREAKFAST` · `LUNCH` · `DINNER` · `SNACK` |
| `photo_path` | server-side stored photo URI |
| `input_method` | `PHOTO_GEMINI` · `QUICK_SELECT` · `MANUAL` |
| `confidence` | 0.0–1.0 from Gemini |
| `user_confirmed` | BOOLEAN — did user accept the classification |
| `user_corrected_category` | if user overrode, their choice |

### 3.3 `chat_messages`

| Column | Notes |
|---|---|
| `id`, `profile_id`, `user_id` | |
| `user_message` | the question |
| `ai_response` | the answer |
| `model_used` | `gemini-2.0-flash` · `deepseek-chat` · `rule-based` |
| `tokens_used` · `latency_ms` | cost / perf telemetry |
| `created_at` | |

### 3.4 `chat_context_profiles`

Cached summaries of long chat histories (fed back into model as context on the next call — keeps token cost bounded).

| Column | Notes |
|---|---|
| `id`, `profile_id`, `user_id` | |
| `summary_text` | rolling summary |
| `last_message_id` | watermark |
| `updated_at` | |

### 3.5 `trend_summary_cache`

Caches weekly/monthly AI trend summaries to avoid regenerating on every dashboard load.

| Column | Notes |
|---|---|
| `profile_id`, `period_days`, `summary_text` | |
| `generated_at`, `expires_at` | TTL (6h typical) |

---

## 4. Doctor portal

### 4.1 `doctor_profiles`

Extension of `users` for doctor-specific metadata. 1:1 with `users`.

| Column | Notes |
|---|---|
| `id`, `user_id` (FK users, UNIQUE) | |
| `nmc_number` | UNIQUE — National Medical Commission ID |
| `specialty` | `General Medicine`, `Cardiology`, etc. |
| `clinic_name` · `clinic_address` · `clinic_city` | |
| `doctor_code` | 8-char UNIQUE, e.g. `DRRAJ52`. Patients use this to discover the doctor. |
| `is_verified` | BOOLEAN — NMC verification done by admin |
| `verified_at`, `verified_by` (FK users, admin) | |
| `bio` · `languages_spoken` | |
| `created_at`, `updated_at` | |

### 4.2 `doctor_patient_links` — state machine

| Column | Notes |
|---|---|
| `id`, `doctor_id` (FK users), `profile_id` (FK profiles) | |
| `status` | `pending_doctor_accept` · `active` · `revoked` |
| `is_active` | legacy boolean (kept in sync with `status='active'`; will be dropped) |
| `consent_granted_at` · `consent_granted_by` (FK users) · `consent_type` | DPDPA audit fields |
| `accepted_at` · `accepted_by_doctor_id` (FK users) | when doctor accepted |
| `examined_on` | DATE — when doctor examined the patient (NMC requirement) |
| `examined_for_condition` | what condition the examination was for |
| `triage_status` | derived from recent readings: `critical` · `attention` · `stable` · `no_data` |
| `last_reading_value`, `last_reading_type`, `last_reading_timestamp` | denormalized for triage list |
| `compliance_7d` | 0–1 — % days with at least one reading in last 7 days |
| `trend_direction` | `improving` · `stable` · `worsening` |
| `revoked_at`, `revoked_by` | |
| UNIQUE(`doctor_id`, `profile_id`) | |

### 4.3 `doctor_notes`

| Column | Notes |
|---|---|
| `id`, `doctor_id`, `profile_id`, `link_id` (FK doctor_patient_links) | |
| `note_text` | |
| `is_shared` | BOOLEAN — true → patient can see; false → doctor-only |
| `note_type` | `general` · `prescription` · `follow_up` · `alert_response` |
| `created_at`, `updated_at` | |

### 4.4 `doctor_access_log`

Immutable audit trail of every doctor read of patient data. DPDPA / NMC compliance.

| Column | Notes |
|---|---|
| `id`, `doctor_id`, `profile_id`, `link_id` | |
| `action` | `read_readings` · `read_summary` · `view_profile` · `add_note` |
| `accessed_at` | TIMESTAMPTZ default now() |
| `ip_address` · `user_agent` | forensic |

---

## 5. Compliance / audit tables

### 5.1 `critical_alert_logs`

Every critical reading that triggered fanout. Debugging + audit.

| Column | Notes |
|---|---|
| `id`, `profile_id`, `reading_id` (FK health_readings), `recipient_user_id` | |
| `channel` | `email` · `whatsapp` · `sms` |
| `status` | `sent` · `failed` · `skipped` (dedup) |
| `error` | TEXT — error message if failed |
| `severity` | `CRITICAL` · `HIGH-STAGE-2` |
| `created_at` | |

### 5.2 `ai_insight_logs`

Every AI call. Clinical audit + hallucination debugging.

| Column | Notes |
|---|---|
| `id`, `user_id`, `profile_id` | |
| `use_case` | `meal_classification` · `health_insight` · `trend_summary` · `chat` · `weekly_report` |
| `model_used` | `gemini-2.0-flash` · `deepseek-chat` · `rule-based` · `groq-...` |
| `prompt_hash` | SHA-256 of prompt (we don't store PHI-containing prompts) |
| `response_text` | the actual output, for audit |
| `tokens_used`, `latency_ms` | |
| `succeeded` | BOOLEAN |
| `error` | TEXT if failed |
| `created_at` | |

### 5.3 `admin_audit_log`

Every admin action. CERT-In 180-day retention. Immutable (no UPDATE/DELETE by policy).

| Column | Notes |
|---|---|
| `id`, `admin_user_id` (FK users) | |
| `action_type` | e.g. `suspend_user`, `verify_doctor`, `create_user`, `export_audit` |
| `target_user_id` · `target_profile_id` · `target_doctor_id` | what was acted on |
| `details` | JSONB — action-specific payload |
| `outcome` | `SUCCESS` · `DENIED` · `ERROR` |
| `error_message` | if outcome != SUCCESS |
| `ip_address` · `user_agent` | |
| `created_at` | |

---

## 6. Transient / OTP tables

### 6.1 `password_reset_otps`

| Column | Notes |
|---|---|
| `id`, `user_id`, `otp_code_hash` | hashed, not plaintext |
| `created_at`, `expires_at` | 10-min TTL |
| `consumed_at` | once used, can't reuse |

### 6.2 `email_verification_otps`

Same shape as password_reset_otps. Separate table for clarity.

### 6.3 `whatsapp_message_status`

Delivery receipts from Twilio webhook.

| Column | Notes |
|---|---|
| `message_sid` (Twilio ID), `to_number`, `status` | `queued` · `sent` · `delivered` · `read` · `failed` |
| `error_code`, `error_message` | |
| `updated_at` | |

---

## 7. Migrations

**Location:** `backend/migrations/versions/`

**Current history (as of 2026-04-20):**

| Revision | File | Purpose |
|---|---|---|
| `0001` | `0001_baseline.py` | Baseline marker; creates `alembic_version` row against existing schema |
| `0002` | `0002_weight_columns_and_default_drift.py` | Adds weight columns to `health_readings`; backfills server defaults for timezone / access_level / status |
| `0003` | `0003_profile_invites_access_level_default.py` | Sets `profile_invites.access_level` server default |
| `0004` | `0004_align_existing_server_defaults.py` | Aligns model `server_default=` attributes with live prod DB (no-op on prod; prevents future drift) |

**Workflow (copy this to muscle memory):**

```bash
# 1. Edit backend/models.py
# 2. Generate migration
cd backend && source venv/bin/activate
alembic revision --autogenerate -m "add foo column to bar"

# 3. Review the generated file — autogenerate misses renames and data migrations
# 4. Test both directions
alembic upgrade head
alembic downgrade -1
alembic upgrade head
alembic check   # must say "No new upgrade operations detected"

# 5. Commit BOTH models.py AND the new migration in ONE commit
git add backend/models.py backend/migrations/versions/NNNN_*.py
git commit -m "feat(backend): add foo to bar + migration"

# Pre-commit hook verifies a migration exists. CI (migration-check.yml)
# re-runs upgrade+check against ephemeral Postgres.
```

**Escape hatch** (for no-op `models.py` edits — docstrings, type hint tweaks):

```bash
SWASTH_NO_MIGRATION_NEEDED=1 git commit -m "refactor(backend): docstrings only"
```

Do not abuse this. If autogenerate detects *anything*, it's not a no-op.

**Deploy:** `alembic upgrade head` runs automatically before the backend restart (idempotent; safe to re-run).

**Rollback:** `alembic downgrade -1` is supported but risky on prod — prefer rolling forward with a corrective migration. Never delete merged migrations.

---

## 8. Common query patterns

### Recent readings for a profile (dashboard)

```sql
SELECT * FROM health_readings
WHERE profile_id = :pid
ORDER BY reading_timestamp DESC
LIMIT 30;
-- Uses (profile_id, reading_timestamp DESC) index
```

### Glucose readings for trend analysis

```sql
SELECT * FROM health_readings
WHERE profile_id = :pid
  AND reading_type = 'glucose'
  AND reading_timestamp > now() - interval '30 days'
ORDER BY reading_timestamp;
-- Uses (profile_id, reading_type, reading_timestamp DESC) index
```

### Doctor's active patients with triage

```sql
SELECT dpl.*, p.name, p.age
FROM doctor_patient_links dpl
JOIN profiles p ON p.id = dpl.profile_id
WHERE dpl.doctor_id = :did AND dpl.status = 'active'
ORDER BY
  CASE dpl.triage_status
    WHEN 'critical'  THEN 0
    WHEN 'attention' THEN 1
    WHEN 'stable'    THEN 2
    WHEN 'no_data'   THEN 3
  END,
  dpl.last_reading_timestamp DESC NULLS LAST;
```

---

## 9. Data retention

| Table | Retention | Why |
|---|---|---|
| `users` | Indefinite (until deletion request) | DPDPA Right to Erasure |
| `profiles` | Cascades with user deletion | |
| `health_readings` | Indefinite (clinically useful long-term) | Patient owns via Right to Portability |
| `meal_logs` | 2 years | Shorter — minimal clinical value long-term |
| `chat_messages` | 90 days | Cost + privacy |
| `critical_alert_logs` | 90 days | Monitoring/debugging window |
| `ai_insight_logs` | 1 year | Hallucination debugging |
| `admin_audit_log` | 180 days | CERT-In Rule 5 requirement |
| `doctor_access_log` | 2 years | NMC telemedicine audit |
| `password_reset_otps`, `email_verification_otps` | 1 day | Auto-pruned; only active rows matter |

Retention pruning jobs run in `scheduler.py` (nightly).

---

## 10. When to change the schema

1. Is a simpler JSONB column enough? Prefer that over a new table for optional metadata.
2. Are you adding a new enum value? Use a VARCHAR — Postgres enums are a migration nightmare.
3. Are you adding a "column everyone will query"? Add an index in the same migration.
4. Are you dropping a column? Use a two-step migration: first stop writing (deploy A), then drop in a later release (deploy B). Never drop in one shot — rollback becomes impossible.
5. Are you renaming? Add new, backfill, stop writing old, drop old — four releases. Do not alembic-rename in one step.

---

Next: [06 — API Reference](06-API-REFERENCE.md) · [07 — Security & Compliance](07-SECURITY-AND-COMPLIANCE.md)
