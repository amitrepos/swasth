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

From this directory:

```bash
npm install                # one-time
npx playwright install chromium   # one-time
npm test                   # run smoke test headless (~5s)
npm run test:ui            # open Playwright UI panel with time-travel
npm run test:headed        # run with visible browser window
npm run report             # open HTML report from last run
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
