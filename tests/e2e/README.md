# Swasth E2E — Playwright deploy canary

This directory contains a single Playwright smoke test that runs against the live dev server. Its job is to be a **deploy canary**: catches "the dev server is broken / the Flutter bundle stopped loading" without trying to interact with the canvas-rendered UI.

## What's here

```
tests/e2e/
├── smoke.spec.ts          ← the only test (passes in ~3.5s)
├── helpers.ts             ← bootFlutter() — handles Flutter web's accessibility quirk
├── playwright.config.ts   ← targets https://65.109.226.36:8443, ignoreHTTPSErrors
├── package.json           ← npm scripts
└── README.md              ← you are here
```

## How to run

### First-time setup (do this ONCE on a new machine)

```bash
cd tests/e2e                       # all commands run from here
npm install                        # downloads @playwright/test (~5s)
npx playwright install chromium    # downloads Chrome browser binary (~1 min, 100MB)
```

That's the entire setup. Both commands are idempotent — re-running them is safe.

### Every time you want to run the smoke test

You must be in `tests/e2e/`. All four commands below do the same test, just present it differently:

```bash
cd tests/e2e

# Option A: headless, fastest (~5s). Just terminal output.
npm test

# Option B: open Playwright's UI panel — sidebar of tests, click "▶" to run,
# scrub through every action with a time-travel timeline. RECOMMENDED for the
# first run so you can see what's happening.
npm run test:ui

# Option C: open a real visible Chrome window and watch it bootstrap the Flutter
# bundle. Slower but visceral — useful when troubleshooting.
npm run test:headed

# Option D: open the HTML report from the LAST run (screenshots, video, trace).
# Run this AFTER any of A/B/C to see what happened.
npm run report
```

### What "passing" looks like

When you run `npm test`, you should see:

```
Running 1 test using 1 worker

  ✓  1 [chromium] › smoke.spec.ts:10:7 › Smoke › dev server responds and login screen renders (3.5s)

  1 passed (5.0s)
```

The first time you run it, a screenshot of the live dev server's login screen lands at `tests/e2e/screenshots/smoke-login.png`. Open it to confirm visually.

### What "failing" looks like

If the smoke test fails, the HTML report opens automatically in your browser. You'll see:

- A red ✗ next to the test name
- The exact assertion that failed
- A screenshot of the page at the moment of failure (so you can see the broken state)
- A 10-second video of the test run
- A trace file you can scrub through frame-by-frame

If the report doesn't auto-open (CI runs, headless terminals), open it manually:

```bash
npm run report
```

### Run it from VS Code

Open the integrated terminal (`Ctrl+\`` or `Cmd+\``), then:

```bash
cd tests/e2e && npm run test:ui
```

The Playwright UI panel will open in a separate window. Click the "▶" next to `smoke.spec.ts` to run it. You'll see the live browser preview on the right while it executes.

You can also install the VS Code extension "Playwright Test for VS Code" (Microsoft) which adds inline ▶ buttons next to every test in the source file.

### Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `npm: command not found` | Node.js not installed | `brew install node` |
| `playwright: command not found` after `npm install` | You're not in `tests/e2e/` | `cd tests/e2e` first |
| `Browser executable doesn't exist` | Skipped `npx playwright install chromium` | Run that command |
| `net::ERR_CERT_AUTHORITY_INVALID` | The dev server has a self-signed cert; config already handles this | If you still see it, check `playwright.config.ts` has `ignoreHTTPSErrors: true` |
| Test fails with "expect locator visible" | The dev server is actually broken — this is the canary doing its job | Check `https://65.109.226.36:8443` in your real browser; if it's down or shows an error, fix the deploy |
| HTML report doesn't open automatically | Common in headless terminals | Run `npm run report` manually |

### Run against a different server

The default target is `https://65.109.226.36:8443`. To point at production, localhost, or a staging URL, set `BASE_URL`:

```bash
# Against localhost (e.g. flutter run -d web-server --web-port 8080)
BASE_URL=http://localhost:8080 npm test

# Against production (only if/when prod has a public URL)
BASE_URL=https://swasth.example.com npm test
```

## What the smoke test checks

1. The dev server at `https://65.109.226.36:8443` responds.
2. Chromium can load the Flutter web bundle (no network errors, no missing assets).
3. The login screen renders with email + password fields and a sign-in button visible in the accessibility tree.
4. A full-page screenshot is saved to `screenshots/smoke-login.png` as visual evidence.

