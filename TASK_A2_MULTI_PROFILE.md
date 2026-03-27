# Task A2 — Multi-Profile with Cross-User Sharing

---

## Product Description (for Product Manager)

Today, every user in Swasth manages only their own health data. This feature changes that fundamentally.

After this feature, one user account can hold **multiple health profiles** — their own, and profiles they manage on behalf of others. There are two ways a profile can exist under your account:

**1. You created it (person without a smartphone)**
A son can create a profile called "Papa" directly inside his own account. He scans Papa's glucometer and BP monitor on Papa's behalf. Papa doesn't need a phone or an account. All of Papa's health data lives under the son's account, and the son is the owner.

**2. Someone invited you (person with their own account)**
If Papa does have a smartphone and his own Swasth account, he can invite his son by email. The son receives an email saying "Papa wants to share his health data with you." The son opens the app, sees a pending invite notification, and explicitly accepts it. Only after acceptance does Papa's profile appear in the son's account as a shared profile (viewer access).

**What the user sees after this feature:**
On the home screen, instead of jumping straight to one dashboard, the user first sees a profile selection screen showing all profiles they have access to — with a clear label on each:

- **"My Health"** — their own profile, created automatically when they registered
- **"Papa"** — a profile they created for someone without a smartphone (they are the owner)
- **"Ramesh"** — a profile shared with them by another user (viewer, read-only)

The user taps any card to view that person's health dashboard. Every reading saved is tagged with both the profile it belongs to and who logged it.

**Invite flow uses email for now. WhatsApp notification is planned for a later sprint.**

---

## Current State vs Target State

### Current
```
User (auth + health identity combined)
  └── HealthReading (user_id FK)
```
One user = one person's health data. No way to manage someone else's health from your account.

### Target
```
User (auth only — email, password, name, phone)
  ├── ProfileAccess ──► Profile (owned by me — "My Health")
  ├── ProfileAccess ──► Profile (created by me for Papa — owner)
  └── ProfileAccess ──► Profile (shared by Ramesh — viewer)

Profile
  └── HealthReading (profile_id FK + logged_by user_id FK)

ProfileInvite (pending until accepted)
  ├── invited by: User A
  ├── invited email: userB@email.com
  └── status: pending / accepted / rejected
```

---

## Data Model Design

### New table: `profiles`

| Column | Type | Notes |
|--------|------|-------|
| id | Integer PK | |
| name | String | "My Health", "Papa", "Mummy" |
| age | Integer | |
| gender | String | Male / Female / Other |
| height | Float | cm |
| blood_group | String | |
| medical_conditions | ARRAY(String) | |
| other_medical_condition | Text nullable | |
| current_medications | Text nullable | |
| created_at | DateTime | |
| updated_at | DateTime | |

### New table: `profile_access`

| Column | Type | Notes |
|--------|------|-------|
| id | Integer PK | |
| user_id | Integer FK → users.id | who has access |
| profile_id | Integer FK → profiles.id | to which profile |
| access_level | String | `owner` or `viewer` |
| created_at | DateTime | |

Constraint: `unique(user_id, profile_id)` — one row per user-profile pair.

### New table: `profile_invites`

| Column | Type | Notes |
|--------|------|-------|
| id | Integer PK | |
| profile_id | Integer FK → profiles.id | which profile is being shared |
| invited_by_user_id | Integer FK → users.id | who sent the invite |
| invited_email | String | email of the person being invited |
| invited_user_id | Integer FK → users.id, nullable | resolved when invitee accepts |
| status | String | `pending`, `accepted`, `rejected` |
| created_at | DateTime | |
| expires_at | DateTime | invite expires after 7 days |

Rules:
- Only profile owners can send invites
- One pending invite per (profile_id, invited_email) — no duplicates
- Expired invites are treated as rejected

### Modified table: `users`

Remove health columns — they move to `profiles`:
- ~~age, gender, height, weight, blood_group, medical_conditions, other_medical_condition, current_medications~~

Keep: `id, email, password_hash, full_name, phone_number, is_active, created_at, updated_at`

