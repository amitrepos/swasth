# 06 — API Reference

**Base URL (staging):** `https://65.109.226.36:8443`
**Base URL (local):** `http://localhost:8007`
**Auth:** `Authorization: Bearer <JWT>` on every protected route.
**Interactive docs:** `GET /docs` (Swagger UI), `GET /redoc` (ReDoc). These are always in sync with the code — prefer them as source of truth.

All request/response bodies are JSON unless noted. Timestamps are ISO 8601 with timezone. IDs are integers.

---

## 1. Conventions

### Request headers

| Header | Required? | Example |
|---|---|---|
| `Authorization: Bearer <JWT>` | yes (except `/auth/register`, `/auth/login`, `/auth/forgot-password`) | `Bearer eyJhbGci...` |
| `Content-Type: application/json` | on write requests | |
| `X-App-Version` | recommended | `1.4.2` |
| `X-Locale` | recommended | `en` or `hi` |

### Standard error envelope

```json
{ "detail": "Human-readable message" }
```

For validation errors (422), FastAPI returns a pydantic-style array:

```json
{ "detail": [{ "loc": ["body", "email"], "msg": "value is not a valid email address", "type": "value_error.email" }] }
```

### Status codes

| Code | Meaning |
|---|---|
| 200 | OK |
| 201 | Created |
| 204 | No content (on successful DELETE) |
| 400 | Bad request (malformed payload) |
| 401 | Unauthorized (missing / invalid / expired token) |
| 403 | Forbidden (authenticated but not allowed) |
| 404 | Not found |
| 409 | Conflict (e.g., duplicate email, unique violation) |
| 422 | Validation error (pydantic) |
| 429 | Rate limited |
| 5xx | Server error |

---

## 2. `/api/auth/*`

Source: `backend/routes.py`.

### `POST /auth/register`

Public. Creates a user.

```json
// Request
{
  "email": "you@example.com",
  "password": "Passw0rd!",
  "full_name": "You",
  "phone_number": "+919876543210",
  "consent_given": true,
  "ai_consent": true,
  "consent_language": "en",
  "consent_app_version": "1.4.2"
}

// 201 Response
{
  "access_token": "eyJhbGci...",
  "token_type": "bearer",
  "user": { "id": 42, "email": "you@example.com", "full_name": "You", ... }
}
```

### `POST /auth/login`

Public. OAuth2 password-form body (not JSON):

```
Content-Type: application/x-www-form-urlencoded
username=you@example.com&password=Passw0rd!
```

```json
// 200 Response
{ "access_token": "eyJhbGci...", "token_type": "bearer" }
```

### `POST /auth/forgot-password`

Public. Sends OTP email.

```json
{ "email": "you@example.com" }
```

### `POST /auth/verify-otp`

Public. Validates OTP, returns a short-lived reset token.

```json
{ "email": "you@example.com", "otp": "123456" }
// → { "reset_token": "...", "expires_in": 600 }
```

### `POST /auth/reset-password`

```json
{ "reset_token": "...", "new_password": "NewPass!" }
```

### `GET /auth/me`

Returns current user.

### `PUT /auth/me`

Update name / phone / timezone. Email change triggers verification flow.

### `POST /auth/ai-consent`

Opt-in for AI features.

```json
{ "ai_consent": true }
```

### `POST /auth/send-email-verification`

Trigger email verification OTP for current email.

### `POST /auth/verify-email`

```json
{ "otp": "123456" }
```

### `DELETE /auth/account`

Full cascade delete. DPDPA Right to Erasure. Irreversible.

```json
{ "password": "current-password-for-confirmation" }
```

---

## 3. `/api/health/*`

Source: `backend/routes_health.py`.

### `POST /health/readings`

Log a reading. Access: profile editor or owner.

```json
// Glucose
{
  "profile_id": 5,
  "reading_type": "glucose",
  "reading_timestamp": "2026-04-20T08:30:00+05:30",
  "glucose_value": 140,
  "glucose_unit": "mg/dL",
  "sample_type": "fasting",
  "notes": "before breakfast"
}

// Blood pressure
{
  "profile_id": 5,
  "reading_type": "blood_pressure",
  "reading_timestamp": "...",
  "systolic": 145,
  "diastolic": 92,
  "pulse_rate": 78
}

// SpO2
{ "profile_id": 5, "reading_type": "spo2", "spo2_value": 95, ... }

// Weight
{ "profile_id": 5, "reading_type": "weight", "weight_value": 72.4, "weight_unit": "kg", ... }

// Steps
{ "profile_id": 5, "reading_type": "steps", "steps_count": 6400, "steps_goal": 8000, ... }
```

```json
// 201 Response
{
  "id": 987,
  "profile_id": 5,
  "reading_type": "blood_pressure",
  "systolic": 145,
  "diastolic": 92,
  "status_flag": "HIGH-STAGE-2",
  "reading_timestamp": "...",
  "created_at": "..."
}
```

