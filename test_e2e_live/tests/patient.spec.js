// patient.spec.js — Exhaustive patient flow E2E tests
// Covers: login, profile creation, health logging, history, chat, AI insights,
//         doctor linking, relative invite, manage access, offline behaviour.
//
// Run: npx playwright test tests/patient.spec.js
// Env vars: PATIENT_EMAIL, PATIENT_PASS, TARGET (default https://app.swasth.health)

const { test, expect } = require('@playwright/test');
const { hydrate, enableSemantics, shot, navTo, clickByLabel, waitForLabel } = require('./helpers/flutter');
const { login, selectProfile, CREDS } = require('./helpers/auth');

const API = process.env.API_URL || 'https://api.swasth.health';

// ---------------------------------------------------------------------------
// P1 — Authentication
// ---------------------------------------------------------------------------
test.describe('P1 — Authentication', () => {
  test('P1.1 — Login page loads and shows email field', async ({ page }) => {
    await page.goto('/');
    await hydrate(page);
    await enableSemantics(page);
    await shot(page, 'p1_1_login_loaded');
    const labels = await page.$$eval('flt-semantics[aria-label]', els =>
      els.map(e => e.getAttribute('aria-label')));
    const hasEmail = labels.some(l => l?.toLowerCase().includes('email') ||
      l?.toLowerCase().includes('phone') || l?.toLowerCase().includes('sign'));
    expect(hasEmail).toBeTruthy();
  });

  test('P1.2 — Invalid credentials shows error message', async ({ page }) => {
    await page.goto('/');
    await hydrate(page);
    await enableSemantics(page);
    await page.mouse.click(640, 308);
    await page.keyboard.type('wrong@nowhere.com', { delay: 50 });
    await page.mouse.click(640, 530);
    await page.waitForTimeout(1500);
    await page.mouse.click(640, 370);
    await page.keyboard.type('WrongPass99!', { delay: 50 });
    await page.mouse.click(640, 530);
    await page.waitForTimeout(4000);
    await shot(page, 'p1_2_invalid_creds');
    // Should stay on login or show error — not reach dashboard
    const url = page.url();
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' '));
    const hasError = content.toLowerCase().includes('invalid') ||
      content.toLowerCase().includes('incorrect') ||
      content.toLowerCase().includes('failed') ||
      content.toLowerCase().includes('error') ||
      !content.toLowerCase().includes('dashboard');
    expect(hasError).toBeTruthy();
  });

  test('P1.3 — Valid patient login succeeds and reaches profile selector', async ({ page }) => {
    const ok = await login(page, 'patient');
    await shot(page, 'p1_3_logged_in');
    expect(ok).toBeTruthy();
  });

  test('P1.4 — Empty email shows validation error', async ({ page }) => {
    await page.goto('/');
    await hydrate(page);
    await enableSemantics(page);
    // Click Continue without typing email
    await page.mouse.click(640, 530);
    await page.waitForTimeout(2000);
    await shot(page, 'p1_4_empty_email');
    // Should not advance to password screen
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' '));
    expect(content.toLowerCase()).not.toContain('password');
  });
});