> `weight` is a time-series reading, not a fixed profile attribute — stays out of this table.

### Modified table: `health_readings`

| Change | Detail |
|--------|--------|
| Rename `user_id` → `logged_by` | Who saved this reading — for "Logged by Son" display |
| Add `profile_id` FK → profiles.id | Which profile this reading belongs to |

---

## Backend Changes

### 1. `backend/models.py`
- Add `Profile` model
- Add `ProfileAccess` model
- Add `ProfileInvite` model
- Remove health columns from `User` (keep auth fields only)
- In `HealthReading`: rename `user_id` → `logged_by`, add `profile_id` FK

### 2. `backend/schemas.py`

New schemas to add:
- `ProfileCreate` — name, age, gender, height, blood_group, conditions, medications
- `ProfileUpdate` — all fields optional
- `ProfileResponse` — profile fields + `access_level` (injected per-user when returned)
- `InviteRequest` — `email: EmailStr`
- `InviteResponse` — id, profile_id, profile_name, invited_by_name, status, expires_at
- `InviteRespondRequest` — `action: Literal["accept", "reject"]`

Existing schemas to update:
- `UserRegister` — remove health fields. Add optional `profile_name` (defaults to `"My Health"`)
- `UserResponse` — remove health fields
- `HealthReadingCreate` — replace `user_id` with `profile_id`
- `HealthReadingResponse` — replace `user_id` with `profile_id`, add `logged_by_name: str`

### 3. New file: `backend/routes_profiles.py`

**Profile CRUD:**

| Method | Path | Description | Access |
|--------|------|-------------|--------|
| GET | `/api/profiles` | List all profiles the user has access to (owned + shared) | Auth |
| POST | `/api/profiles` | Create a new profile (caller becomes owner) | Auth |
| GET | `/api/profiles/{id}` | Get a single profile | Owner or Viewer |
| PUT | `/api/profiles/{id}` | Update profile details | Owner only |
| DELETE | `/api/profiles/{id}` | Delete profile and all its readings | Owner only |

**Invite management (owner sends invites):**

| Method | Path | Description | Access |
|--------|------|-------------|--------|
| POST | `/api/profiles/{id}/invite` | Send invite to an email — triggers email notification | Owner only |
| DELETE | `/api/profiles/{id}/invites/{invite_id}` | Cancel a pending invite | Owner only |
| GET | `/api/profiles/{id}/access` | List who has access to this profile | Owner only |
| DELETE | `/api/profiles/{id}/access/{user_id}` | Revoke a viewer's access | Owner only |

**Invite management (invitee responds):**

| Method | Path | Description | Access |
|--------|------|-------------|--------|
| GET | `/api/invites/pending` | List all pending invites sent to current user's email | Auth |
| POST | `/api/invites/{id}/respond` | Accept or reject an invite | Auth |

**Invite flow logic on backend:**
- `POST /invite`: verify caller is owner → check no duplicate pending invite exists → create `ProfileInvite(status=pending)` → call `email_service.send_profile_invite_email()`
- `POST /invites/{id}/respond` with `accept`: verify invite is pending + not expired + addressed to current user's email → create `ProfileAccess(viewer)` → set `invited_user_id` + `status=accepted`
- `POST /invites/{id}/respond` with `reject`: set `status=rejected`

### 4. `backend/routes.py`
- `POST /register` — remove health fields from request body. After creating `User`, auto-create a `Profile` using the registration health data, then create a `ProfileAccess(owner)` row.

### 5. `backend/routes_health.py`
- All endpoints require `profile_id` (as query param for GET, body field for POST)
- Before any operation: call `get_profile_access_or_403()` to verify current user has access to the profile
- On save: set `logged_by = current_user.id`

### 6. `backend/email_service.py`
- Add `send_profile_invite_email(invitee_email, inviter_name, profile_name, invite_id)` method
- Email body: "{{inviter_name}} wants to share their health profile '{{profile_name}}' with you on Swasth. Open the app to accept or reject."
- *(WhatsApp version of this notification is parked for a later sprint)*

