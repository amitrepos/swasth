# Play Store Release Runbook — First Submission

Step-by-step guide to get Swasth live on the Play Store Internal Testing track. Steps marked **[You]** require human action (browser, 2FA, credit card); steps marked **[Done]** have already been completed or automated.

**Goal**: end state where you can message a doctor a Play Store opt-in link and they install Swasth in 3 taps.

---

## Prerequisites (already done)

- [Done] `applicationId` renamed to `health.swasth.app` (PR #128)
- [Done] Build flavors `staging` / `production` set up (PR #128)
- [Done] Upload keystore generated at `~/.swasth/swasth-upload.jks`
- [Done] Keystore password written to `~/.swasth/.keystore-password.txt` (back up to 1Password now, then `rm` this file)
- [Done] Release signing wired into `android/app/build.gradle.kts`
- [Done] `android/key.properties` created locally (gitignored)
- [Done] Signed production AAB built at `build/app/outputs/bundle/productionRelease/app-production-release.aab`
- [Done] Signed production APK built at `build/app/outputs/flutter-apk/app-production-release.apk`
- [Done] Privacy policy HTML at `docs/legal/privacy.html`
- [Done] Play Store listing content drafted in `docs/PLAY_STORE_LISTING.md`

---

## Step A — Back up the keystore (5 min, **do this first**)

**CRITICAL**: if you lose the keystore, you cannot update the app ever again.

1. Open 1Password → New Item → **Secure Note**, name it "Swasth Android Upload Keystore"
2. Attach the file `~/.swasth/swasth-upload.jks`
3. Paste into the note body (copy from `~/.swasth/.keystore-password.txt`):
   ```
   storeFile: ~/.swasth/swasth-upload.jks
   keyAlias: swasth-upload
   storePassword: <paste from ~/.swasth/.keystore-password.txt>
   keyPassword: <same as storePassword>
   dname: CN=Swasth Health, OU=Engineering, O=Swasth, L=Patna, ST=Bihar, C=IN
   SHA-256 fingerprint: (run `keytool -list -keystore ~/.swasth/swasth-upload.jks -storepass <pass>` to get it)
   Generated: 2026-04-17
   ```
4. Save. Verify it's synced to another device (iPad / other Mac).
5. **After confirming the 1Password backup works**, delete the plaintext password file:
   ```bash
   rm ~/.swasth/.keystore-password.txt
   ```

---

## Step B — Create `swasth.admin@gmail.com` [You, 10 min]

1. Go to https://accounts.google.com/signup in an incognito window.
2. Register `swasth.admin@gmail.com` (use your phone number for verification).
3. After signup, immediately:
   - Go to https://myaccount.google.com/security → **2-Step Verification** → enable using **Google Authenticator app** (not SMS — SMS can be SIM-swapped).
   - Add your 1Password as a TOTP backup (scan the QR code in both Authenticator and 1Password).
   - Set recovery email to your personal Gmail (`amitkumarmishra@gmail.com`).
   - Save 8 backup codes → paste into the 1Password "Swasth Google Account" item.
4. **Do not use this account for anything personal.** Only Swasth infrastructure (Play Console, Google Cloud, Firebase, registrar logins, etc.).

---

## Step C — Sign up for Play Console [You, 30 min]

1. Log in as `swasth.admin@gmail.com`.
2. Go to https://play.google.com/console/signup.
3. Choose **"Myself"** (Personal developer account).
4. Pay the **$25 one-time fee** (credit card).
5. Verify identity:
   - Upload passport or Aadhaar
   - Google will email back in 1–3 days with identity verified
6. While waiting for identity verification, you CAN still:
   - Create the app entry
   - Upload the AAB
   - Draft the listing

---

## Step D — Create the app [You, 5 min]

In Play Console:
1. **All apps → Create app**
2. Fill in:
   - App name: `Swasth — Health Tracker`
   - Default language: English (India)
   - App or game: **App**
   - Free or paid: **Free**
   - Declarations: tick both required checkboxes
3. **Create**. You're now in the app dashboard.

---

## Step E — Deploy privacy policy [You, 5 min]

Play Store requires a publicly-accessible privacy policy URL before you can submit. Deploy the HTML we generated:

```bash
# From repo root on your local machine
scp -i ~/.ssh/new-server-key docs/legal/privacy.html \
    root@65.109.226.36:/var/www/swasth/web/privacy.html

# Verify
curl -kI https://65.109.226.36:8443/privacy.html  # should return 200
```

Use URL: `https://65.109.226.36:8443/privacy.html` for the Play Console field until `swasth.health` DNS is configured. Update to `https://swasth.health/privacy` later — Play Console lets you edit this field without re-review.

---

## Step F — Fill store listing [You, 30 min]

In Play Console → **Grow users → Main store listing**:
1. Copy-paste all fields from `docs/PLAY_STORE_LISTING.md`.
2. Upload graphic assets (see "Graphic Assets" section in that file).
   - App icon: extract 512×512 from existing mipmap, or regenerate at higher res from the source SVG/PNG.
   - Feature graphic 1024×500: create a simple banner (Canva, Figma) with Swasth logo + tagline.
   - Screenshots: install the release APK on an emulator (`adb install build/app/outputs/flutter-apk/app-production-release.apk`), log in as a demo user, take screenshots of the 5 screens from the shot-list.
3. **Save**.

---

## Step G — Data Safety + Content Rating + other app content [You, 30 min]

In Play Console → **Policy → App content**:

1. **Privacy Policy**: paste the URL from Step E.
2. **App access**: "All functionality is available without special access" (unless you want to describe the Bihar invite-only gate).
3. **Ads**: "No, my app does not contain ads".
4. **Content rating**: fill the questionnaire using answers in `docs/PLAY_STORE_LISTING.md` → Content rating section. Expected rating: Everyone.
5. **Target audience**: 18+ only.
6. **Data safety**: copy answers from `docs/PLAY_STORE_LISTING.md` → Data Safety section.
7. **News app**: No.
8. **COVID-19 contact tracing**: No.
9. **Government apps**: No.
10. **Financial features**: No.
11. **Health apps declaration**: Yes (this is a health app). You may be asked for additional health app declarations — answer truthfully about what vitals you track.

---

## Step H — Upload the AAB [You, 10 min]

In Play Console → **Release → Testing → Internal testing → Create new release**:

1. If prompted, **Enroll in Play App Signing** — Google holds the real signing key, you keep the upload key. **This is irreversible** but is the right answer.
2. Click **Upload** and select:
   ```
   build/app/outputs/bundle/productionRelease/app-production-release.aab
   ```
3. Release name: `1.0.0 (internal)`
4. Release notes: paste from `docs/PLAY_STORE_LISTING.md` → Release notes section.
5. **Review release** → **Start rollout to Internal testing**.

---

## Step I — Add internal testers [You, 10 min]

In Play Console → **Release → Testing → Internal testing → Testers tab**:

1. **Create email list** → name it "Swasth Doctors Pilot"
2. Paste doctor email addresses (one per line)
3. **Save changes**
4. Copy the **opt-in URL** from the "How testers join your test" section — looks like:
   `https://play.google.com/apps/internaltest/4700123456789012345`
5. Send doctors this URL via WhatsApp (template in `docs/DOCTOR_INVITE_TEMPLATE.md`).

---

## Step J — Smoke test the install yourself [You, 5 min]

Before messaging doctors:
1. On your own Android phone, log in to the Play Store app with `swasth.admin@gmail.com`
2. Open the opt-in URL from Step I
3. Tap **Become a tester** → **Download it on Google Play**
4. Confirm:
   - No "unknown sources" warning
   - Install works smoothly
   - App launches with label "Swasth" and hits the production backend (:8444)
5. Log in with a test account, verify a reading saves correctly.

If smoke test passes → message doctors.

---

## Post-launch: pushing updates

For a version bump later:
```bash
# Edit pubspec.yaml: bump version (e.g., 1.0.0+1 → 1.0.1+2 — the +N is versionCode, must increase monotonically)
flutter build appbundle --flavor production --target lib/main_production.dart --release
```
Then in Play Console → Internal testing → Create new release → upload the new AAB. Testers get the update automatically within a few hours.

---

## If something breaks

- **Lost keystore**: retrieve from 1Password. If truly lost (1Password gone too), contact Google support; with Play App Signing, they can reset the upload key.
- **"Upload failed: package already exists"**: the versionCode didn't increment. Bump `+N` in `pubspec.yaml`.
- **Play Console identity verification stuck**: email googleplay-developer-support@google.com from the Play Console account. Response SLA is ~24–48h.
- **Doctors not receiving opt-in emails**: Internal Testing emails come from `googleplay-developer-noreply@google.com`. Ask them to check spam. Alternatively, share the opt-in URL directly via WhatsApp (it's a public URL, anyone with it can opt in).
