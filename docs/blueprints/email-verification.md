# Blueprint: Email Verification (OTP)

## Objective
Verify user email ownership via OTP during registration. Phase 1: soft enforcement (banner nudge, login allowed). Phase 2: hard block (one-line backend change).

## Phasing
- **Phase 1 (this blueprint):** Register → send OTP → allow login → show banner → user verifies anytime
- **Phase 2 (future, trivial):** Add `if not user.email_verified` guard in login endpoint → redirect to OTP screen

---

## Steps

### Step 1: Backend — Model + Migration + Endpoints
**Context brief:** The app uses SQLAlchemy with `Base.metadata.create_all()` (no Alembic). The `PasswordResetOTP` model at `models.py:278` already has the exact pattern we need (email, otp, created_at, expires_at, is_used). The `email_service.py` has `generate_otp()` and `send_otp_email()` already working via Brevo SMTP. The login endpoint returns a JWT token via `schemas.Token`; user data is fetched via `GET /me` using `schemas.UserResponse`.

**Files to modify:**
- `backend/models.py` — add `email_verified` + `email_verified_at` to User model; add `EmailVerificationOTP` model
- `backend/schemas.py` — add `email_verified` to `UserResponse`; add `SendEmailVerificationRequest` and `VerifyEmailRequest` schemas
- `backend/routes.py` — modify `register()` to send verification OTP instead of welcome email; add 3 new endpoints
- `backend/email_service.py` — add `send_email_verification_otp()` method (new template)

**Changes:**

1. **`models.py` — User model** (after line 31):
   ```python
   email_verified = Column(Boolean, default=False)
   email_verified_at = Column(DateTime(timezone=True), nullable=True)
   ```

2. **`models.py` — New model** (after PasswordResetOTP):
   ```python
   class EmailVerificationOTP(Base):
       __tablename__ = "email_verification_otps"
       id = Column(Integer, primary_key=True, index=True)
       user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
       email = Column(String, nullable=False)
       otp = Column(String, nullable=False)
       created_at = Column(DateTime(timezone=True), server_default=func.now())
       expires_at = Column(DateTime, nullable=False)
       is_used = Column(Boolean, default=False)
   ```

3. **`schemas.py` — UserResponse** — add:
   ```python
   email_verified: bool = False
   ```

4. **`schemas.py` — New schemas:**
   ```python
   class SendEmailVerificationRequest(BaseModel):
       """Request to send/resend email verification OTP."""
       pass  # Uses auth token — no body needed

   class VerifyEmailOTPRequest(BaseModel):
       otp: str = Field(..., min_length=6, max_length=6)
   ```

5. **`routes.py` — Modify `register()`:**
   - After creating user (line 76, after `db.commit()`), send verification OTP instead of welcome email
   - Generate OTP, save `EmailVerificationOTP`, call `email_service.send_email_verification_otp()`

6. **`routes.py` — 3 new endpoints:**
   - `POST /send-email-verification` — (authenticated) generate OTP, send to user's email. Rate limit: 3/minute.
   - `POST /verify-email` — (authenticated) verify OTP, set `email_verified=True`, `email_verified_at=now()`. Mark OTP used.
   - `GET /email-verification-status` — (authenticated) return `{email_verified: bool}` (lightweight check without fetching full user)

7. **`email_service.py` — New method** `send_email_verification_otp(email, otp, full_name)`:
   - Similar to `send_otp_email()` but with verification-specific subject and copy
   - Subject: "Verify Your Email - Swasth Health App"
   - Body: bilingual (EN + HI) — "Welcome to Swasth! Your verification code is: {otp}"

**Tests to write:**
- `tests/test_email_verification.py`:
  - Register → check `email_verified=False` in response
  - Send verification OTP → verify OTP → check `email_verified=True`
  - Verify with wrong OTP → 400
  - Verify with expired OTP → 400
  - Resend OTP → new OTP generated, old one still valid
  - Login works regardless of `email_verified` status (Phase 1)
  - Double-verify (already verified) → idempotent success

**Done when:**
- `email_verified` field appears in `GET /me` response
- Registration sends verification OTP email
- `POST /verify-email` marks user as verified
- All new tests pass
- Existing auth tests still pass

**Blocks:** Step 2, Step 3

---

### Step 2: Flutter — API Service + Storage
**Context brief:** `lib/services/api_service.dart` handles all HTTP via `ApiClient`. `lib/services/storage_service.dart` persists user data as JSON string via `saveUserData()`. The login flow calls `getCurrentUser(token)` and saves via `saveUserData(userData)`. `UserResponse` now includes `email_verified`.

**Files to modify:**
- `lib/services/api_service.dart` — add `sendEmailVerification()`, `verifyEmailOTP()`, `getEmailVerificationStatus()` methods
- `lib/services/storage_service.dart` — add `isEmailVerified()` helper that reads from cached user data

**Changes:**

1. **`api_service.dart`** — 3 new methods:
   ```dart
   Future<void> sendEmailVerification(String token) async { ... }
   Future<void> verifyEmailOTP(String token, String otp) async { ... }
   Future<bool> getEmailVerificationStatus(String token) async { ... }
   ```

