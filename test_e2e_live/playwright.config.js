const { defineConfig, devices } = require('@playwright/test');

const BASE_URL = process.env.TARGET || 'https://app.swasth.health';

module.exports = defineConfig({
  testDir: './tests',
  timeout: 60000,
  expect: { timeout: 15000 },
  fullyParallel: false, // Flutter web needs sequential — shares auth state
  retries: process.env.CI ? 1 : 0,
  reporter: [['html', { open: 'never' }], ['line']],
  outputDir: './test-results',

  use: {
    baseURL: BASE_URL,
    ignoreHTTPSErrors: true,
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
    viewport: { width: 1280, height: 900 },
    slowMo: parseInt(process.env.SLOW_MS || '200'),
  },

  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        headless: process.env.HEADLESS !== 'false',
        slowMo: parseInt(process.env.SLOW_MS || '200'),
        video: process.env.HEADLESS === 'false' ? 'on' : 'retain-on-failure',
      },
    },
    {
      name: 'mobile',
      use: {
        ...devices['Pixel 5'],
        headless: process.env.HEADLESS !== 'false',
      },
    },
  ],
});