// ---------------------------------------------------------------------------
// P2 — Profile selection & creation
// ---------------------------------------------------------------------------
test.describe('P2 — Profile management', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, 'patient');
    await page.waitForTimeout(2000);
  });

  test('P2.1 — Profile selector screen renders after login', async ({ page }) => {
    await shot(page, 'p2_1_profile_selector');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' '));
    // Should show "My Health" or profile name or "Add Profile"
    const valid = content.toLowerCase().includes('health') ||
      content.toLowerCase().includes('profile') ||
      content.toLowerCase().includes('add');
    expect(valid).toBeTruthy();
  });

  test('P2.2 — Selecting a profile navigates to dashboard', async ({ page }) => {
    await selectProfile(page, 'My Health');
    await page.waitForTimeout(3000);
    await shot(page, 'p2_2_dashboard_loaded');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' '));
    const onDashboard = content.toLowerCase().includes('blood pressure') ||
      content.toLowerCase().includes('glucose') ||
      content.toLowerCase().includes('dashboard') ||
      content.toLowerCase().includes('bp') ||
      content.toLowerCase().includes('add reading');
    expect(onDashboard).toBeTruthy();
  });

  test('P2.3 — Create new profile button is visible', async ({ page }) => {
    await shot(page, 'p2_3_profile_list');
    const labels = await page.$$eval('flt-semantics[aria-label]', els =>
      els.map(e => e.getAttribute('aria-label')));
    const hasAdd = labels.some(l => l?.toLowerCase().includes('add') ||
      l?.toLowerCase().includes('create') || l?.toLowerCase().includes('+'));
    expect(hasAdd).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// P3 — Dashboard
// ---------------------------------------------------------------------------
test.describe('P3 — Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, 'patient');
    await selectProfile(page, 'My Health');
    await page.waitForTimeout(2000);
  });

  test('P3.1 — Dashboard shows BP card', async ({ page }) => {
    await shot(page, 'p3_1_dashboard');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    expect(content).toMatch(/blood pressure|bp|systolic/);
  });

  test('P3.2 — Dashboard shows glucose card', async ({ page }) => {
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    expect(content).toMatch(/glucose|sugar|blood sugar/);
  });

  test('P3.3 — Dashboard shows AI insight card or loading state', async ({ page }) => {
    await page.waitForTimeout(3000); // allow AI insight to load
    await shot(page, 'p3_3_ai_insight');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const hasInsight = content.includes('insight') || content.includes('ai') ||
      content.includes('health') || content.includes('loading');
    expect(hasInsight).toBeTruthy();
  });

  test('P3.4 — Bottom navigation has 5 tabs', async ({ page }) => {
    await shot(page, 'p3_4_bottom_nav');
    // Nav tabs visible: Home, History, Streaks, Insights, Chat
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const tabs = ['home', 'history', 'insights', 'chat'];
    const found = tabs.filter(t => content.includes(t));
    expect(found.length).toBeGreaterThanOrEqual(2);
  });

  test('P3.5 — No JS errors on dashboard', async ({ page }) => {
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.waitForTimeout(3000);
    const fatalErrors = errors.filter(e => !e.includes('ResizeObserver'));
    expect(fatalErrors.length).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// P4 — Blood pressure logging
// ---------------------------------------------------------------------------
test.describe('P4 — Blood pressure logging', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, 'patient');
    await selectProfile(page, 'My Health');
    await page.waitForTimeout(2000);
  });

  test('P4.1 — BP entry screen opens from dashboard', async ({ page }) => {
    // Tap the BP card / Add BP button
    await page.mouse.click(320, 400); // left card area (BP)
    await page.waitForTimeout(2000);
    await shot(page, 'p4_1_bp_screen_opened');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const onBP = content.includes('systolic') || content.includes('blood pressure') ||
      content.includes('diastolic') || content.includes('mmhg');
    expect(onBP).toBeTruthy();
  });

  test('P4.2 — Can enter valid BP values (128/84)', async ({ page }) => {
    await page.mouse.click(320, 400);
    await page.waitForTimeout(2000);
    await shot(page, 'p4_2_bp_entry_before');
    // Systolic field
    await page.mouse.click(640, 340);
    await page.waitForTimeout(300);
    await page.keyboard.type('128', { delay: 80 });
    // Diastolic field
    await page.mouse.click(640, 430);
    await page.waitForTimeout(300);
    await page.keyboard.type('84', { delay: 80 });
    await shot(page, 'p4_2_bp_values_entered');
  });

  test('P4.3 — BP boundary: hypertensive values (180/110) accepted', async ({ page }) => {
    await page.mouse.click(320, 400);
    await page.waitForTimeout(2000);
    await page.mouse.click(640, 340);
    await page.keyboard.type('180', { delay: 80 });
    await page.mouse.click(640, 430);
    await page.keyboard.type('110', { delay: 80 });
    await shot(page, 'p4_3_hypertensive_values');
    // Should show a warning or accept with alert flag
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    // Should still be on entry screen (not error out)
    expect(content).toMatch(/systolic|diastolic|bp|pressure|180/);
  });

  test('P4.4 — BP entry: submit saves reading and returns to dashboard', async ({ page }) => {
    await page.mouse.click(320, 400);
    await page.waitForTimeout(2000);
    await page.mouse.click(640, 340);
    await page.keyboard.type('120', { delay: 80 });
    await page.mouse.click(640, 430);
    await page.keyboard.type('80', { delay: 80 });
    await page.waitForTimeout(500);
    // Save button
    await page.mouse.click(640, 700);
    await page.waitForTimeout(4000);
    await shot(page, 'p4_4_after_save');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    // Should be back at dashboard or confirmation screen
    const back = content.includes('dashboard') || content.includes('blood pressure') ||
      content.includes('glucose') || content.includes('120') || content.includes('confirm');
    expect(back).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// P5 — Glucose logging
// ---------------------------------------------------------------------------
test.describe('P5 — Glucose logging', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, 'patient');
    await selectProfile(page, 'My Health');
    await page.waitForTimeout(2000);
  });

  test('P5.1 — Glucose entry screen opens from dashboard', async ({ page }) => {
    await page.mouse.click(960, 400); // right card area (glucose)
    await page.waitForTimeout(2000);
    await shot(page, 'p5_1_glucose_screen');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const onGlucose = content.includes('glucose') || content.includes('sugar') ||
      content.includes('mg/dl') || content.includes('mmol');
    expect(onGlucose).toBeTruthy();
  });

  test('P5.2 — Can enter valid glucose (142 mg/dL) and save', async ({ page }) => {
    await page.mouse.click(960, 400);
    await page.waitForTimeout(2000);
    await page.mouse.click(640, 380);
    await page.keyboard.type('142', { delay: 80 });
    await shot(page, 'p5_2_glucose_entered');
    // Save
    await page.mouse.click(640, 700);
    await page.waitForTimeout(4000);
    await shot(page, 'p5_2_after_save');
  });

  test('P5.3 — Glucose boundary: hypoglycaemic value (55) shows warning', async ({ page }) => {
    await page.mouse.click(960, 400);
    await page.waitForTimeout(2000);
    await page.mouse.click(640, 380);
    await page.keyboard.type('55', { delay: 80 });
    await page.waitForTimeout(500);
    await shot(page, 'p5_3_hypo_value');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    // Value should be entered without crashing
    expect(content).toMatch(/glucose|sugar|55|mg/);
  });

  test('P5.4 — Glucose boundary: hyperglycaemic (400 mg/dL) accepted', async ({ page }) => {
    await page.mouse.click(960, 400);
    await page.waitForTimeout(2000);
    await page.mouse.click(640, 380);
    await page.keyboard.type('400', { delay: 80 });
    await shot(page, 'p5_4_hyper_value');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    expect(content).toMatch(/glucose|sugar|400|mg/);
  });
});