**Side effect:** if `status_flag ∈ {CRITICAL, HIGH-STAGE-2}`, fan-out alerts fire to all profile access users (email + WhatsApp + SMS).

### `GET /health/readings`

Query params: `profile_id` (required), `reading_type` (optional), `from` (ISO date), `to` (ISO date), `limit` (default 30, max 200).

Returns array of readings, decrypted.

### `GET /health/readings/{id}`

Single reading.

### `DELETE /health/readings/{id}`

Editor-only. Soft delete preserved in audit.

### `GET /health/readings/health-score`

Query: `profile_id`. Returns composite 0–100 score over rolling 7 days.

### `GET /health/readings/ai-insight`

Query: `profile_id`. Returns AI-generated insight. Requires `ai_consent=true`.

```json
{
  "insight": "Your fasting glucose has trended up by 12 mg/dL this week...",
  "model_used": "gemini-2.0-flash",
  "generated_at": "..."
}
```

### `GET /health/readings/trend-summary`

Query: `profile_id`, `period_days` (7 / 14 / 30).

### `GET /health/readings/family-streaks`

Query: `user_id` (self). Returns adherence streaks across all profiles the user can access.

### `POST /health/readings/parse-image`

Multipart: `file=<image>`. Server-side OCR fallback for web clients without MLKit. Returns parsed fields.

### `POST /health/report/manual-trigger`

Debug/admin. Forces the weekly report job for a profile. Requires editor access.

```json
{ "profile_id": 5 }
```

---

## 4. `/api/meals/*`

Source: `backend/routes_meals.py`.

### `POST /meals`

Log a meal (optionally with photo classification via Gemini).

```json
// With photo
{
  "profile_id": 5,
  "timestamp": "2026-04-20T13:30:00+05:30",
  "meal_type": "LUNCH",
  "photo_base64": "data:image/jpeg;base64,...",
  "use_ai": true
}

// With quick-select category
{
  "profile_id": 5,
  "timestamp": "...",
  "meal_type": "LUNCH",
  "category": "MODERATE_CARB",
  "input_method": "QUICK_SELECT"
}
```

```json
// 201 Response
{
  "id": 321,
  "category": "HIGH_CARB",
  "glucose_impact": "HIGH",
  "tip_en": "Consider portion control...",
  "tip_hi": "हिस्सा कम रखें...",
  "confidence": 0.87,
  "input_method": "PHOTO_GEMINI"
}
```

### `GET /meals`

Query: `profile_id`, `from`, `to`, `limit`.

### `DELETE /meals/{id}`

### `POST /meals/parse-image`

Classification only — no persistence. Same input as `POST /meals` with a photo.

---

## 5. `/api/profiles/*`

Source: `backend/routes_profiles.py`.

### `GET /profiles`

Returns all profiles the current user can access (owned + shared).

### `POST /profiles`

Creates a profile. Caller becomes the `owner`.

```json
{
  "name": "Ma",
  "relationship": "mother",
  "date_of_birth": "1958-06-15",
  "gender": "female",
  "blood_group": "B+",
  "medical_conditions": ["diabetes_type_2", "hypertension"],
  "current_medications": "Metformin 500mg BID"
}
```

### `GET /profiles/{id}` · `PUT /profiles/{id}` · `DELETE /profiles/{id}`

Standard CRUD. Delete is owner-only and cascades to readings.

### `POST /profiles/{id}/invite`

Invite a family member.

```json
{
  "invited_email": "sister@example.com",
  "access_level": "viewer",
  "relationship": "sister"
}
```

### `DELETE /profiles/{id}/invites/{invite_id}`

Cancel pending invite.

### `GET /profiles/{id}/access`

List everyone with access.

### `DELETE /profiles/{id}/access/{user_id}`

Revoke a user's access. Owner-only.

### `PATCH /profiles/{id}/access/{user_id}`

Change access level. Owner-only.

```json
{ "access_level": "editor" }
```

### `GET /invites/pending`

Current user's pending invites.

### `PATCH /invites/{id}`

Accept or reject.

```json
{ "action": "accept" }  // or "reject"
```

---

## 6. `/api/chat/*`

Source: `backend/routes_chat.py`.

### `POST /chat/messages`

Send a chat message. Quota-enforced (default 5/day).

```json
{
  "profile_id": 5,
  "message": "What do these glucose readings mean?"
}
```

```json
// 200 Response
{
  "id": 456,
  "ai_response": "...",
  "model_used": "deepseek-chat",
  "remaining_quota": 4
}
```

429 if quota exceeded.

### `GET /chat/messages`

Query: `profile_id`, `limit`, `before_id` (pagination).

---

## 7. `/api/doctor/*`

Source: `backend/routes_doctor.py`.

### Doctor registration

#### `POST /doctor/register`

Requires authenticated user (role gets upgraded to `doctor`).

