# Blueprint: Flutter Build Flavors + Play Store Deployment

## Objective
Two build flavors (`staging` → 8443, `production` → 8444), signed AABs, side-by-side installable, CI builds both on every master merge and auto-uploads staging AAB to Play Console internal track.

## End State
```bash
flutter build appbundle --flavor staging --target lib/main_staging.dart       # → 8443 AAB
flutter build appbundle --flavor production --target lib/main_production.dart # → 8444 AAB
# Both signed, side-by-side installable. CI uploads staging to internal track on push to master.
```

## One-Way Doors (decide before starting)
1. **Package name**: Recommend `com.swasth.app` (prod) + `com.swasth.app.staging` (staging). Once uploaded to Play Store, **cannot** be changed. Confirm with user before Step 1.
2. **Keystore**: Generate once, back up to 1Password + offline. Losing it = cannot update the app ever again (only workaround = Google support + key reset flow, painful).
3. **Play App Signing**: Recommended (Google holds the app signing key; we only manage the upload key). Must enroll at first upload — irreversible.

---

## Steps

### Step 1: Rename applicationId
**Context brief:** `android/app/build.gradle.kts` has `applicationId = "com.example.swasth_app"` (Flutter's generated placeholder). Play Store rejects `com.example.*`. This change must happen BEFORE any Play Store upload because package name is immutable post-upload.

**Files:**
- `android/app/build.gradle.kts` (applicationId + namespace)
- `android/app/src/main/AndroidManifest.xml` (verify no hardcoded FQN references)
- `android/app/src/main/kotlin/com/example/swasth_app/MainActivity.kt` (move dir + update package)
- `lib/main.dart` — no change (uses `applicationName` variable)

**Changes:**
- `applicationId = "com.swasth.app"`
- `namespace = "com.swasth.app"`
- Move MainActivity.kt to `android/app/src/main/kotlin/com/swasth/app/`
- Update `package com.swasth.app` in MainActivity.kt

**Tests:** `flutter clean && flutter build apk --debug` succeeds. Install on emulator — app launches with new package visible via `adb shell pm list packages | grep swasth`.

**Done when:** debug APK installs as `com.swasth.app`, launches, existing flows work (splash → login).

**Blocks:** Step 2

---

### Step 2: Add Android build flavors
**Context brief:** Add two product flavors in `build.gradle.kts` so `--flavor staging` and `--flavor production` produce separate APKs/AABs. Staging gets `applicationIdSuffix ".staging"` so both install side-by-side. Debug signing is fine at this step — Step 5 adds release signing.

**Files:**
- `android/app/build.gradle.kts`

**Changes:**
```kotlin
android {
  flavorDimensions += "environment"
  productFlavors {
    create("staging") {
      dimension = "environment"
      applicationIdSuffix = ".staging"
      versionNameSuffix = "-staging"
      resValue("string", "app_name", "Swasth Staging")
    }
    create("production") {
      dimension = "environment"
      resValue("string", "app_name", "Swasth")
    }
  }
}
```
Also update `AndroidManifest.xml`: `android:label="@string/app_name"` (replaces hardcoded `"swasth_app"`).

**Tests:**
- `flutter build apk --flavor staging --debug` succeeds
- `flutter build apk --flavor production --debug` succeeds
- Install both on emulator simultaneously — two icons appear

**Done when:** Both flavors install side-by-side with different labels (`Swasth Staging`, `Swasth`).

**Blocks:** Step 3, Step 4

---

### Step 3: Dart entry points + flavor-aware config
**Context brief:** Replace `--dart-define=SERVER_HOST=...` pattern with compile-time flavor config. Two entry points delegate to a shared `bootstrap(Flavor)`. `AppConfig.serverHost` reads the compiled-in flavor, dotenv becomes optional (only for dev overrides).

**Files (new):**
- `lib/bootstrap.dart`
- `lib/main_staging.dart`
- `lib/main_production.dart`
- `lib/config/flavor.dart`

**Files (modified):**
- `lib/main.dart` — keep as thin wrapper delegating to staging (so default `flutter run` = staging), OR delete and update tests that import it
- `lib/config/app_config.dart` — add `Flavor.current.serverHost` lookup, dotenv becomes override-only

**Changes:**
```dart
// lib/config/flavor.dart
enum Flavor {
  staging(serverHost: 'https://65.109.226.36:8443', label: 'Swasth Staging'),
  production(serverHost: 'https://65.109.226.36:8444', label: 'Swasth');
  const Flavor({required this.serverHost, required this.label});
  final String serverHost;
  final String label;
  static late final Flavor current;
}

// lib/main_production.dart
import 'bootstrap.dart';
import 'config/flavor.dart';
void main() => bootstrap(Flavor.production);
```

**Tests:**
- `flutter build apk --flavor staging --target lib/main_staging.dart` → runtime `AppConfig.serverHost` returns `...:8443`
- Same for production → `...:8444`
- Existing unit tests still pass (`flutter test`)

**Done when:** Launching each flavor on emulator and hitting login successfully reaches the expected backend (check network panel or server logs).

**Blocks:** Step 6

---

### Step 4: Per-flavor resources (icon + strings)
**Context brief:** Testers need to visually distinguish staging from production at a glance. Use Android source sets — `android/app/src/staging/res/` overrides `main/res/` when the staging flavor builds. Add a colored badge to the staging icon.

**Files (new):**
- `android/app/src/staging/res/mipmap-*/ic_launcher.png` (5 densities, staging-badged)
- `android/app/src/production/res/mipmap-*/ic_launcher.png` (5 densities — or rely on `main/`)
- `android/app/src/staging/res/values/strings.xml` (`app_name = "Swasth Staging"`) — **only if `resValue` in Step 2 is removed**

**Tool:** `flutter_launcher_icons` package with per-flavor config, OR manually generate via Android Studio Image Asset Studio.

**Tests:** Install both flavors — icons visibly different (e.g., staging has orange corner ribbon).

**Done when:** User can tell which build is which on home screen without opening.

**Blocks:** (parallel with Step 5)

---

### Step 5: Release signing with upload keystore
**Context brief:** Generate an upload keystore (JKS), encode it base64, store in GitHub secrets. `build.gradle.kts` reads `key.properties` (local) OR env vars (CI). Play App Signing keeps the real signing key on Google's side — we only manage the upload key.

**Files (new):**
- `android/key.properties.example` (committed, documents required fields)
- `android/keystore/` — **gitignored**

**Files (modified):**
- `android/app/build.gradle.kts` — add `signingConfigs.release` that loads from `key.properties`, apply to `buildTypes.release`
- `.gitignore` — add `android/key.properties`, `android/keystore/*.jks`

**One-time commands (user runs locally):**
```bash
keytool -genkey -v -keystore ~/swasth-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias swasth-upload
# Back up ~/swasth-upload.jks to 1Password IMMEDIATELY
base64 -i ~/swasth-upload.jks -o /tmp/keystore.b64
gh secret set ANDROID_KEYSTORE_BASE64 < /tmp/keystore.b64
gh secret set ANDROID_KEYSTORE_PASSWORD --body "..."
gh secret set ANDROID_KEY_ALIAS --body "swasth-upload"
gh secret set ANDROID_KEY_PASSWORD --body "..."
```

**Tests:**
- Local: `flutter build appbundle --flavor production --release --target lib/main_production.dart` produces a signed AAB
- `jarsigner -verify build/app/outputs/bundle/productionRelease/*.aab` passes

**Done when:** Signed AAB ready to upload to Play Console manually (first upload enrolls in Play App Signing).

**Blocks:** Step 6, Step 7

---

### Step 6: CI matrix build for both flavors
**Context brief:** Update `.github/workflows/dev.yml` — add `build-android` job with a 2x matrix (staging, production). Decode keystore from secret, run `flutter build appbundle --flavor $FLAVOR`, upload AAB + APK as artifacts. Replace the existing `--dart-define=SERVER_HOST=...:8443` in web build (no longer needed since flavors encode this, but web is a separate target — keep web on staging for now, documented in Step 9).

**Files:**
- `.github/workflows/dev.yml`

**Changes:**
```yaml
build-android:
  strategy:
    matrix:
      flavor: [staging, production]
  steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
    - run: echo "SERVER_HOST=override-unused" > .env  # asset bundling workaround
    - run: echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/keystore/upload.jks
      env: { ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }} }
    - run: |
        cat > android/key.properties <<EOF
        storeFile=keystore/upload.jks
        storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
        keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
        keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
        EOF
    - run: flutter build appbundle --flavor ${{ matrix.flavor }} --target lib/main_${{ matrix.flavor }}.dart --release
    - uses: actions/upload-artifact@v4
      with:
        name: swasth-${{ matrix.flavor }}-aab
        path: build/app/outputs/bundle/${{ matrix.flavor }}Release/*.aab
```

**Tests:** Merge a trivial PR to master, watch CI — both AAB artifacts downloadable from Actions run.

**Done when:** Green CI run with both `swasth-staging-aab` and `swasth-production-aab` artifacts.

**Blocks:** Step 7

---

### Step 7: Auto-upload staging AAB to Play Console internal track
**Context brief:** After CI builds the staging AAB, auto-upload to Play Store internal testing track. Production AAB stays as artifact only (manual promotion for now — safer). Requires a Google Play Console service account with API access and `releaser` role.

**One-time setup (user does in Play Console):**
1. Create service account in Google Cloud → download JSON
2. Play Console → API access → link project → grant `Release manager` role to service account
3. First AAB must be uploaded **manually** to enroll in Play App Signing (one-time, can't be automated)

**Files:**
- `.github/workflows/dev.yml` — append upload step to `build-android` job, only runs for `flavor == staging`

**Changes:**
```yaml
    - if: matrix.flavor == 'staging'
      uses: r0adkll/upload-google-play@v1
      with:
        serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
        packageName: com.swasth.app.staging
        releaseFiles: build/app/outputs/bundle/stagingRelease/*.aab
        track: internal
        status: completed
```

**Tests:** Merge to master → CI → Play Console shows new internal track release within 5 min.

**Done when:** Internal testers receive push update of staging build automatically on every master merge.

**Blocks:** —

---

### Step 8: Port reference cleanup
**Context brief:** Repository has 8+ references to `:8443`. After flavors land, the semantics change: 8443 = staging (correct in e2e tests, WORKING-CONTEXT), 8444 = prod (missing everywhere). Clean up the ambiguous references and add prod mentions where appropriate.

**Files to update:**
- `CLAUDE.md:401` — deploy command for prod should use 8444; add a staging example with 8443
- `WORKING-CONTEXT.md:48` — split Frontend into `staging 8443 / prod 8444`
- `TASK_TRACKER.md:12` — cert note applies to both, mention both ports
- `lib/main.dart:27` — update comment: "staging at 8443 and prod at 8444 both use..."
- `tests/e2e/README.md` (5 lines) — no change (tests target staging = correct)
- `docs/VIDEO_SCRIPTS_AND_TEST_DATA.md` (2 lines) — update URL to whichever env the video targets (ask)
- `.github/workflows/dev.yml:116` — web deploy stays on staging (8443) until web has its own flavor story (out of scope)

**Tests:** `grep -n "8443\|8444" <file>` for each — every mention clearly labeled staging or production.

**Done when:** No ambiguous port references remain.

**Blocks:** —

---

### Step 9: Release runbook + CLAUDE.md updates
**Context brief:** Document the new release process so future sessions don't reinvent. Add a `docs/RELEASE_RUNBOOK.md` covering: local signed build, version bumping, Play Console track promotion (internal → closed → production), rollback.

**Files (new):**
- `docs/RELEASE_RUNBOOK.md`

**Files (modified):**
- `CLAUDE.md` — update build commands section to use flavors
- `WORKING-CONTEXT.md` — add "Android release tracks" section

**Content outline for runbook:**
- How to build locally (both flavors, debug + release)
- Version bumping rules (`versionCode` strictly monotonic — use git commit count or CI run number)
- Promoting a build: internal → closed (pilot users) → production (public)
- Rollback: halt rollout percentage in Play Console → revert commit → next CI builds new AAB
- Keystore recovery (link to 1Password note)

**Tests:** Human review.

**Done when:** A new teammate can ship a release from scratch using only the runbook.

**Blocks:** —

---

## Dependency Graph
```
Step 1 (applicationId)
  └─→ Step 2 (flavors)
        ├─→ Step 3 (entry points) ──┐
        └─→ Step 4 (resources)       ├─→ Step 6 (CI matrix) ─→ Step 7 (Play upload)
              └─→ Step 5 (signing) ──┘
                    └─→ Step 8 (port cleanup)  ← can start any time after Step 3
                          └─→ Step 9 (runbook) ← last
```

## Parallel Opportunities
- Steps 3 and 4 after Step 2
- Step 8 can run in parallel with Steps 4–7 (pure doc/comment edits)

## Risks

| Risk | Mitigation |
|------|-----------|
| Package name locked after first Play Store upload | Confirm `com.swasth.app` with user BEFORE Step 1 |
| Upload keystore lost = app update chain dead | Back up to 1Password immediately after generation. Store recovery instructions in runbook. |
| Play App Signing enrollment is irreversible | Enroll deliberately — first upload triggers it |
| `versionCode` collision between flavors | Use shared monotonic source (git commit count) — Play Store accepts same versionCode across different package names |
| Self-signed cert on 8444 prod | Verify before first prod release — either Let's Encrypt + domain, or extend `_PilotHttpOverrides` to allow both ports |
| Existing tests reference `main.dart` directly | Update test imports OR keep `lib/main.dart` as thin shim → staging |
| Web build still uses `--dart-define=...:8443` | Documented as out-of-scope in Step 6; web flavor story is separate blueprint |
| AndroidManifest label hardcoded → widget/integration tests matching "swasth_app" break | Grep tests for `swasth_app` label matches before Step 2 |
| `gh secret set` for keystore base64 can truncate on large values | Verified in project memory (`feedback_github_secrets.md`) that CLI is correct path; pipe from file, not arg |

## Estimated Steps: 9 | Critical Path: 1 → 2 → 3 → 5 → 6 → 7 (≈6 sessions)

## Open Questions for User
1. Confirm package name: `com.swasth.app` (prod) / `com.swasth.app.staging` (staging)?
2. Do you already have a Play Console account and an app entry? If yes, the first upload triggers Play App Signing — I need to know the current state.
3. Is there an existing upload keystore I should know about, or do we generate fresh in Step 5?
4. Staging flavor is auto-deployed to internal track. Production flavor — auto to production track, or keep manual promotion (my recommendation)?
5. `docs/VIDEO_SCRIPTS_AND_TEST_DATA.md` URLs — those point to a demo, should they stay on staging (8443) or move to prod (8444)?