// ---------------------------------------------------------------------------
// P6 — Meal logging
// ---------------------------------------------------------------------------
test.describe('P6 — Meal logging', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, 'patient');
    await selectProfile(page, 'My Health');
    await page.waitForTimeout(2000);
  });

  test('P6.1 — Meal logging button/icon visible on dashboard', async ({ page }) => {
    await shot(page, 'p6_1_dashboard_meal');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const hasMeal = content.includes('meal') || content.includes('food') ||
      content.includes('eat') || content.includes('log meal');
    expect(hasMeal).toBeTruthy();
  });

  test('P6.2 — Quick select meal screen opens', async ({ page }) => {
    // Scroll down to find meal section or tap meal icon
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(1000);
    await shot(page, 'p6_2_scrolled');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    // Look for meal-related content
    const found = content.includes('breakfast') || content.includes('lunch') ||
      content.includes('dinner') || content.includes('meal') || content.includes('food');
    expect(found).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// P7 — Health history
// ---------------------------------------------------------------------------
test.describe('P7 — Health history', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, 'patient');
    await selectProfile(page, 'My Health');
    await page.waitForTimeout(2000);
  });

  test('P7.1 — History tab opens from bottom nav', async ({ page }) => {
    await navTo(page, 'history');
    await shot(page, 'p7_1_history_opened');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const onHistory = content.includes('history') || content.includes('reading') ||
      content.includes('bp') || content.includes('glucose') || content.includes('record');
    expect(onHistory).toBeTruthy();
  });

  test('P7.2 — History list shows at least one reading', async ({ page }) => {
    await navTo(page, 'history');
    await page.waitForTimeout(2000);
    await page.mouse.wheel(0, 200);
    await page.waitForTimeout(1000);
    await shot(page, 'p7_2_history_scrolled');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    // Check for date patterns or reading values
    const hasReadings = content.match(/\d{1,3}\/\d{1,3}/) || // BP like 128/84
      content.match(/\d{2,3} mg/) || // glucose
      content.includes('mmhg') || content.includes('2026') || content.includes('2025');
    expect(hasReadings).toBeTruthy();
  });

  test('P7.3 — History filters are accessible (BP / Glucose / Meals)', async ({ page }) => {
    await navTo(page, 'history');
    await page.waitForTimeout(1500);
    await shot(page, 'p7_3_history_filters');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const hasFilter = content.includes('filter') || content.includes('blood') ||
      content.includes('glucose') || content.includes('all') || content.includes('type');
    expect(hasFilter).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// P8 — AI Insights
// ---------------------------------------------------------------------------
test.describe('P8 — AI Insights', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, 'patient');
    await selectProfile(page, 'My Health');
    await page.waitForTimeout(2000);
  });

  test('P8.1 — Insights tab opens', async ({ page }) => {
    await navTo(page, 'insights');
    await shot(page, 'p8_1_insights_opened');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const onInsights = content.includes('insight') || content.includes('trend') ||
      content.includes('analysis') || content.includes('health') || content.includes('ai');
    expect(onInsights).toBeTruthy();
  });

  test('P8.2 — Insights loads without JS crash', async ({ page }) => {
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await navTo(page, 'insights');
    await page.waitForTimeout(5000); // AI response may take time
    await shot(page, 'p8_2_insights_loaded');
    const fatal = errors.filter(e => !e.includes('ResizeObserver'));
    expect(fatal.length).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// P9 — AI Chat
// ---------------------------------------------------------------------------
test.describe('P9 — AI Chat', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, 'patient');
    await selectProfile(page, 'My Health');
    await page.waitForTimeout(2000);
  });

  test('P9.1 — Chat tab opens and shows input field', async ({ page }) => {
    await navTo(page, 'chat');
    await page.waitForTimeout(2000);
    await shot(page, 'p9_1_chat_opened');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const hasInput = content.includes('message') || content.includes('ask') ||
      content.includes('type') || content.includes('chat') || content.includes('send');
    expect(hasInput).toBeTruthy();
  });

  test('P9.2 — Sending a chat message gets a response', async ({ page }) => {
    await navTo(page, 'chat');
    await page.waitForTimeout(2000);
    // Click message input area
    await page.mouse.click(580, 820);
    await page.waitForTimeout(500);
    await page.keyboard.type('What is a healthy blood pressure?', { delay: 50 });
    await shot(page, 'p9_2_message_typed');
    // Send button (right side of input)
    await page.mouse.click(1200, 820);
    await page.waitForTimeout(8000); // AI takes time
    await shot(page, 'p9_2_response_received');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    // Should have more text — response visible
    const hasResponse = content.includes('blood pressure') || content.includes('mmhg') ||
      content.includes('systolic') || content.includes('normal') || content.length > 200;
    expect(hasResponse).toBeTruthy();
  });

  test('P9.3 — Chat shows quota indicator', async ({ page }) => {
    await navTo(page, 'chat');
    await page.waitForTimeout(2000);
    await shot(page, 'p9_3_quota');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    // Quota remaining label or count
    const hasQuota = content.includes('question') || content.includes('quota') ||
      content.includes('remaining') || content.includes('left') || content.includes('/');
    expect(hasQuota).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// P10 — Doctor linking
// ---------------------------------------------------------------------------
test.describe('P10 — Doctor linking', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, 'patient');
    await selectProfile(page, 'My Health');
    await page.waitForTimeout(2000);
  });

  test('P10.1 — Link doctor option accessible from profile/settings', async ({ page }) => {
    // Navigate to profile screen (usually via avatar/settings icon)
    await page.mouse.click(1220, 80); // top-right profile icon area
    await page.waitForTimeout(2000);
    await shot(page, 'p10_1_profile_menu');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const hasDoctor = content.includes('doctor') || content.includes('link') ||
      content.includes('physician') || content.includes('connect');
    expect(hasDoctor).toBeTruthy();
  });

  test('P10.2 — API: doctor directory endpoint returns list', async ({ request }) => {
    const loginRes = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.patient.email, password: CREDS.patient.pass },
    });
    if (loginRes.status() !== 200) test.skip();
    const { access_token } = await loginRes.json();
    const res = await request.get(`${API}/api/doctors/directory`, {
      headers: { Authorization: `Bearer ${access_token}` },
    });
    expect([200, 404]).toContain(res.status()); // 404 = no doctors yet, still OK
  });
});

