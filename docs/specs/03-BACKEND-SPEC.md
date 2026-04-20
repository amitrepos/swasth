# 03 — Backend Spec

**Stack:** Python 3.12 · FastAPI · SQLAlchemy 2.0 · PostgreSQL 14 · Alembic · APScheduler
**Entry point:** `backend/main.py` · **Local port:** 8007 · **Swagger UI:** `/docs`

---

## 1. Module layout

```
backend/
├── main.py                 # FastAPI app factory, middleware, exception handlers
├── config.py               # Pydantic BaseSettings — all env vars
├── database.py             # SQLAlchemy engine + SessionLocal + Base + get_db()
├── auth.py                 # JWT create/decode, bcrypt hash/verify
├── dependencies.py         # get_current_user + profile/doctor access guards
├── models.py               # All ORM models (~20 tables)
├── schemas.py              # Pydantic v2 request/response schemas
│
├── routes.py               # /api/auth/*
├── routes_health.py        # /api/health/*
├── routes_meals.py         # /api/meals/*
├── routes_profiles.py      # /api/profiles/*
├── routes_chat.py          # /api/chat/*
├── routes_doctor.py        # /api/doctor/*
├── routes_admin.py         # /api/admin/*
│
├── ai_service.py           # Gemini/DeepSeek fallback chain
├── ai_report_service.py    # Weekly AI-generated health reports
├── email_service.py        # Brevo SMTP (OTP, password reset, alerts)
├── sms_service.py          # Twilio SMS (stub until number configured)
├── twilio_service.py       # Twilio WhatsApp Business API
├── encryption_service.py   # AES-256-GCM for PHI fields
├── alert_service.py        # Critical alert fanout (email + WA + SMS)
├── report_service.py       # Weekly report aggregation + dispatch
├── scheduler.py            # APScheduler background jobs
├── health_utils.py         # Glucose/BP/SpO2 clinical classification
├── doctor_utils.py         # Triage calc, link state machine
│
├── migrations/             # Alembic revisions
│   ├── env.py              # Alembic runtime config (escape % in DSN)
│   ├── script.py.mako      # Template for generated files
│   └── versions/           # 0001_baseline, 0002_weight_columns, 0003_...
├── alembic.ini             # Alembic config (script_location, logging)
│
├── tests/                  # pytest suite (~40 files)
├── requirements.txt        # Pinned dependencies
├── .env.example            # Template for local .env
└── admin_dashboard.html    # Server-rendered admin UI (Jinja-less, static)
```

Ignore the legacy `migrate_*.py` scripts in the backend root — those predate Alembic. Alembic is the only source of truth for schema changes.

---

## 2. `main.py` — what happens at startup

```python
app = FastAPI(title="Swasth API", ...)

# 1. CORS middleware (allow Flutter web + localhost)
# 2. Rate limiter (slowapi) — per-route limits
# 3. Exception handlers:
#    - IntegrityError → 409 Conflict (with safe detail)
#    - SQLAlchemyError → 500 (logs traceback, returns generic message)
#    - ValidationError → 422 (Pydantic default, but with our error shape)
# 4. Router registration (each routes_*.py module)
# 5. Scheduler start: weekly-report-sunday-ist, alert-cleanup-daily
# 6. Admin dashboard HTML served at /admin (static file)
```

Shutdown: scheduler graceful stop, DB connections closed.

---

## 3. Configuration (`config.py`)