```json
{
  "nmc_number": "REG-12345",
  "specialty": "General Medicine",
  "clinic_name": "Patna Health Clinic",
  "clinic_city": "Patna",
  "bio": "25 years experience..."
}
```

Returns doctor profile with auto-generated `doctor_code` (e.g., `DRRAJ52`).

#### `GET /doctor/me`

Current doctor's profile + summary of patients.

### Discovery (patient side)

#### `GET /doctor/lookup/{code}`

Lookup by doctor code. Public info only (name, specialty, verified flag).

#### `GET /doctor/directory`

Query: `specialty`, `city`, `q` (name search). Searchable registry.

#### `GET /doctor/known-doctors`

Doctors linked to any of the current user's profiles.

### Linking

#### `POST /doctor/link/{profile_id}`

Patient initiates a link request.

```json
{ "doctor_code": "DRRAJ52", "consent_type": "explicit" }
```

Returns link in `pending_doctor_accept` status.

#### `DELETE /doctor/link/{profile_id}`

Patient revokes.

#### `GET /doctor/link/{profile_id}`

Link details (status, triage).

### Doctor patient management

#### `GET /doctor/patients/pending`

Pending link requests awaiting doctor action.

#### `POST /doctor/patients/{id}/accept`

```json
{
  "examined_on": "2026-04-15",
  "examined_for_condition": "Type 2 Diabetes follow-up"
}
```

#### `POST /doctor/patients/{id}/decline`

```json
{ "reason": "Not my specialty" }
```

#### `GET /doctor/patients`

Active patients. Sorted by triage: `critical` → `attention` → `stable` → `no_data`.

#### `GET /doctor/patients/{id}/readings`

Readings for a patient. Access logged.

#### `GET /doctor/patients/{id}/profile`

Patient profile metadata.

#### `GET /doctor/patients/{id}/summary`

AI-generated clinical summary.

#### `POST /doctor/patients/{id}/notes`

```json
{
  "note_text": "Patient reports morning headaches. Advised to monitor BP...",
  "is_shared": true,
  "note_type": "follow_up"
}
```

#### `GET /doctor/patients/{id}/notes`

List notes.

### Admin doctor verification

#### `POST /doctor/verify/{id}`

Admin-only. Marks doctor as NMC-verified.

#### `GET /doctor/audit/{id}`

Doctor access audit trail. Admin-only.

---

## 8. `/api/admin/*`

Source: `backend/routes_admin.py`. All routes require `is_admin=true`. Every action logged to `admin_audit_log`.

### `GET /admin/`

Serves admin dashboard HTML.

### `GET /admin/metrics`

System metrics (user / reading / alert counts, trend lines).

### `GET /admin/users`

Paginated user list. Query params: `q`, `role`, `is_active`, `limit`, `offset`.

### `GET /admin/users/{id}/detail`

Full user detail: consent snapshots, profiles, readings, linked doctors, family access.

### `PUT /admin/users/{id}`

Update email, phone, timezone.

### `PATCH /admin/users/{id}/suspend`

```json
{ "reason": "Violation of terms" }
```

### `POST /admin/users`

Create a user (for onboarding beta testers).

### `GET /admin/doctors`

List with verification status.

### `POST /admin/doctors/{id}/verify`

Approve NMC verification.

### `POST /admin/doctors/{id}/reject`

```json
{ "reason": "Invalid NMC number" }
```

### `GET /admin/consent`

Consent audit (all users, timestamps, versions, language).

### `GET /admin/alerts`

Recent 24h critical alerts with fanout outcomes.

### `GET /admin/audit-log`

Query: `admin_user_id`, `action_type`, `from`, `to`, `limit`.

---

## 9. Rate limits

Most routes are rate-limited via `slowapi` (IP + token). Defaults:

| Route group | Limit |
|---|---|
| `/auth/register`, `/auth/login`, `/auth/forgot-password` | 5/min per IP |
| `/auth/verify-otp` | 10/min per IP |
| `/chat/messages` | daily quota (see `CHAT_DAILY_QUOTA` env) |
| All others | 60/min per user |

429 responses include a `Retry-After` header.

---

## 10. Webhooks (inbound)

### `POST /webhooks/twilio/status`

Twilio delivery status callbacks. Updates `whatsapp_message_status`. Not authenticated by JWT — instead verifies Twilio signature.

---

## 11. Testing against the API

For quick exploration:

```bash
# Login and capture token
TOKEN=$(curl -s -X POST http://localhost:8007/api/auth/login \
  -d 'username=you@example.com&password=Passw0rd!' \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")

# Use it
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8007/api/profiles | jq
```

Or use Swagger UI at `/docs` — click "Authorize", paste the token, then execute any endpoint interactively.

---

**Note:** This reference documents intent. The authoritative source is always:
- `backend/schemas.py` (request/response shapes)
- `backend/routes_*.py` (actual route definitions)
- `GET /docs` on a running server (live Swagger)

When docs and code disagree, code wins — and please open a PR to fix the doc.