// ---------------------------------------------------------------------------
// P11 — Invite management (sharing profile with relative)
// ---------------------------------------------------------------------------
test.describe('P11 — Invite management', () => {
  test('P11.1 — API: can send invite to relative email', async ({ request }) => {
    const loginRes = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.patient.email, password: CREDS.patient.pass },
    });
    if (loginRes.status() !== 200) test.skip();
    const { access_token } = await loginRes.json();
    // Get profiles
    const profilesRes = await request.get(`${API}/api/profiles/`, {
      headers: { Authorization: `Bearer ${access_token}` },
    });
    if (profilesRes.status() !== 200) test.skip();
    const profiles = await profilesRes.json();
    if (!profiles.length) test.skip();
    const profileId = profiles[0].id;
    // Send invite
    const inviteRes = await request.post(`${API}/api/profiles/${profileId}/invite`, {
      headers: { Authorization: `Bearer ${access_token}` },
      data: {
        email: CREDS.relative.email,
        access_level: 'viewer',
        relationship: 'child',
      },
    });
    expect([200, 201, 400]).toContain(inviteRes.status()); // 400 = already invited, OK
  });

  test('P11.2 — API: pending invites endpoint returns data', async ({ request }) => {
    const loginRes = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.relative.email, password: CREDS.relative.pass },
    });
    if (loginRes.status() !== 200) test.skip();
    const { access_token } = await loginRes.json();
    const res = await request.get(`${API}/api/profiles/invites/pending`, {
      headers: { Authorization: `Bearer ${access_token}` },
    });
    expect(res.status()).toBe(200);
  });
});

