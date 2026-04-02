# Timezone Feature — Testing Guide

## Overview
The Swasth app now supports multi-timezone functionality so users from different countries see timestamps in their local timezone. Users select their timezone during registration and all timestamps (registration, login, health readings) respect that selection.

---

## Supported Timezones

| Region | Timezone ID | Display Name |
|--------|-------------|--------------|
| **USA** | America/New_York | USA - Eastern Time (EST/EDT) |
| | America/Chicago | USA - Central Time (CST/CDT) |
| | America/Denver | USA - Mountain Time (MST/MDT) |
| | America/Los_Angeles | USA - Pacific Time (PST/PDT) |
| **India** | Asia/Kolkata | India (IST) — **Default** |
| **Europe** | Europe/London | Europe - London (GMT/BST) |
| | Europe/Paris | Europe - Paris (CET/CEST) |
| | Europe/Berlin | Europe - Berlin (CET/CEST) |
| **Asia-Pacific** | Asia/Bangkok | Asia - Bangkok (ICT) |
| | Asia/Singapore | Asia - Singapore (SGT) |
| | Asia/Tokyo | Asia - Tokyo (JST) |
| | Asia/Hong_Kong | Asia - Hong Kong (HKT) |
| | Asia/Dubai | Asia - Dubai (GST) |
| | Australia/Sydney | Australia - Sydney (AEST/AEDT) |
| | Australia/Melbourne | Australia - Melbourne (AEST/AEDT) |
| **Global** | UTC | UTC (Coordinated Universal Time) |

---

## How to Test Timezone Feature

### **Option 1: Manual Testing (Recommended for QA)**

#### Test 1: Register a USA User
1. Open app and go to registration
2. Fill in:
   - Email: `usa_user@example.com`
   - Password: `TestPassword123!`
   - Full Name: `USA Test User`
   - Phone: `+12025551234`
3. **Select Timezone: "USA - Eastern Time (EST/EDT)"**
4. Accept privacy consent
5. Register

**Verify in Database:**
```sql
SELECT email, timezone, consent_timestamp FROM users WHERE email = 'usa_user@example.com';
```

**Expected Output:**
```
email                | timezone             | consent_timestamp
usa_user@example.com | America/New_York     | 2026-04-02 05:10:15 -04:00
```

The timestamp should show `-04:00` or `-05:00` offset (EDT/EST), not `+05:30`.

---

#### Test 2: Register an India User
1. Open app and go to registration
2. Fill in:
   - Email: `india_user@example.com`
   - Password: `TestPassword123!`
   - Full Name: `India Test User`
   - Phone: `+919876543210`
3. **Select Timezone: "India (IST)"** (default)
4. Accept privacy consent
5. Register

**Verify in Database:**
```sql
SELECT email, timezone, consent_timestamp FROM users WHERE email = 'india_user@example.com';
```

**Expected Output:**
```
email               | timezone         | consent_timestamp
india_user@example.com | Asia/Kolkata  | 2026-04-02 10:40:15 +05:30
```

The timestamp should show `+05:30` offset (IST).

---

#### Test 3: Register an Australia User
1. Open app and go to registration
2. Fill in:
   - Email: `australia_user@example.com`
   - Password: `TestPassword123!`
   - Full Name: `Australia Test User`
   - Phone: `+61412345678`
3. **Select Timezone: "Australia - Sydney (AEST/AEDT)"**
4. Accept privacy consent
5. Register

**Verify in Database:**
```sql
SELECT email, timezone, consent_timestamp FROM users WHERE email = 'australia_user@example.com';
```

**Expected Output:**
```
email                    | timezone          | consent_timestamp
australia_user@example.com | Australia/Sydney | 2026-04-02 15:40:15 +11:00
```

The timestamp should show `+11:00` offset (AEST).

---

#### Test 4: Login with Different Timezones
1. Login with `usa_user@example.com`
2. Check database for `last_login_at`:

```sql
SELECT email, timezone, last_login_at FROM users WHERE email = 'usa_user@example.com';
```

**Expected:**
```
email                | timezone        | last_login_at
usa_user@example.com | America/New_York | 2026-04-02 05:20:30 -04:00
```

Login timestamp should be in the user's timezone (Eastern Time, not India time).

---

#### Test 5: Verify Timezone Dropdown in Registration
1. Open registration screen
2. Scroll down to Timezone selector
3. Verify:
   - Default says "India (IST)"
   - Can tap dropdown and see all 15+ timezones
   - Can select any timezone
   - Selection persists after scrolling

---

### **Option 2: Automated Backend Tests**

```bash
cd backend
pip install -r requirements.txt
python -m pytest tests/test_timezone.py -v
```

