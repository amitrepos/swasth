# Play Store Listing — Swasth (health.swasth.app)

Copy-paste content for the Play Console "Main store listing" form. All fields below comply with Play Store policy as of April 2026.

---

## App name (30 char limit)
```
Swasth — Health Tracker
```

## Short description (80 char limit)
```
Track blood pressure, glucose, and meals. Personalised health insights for India.
```

## Full description (4000 char limit)
```
Swasth is a personal health companion built for patients in India managing chronic conditions like diabetes and hypertension.

WHAT YOU CAN DO
• Log blood pressure, blood glucose, and pulse with a tap — or auto-capture by photographing your meter.
• Track meals and see how food affects your readings.
• Get a clear health score and trend charts over 7, 30, and 90 days.
• Receive personalised insights in English or Hindi.
• Share readings with family members you trust.
• Let your doctor see your history during consultations.

BUILT FOR INDIA
• Fully bilingual: English and हिन्दी.
• Works on everyday Android phones — no fancy wearables needed.
• Photograph your existing glucometer or BP monitor — no new device to buy.
• Designed with doctors in Bihar, built for elders and their families.

PRIVACY & SECURITY
• Your health data is encrypted (AES-256) and stored on servers with industry-standard security.
• Nothing is sold. No ads. No advertisers.
• Delete all your data from the app whenever you want.
• Compliant with DPDP Act 2023 and SPDI Rules 2011.

WHO IT'S FOR
• Adults (18+) managing diabetes, hypertension, or other chronic conditions.
• Family members caring for a parent at a distance.
• Doctors who want a clearer picture of patient vitals between visits.

CURRENTLY IN PILOT
Swasth is in an invite-only pilot with doctors in Bihar. Features are updated weekly based on real feedback.

Questions, feedback, data requests? Email swasth.admin@gmail.com.
```

## App category
```
Medical
```

## Tags (choose up to 5)
```
Health & Fitness, Medical, Diabetes, Blood Pressure, Personal Health
```

## Contact details
- **Email:** swasth.admin@gmail.com (required — must be reachable; swap to support@swasth.health after domain setup)
- **Website:** https://swasth.health (optional but recommended)
- **Phone:** (leave blank unless you have a support line)

## Privacy Policy URL
```
https://swasth.health/privacy
```
(Deploy `docs/legal/privacy.html` to this URL before submitting — see `docs/PLAY_STORE_RUNBOOK.md` for the scp command.)

---

## Graphic Assets (required)

Create and upload:

| Asset | Dimensions | Format | Notes |
|-------|-----------|--------|-------|
| App icon | 512×512 px | 32-bit PNG | Already exists in `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` — upscale to 512. |
| Feature graphic | 1024×500 px | JPG/PNG | Required. Shows on top of your listing. Use the Swasth logo on a light background. |
| Phone screenshots | 2–8 images, min 1080px | PNG/JPG | **Minimum 2 required.** See list below. |

### Screenshot shot-list (record with the production AAB installed)

1. Home screen showing health score ring + recent readings
2. Adding a BP reading (input modal)
3. Trend chart — 30-day view
4. AI insight card with personalised recommendation
5. Meal log with photo scan
6. Doctor link / sharing screen
7. (Optional) Family-member dashboard view

**Tip:** Use a Pixel 6 / 7 emulator at 1080×2400. Record after logging in as a demo user so the screens have realistic data.

---

## Content rating (fill in via Play Console questionnaire)

Expected rating: **Everyone / Rated for 3+**. Key answers to the questionnaire:
- No violence, sexual content, profanity, drugs, gambling: **No** to all.
- Collects personal data: **Yes** (email, name, health info).
- Shares personal data with third parties: **Yes** (Gemini, DeepSeek for AI; explained in privacy policy).
- Intended for children: **No** (18+ only).

---

## Data Safety form (Play Console → App content → Data Safety)

### Does your app collect or share any required user data types?
**Yes.**

### Is all user data collected by your app encrypted in transit?
**Yes** — TLS/HTTPS everywhere.

### Do you provide a way for users to request that their data is deleted?
**Yes** — in-app "Delete account" button, removes all data permanently.

### Data types collected

Fill in the table in Play Console as follows:

| Data type | Collected | Shared | Required/Optional | Purpose |
|-----------|-----------|--------|-------------------|---------|
| **Name** | Yes | No | Required | Account management, Personalization |
| **Email address** | Yes | No | Required | Account management, Communications |
| **Phone number** | Yes | No | Optional | Account management (2FA if enabled) |
| **User IDs** | Yes | No | Required | Account management |
| **Health info** | Yes | Yes — to AI providers with user consent | Required | App functionality, Personalization |
| **Fitness info** | No | — | — | — |
| **Photos** | Yes | No | Optional | App functionality (meter/meal photo scan) |
| **App activity — other actions** | Yes | No | Required | Analytics, App functionality |
| **Crash logs** | Yes | No | Required | App functionality |
| **Diagnostics** | Yes | No | Required | App functionality |

### Security practices
- Data is encrypted in transit: **Yes**
- Users can request data deletion: **Yes**
- Data is encrypted at rest: **Yes** (AES-256)
- Follows Families Policy: **No** (not for children)
- Independent security review: **No** (be honest — you can add later)

---

## Release notes (for first Internal Testing release)
```
First internal build. Core features:
- BP, glucose, pulse logging (manual + photo scan)
- Health score and trend charts
- AI-powered insights (Gemini/DeepSeek)
- Family sharing + doctor view
- English + हिन्दी

Feedback: swasth.admin@gmail.com
```
