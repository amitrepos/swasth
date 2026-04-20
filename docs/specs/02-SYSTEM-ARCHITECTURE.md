# 02 — System Architecture

**Last updated:** 2026-04-20

---

## 1. One-page summary

Swasth is a three-tier application:

```
┌──────────────────────────────┐
│  Flutter Client              │     Android APK · Web (swasth.app/web)
│  (lib/)                      │     · Offline-capable, Riverpod state
└──────────────┬───────────────┘
               │ HTTPS/JSON · Bearer JWT
               ▼
┌──────────────────────────────┐
│  FastAPI Backend             │     Uvicorn @ :8007 behind Nginx @ :8443
│  (backend/)                  │     · SQLAlchemy ORM · APScheduler jobs
└──┬──────────┬──────────┬─────┘
   │          │          │
   ▼          ▼          ▼
PostgreSQL  Gemini/   Brevo · Twilio
 (prod DB)  DeepSeek   (email · WA · SMS)
```

A family member installs the app, creates profiles for themselves and relatives, logs readings (manual, photo OCR, or Bluetooth-paired device), and shares selected data with a verified doctor. AI generates weekly summaries and meal tips. Dangerous readings fan out as alerts to all family users.

---

## 2. Technology stack

| Layer | Choice | Why |
|---|---|---|
| **Mobile / Web client** | Flutter 3.22 + Dart 3.4 | Single codebase for Android + web; strong performance on low-end devices (Bihar). |
| **State management** | Riverpod 3.x | Compile-time safety, testability; replaces Provider/Bloc. |
| **Backend framework** | FastAPI (Python 3.12) | Async, auto-OpenAPI, Pydantic validation, team already knows Python. |
| **Database** | PostgreSQL 14 | Relational integrity for health data; JSONB for flexible fields; mature migrations. |
| **ORM** | SQLAlchemy 2.0 | Explicit queries; transaction safety for health-critical writes. |
| **Migrations** | Alembic | Declarative, auto-generated, enforced via pre-commit hook + CI. |
| **Auth** | JWT (HS256) + bcrypt | Stateless, scales trivially; 30-min access token expiry. |
| **Encryption at rest** | AES-256-GCM | DPDPA / SPDI compliance for sensitive health fields. |
| **AI — text** | Gemini → DeepSeek → rule-based | Fallback chain for uptime; cost optimization. |
| **AI — vision** | Gemini (with key rotation) → Groq → DeepSeek | Multi-provider redundancy for OCR/meal classification. |
| **Email** | Brevo (Sendinblue) | Cheap, reliable transactional email for OTP + alerts. |
| **WhatsApp / SMS** | Twilio | Business API for alerts and weekly reports. |
| **OCR (client-side)** | Google MLKit (on-device) | Works offline; reduces server load for BP/glucose photo reading. |
| **Scheduling** | APScheduler | Weekly reports, alert deduplication windows, scheduled cleanups. |
| **Deployment** | Systemd + Nginx on bare-metal VPS | Simple, auditable, no container orchestration overhead at current scale. |
| **CI/CD** | GitHub Actions | Free, tight GitHub integration, ephemeral Postgres for migration tests. |

---

## 3. Deployment topology

```
┌────────────────────────────────────────────┐
│  Bare-metal VPS (Hetzner, 65.109.226.36)   │
│                                            │
│   Nginx (443) ─┬─► /api/*   → Uvicorn :8007│
│                ├─► /admin/* → Uvicorn :8007│
│                └─► /*       → /var/www/web │
│                                            │
│   systemd service: swasth-backend          │
│   APScheduler: weekly-report job           │
│                                            │
│   PostgreSQL (local, 5432, swasth_prod)    │
│   File storage: /var/swasth/uploads/       │
└────────────────────────────────────────────┘
                │
                ├─► Brevo SMTP (email)
                ├─► Twilio API (WhatsApp + SMS)
                └─► Gemini / DeepSeek APIs (AI)
```

**Environments:**

| Env | Host | Branch | Purpose |
|---|---|---|---|
| **local dev** | developer machine | any | Running backend + Flutter on localhost |
| **staging** | 65.109.226.36:8443 | `master` (auto-deploy) | Pre-prod, real data acceptable for test users |
| **production** | TBD (same server, different port or dedicated host) | `master` (manual approval) | Real users; full audit logging |

Deployment is triggered by `.github/workflows/prod.yml` (manual) and `.github/workflows/dev.yml` (auto-on-push). Migrations run **before** the backend restart, ordered so the new code never sees the old schema.

---

## 4. Request lifecycle (happy path)

A patient logs a blood-pressure reading. Here's what happens:

```
1. User taps "Log BP" on the dashboard.
2. Flutter: scan_screen.dart opens camera.
3. Photo captured → ocr_service.dart (MLKit) extracts systolic / diastolic.
4. User confirms values on reading_confirmation screen.
5. health_reading_service.dart → ApiClient.post('/api/health/readings',
   {profile_id, reading_type: 'blood_pressure', systolic: 145, diastolic: 92, ...})
6. Network layer adds Bearer <JWT>.
7. Offline? → sync_service caches, returns success optimistically.

8. FastAPI main.py routes to routes_health.py → create_health_reading().
9. Depends(get_current_user) validates JWT, fetches User.
10. get_profile_editor_or_403() confirms user has write access to profile.
11. health_utils.classify_blood_pressure(145, 92) → 'hypertension_stage_2'.
12. encryption_service.encrypt() wraps systolic/diastolic/notes → *_enc columns.
13. HealthReading row written in a transaction.
14. If status_flag is CRITICAL or HIGH-STAGE-2:
    alert_service.dispatch_critical_alert(reading) →
      - Look up all ProfileAccess users for this profile.
      - Dedup check against critical_alert_logs (30-min window).
      - Fan out: email (Brevo) + WhatsApp (Twilio) + SMS (Twilio stub).
      - Log each channel's outcome to critical_alert_logs.
15. Return HealthReadingResponse.

16. Flutter updates dashboard; history screen refreshes via Riverpod invalidation.
```

