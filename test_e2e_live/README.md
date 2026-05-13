# Swasth Live E2E Tests (Playwright)

Headed Playwright tests that exercise the live deployed backend + Flutter web UI.
Unlike `test/flows/*` (which use mocked HTTP), these hit the real DEV or PROD server.

## Prereq
```bash
cd /tmp && npm install playwright && npx playwright install chromium
```

## Run
```bash
# DEV
TARGET=https://api.swasth.health node test_e2e_live/run.js login
TARGET=https://api.swasth.health node test_e2e_live/run.js select_profile
TARGET=https://api.swasth.health node test_e2e_live/run.js log_bp
TARGET=https://api.swasth.health node test_e2e_live/run.js log_glucose
TARGET=https://api.swasth.health node test_e2e_live/run.js all

# PROD (be careful — writes data)
TARGET=https://api.swasth.health node test_e2e_live/run.js all
```

## Files
- `run.js` — dispatcher + shared login helper + individual flow tests
- `screenshots/` — saved at each key step
