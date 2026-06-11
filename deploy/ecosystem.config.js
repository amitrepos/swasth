// pm2 ecosystem — pins each backend process to its OWN dir + venv so a bare
// `pm2 restart` (or a reboot `pm2 resurrect`) can never pick the wrong
// directory again. This is the durable guard behind the 2026-06-11 prod/staging
// split (see docs/blueprints/split-prod-staging-backend.md).
//
// Each process reads its own /backend/.env for DATABASE_URL + SERVER_PORT, so
// no DB creds live here. Prod → swasth_prod:8007, staging → swasth_staging:8008.
//
// Usage on the server:
//   ONE-TIME adoption of an ad-hoc process (different script signature) — must
//   delete first, or pm2 races the old process on the port and BOTH error:
//     pm2 delete swasth-backend; pm2 start deploy/ecosystem.config.js --only swasth-backend
//   AFTER adoption, normal reload/restart keeps the pinned cwd:
//     pm2 startOrReload deploy/ecosystem.config.js --only swasth-backend
//     pm2 restart swasth-backend
//   Always `pm2 save` after, so a reboot `pm2 resurrect` restores the right dirs.
//
// NOTE: swasth-health-form (the Node interest-form app) is managed separately
// and intentionally NOT included here — this file owns the FastAPI backends.

module.exports = {
  apps: [
    {
      name: 'swasth-backend',                                  // PRODUCTION
      script: '/var/www/swasth/prod/backend/main.py',          // ABSOLUTE — pm2 resolves `script` relative to this file's dir, not cwd
      interpreter: '/var/www/swasth/prod/venv/bin/python3',    // python3.11 venv
      interpreter_args: '-B',
      cwd: '/var/www/swasth/prod/backend',
      autorestart: true,
      max_restarts: 10,
      // DATABASE_URL + SERVER_PORT(8007) come from /var/www/swasth/prod/backend/.env
    },
    {
      name: 'swasth-staging',                                  // STAGING
      script: '/var/www/swasth/staging/backend/main.py',       // ABSOLUTE — see prod note above
      interpreter: '/var/www/swasth/staging/venv/bin/python3', // python3.11 venv
      interpreter_args: '-B',
      cwd: '/var/www/swasth/staging/backend',
      autorestart: true,
      max_restarts: 10,
      // DATABASE_URL + SERVER_PORT(8008) come from /var/www/swasth/staging/backend/.env
    },
  ],
};