---

## 5. AI architecture

AI is used for four things: meal classification, health insights, trend summaries, and chatbot responses. All AI calls go through `ai_service.py` and are logged to `ai_insight_logs` (model used, tokens, latency, outcome).

**Fallback chains:**

```
TEXT:    DeepSeek ──(429 / timeout / 5xx)──► Gemini ──► rule-based template

VISION:  Gemini A ──► Gemini B ──► Gemini C  (3-key rotation on quota error)
         │
         └──► Groq (on persistent 4xx/5xx)
              │
              └──► DeepSeek vision (last resort)
```

**Key properties:**

- Every call writes a row in `ai_insight_logs` before returning. This is how we audit clinical claims and debug hallucinations.
- User consent is checked (`User.ai_consent == true`) before calling any AI. Otherwise we return a rule-based tip.
- Chat has a **daily quota** (default 5 messages/day, per `CHAT_DAILY_QUOTA` env var) to cap cost during the pilot.
- AI responses always include a disclaimer: "This is not medical advice." (Wired at prompt level; NMC compliance.)

---

## 6. Data flow — who can see what

Swasth has a three-axis access-control model:

| Axis | Values | Where enforced |
|---|---|---|
| **User role** | `patient`, `doctor`, `admin` | `User.role` column + route decorators |
| **Profile access** | `owner`, `editor`, `viewer` | `ProfileAccess` join table + `get_profile_*_or_403()` guards |
| **Doctor-patient link** | `pending_doctor_accept`, `active`, `revoked` | `DoctorPatientLink.status` + `get_doctor_patient_access()` |

Examples:

- A user with `role=patient` and `ProfileAccess(profile_id=5, access_level=viewer)` can **read** profile 5's readings but cannot add or delete them.
- A user with `role=doctor` and an active `DoctorPatientLink` to profile 5 can read readings (logged to `doctor_access_log` for audit), add shared or private notes, but cannot edit the profile demographics.
- A user with `is_admin=true` can see the admin dashboard, suspend users, and verify doctors, with every action logged to `admin_audit_log` (CERT-In 180-day retention).

All cross-user access is logged. All reads by doctors are logged. This is non-negotiable for DPDPA / SPDI compliance.

---

## 7. Offline-first behavior

The Flutter app is designed for unreliable Indian mobile networks:

- **`connectivity_service`** monitors network status.
- **`sync_service`** maintains a local queue (secure storage) of writes when offline.
- On reconnect, the queue is replayed in FIFO order. Failures are retried with exponential backoff.
- Reads hit a local cache first; stale data is indicated in the UI.
- Auth tokens persist in `flutter_secure_storage`; a 401 response triggers silent refresh (or logout if refresh fails).

See `lib/services/sync_service.dart` and `test/flows/offline_sync_test.dart` for the canonical patterns.

---

## 8. Observability

**Backend:**

- Python `logging` module → stdout → captured by systemd journal.
- Critical alerts and AI calls have structured log lines (`extra={...}`).
- No Sentry / New Relic at current scale — review when DAU > 100.

**Frontend:**

- No crash reporter wired yet (deferred; see `KNOWN_ISSUES.md`).
- Debug mode: `flutter run --flavor staging` surfaces all API errors in a debug banner.

**Audit:**

- `admin_audit_log` — immutable, 180-day retention (CERT-In directive).
- `doctor_access_log` — every doctor read of patient data.
- `critical_alert_logs` — every critical reading and the resulting fanout outcome.
- `ai_insight_logs` — every AI call (model, tokens, latency, result).

---

## 9. Architectural decisions you should not change without discussion

These are load-bearing choices. If you think one is wrong, open an ADR and discuss.

1. **Auth is JWT + bcrypt, not Firebase.** We own the identity layer for privacy / compliance reasons.
2. **Postgres, not MongoDB.** Health data is relational. Schema drift kills us faster than query complexity does.
3. **Alembic, not raw SQL migrations.** Enforced by hook.
4. **Riverpod, not Provider or Bloc.** Settled after a long evaluation; don't re-open.
5. **No direct `http` client calls in screens.** Everything goes through `ApiClient` for consistent error mapping, retry, and auth injection.
6. **No `print()` in backend.** Logging module only.
7. **Encryption keys are 32-byte (64 hex chars).** AES-256-GCM. Rotation procedure is documented in `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md`.
8. **Gemini key rotation is comma-separated `GEMINI_API_KEYS`.** Don't invent a new format.
9. **Every schema change is an Alembic revision in the same commit.** Hook-enforced.
10. **No skipping hooks (`--no-verify`).** If a hook fires, it has a reason.

---

## 10. Known architectural debt

See `KNOWN_ISSUES.md` for the authoritative list. High-level flavor:

- No crash reporter on the client.
- No dedicated read replica for analytics — admin metrics hit the primary.
- Migration `0002` backfilled defaults — run once; do not re-run.
- No API gateway / rate limiter beyond `slowapi` per-route limits.
- Twilio SMS is a stub — activates automatically once `TWILIO_SMS_NUMBER` is set in prod env.

---

For the next level of detail, proceed to:

- [03 — Backend Spec](03-BACKEND-SPEC.md)
- [04 — Frontend Spec](04-FRONTEND-SPEC.md)
- [05 — Data Model](05-DATA-MODEL.md)