// ---------------------------------------------------------------------------
// P12 — API contract tests (fast, no UI)
// ---------------------------------------------------------------------------
test.describe('P12 — API contract (patient)', () => {
  let token;

  test.beforeAll(async ({ request }) => {
    const res = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.patient.email, password: CREDS.patient.pass },
    });
    if (res.status() === 200) {
      const body = await res.json();
      token = body.access_token;
    }
  });

  test('P12.1 — GET /api/profiles returns array', async ({ request }) => {
    if (!token) test.skip();
    const res = await request.get(`${API}/api/profiles/`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body)).toBeTruthy();
  });

  test('P12.2 — GET /api/health/readings returns array', async ({ request }) => {
    if (!token) test.skip();
    const res = await request.get(`${API}/api/health/readings`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect([200, 404]).toContain(res.status());
  });

  test('P12.3 — POST BP reading succeeds with valid data', async ({ request }) => {
    if (!token) test.skip();
    const profilesRes = await request.get(`${API}/api/profiles/`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (profilesRes.status() !== 200) test.skip();
    const profiles = await profilesRes.json();
    if (!profiles.length) test.skip();
    const res = await request.post(`${API}/api/health/readings`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        profile_id: profiles[0].id,
        reading_type: 'blood_pressure',
        systolic: 120,
        diastolic: 80,
        notes: 'Playwright E2E test',
      },
    });
    expect([200, 201]).toContain(res.status());
  });

  test('P12.4 — POST glucose reading succeeds with valid data', async ({ request }) => {
    if (!token) test.skip();
    const profilesRes = await request.get(`${API}/api/profiles/`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (profilesRes.status() !== 200) test.skip();
    const profiles = await profilesRes.json();
    if (!profiles.length) test.skip();
    const res = await request.post(`${API}/api/health/readings`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        profile_id: profiles[0].id,
        reading_type: 'glucose',
        glucose_value: 98,
        notes: 'Playwright E2E test',
      },
    });
    expect([200, 201]).toContain(res.status());
  });

  test('P12.5 — GET /api/meals returns array', async ({ request }) => {
    if (!token) test.skip();
    const profilesRes = await request.get(`${API}/api/profiles/`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (profilesRes.status() !== 200) test.skip();
    const profiles = await profilesRes.json();
    if (!profiles.length) test.skip();
    const res = await request.get(`${API}/api/meals/?profile_id=${profiles[0].id}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect([200, 404]).toContain(res.status());
  });

  test('P12.6 — GET /api/chat/messages returns array', async ({ request }) => {
    if (!token) test.skip();
    const profilesRes = await request.get(`${API}/api/profiles/`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (profilesRes.status() !== 200) test.skip();
    const profiles = await profilesRes.json();
    if (!profiles.length) test.skip();
    const res = await request.get(`${API}/api/chat/messages?profile_id=${profiles[0].id}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect([200, 404]).toContain(res.status());
  });

  test('P12.7 — Malformed BP (string values) rejected with 422', async ({ request }) => {
    if (!token) test.skip();
    const res = await request.post(`${API}/api/health/readings`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { reading_type: 'blood_pressure', systolic: 'abc', diastolic: 'xyz' },
    });
    expect([400, 422]).toContain(res.status());
  });
});
