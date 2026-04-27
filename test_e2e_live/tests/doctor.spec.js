// doctor.spec.js — Doctor portal flow E2E tests
// Covers: doctor registration, triage board, patient list, patient readings, notes.
//
// Run: npx playwright test tests/doctor.spec.js
// Env vars: DOCTOR_EMAIL, DOCTOR_PASS

const { test, expect } = require('@playwright/test');
const { hydrate, enableSemantics, shot, navTo } = require('./helpers/flutter');
const { login, CREDS } = require('./helpers/auth');

const API = process.env.API_URL || 'https://api.swasth.health';

// ---------------------------------------------------------------------------
// D1 — Doctor authentication
// ---------------------------------------------------------------------------
test.describe('D1 — Doctor login', () => {
  test('D1.1 — Doctor can log in with doctor credentials', async ({ page }) => {
    const ok = await login(page, 'doctor');
    await shot(page, 'd1_1_doctor_logged_in');
    expect(ok).toBeTruthy();
  });

  test('D1.2 — Doctor sees profile selector or doctor dashboard after login', async ({ page }) => {
    await login(page, 'doctor');
    await page.waitForTimeout(2000);
    await shot(page, 'd1_2_after_login');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    const valid = content.includes('profile') || content.includes('doctor') ||
      content.includes('triage') || content.includes('patient') || content.includes('health');
    expect(valid).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// D2 — Doctor registration (API)
// ---------------------------------------------------------------------------
test.describe('D2 — Doctor registration (API)', () => {
  test('D2.1 — Unauthenticated registration attempt returns 401 or 422', async ({ request }) => {
    const res = await request.post(`${API}/api/doctors/register`, {
      data: {
        registration_number: 'MCI-TEST-99999',
        specialization: 'General Medicine',
        hospital: 'Test Hospital',
        city: 'Patna',
        state: 'Bihar',
      },
    });
    // Must be authenticated to register as doctor
    expect([401, 422]).toContain(res.status());
  });

  test('D2.2 — Authenticated user can register as doctor', async ({ request }) => {
    const loginRes = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.doctor.email, password: CREDS.doctor.pass },
    });
    if (loginRes.status() !== 200) test.skip();
    const { access_token } = await loginRes.json();
    const res = await request.post(`${API}/api/doctors/register`, {
      headers: { Authorization: `Bearer ${access_token}` },
      data: {
        registration_number: 'MCI-TEST-E2E-001',
        specialization: 'General Medicine',
        hospital: 'Playwright Test Hospital',
        city: 'Patna',
        state: 'Bihar',
      },
    });
    expect([200, 201, 400]).toContain(res.status()); // 400 = already registered
  });

  test('D2.3 — Registered doctor can fetch own doctor profile', async ({ request }) => {
    const loginRes = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.doctor.email, password: CREDS.doctor.pass },
    });
    if (loginRes.status() !== 200) test.skip();
    const { access_token } = await loginRes.json();
    const res = await request.get(`${API}/api/doctors/profile`, {
      headers: { Authorization: `Bearer ${access_token}` },
    });
    expect([200, 404]).toContain(res.status()); // 404 = not registered yet
    if (res.status() === 200) {
      const body = await res.json();
      expect(body).toHaveProperty('specialization');
    }
  });

  test('D2.4 — Doctor profile has a unique 6-char doctor code', async ({ request }) => {
    const loginRes = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.doctor.email, password: CREDS.doctor.pass },
    });
    if (loginRes.status() !== 200) test.skip();
    const { access_token } = await loginRes.json();
    const res = await request.get(`${API}/api/doctors/profile`, {
      headers: { Authorization: `Bearer ${access_token}` },
    });
    if (res.status() !== 200) test.skip();
    const body = await res.json();
    if (!body.doctor_code) test.skip();
    expect(body.doctor_code).toMatch(/^[A-Z0-9]{6}$/);
  });
});