**Tests Cover:**
- Registration with multiple timezones
- Consent timestamp stored correctly in user timezone
- Login timestamp reflects user timezone
- Timezone NULL handling for backward compatibility
- Multiple users with different timezones
- Proper timezone conversion (UTC → local)

---

### **Option 3: Automated Frontend Tests**

```bash
cd D:\NUOFIN\swasth
flutter test test/timezone_unit_test.dart -v
```

**Tests Cover:**
- Timezone list includes all major regions
- Default timezone is India
- Timezone validation for IANA format
- Timezone serialization in registration payload
- Multiple users can have different timezones

---

## Key Timestamps to Check

When testing, verify these timestamps are stored in the user's **local timezone**, not UTC or India time:

| Event | Database Field | Route |
|-------|----------------|-------|
| Registration | `consent_timestamp` | POST /register |
| AI Consent | `ai_consent_timestamp` | POST /ai-consent |
| Login | `last_login_at` | POST /login |
| Profile Update | `updated_at` | PUT /profile/{profile_id} |

---

## Expected Timezone Offsets

| Timezone | UTC Offset | Abbreviation |
|----------|-----------|--------------|
| America/New_York | UTC-5 / UTC-4 | EST / EDT |
| America/Chicago | UTC-6 / UTC-5 | CST / CDT |
| America/Denver | UTC-7 / UTC-6 | MST / MDT |
| America/Los_Angeles | UTC-8 / UTC-7 | PST / PDT |
| Asia/Kolkata | UTC+5:30 | IST |
| Europe/London | UTC+0 / UTC+1 | GMT / BST |
| Europe/Paris | UTC+1 / UTC+2 | CET / CEST |
| Asia/Bangkok | UTC+7 | ICT |
| Australia/Sydney | UTC+10 / UTC+11 | AEST / AEDT |
| UTC | UTC+0 | UTC |

---

## Troubleshooting

### **Issue: Login shows 500 error**
- **Cause:** Existing users without timezone column
- **Status:** ✅ **FIXED** - All old users now have timezone = 'Asia/Kolkata' after migration
- **Fix:** Run migration if needed: `python backend/migrate_add_timezone.py`

### **Issue: Timestamps show wrong timezone offset**
- **Cause:** Server not using `datetime.now(pytz.UTC).astimezone(user_tz)` conversion
- **Status:** ✅ **FIXED** in routes.py (lines 35-36, 100-101, 164, 194, 213)

### **Issue: Timezone dropdown not showing all options**
- **Cause:** Timezone list not included in registration screen
- **Status:** ✅ **FIXED** - All 15+ timezones now in dropdown

### **Issue: Timezone not being sent to backend**
- **Cause:** Registration payload missing timezone field
- **Status:** ✅ **FIXED** - timezone now included in registration API call

---

## Database Verification Queries

### Check all users and their timezones:
```sql
SELECT id, email, timezone, consent_timestamp, last_login_at FROM users ORDER BY id DESC LIMIT 10;
```

### Check USA timezone user:
```sql
SELECT email, timezone, 
  EXTRACT(EPOCH FROM (consent_timestamp AT TIME ZONE timezone) - 
  consent_timestamp AT TIME ZONE 'UTC') / 3600 as offset_hours 
FROM users WHERE timezone = 'America/New_York';
```

### Check India timezone user:
```sql
SELECT email, timezone, consent_timestamp FROM users WHERE timezone = 'Asia/Kolkata';
```

### Check for NULL timezones (should be empty after migration):
```sql
SELECT id, email FROM users WHERE timezone IS NULL;
```

---

## Backward Compatibility

✅ **Old users (created before timezone feature) are handled correctly:**
- Migration adds timezone column with default `'Asia/Kolkata'`
- All old users automatically get India timezone as default
- They can login, reset password, update profile without errors
- They can update their timezone in settings (future feature)

---

## Files Changed for Timezone

### Backend
- `backend/models.py` — Added timezone column to User model
- `backend/schemas.py` — Added timezone to UserRegister schema
- `backend/routes.py` — Updated all timezone conversions and added NULL checks
- `backend/requirements.txt` — Added pytz>=2024.1
- `backend/migrate_add_timezone.py` — Migration script (already run)

### Frontend
- `lib/screens/registration_screen.dart` — Added timezone dropdown
- `lib/screens/consent_screen.dart` — Updated callback to pass ai_consent

### Tests
- `backend/tests/test_timezone.py` — 50+ backend timezone tests
- `test/timezone_unit_test.dart` — Flutter unit tests

---

## Status

✅ **Timezone feature COMPLETE and TESTED**
- ✅ Backend timezone storage and conversion
- ✅ Frontend timezone selection in registration
- ✅ All timestamps use correct timezone
- ✅ Backward compatibility with old users (NULL timezone handling)
- ✅ Test coverage (backend + frontend)
- ✅ Migration script executed

**Ready for:** Bihar pilot & global user testing
