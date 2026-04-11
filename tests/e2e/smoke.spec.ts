// Smoke test — fastest possible signal that the dev server is up,
// the Flutter web bundle loads, and the login screen renders. If
// THIS fails, nothing else will work and you should investigate the
// deploy before running the rest of the suite.

import { test, expect } from '@playwright/test';
import { bootFlutter } from './helpers';

test.describe('Smoke', () => {
  test('dev server responds and login screen renders', async ({ page }) => {
    // bootFlutter handles the goto + accessibility-enable dance.
    await bootFlutter(page);

    // The login screen has email + password fields and a sign-in button.
    // We're not picky about exact text — any of these matches counts.
    await expect(
      page.getByLabel(/email/i).first()
    ).toBeVisible({ timeout: 15_000 });
    await expect(
      page.getByLabel(/^password/i).first()
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: /sign in|log in|login/i }).first()
    ).toBeVisible();

    // Capture a screenshot of the login screen as run evidence —
    // useful for visually confirming the deploy looks right after a CI
    // run, even when the test passes.
    await page.screenshot({
      path: 'screenshots/smoke-login.png',
      fullPage: true,
    });
  });
});