All configuration flows through a single Pydantic `Settings` instance. Never `os.getenv()` directly.

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | — | Postgres DSN (required) |
| `SECRET_KEY` | — | JWT signing secret (required, min 32 chars) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | 30 | JWT lifetime |
| `ENCRYPTION_KEY` | — | 64-char hex for AES-256-GCM (required) |
| `GEMINI_API_KEY` / `GEMINI_API_KEYS` | — | Single key or comma-separated rotation pool |
| `DEEPSEEK_API_KEY` | — | Text fallback |
| `GROQ_API_KEY` | — | Vision fallback |
| `BREVO_API_KEY` / `BREVO_SMTP_USER` / `BREVO_SMTP_PASSWORD` | — | Email |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` | — | Twilio |
| `TWILIO_WHATSAPP_NUMBER` | — | Twilio WA sender (format: `whatsapp:+14155238886`) |
| `TWILIO_SMS_NUMBER` | — | SMS sender; if unset, SMS dispatch no-ops gracefully |
| `CHAT_DAILY_QUOTA` | 5 | Messages per user per day |
| `ALERT_DEDUP_WINDOW_MINUTES` | 30 | Suppress duplicate critical alerts within this window |
| `TESTING` | `false` | When true: in-memory SQLite, no external APIs, seed data |
| `APP_VERSION` | reads from git | For consent capture |

---

## 4. Routes — a tour

### 4.1 `/api/auth/*` (routes.py)

Public endpoints (no JWT required):
- `POST /register` — email + password + consent snapshot. Bcrypt hash, send welcome email, return token.
- `POST /login` — OAuth2PasswordRequestForm. Bcrypt verify, check `is_active`. Issues JWT.
- `POST /forgot-password` — email → OTP via Brevo. Stored in `password_reset_otps` (10-min expiry).
- `POST /verify-otp` — validate OTP against table. Returns short-lived reset token.
- `POST /reset-password` — new password + reset token → bcrypt, invalidate OTPs.

Authenticated:
- `GET /me` — current user profile.
- `PUT /me` — update name / phone / timezone. Email change triggers verification flow.
- `POST /ai-consent` — opt-in for AI features (required before AI endpoints return content).
- `POST /send-email-verification` — OTP to new email on change.
- `POST /verify-email` — validate email OTP.
- `DELETE /account` — full cascade delete (profiles, readings, access rows). DPDPA Right to Erasure.

### 4.2 `/api/health/*` (routes_health.py — largest file, ~1374 lines)

- `POST /readings` — the canonical write path. Validates profile access, classifies, encrypts, persists, fans out alerts if critical.
- `GET /readings` — query by `profile_id`, `reading_type`, date range, limit. Returns decrypted view.
- `GET /readings/health-score` — 7-day rolling composite score.
- `GET /readings/ai-insight` — Gemini insight for last N readings (requires `ai_consent`).
- `GET /readings/trend-summary` — period (7/14/30 days) trend analysis.
- `GET /readings/family-streaks` — adherence streaks per family member.
- `POST /readings/parse-image` — OCR-based pre-parse (fallback for clients without MLKit).
- `DELETE /readings/{id}` — editor-only. Soft delete for audit.
- `POST /report/manual-trigger` — force weekly report dispatch (debug / admin).

See [06 — API Reference](06-API-REFERENCE.md) for request/response shapes.

### 4.3 `/api/meals/*` (routes_meals.py)

- `POST /meals` — log a meal. Photo optional. If photo present, Gemini classifies into `category` (HIGH_CARB / MODERATE_CARB / LOW_CARB / HIGH_PROTEIN / SWEETS) and generates `glucose_impact` + `tip_en` + `tip_hi`.
- `GET /meals` — query by profile + date.
- `DELETE /meals/{id}` — editor-only.
- `POST /parse-image` — classification-only, no persistence.

### 4.4 `/api/profiles/*` (routes_profiles.py)

Multi-profile + family sharing:
- CRUD on profiles (`POST`, `GET`, `PUT`, `DELETE`).
- `POST /profiles/{id}/invite` — invite family member by email.
- `PATCH /invites/{id}` — accept or reject.
- `GET /profiles/{id}/access` — list users with access.
- `DELETE /profiles/{id}/access/{user_id}` — revoke.
- `PATCH /profiles/{id}/access/{user_id}` — change access level (owner-only).

### 4.5 `/api/chat/*` (routes_chat.py)

- `POST /messages` — AI chat. Quota-enforced. Uses `ChatContextProfile` to summarize long history.
- `GET /messages` — history.

### 4.6 `/api/doctor/*` (routes_doctor.py — ~1150 lines)

Three state-machine flows (see `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` for legal context):

**Registration flow:**
- `POST /register` — doctor signup. Captures NMC number, specialty. Generates unique `doctor_code` (e.g., `DRRAJ52`). Starts unverified.
- Admin `POST /verify/{id}` — verifies NMC out-of-band, marks `is_verified=true`.

**Linking flow (patient-initiated):**
1. Patient finds doctor via `GET /lookup/{code}` or `GET /directory`.
2. `POST /link/{profile_id}` — creates `DoctorPatientLink(status=pending_doctor_accept)`.
3. Doctor sees it in `GET /patients/pending`.
4. `POST /patients/{id}/accept` — doctor accepts with `examined_on` date and condition. Status → `active`.
5. OR `POST /patients/{id}/decline` — status → revoked.
6. Patient can `DELETE /link/{profile_id}` any time → status → revoked.

**Clinical access:**
- `GET /patients` — doctor's active list with triage status (critical/attention/stable/no_data).
- `GET /patients/{id}/readings` — decrypted readings. Each call logged to `doctor_access_log`.
- `GET /patients/{id}/summary` — AI-generated clinical summary.
- `POST /patients/{id}/notes` — `is_shared=true` visible to patient; else doctor-only.

### 4.7 `/api/admin/*` (routes_admin.py)

All routes gate on `User.is_admin`. Every action logged to `admin_audit_log` (immutable, 180-day retention).

- `GET /metrics` — system dashboard (user count, readings count, alerts 24h).
- `GET /users` — paginated list with filters.
- `PATCH /users/{id}/suspend` — `is_active=false`. User is locked out immediately.
- `POST /doctors/{id}/verify` — approve doctor registration.
- `GET /alerts` — recent critical alerts.
- `GET /audit-log` — admin action history with filters.
- `GET /consent` — user consent snapshots.

The admin dashboard HTML is served at `/admin` (see `admin_dashboard.html`) — a static page that calls these APIs.

---

## 5. Auth pipeline

### 5.1 Creating a token

```python
# backend/auth.py
def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=30))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm="HS256")
```

`data` is always `{"sub": user.email}`. We don't put user_id in the token — only email — to keep token invalidation simple (email is immutable except via verification flow).

### 5.2 Validating a request

```python
# backend/dependencies.py
def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
    email = payload.get("sub")
    user = db.query(User).filter_by(email=email).first()
    if not user or not user.is_active:
        raise HTTPException(401, "Inactive or missing user")
    return user
```

Any route with `Depends(get_current_user)` is protected. Do not pass user identity through the request body.

### 5.3 Profile-level access guards

```python
def get_profile_access_or_403(profile_id: int, user: User, db: Session) -> ProfileAccess:
    access = db.query(ProfileAccess).filter_by(user_id=user.id, profile_id=profile_id).first()
    if not access:
        raise HTTPException(403, "No access to this profile")
    return access

def get_profile_editor_or_403(...):  # requires owner OR editor
def get_profile_owner_or_403(...):   # requires owner only
```

Use the strictest guard the operation needs. `GET` → `get_profile_access_or_403` (any access level). `POST/PUT` → `get_profile_editor_or_403`. `DELETE profile itself` → `get_profile_owner_or_403`.

### 5.4 Doctor-patient access

```python
def get_doctor_patient_access(profile_id: int, doctor: User, db: Session) -> DoctorPatientLink:
    link = db.query(DoctorPatientLink).filter_by(
        profile_id=profile_id,
        doctor_id=doctor.id,
        status='active'
    ).first()
    if not link:
        raise HTTPException(403, "No active doctor-patient link")
    # DPDPA audit: log every read
    db.add(DoctorAccessLog(doctor_id=doctor.id, profile_id=profile_id, action='read', ...))
    return link
```

---

## 6. Services

### 6.1 `ai_service.py` — the fallback chain

```python
async def generate_text(prompt: str, *, model_preference: str = "deepseek") -> str:
    # 1. Try primary (DeepSeek for text, Gemini for vision).
    # 2. On 429/5xx/timeout, rotate to next provider.
    # 3. If all fail, return deterministic rule-based template.
    # 4. Log to ai_insight_logs before returning.
```

**Key invariants:**
- Every call is logged. No exceptions.
- Latency is always measured and stored.
- If the user has `ai_consent=false`, we short-circuit and return the rule-based template.
- Gemini vision rotates across up to 3 API keys to work around per-key rate limits.

### 6.2 `alert_service.py` — critical alert fanout

Called from `routes_health.create_health_reading()` when `status_flag in {'CRITICAL', 'HIGH-STAGE-2'}`.

```python
def dispatch_critical_alert(reading: HealthReading, db: Session) -> None:
    # 1. Check dedup window — same profile + type + severity within 30 min?
    # 2. Look up all ProfileAccess rows for this profile.
    # 3. For each recipient, for each channel (email, WhatsApp, SMS):
    #    - Attempt dispatch.
    #    - Log outcome (sent / failed / skipped) to critical_alert_logs.
    # 4. Return. Errors do not block the original reading write.
```

Wrapped in a broad `try/except` — we never want alert failures to corrupt the reading write.

### 6.3 `encryption_service.py` — AES-256-GCM

```python
def encrypt(plaintext: str) -> str:
    # Returns base64(nonce_12 || ciphertext || tag_16)
def decrypt(ciphertext: str) -> str:
    # Reverses the above
```

Encrypted columns: `glucose_value_enc`, `systolic_enc`, `diastolic_enc`, `pulse_rate_enc`, `weight_value_enc`, `notes_enc`. The plaintext column exists alongside temporarily for backfill; we're migrating to encrypted-only per `KNOWN_ISSUES.md`.

The `ENCRYPTION_KEY` env var must be exactly 64 hex chars = 32 bytes. Rotation is a planned-downtime procedure — see `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md`.

### 6.4 `email_service.py` — Brevo SMTP

Sends via Brevo's SMTP relay. Templates are inline (no Jinja). Three canonical use cases:

- OTP for password reset (6 digits, 10-min expiry).
- Email verification OTP.
- Critical alert notifications.

### 6.5 `twilio_service.py` — WhatsApp

Uses Twilio Business API with approved templates for:

- Weekly health report (triggered by scheduler).
- Critical alert to family members.
- Doctor link consent notification.

Templates must be pre-approved in Twilio console. See `deploy/twilio-templates/`.

### 6.6 `scheduler.py` — APScheduler

Two jobs:

- **weekly-report-sunday-ist** — every Sunday 09:00 IST. Iterates active profiles, generates AI summary, dispatches via WhatsApp.
- **alert-cleanup-daily** — prunes `critical_alert_logs` older than 90 days (keeps recent for dashboards).

APScheduler is started in `main.py` lifespan; stopped on shutdown.

---

## 7. Migrations (Alembic)

**Hook-enforced workflow:**

1. Edit `models.py`.
2. Auto-generate migration:
   ```bash
   cd backend && source venv/bin/activate
   alembic revision --autogenerate -m "short description"
   ```
3. Review the generated file in `migrations/versions/NNNN_*.py`. Fix anything auto-gen got wrong (renames, data migrations).
4. Test locally:
   ```bash
   alembic upgrade head
   alembic downgrade -1
   alembic upgrade head
   alembic check   # should say "No new upgrade operations detected"
   ```
5. Commit `models.py` AND the new migration in the same commit. The pre-commit hook will refuse otherwise.
6. CI (`.github/workflows/migration-check.yml`) re-runs upgrade + check against an ephemeral Postgres. This catches drift from reviewers who only eyeball diffs.
7. On deploy, the pipeline runs `alembic upgrade head` before restarting the backend.

**If you need to do a no-op models.py edit** (e.g., a docstring change) use `SWASTH_NO_MIGRATION_NEEDED=1 git commit ...` as a documented escape hatch. Do not abuse it.

See `backend/migrations/README.md` for the detailed procedure.

---

## 8. Testing

Full detail in [08 — Testing & Deployment](08-TESTING-AND-DEPLOYMENT.md). Highlights:

```bash
cd backend && source venv/bin/activate
TESTING=true python -m pytest tests/ -v                 # all tests
TESTING=true python -m pytest tests/ --cov=. --cov-report=term-missing
```

`TESTING=true` switches to in-memory SQLite and stubs out external APIs (Gemini, Brevo, Twilio). `conftest.py` provides the canonical fixtures (`client`, `auth_headers`, `sample_profile`, etc.).

**Coverage tiers (hard gates):**

| Tier | Target | Files |
|---|---|---|
| 1 | 95% | `health_utils.py`, `routes_health.py`, `routes_meals.py`, `models.py`, `schemas.py` |
| 2 | 90% | `dependencies.py`, `routes.py` (auth), `encryption_service.py` |
| 3 | 85% | Everything else |

---

## 9. Things to avoid

1. **Don't write `print()`** — use `logging`.
2. **Don't hit external APIs from tests** — mock them.
3. **Don't swallow exceptions silently** — log at minimum.
4. **Don't put user identity in request bodies** — get it from `Depends(get_current_user)`.
5. **Don't bypass `alert_service`** — all critical reading fan-out goes through it, so dedup and audit work.
6. **Don't write plaintext PHI** — if it's a `*_enc` column, encrypt before insert.
7. **Don't add a new env var without adding it to `config.py`** and `.env.example`.
8. **Don't create a new migration without running `alembic check`** locally first.

---

Next: [04 — Frontend Spec](04-FRONTEND-SPEC.md) · [05 — Data Model](05-DATA-MODEL.md) · [06 — API Reference](06-API-REFERENCE.md)