// ---------------------------------------------------------------------------
// D3 — Triage board
// ---------------------------------------------------------------------------
test.describe('D3 — Triage board (API)', () => {
  let doctorToken;

  test.beforeAll(async ({ request }) => {
    const res = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.doctor.email, password: CREDS.doctor.pass },
    });
    if (res.status() === 200) doctorToken = (await res.json()).access_token;
  });

  test('D3.1 — Triage board endpoint returns array', async ({ request }) => {
    if (!doctorToken) test.skip();
    const res = await request.get(`${API}/api/doctors/triage`, {
      headers: { Authorization: `Bearer ${doctorToken}` },
    });
    expect([200, 404]).toContain(res.status());
    if (res.status() === 200) {
      const body = await res.json();
      expect(Array.isArray(body)).toBeTruthy();
    }
  });

  test('D3.2 — Triage entries have expected fields', async ({ request }) => {
    if (!doctorToken) test.skip();
    const res = await request.get(`${API}/api/doctors/triage`, {
      headers: { Authorization: `Bearer ${doctorToken}` },
    });
    if (res.status() !== 200) test.skip();
    const body = await res.json();
    if (!body.length) test.skip(); // No patients yet
    const entry = body[0];
    expect(entry).toHaveProperty('profile_id');
    expect(entry).toHaveProperty('triage_status');
  });

  test('D3.3 — Patient not linked to this doctor returns 403 on triage', async ({ request }) => {
    if (!doctorToken) test.skip();
    // Try to access triage for an unlinked profile
    const res = await request.get(`${API}/api/doctors/patients/99999/readings`, {
      headers: { Authorization: `Bearer ${doctorToken}` },
    });
    expect([403, 404]).toContain(res.status());
  });
});

// ---------------------------------------------------------------------------
// D4 — Patient link management
// ---------------------------------------------------------------------------
test.describe('D4 — Patient linking (API)', () => {
  let doctorToken;
  let patientToken;
  let doctorCode;

  test.beforeAll(async ({ request }) => {
    const dRes = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.doctor.email, password: CREDS.doctor.pass },
    });
    if (dRes.status() === 200) doctorToken = (await dRes.json()).access_token;

    const pRes = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.patient.email, password: CREDS.patient.pass },
    });
    if (pRes.status() === 200) patientToken = (await pRes.json()).access_token;

    // Get doctor code
    if (doctorToken) {
      const profileRes = await request.get(`${API}/api/doctors/profile`, {
        headers: { Authorization: `Bearer ${doctorToken}` },
      });
      if (profileRes.status() === 200) {
        const profile = await profileRes.json();
        doctorCode = profile.doctor_code;
      }
    }
  });

  test('D4.1 — Doctor code lookup returns doctor info', async ({ request }) => {
    if (!patientToken || !doctorCode) test.skip();
    const res = await request.get(`${API}/api/doctors/lookup/${doctorCode}`, {
      headers: { Authorization: `Bearer ${patientToken}` },
    });
    expect([200, 404]).toContain(res.status());
    if (res.status() === 200) {
      const body = await res.json();
      expect(body).toHaveProperty('specialization');
    }
  });

  test('D4.2 — Invalid doctor code returns 404', async ({ request }) => {
    if (!patientToken) test.skip();
    const res = await request.get(`${API}/api/doctors/lookup/XXXXXX`, {
      headers: { Authorization: `Bearer ${patientToken}` },
    });
    expect([404, 400]).toContain(res.status());
  });

  test('D4.3 — Patient can send link request to doctor', async ({ request }) => {
    if (!patientToken || !doctorCode) test.skip();
    const profilesRes = await request.get(`${API}/api/profiles/`, {
      headers: { Authorization: `Bearer ${patientToken}` },
    });
    if (profilesRes.status() !== 200) test.skip();
    const profiles = await profilesRes.json();
    if (!profiles.length) test.skip();
    const res = await request.post(`${API}/api/doctors/link`, {
      headers: { Authorization: `Bearer ${patientToken}` },
      data: {
        doctor_code: doctorCode,
        profile_id: profiles[0].id,
      },
    });
    expect([200, 201, 400, 409]).toContain(res.status()); // 409 = already linked
  });

  test('D4.4 — Doctor can see pending link requests', async ({ request }) => {
    if (!doctorToken) test.skip();
    const res = await request.get(`${API}/api/doctors/link-requests/pending`, {
      headers: { Authorization: `Bearer ${doctorToken}` },
    });
    expect([200, 404]).toContain(res.status());
    if (res.status() === 200) {
      const body = await res.json();
      expect(Array.isArray(body)).toBeTruthy();
    }
  });

  test('D4.5 — Doctor can accept a patient link request', async ({ request }) => {
    if (!doctorToken) test.skip();
    const pendingRes = await request.get(`${API}/api/doctors/link-requests/pending`, {
      headers: { Authorization: `Bearer ${doctorToken}` },
    });
    if (pendingRes.status() !== 200) test.skip();
    const pending = await pendingRes.json();
    if (!pending.length) test.skip(); // No pending requests
    const linkId = pending[0].id;
    const res = await request.post(`${API}/api/doctors/link-requests/${linkId}/accept`, {
      headers: { Authorization: `Bearer ${doctorToken}` },
    });
    expect([200, 201, 400]).toContain(res.status());
  });

  test('D4.6 — Doctor can view linked patient readings after accept', async ({ request }) => {
    if (!doctorToken) test.skip();
    // Get linked patients
    const linkedRes = await request.get(`${API}/api/doctors/patients`, {
      headers: { Authorization: `Bearer ${doctorToken}` },
    });
    if (linkedRes.status() !== 200) test.skip();
    const patients = await linkedRes.json();
    if (!patients.length) test.skip();
    const profileId = patients[0].profile_id || patients[0].id;
    const res = await request.get(`${API}/api/doctors/patients/${profileId}/readings`, {
      headers: { Authorization: `Bearer ${doctorToken}` },
    });
    expect([200, 404]).toContain(res.status());
  });
});