If this test fails, the deploy is broken in some way that NO unit test can catch:
- nginx misconfigured
- Flutter bundle hash mismatch
- HTTPS cert expired
- the new build has a JS error preventing bootstrap

## Why there are no other tests here

We tried to add `auth.spec.ts`, `dashboard.spec.ts`, and `history.spec.ts` to drive end-to-end user flows. **None of them work**, and they were deleted. The reason is a fundamental Flutter web limitation:

### The CanvasKit problem

Flutter's default web renderer is **CanvasKit**, which draws the entire UI to a `<canvas>` element. The `<flt-semantics>` nodes Playwright sees in the accessibility tree are an accessibility shim only — they're positioned off-screen (often at coordinates like `-10000, -10000`) and **do not receive pointer events**. Real user input goes through Flutter's own gesture system, which hit-tests against canvas pixels — invisible to Playwright.

What this means in practice:

| Approach | Result |
|---|---|
| `locator.click()` | Refuses — element off-viewport |
| `locator.click({ force: true })` | Returns success, but Flutter ignores it |
| `locator.dispatchEvent('click')` | Works ONLY for `flt-semantics-placeholder` (the bootstrap button has its own listener); fails silently on every other button |
| `page.mouse.click(x, y)` at bounding-box center | Coords are off-screen — hits nothing |
| `locator.focus() + keyboard.press('Enter')` | No-op |
| `locator.focus() + keyboard.press('Space')` | No-op |
| `locator.fill('value')` for text input | Works for SOME fields, silently drops the value for others (no consistent pattern) |
| `locator.pressSequentially('value')` | Works for text input but the FIRST keystroke is sometimes dropped due to focus race |

We managed to get partial flows working (registration form filled, navigation through the multi-step register → consent flow), but the consent screen's "I Accept" button could not be activated by **any** of the six approaches above. This is the dead end that ended the experiment.

## How to expand this if you ever want full E2E browser tests

There are three paths, in increasing order of effort:

### Path 1: Rebuild Flutter web with the HTML renderer (~30 min)

```bash
flutter build web --web-renderer html --release \
  --dart-define=SERVER_HOST=https://65.109.226.36:8443
scp -i ~/.ssh/new-server-key -r build/web/* root@65.109.226.36:/var/www/swasth/web/
```

The HTML renderer outputs real `<div>`, `<input>`, `<button>` elements instead of canvas. Playwright's standard interaction methods work perfectly. Trade-off: slightly slower scroll/animation, slightly different fonts (especially Hindi).

You could keep CanvasKit for production and ship an HTML build only to a `swasth-test.example.com` URL that the E2E tests target. Then re-add the `auth.spec.ts` / `dashboard.spec.ts` / `history.spec.ts` files (their selector strategy is already correct — they only fail because of the canvas hit-testing).

### Path 2: `flutter drive` against Chrome with a driver script

Flutter's official integration testing path for web. Requires writing a driver script at `test_driver/integration_test.dart` and running with:

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_flows_test.dart \
  -d chrome
```

This bypasses the canvas-vs-DOM problem entirely because the test code runs INSIDE the Flutter VM and talks directly to the widget tree. You don't get an HTML report with screenshots — you get the same `flutter test` output you already use, but driving a real Chrome instance. The existing `integration_test/flows/*.dart` files are already structured for this.

### Path 3: Vercel Agent Browser (AI-driven)

Newer approach: write English instructions and an LLM controls the browser. Adapts to small UI changes automatically. Costs API tokens per run (~$0.05–$0.20 per test). Probably the right choice if you want the "controls the browser like a human" experience that motivated this experiment, since the AI can work around Flutter's canvas quirks the same way a human does.

## What you have today (the realistic stack)

- **`test/flows/*.dart`** — 97 widget integration tests run via `flutter test test/flows/`. Pass in ~15s, run in CI on every PR, cover login/registration/dashboard/history/meals/caregiver/doctor including everything we shipped today (PR #115 + #116). This is your **regression suite**.
- **`tests/e2e/smoke.spec.ts`** — this directory. Live deploy canary against the real dev server. This is your **deploy alive check**.
- **Manual testing** — for the "did the new feature actually feel right?" check that no automation will ever fully replace.

For a comprehensive pre-launch test, run `flutter test test/flows/` to confirm green, hard-refresh the dev server in your browser, and walk through the critical user paths manually for 15-20 minutes.