### 7. `backend/dependencies.py`
Add two new helpers:
- `get_profile_access_or_403(profile_id, user, db)` — returns `ProfileAccess` row (owner or viewer) or raises 403
- `get_profile_owner_or_403(profile_id, user, db)` — returns `ProfileAccess` only if `owner`, raises 403 for viewer

### 8. `backend/main.py`
- Register `routes_profiles.router` with prefix `/api`

### 9. New file: `backend/migrate_to_profiles.py`
One-time migration script (run on dev DB now, run on prod before launch):
1. For each `User`: create a `Profile` from their health columns, create `ProfileAccess(owner)`
2. For each `HealthReading`: set `profile_id` from the user's auto-created profile, set `logged_by = user_id`
3. Drop health columns from `users` table

---

## Flutter Changes

### 1. New file: `lib/models/profile_model.dart`
```
ProfileModel {
  id, name, age, gender, height, bloodGroup,
  medicalConditions, otherMedicalCondition,
  medications, accessLevel   // "owner" or "viewer"
}
```

### 2. New file: `lib/models/invite_model.dart`
```
InviteModel {
  id, profileId, profileName,
  invitedByName, status, expiresAt
}
```

### 3. New file: `lib/services/profile_service.dart`
```
getProfiles(token)                              → List<ProfileModel>
createProfile(token, data)                      → ProfileModel
updateProfile(token, profileId, data)           → ProfileModel
deleteProfile(token, profileId)
sendInvite(token, profileId, email)
cancelInvite(token, profileId, inviteId)
getProfileAccess(token, profileId)              → List of viewer users
revokeAccess(token, profileId, userId)
getPendingInvites(token)                        → List<InviteModel>
respondToInvite(token, inviteId, accept: bool)
```

All methods use `ApiClient.headers(token: token)` and `ApiClient.errorDetail()`.

### 4. `lib/services/storage_service.dart`
Add:
- `saveActiveProfileId(int id)`
- `getActiveProfileId()` → `int?`
- `saveActiveProfileName(String name)` — for banner display without re-fetching
- `getActiveProfileName()` → `String?`

### 5. New file: `lib/screens/select_profile_screen.dart`
First screen after login (and reachable via "Switch" from home):
- Two sections:
  - **"My Profiles"** — `accessLevel == "owner"` (own + created for others without phone)
  - **"Shared With Me"** — `accessLevel == "viewer"`
- Each card: profile name, age, condition tags, owner/viewer badge
- Pending invites banner at top if count > 0: "You have N pending invites →" → taps to `PendingInvitesScreen`
- `[+ Add Profile]` button → opens `CreateProfileScreen`
- Tap card → save activeProfileId + name → go to `HomeScreen`

### 6. New file: `lib/screens/create_profile_screen.dart`
Form to create a profile for someone without a smartphone:
- Fields: Name (required), Age, Gender, Height, Blood Group, Medical Conditions, Medications
- Submit → `ProfileService.createProfile()` → back to `SelectProfileScreen`

### 7. New file: `lib/screens/pending_invites_screen.dart`
List of incoming pending invites:
- Each row: "{{Name}} wants to share '{{Profile Name}}' with you — expires in X days"
- `[Accept]` and `[Reject]` buttons per row
- Accept → `ProfileService.respondToInvite(accept: true)` → profile appears on selection screen
- Reject → invite dismissed
- Empty state: "No pending invites"

### 8. New file: `lib/screens/manage_access_screen.dart`
Owner-only screen, opened from profile settings:
- `[Invite someone]` → email input → `ProfileService.sendInvite()` → success toast
- List of current viewers with `[Revoke]` per row
- List of pending sent invites with `[Cancel]` per row

### 9. `lib/screens/home_screen.dart`
- Active profile banner at top: "Viewing: Papa's Health · [Switch]"
- "Switch" → navigates to `SelectProfileScreen`
- Pass active `profileId` to all downstream navigation (scan, history, dashboard)

### 10. `lib/screens/dashboard_screen.dart`
- Accept `profileId` as constructor param
- Pass `profileId` to `HealthReadingService.saveReading()`