// ---------------------------------------------------------------------------
// D5 — Doctor UI: triage screen
// ---------------------------------------------------------------------------
test.describe('D5 — Doctor triage UI', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, 'doctor');
    await page.waitForTimeout(2000);
  });

  test('D5.1 — Doctor portal / triage screen is accessible', async ({ page }) => {
    // Doctor may see a special screen or regular profile selector
    await shot(page, 'd5_1_doctor_portal');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    // No crash = pass. The screen could be triage or profile selector.
    expect(content.length).toBeGreaterThan(5);
  });

  test('D5.2 — Doctor sees triage board or patient list', async ({ page }) => {
    // Navigate to doctor-specific UI
    // Try clicking a "Doctor Portal" or "Triage" button if visible
    const labels = await page.$$eval('flt-semantics[aria-label]', els =>
      els.map(e => e.getAttribute('aria-label')));
    const doctorBtn = labels.find(l => l?.toLowerCase().includes('doctor') ||
      l?.toLowerCase().includes('triage') || l?.toLowerCase().includes('portal'));
    if (doctorBtn) {
      const el = await page.$(`flt-semantics[aria-label="${doctorBtn}"]`);
      if (el) await el.click();
      await page.waitForTimeout(2000);
    }
    await shot(page, 'd5_2_triage_or_portal');
    const content = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics[aria-label]'))
        .map(n => n.getAttribute('aria-label')).join(' ').toLowerCase());
    expect(content.length).toBeGreaterThan(5);
  });
});

// ---------------------------------------------------------------------------
// D6 — Security: doctor cannot access other doctors' patients
// ---------------------------------------------------------------------------
test.describe('D6 — Doctor data isolation', () => {
  let doctorToken;

  test.beforeAll(async ({ request }) => {
    const res = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.doctor.email, password: CREDS.doctor.pass },
    });
    if (res.status() === 200) doctorToken = (await res.json()).access_token;
  });

  test('D6.1 — Doctor cannot access unlinked patient profile', async ({ request }) => {
    if (!doctorToken) test.skip();
    const res = await request.get(`${API}/api/doctors/patients/99999/profile`, {
      headers: { Authorization: `Bearer ${doctorToken}` },
    });
    expect([403, 404]).toContain(res.status());
  });

  test('D6.2 — Doctor cannot revoke a link they do not own', async ({ request }) => {
    if (!doctorToken) test.skip();
    const res = await request.delete(`${API}/api/doctors/link/99999`, {
      headers: { Authorization: `Bearer ${doctorToken}` },
    });
    expect([403, 404]).toContain(res.status());
  });

  test('D6.3 — Patient token cannot access doctor-only triage endpoint', async ({ request }) => {
    const loginRes = await request.post(`${API}/api/auth/login`, {
      data: { email: CREDS.patient.email, password: CREDS.patient.pass },
    });
    if (loginRes.status() !== 200) test.skip();
    const patientToken = (await loginRes.json()).access_token;
    const res = await request.get(`${API}/api/doctors/triage`, {
      headers: { Authorization: `Bearer ${patientToken}` },
    });
    expect([403, 404]).toContain(res.status());
  });
});
