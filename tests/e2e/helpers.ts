// Shared helpers for Swasth E2E tests.
//
// IMPORTANT — WHAT THIS FILE INTENTIONALLY DOES NOT DO:
// We previously had `createTestUser`, `loginAs`, `fillField`, and a
// `clickFlutterButton` helper here. They were all deleted because
// Flutter web's CanvasKit renderer (the default) is fundamentally
// incompatible with Playwright's interaction model:
//
//   - Flutter draws everything to a `<canvas>` element.
//   - The `<flt-semantics>` nodes Playwright sees in the accessibility
//     tree are an a11y shim, NOT real interactive elements. They're
//     positioned off-screen and do not receive pointer events.
//   - Real input goes through Flutter's own gesture system, which
//     hit-tests against canvas pixels — invisible to Playwright.
//   - `click()`, `dispatchEvent('click')`, `mouse.click(x,y)` at the
//     bounding-box center, `focus() + Enter`, `focus() + Space` —
//     ALL succeed silently without firing the underlying handler.
//
// To run end-to-end user flows against Flutter web you need either:
//   1. Rebuild Flutter web with `--web-renderer html` (DOM elements
//      instead of canvas) and re-add the helpers, OR
//   2. Use `flutter drive` against Chrome with a driver script
//      (Flutter's official integration testing path), OR
//   3. Stick to widget-tree tests in `test/flows/*.dart` which run
//      via `flutter test` and already cover everything.
//
// What this file DOES provide is `bootFlutter()`, which is enough to
// load the Flutter web bundle and confirm the deploy is alive — see
// `smoke.spec.ts`. That's the deploy canary: catches "the dev server
// is broken" without trying to interact with the canvas.

import { Page } from '@playwright/test';

/**
 * Loads the Flutter web app and clicks the "Enable accessibility"
 * placeholder Flutter injects on first paint, so the semantic DOM
 * tree is published. Without this, NO HTML inputs are visible to
 * Playwright at all.
 *
 * The placeholder is rendered off-viewport (it's intended for screen
 * readers), so we use `dispatchEvent('click')` rather than `click()`
 * to bypass Playwright's actionability checks.
 */
export async function bootFlutter(page: Page): Promise<void> {
  await page.goto('/');
  await page.waitForLoadState('networkidle');

  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) {
    await placeholder.first().dispatchEvent('click');
    // Flutter starts publishing the semantic tree on the next frame.
    await page.waitForTimeout(1000);
  }
}
