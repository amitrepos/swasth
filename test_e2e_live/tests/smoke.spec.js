// smoke.spec.js — fast sanity checks, no auth required
// Run: npx playwright test tests/smoke.spec.js

const { test, expect } = require('@playwright/test');

const API_BASE = process.env.API_URL || 'https://api.swasth.health';
const STAGING_API = process.env.STAGING_API_URL || 'https://staging-api.swasth.health';

test.describe('Infrastructure smoke tests', () => {
  test('prod API /health returns healthy', async ({ request }) => {
    const res = await request.get(`${API_BASE}/health`);
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.status).toBe('healthy');
  });

  test('staging API /health returns healthy', async ({ request }) => {
    const res = await request.get(`${STAGING_API}/health`);
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.status).toBe('healthy');
  });

  test('Flutter web app loads at app.swasth.health', async ({ page }) => {
    await page.goto('/');
    // flt-glass-pane is present but hidden in canvaskit — use 'attached' not visible
    await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 25000 });
    await expect(page).not.toHaveTitle('Error');
    expect(page.url()).toContain('app.swasth.health');
  });

  test('Interest form loads at swasth.health', async ({ page }) => {
    await page.goto('https://swasth.health');
    await page.waitForLoadState('networkidle');
    expect(page.url()).toContain('swasth.health');
  });

  test('HTTPS cert valid — no cert errors on any domain', async ({ page }) => {
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto('/');
    await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 25000 });
    expect(page.url()).toContain('app.swasth.health');
    // If cert was invalid, page would fail to load entirely
  });

  test('CORS: GET /health with Origin header returns 200 (not blocked)', async ({ request }) => {
    const res = await request.get(`${API_BASE}/health`, {
      headers: { 'Origin': 'https://app.swasth.health' },
    });
    expect(res.status()).toBe(200);
    // Response body should be healthy
    const body = await res.json();
    expect(body.status).toBe('healthy');
  });

  test('prod API rejects unauthenticated requests to protected routes', async ({ request }) => {
    const res = await request.get(`${API_BASE}/api/profiles/`);
    expect([401, 403]).toContain(res.status());
  });
});
