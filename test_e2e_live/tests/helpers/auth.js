// auth.js — Shared login helpers for Playwright E2E tests
// Login screen is SINGLE-STEP: email + password + Login button all visible at once.
// There is NO "Continue" step — both fields are on the same screen.

const { hydrate, enableSemantics, getLabels, typeInto, shot } = require('./flutter');

const CREDS = {
  patient: {
    email: process.env.PATIENT_EMAIL || 'swasth.patient.test@gmail.com',
    pass:  process.env.PATIENT_PASS  || 'Test@1234',
    name:  'Test Patient',
  },
  relative: {
    email: process.env.RELATIVE_EMAIL || 'swasth.relative.test@gmail.com',
    pass:  process.env.RELATIVE_PASS  || 'Test@1234',
    name:  'Test Relative',
  },
  doctor: {
    email: process.env.DOCTOR_EMAIL || 'swasth.doctor.test@gmail.com',
    pass:  process.env.DOCTOR_PASS  || 'Test@1234',
    name:  'Dr Test',
  },
};

// Login as role. Returns true when profile selector / dashboard appears.
async function login(page, role = 'patient') {
  const { email, pass } = CREDS[role];
  await page.goto('/');
  await hydrate(page);
  await enableSemantics(page);
  await page.waitForTimeout(1000); // let semantics tree stabilize

  // Debug: log what's on screen
  const labels = await getLabels(page);
  console.log(`[${role}] Login screen labels:`, labels);
  await shot(page, `${role}_01_landed`);

  // === Fill Email field ===
  await typeInto(page, 'Email', email);
  await shot(page, `${role}_02_email_typed`);

  // Tab to password field for reliability, then fill it
  await page.keyboard.press('Tab');
  await page.waitForTimeout(400);
  await typeInto(page, 'Password', pass);
  await shot(page, `${role}_03_pass_typed`);

  // === Click Login button ===
  const afterPassLabels = await getLabels(page);
  console.log(`[${role}] Pre-login labels:`, afterPassLabels);

  const loginLbl = afterPassLabels.find(l =>
    l && (l.toLowerCase() === 'login' || l.toLowerCase().includes('log in') || l.toLowerCase().includes('sign in'))
  );
  if (loginLbl) {
    await page.locator(`flt-semantics[aria-label="${loginLbl}"]`).first().click({ force: true });
  } else {
    // Fallback: press Enter (submits the focused form field)
    await page.keyboard.press('Enter');
  }

  await page.waitForTimeout(5000);
  await shot(page, `${role}_04_after_login`);

  // Verify we passed the login screen
  const content = (await getLabels(page)).join(' ').toLowerCase();
  console.log(`[${role}] Post-login labels:`, content);

  return content.includes('profile') ||
         content.includes('dashboard') ||
         content.includes('health') ||
         content.includes('select') ||
         content.includes('my health') ||
         content.includes('add profile') ||
         content.includes('patient');
}

// Select a profile by name, or fall back to clicking the first card area
async function selectProfile(page, profileName) {
  await page.waitForTimeout(2000);
  if (profileName) {
    const nodes = await page.$$('flt-semantics[aria-label]');
    for (const node of nodes) {
      const label = await node.getAttribute('aria-label');
      if (label && label.toLowerCase().includes(profileName.toLowerCase())) {
        await node.click({ force: true });
        await page.waitForTimeout(2000);
        return true;
      }
    }
  }
  // Fallback: click centre of profile card area
  await page.mouse.click(640, 400);
  await page.waitForTimeout(2000);
  return true;
}

module.exports = { CREDS, login, selectProfile };
