// Playwright configuration for Swasth E2E tests.
//
// Targets the dev server by default. Override BASE_URL env var to point
// at a different deployment, or "http://localhost:8080" for a local
// `flutter run -d web-server --web-port 8080` session.
//
// Each test creates its own ephemeral user via the registration form
// (timestamped email pattern `e2e-test-<ts>@swasth.test`) so the suite
// is hermetic — no shared state between runs, no test-account pollution.

import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  testMatch: '**/*.spec.ts',
  // Run files in parallel; tests within a file run sequentially.
  fullyParallel: true,
  // Fail the build on CI if a test.only is left in the source.
  forbidOnly: !!process.env.CI,
  // Retry once on CI to absorb flaky network blips against the real
  // dev server. Locally we want failures loud and immediate.
  retries: process.env.CI ? 1 : 0,
  // Single worker locally so the user can WATCH tests run in --ui mode
  // without windows fighting for focus. CI bumps this to 4.
  workers: process.env.CI ? 4 : 1,
  // HTML report opens automatically on failures.
  reporter: [
    ['html', { open: 'on-failure' }],
    ['list'],
  ],
  // Global timeout per test — generous for the dev server's first cold
  // request after a deploy.
  timeout: 60_000,
  expect: {
    // Same generous timeout for waitFor / expect().toBeVisible() calls.
    timeout: 10_000,
  },
  use: {
    baseURL: process.env.BASE_URL ?? 'https://65.109.226.36:8443',
    // Self-signed cert on the dev server — accept it.
    ignoreHTTPSErrors: true,
    // Retain trace + screenshot + video on failure for debugging.
    // Trace files are time-machine snapshots of the entire test run.
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    // Slow down each step by 50ms when running headed so you can see
    // what's happening. No effect in headless mode.
    launchOptions: {
      slowMo: process.env.HEADLESS === 'false' ? 50 : 0,
    },
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
