// flutter.js — Flutter web interaction helpers for Playwright
// Flutter canvaskit: flt-semantics overlays actual canvas rendering.
// Text input: clicking flt-semantics focuses Flutter widget → Flutter creates
// a hidden <input> in <flt-text-editing-host> to capture keyboard events.

// Wait for Flutter canvas to attach (canvaskit renders to canvas, not visible)
async function hydrate(page) {
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 30000 });
  await page.waitForTimeout(2000);
}

// Activate Flutter's a11y semantics overlay so flt-semantics nodes appear in DOM
async function enableSemantics(page) {
  const btn = await page.$('flt-semantics-placeholder');
  if (btn) {
    await btn.click();
    await page.waitForTimeout(1500);
  }
}

// Return all aria-labels currently in the semantics tree
async function getLabels(page) {
  return page.$$eval('flt-semantics[aria-label]',
    els => els.map(e => e.getAttribute('aria-label')));
}

// Click an flt-semantics element whose aria-label contains labelText (case-insensitive)
async function clickByLabel(page, labelText, timeout = 12000) {
  const selector = `flt-semantics[aria-label*="${labelText}"]`;
  await page.waitForSelector(selector, { timeout });
  await page.locator(selector).first().click({ force: true });
  await page.waitForTimeout(600);
}

// Fill a Flutter TextField identified by aria-label hint.
// Strategy:
//   1. Click the flt-semantics node to focus the Flutter widget
//   2. Flutter creates a hidden <input>/<textarea> in flt-text-editing-host
//   3. Fill that real input directly; fall back to keyboard.type if not found
async function typeInto(page, labelText, value, timeout = 12000) {
  // Step 1: find and click the semantic node
  const allLabels = await getLabels(page);
  const match = allLabels.find(l => l && l.toLowerCase().includes(labelText.toLowerCase()));
  if (match) {
    await page.locator(`flt-semantics[aria-label="${match}"]`).first().click({ force: true });
  } else {
    console.warn(`[flutter.js] No flt-semantics found for label hint: "${labelText}"`);
    console.warn(`[flutter.js] Available labels:`, allLabels);
  }
  await page.waitForTimeout(700);

  // Step 2: try the real input Flutter created
  const hostInput = page.locator([
    'flt-text-editing-host input',
    'flt-text-editing-host textarea',
    'input.flt-text-editing',
    'textarea.flt-text-editing',
  ].join(', ')).last();

  if (await hostInput.count() > 0) {
    await hostInput.fill(value);
    await page.waitForTimeout(300);
    return;
  }

  // Step 3: fall back to keyboard (works if Flutter hidden input has focus)
  await page.keyboard.type(value, { delay: 60 });
  await page.waitForTimeout(300);
}

// Wait for visible text in the flt-semantics tree
async function waitForLabel(page, text, timeout = 15000) {
  await page.waitForFunction(
    (t) => {
      const nodes = document.querySelectorAll('flt-semantics[aria-label]');
      return Array.from(nodes).some(n => n.getAttribute('aria-label')?.toLowerCase().includes(t.toLowerCase()));
    },
    text,
    { timeout }
  );
}

// Bottom nav coordinates for 1280×900 viewport
const NAV = {
  home:     [128,  868],
  history:  [379,  868],
  streaks:  [637,  868],
  insights: [897,  868],
  chat:     [1151, 868],
};

async function navTo(page, tab) {
  const [x, y] = NAV[tab] || NAV.home;
  await page.mouse.click(x, y);
  await page.waitForTimeout(2000);
}

async function shot(page, name) {
  const dir = require('path').join(__dirname, '../../screenshots');
  require('fs').mkdirSync(dir, { recursive: true });
  await page.screenshot({ path: `${dir}/${name}.png`, fullPage: false });
}

module.exports = { hydrate, enableSemantics, getLabels, clickByLabel, typeInto, waitForLabel, navTo, shot, NAV };