### 11. `lib/screens/history_screen.dart`
- Accept `profileId` as constructor param
- Pass `profileId` to `HealthReadingService.getReadings()`

### 12. `lib/screens/profile_screen.dart`
- Fetch and show the active profile via `ProfileService.getProfile(profileId)`
- Show `[Edit]` only if `accessLevel == "owner"`
- Show `[Manage Access]` only if `accessLevel == "owner"` → opens `ManageAccessScreen`

### 13. `lib/main.dart`
Post-login routing:
- Check `StorageService.getActiveProfileId()`
  - Has value → go to `HomeScreen`
  - No value → go to `SelectProfileScreen`

---

## Execution Order

```
Step 1  — backend/models.py              Add Profile, ProfileAccess, ProfileInvite. Update User + HealthReading.
Step 2  — backend/schemas.py             New profile + invite schemas. Update user + reading schemas.
Step 3  — backend/migrate_to_profiles.py Write + run on dev DB.
Step 4  — backend/dependencies.py        Add get_profile_access_or_403 + get_profile_owner_or_403.
Step 5  — backend/email_service.py       Add send_profile_invite_email().
Step 6  — backend/routes_profiles.py     Profile CRUD + invite send/respond endpoints.
Step 7  — backend/routes.py              Update register to auto-create profile.
Step 8  — backend/routes_health.py       Switch from user_id to profile_id.
Step 9  — backend/main.py                Register profiles router.

--- Verify all endpoints via /docs before touching Flutter ---

Step 10 — lib/models/profile_model.dart
Step 11 — lib/models/invite_model.dart
Step 12 — lib/services/profile_service.dart
Step 13 — lib/services/storage_service.dart        Add active profile methods
Step 14 — lib/screens/select_profile_screen.dart   New
Step 15 — lib/screens/create_profile_screen.dart   New
Step 16 — lib/screens/pending_invites_screen.dart  New
Step 17 — lib/screens/manage_access_screen.dart    New
Step 18 — lib/screens/home_screen.dart             Profile banner + pass profileId
Step 19 — lib/screens/dashboard_screen.dart        Accept profileId param
Step 20 — lib/screens/history_screen.dart          Accept profileId param
Step 21 — lib/screens/profile_screen.dart          Active profile data, owner-only controls
Step 22 — lib/main.dart                            Post-login routing
```

---

## What Is NOT in This Task

| Out of scope | When |
|---|---|
| WhatsApp invite notification | Later sprint — email only for now |
| Invite for users without a Swasth account yet | Parked — invitee must have an account |
| Doctor access role | Phase 1 later |
| Deep link / install via invite | A10 — separate task |
| Profile photo | Not in Phase 1 |
| Notification preferences per profile | Module D |

---

## Files Touched Summary

| File | Type |
|------|------|
| `backend/models.py` | Modify |
| `backend/schemas.py` | Modify |
| `backend/routes.py` | Modify |
| `backend/routes_health.py` | Modify |
| `backend/routes_profiles.py` | **New** |
| `backend/email_service.py` | Modify |
| `backend/main.py` | Modify |
| `backend/dependencies.py` | Modify |
| `backend/migrate_to_profiles.py` | **New** |
| `lib/models/profile_model.dart` | **New** |
| `lib/models/invite_model.dart` | **New** |
| `lib/services/profile_service.dart` | **New** |
| `lib/services/storage_service.dart` | Modify |
| `lib/screens/select_profile_screen.dart` | **New** |
| `lib/screens/create_profile_screen.dart` | **New** |
| `lib/screens/pending_invites_screen.dart` | **New** |
| `lib/screens/manage_access_screen.dart` | **New** |
| `lib/screens/home_screen.dart` | Modify |
| `lib/screens/dashboard_screen.dart` | Modify |
| `lib/screens/history_screen.dart` | Modify |
| `lib/screens/profile_screen.dart` | Modify |
| `lib/main.dart` | Modify |

**Total: 9 backend files (2 new), 13 Flutter files (6 new) — 22 files, 22 steps**