2. **`storage_service.dart`** — helper:
   ```dart
   Future<bool> isEmailVerified() async {
     final data = await getUserData();
     return data?['email_verified'] == true;
   }
   ```

**Tests:** Update `test/helpers/mock_http.dart` with mock responses for the 3 new endpoints.

**Done when:**
- API methods callable from Flutter
- `isEmailVerified()` returns correct value from cached user data
- Mock HTTP helper updated

**Blocks:** Step 3

---

### Step 3: Flutter — Email Verification Screen + Banner
**Context brief:** The existing `OtpVerificationScreen` at `lib/screens/otp_verification_screen.dart` handles password-reset OTP with a 6-digit input, resend timer, and back-to-login link. We'll create a similar screen for email verification. The banner goes on `SelectProfileScreen` (first screen after login) and `HomeScreen` (main dashboard). Both already import `StorageService` and `AppLocalizations`.

**Files to create:**
- `lib/screens/email_verification_screen.dart` — OTP entry screen for email verification

**Files to modify:**
- `lib/screens/login_screen.dart` — after login, check `email_verified`; if false, show the verification screen (but allow skip)
- `lib/screens/select_profile_screen.dart` — show persistent banner if unverified
- `lib/screens/home_screen.dart` — show persistent banner if unverified
- `lib/l10n/app_en.arb` — add ~10 new strings (banner text, verification screen copy, button labels)
- `lib/l10n/app_hi.arb` — Hindi translations for same strings

**Changes:**

1. **`email_verification_screen.dart`** (new):
   - Reuses pattern from `otp_verification_screen.dart`
   - 6-digit OTP input, verify button, resend with 60s cooldown
   - On success: update cached user data (`email_verified: true`), navigate to SelectProfileScreen
   - "Skip for now" button → navigate to SelectProfileScreen
   - Auto-sends OTP on screen load (via `sendEmailVerification()`)

2. **`login_screen.dart`** — in `_login()` after `saveUserData()`:
   - Check `userData['email_verified']`
   - If false AND not a doctor: show dialog "Verify your email for account security" with "Verify Now" and "Later" buttons
   - "Verify Now" → push `EmailVerificationScreen`
   - "Later" → continue to SelectProfileScreen as usual

3. **`select_profile_screen.dart`** + **`home_screen.dart`** — banner:
   - In `_loadData()`, check `StorageService().isEmailVerified()`
   - If false, show a `MaterialBanner` or colored `Container` at top:
     - Text: "Please verify your email address" / "कृपया अपना ईमेल सत्यापित करें"
     - "Verify" button → push `EmailVerificationScreen`
     - Dismissible but reappears on next visit

4. **Localization strings** (~10 new keys):
   - `emailVerificationTitle`, `emailVerificationSubtitle`, `verifyEmailButton`, `skipForNow`
   - `emailNotVerifiedBanner`, `emailVerifiedSuccess`
   - Hindi equivalents

**Tests to write:**
- `test/flows/email_verification_flow_test.dart`:
  - Banner appears when `email_verified=false`
  - Banner absent when `email_verified=true`
  - OTP screen renders, accepts 6-digit input
  - Skip button navigates to profile selection
  - Successful verification updates cached data

**Done when:**
- Unverified users see a banner on profile selection and home screens
- Banner has a "Verify" button that opens OTP screen
- OTP screen sends/verifies OTP
- Skip works — user can use the app without verifying
- All flow tests pass
- All existing tests still pass

**Blocked by:** Step 1, Step 2

---

## Dependency Graph
```
Step 1 (Backend) ──┐
                   ├──► Step 3 (Flutter screens + banner)
Step 2 (Flutter API)┘
```

Step 1 and Step 2 can be developed in parallel (Step 2 uses mocks), but Step 2's integration test needs Step 1 deployed.

## Parallel Opportunities
- Steps 1 and 2 touch completely different files (backend vs Flutter) — can run in parallel
- Step 3 depends on both being complete

## Risks
- **DB migration on production:** No Alembic — `create_all()` adds new columns/tables but doesn't alter existing ones. Need to run `ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE` and `ALTER TABLE users ADD COLUMN email_verified_at TIMESTAMPTZ` manually on production PostgreSQL. **Mitigation:** Include the SQL in the PR description and deploy notes.
- **Existing users:** All existing users will have `email_verified=False`. This is correct — they'll see the banner. No forced migration needed for Phase 1.
- **Email deliverability:** Brevo SMTP is already working for password reset OTPs, so this is proven infrastructure.
- **Phase 2 flip:** When ready to enforce, add one guard in `login()`: `if not db_user.email_verified: raise HTTPException(403, "Email not verified")`. Flutter login catches 403 and redirects to verification screen.

## Phase 2 Toggle (Future — Not In This Blueprint)
When ready to block unverified users:
```python
# routes.py login() — add after password check
if not db_user.email_verified:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Email not verified. Please verify your email first."
    )
```
Flutter: catch 403 in `_login()` → push `EmailVerificationScreen` with no skip button.

## Estimated Steps: 3 | Critical Path: Steps 1 → 3 (or 2 → 3)
## Estimated Effort: Single session (~2-3 hours total)
