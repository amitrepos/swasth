# Blueprint: Split prod/staging backend + atomic gated prod deploy

## Objective
Give prod and staging fully separate on-disk dirs + venvs so a staging deploy can never alter prod's running code, and make the prod deploy ship code + migration as one gated, readiness-verified unit. Fixes the 2026-06-11 root cause.

## Current state (verified 2026-06-11)
- `swasth-backend` (prod, `swasth_prod`) **and** `swasth-staging` (`swasth_staging`, port 8008) both run with `cwd=/var/www/swasth/backend` — **the same directory**.
- Both use the shared venv `/var/www/swasth/venv`.
- Staging deploy: `scp backend/ → /var/www/swasth/ (overwrite:true)` then `alembic upgrade head` (staging DB) — this **overwrites prod's code on disk**. Prod picks it up on its next restart.
- Prod backend deploy is gated (`environment: production`) and runs its own `alembic upgrade head` against `swasth_prod` — but the gate holds the migration while the shared-dir code already changed. → drift → outage.

## Target layout
```
/var/www/swasth/
├── prod/
│   ├── backend/        # ONLY the prod deploy writes here
│   └── venv/           # prod-only virtualenv
├── staging/
│   ├── backend/        # ONLY the staging deploy writes here
│   └── venv/           # staging-only virtualenv
├── web/                # (unchanged) flutter web roots
└── backend.LEGACY/     # old shared dir, kept read-only for 1 week then deleted
```
- `swasth-backend` → `cwd=/var/www/swasth/prod/backend`, venv `/var/www/swasth/prod/venv`, `.env` → `swasth_prod`.
- `swasth-staging` → `cwd=/var/www/swasth/staging/backend`, venv `/var/www/swasth/staging/venv`, `DATABASE_URL=swasth_staging`, port 8008.
- No path is shared between the two. A staging deploy physically cannot touch `prod/`.

## Steps

### Step 1: Provision the two new dirs + venvs on the server (no traffic change)
**Context brief:** Host `swasth-prod` (ec2-user@13.127.215.113), shared dir is `/var/www/swasth/backend`, shared venv `/var/www/swasth/venv`. Both pm2 apps still run from the shared dir — do NOT touch them yet.
**Changes:**
- `mkdir -p /var/www/swasth/{prod,staging}`
- `cp -a /var/www/swasth/backend /var/www/swasth/prod/backend` and `… /var/www/swasth/staging/backend`
- Create per-env venvs: `python3 -m venv /var/www/swasth/prod/venv && …/prod/venv/bin/pip install -r /var/www/swasth/prod/backend/requirements.txt` (same for staging).
- Copy the correct `.env` into each: prod's existing `.env` → `prod/backend/.env`; build `staging/backend/.env` with `DATABASE_URL=<swasth_staging>` + `SERVER_PORT=8008`.
**Done when:** both new trees exist with working venvs; `prod/venv/bin/python -c "import main"` imports clean against the prod `.env`. Running processes still untouched.
**Rollback:** `rm -rf /var/www/swasth/prod /var/www/swasth/staging` — nothing live changed.
**Blocks:** Step 2, 3.

### Step 2: Cut STAGING over to its new dir first (lowest risk — staging has no patients)
**Context brief:** Validate the whole split on staging before prod. Staging serves no patients; an error here is safe.
**Changes:**
- `pm2 delete swasth-staging`
- `cd /var/www/swasth/staging/backend && DATABASE_URL=<swasth_staging> SERVER_PORT=8008 /var/www/swasth/staging/venv/bin/pm2 start "python3 -B main.py" --name swasth-staging` (or via ecosystem file — see Step 5).
- `pm2 save`
**Done when:** `curl https://staging-api.swasth.health/health/ready` → 200; staging logs clean; `pm2 jlist` shows `swasth-staging cwd=/var/www/swasth/staging/backend`.
**Rollback:** `pm2 delete swasth-staging` then restart it with `--cwd /var/www/swasth/backend` (old shared dir, still intact).
**Blocks:** Step 3.

### Step 3: Cut PROD over to its new dir (the sensitive one — minimal downtime)
**Context brief:** prod serves real patients. `pm2 restart` reloads in ~1–2s. Do this at a low-traffic window. `/health/ready` must be green before and after.
**Changes:**
- Confirm `prod/backend/.env` has the **prod** `DATABASE_URL` (swasth_prod) and prod web build flavor expectations.
- `pm2 delete swasth-backend && cd /var/www/swasth/prod/backend && /var/www/swasth/prod/venv/bin/pm2 start "python3 -B main.py" --name swasth-backend` (port 8444/whatever prod uses), `pm2 save`.
- Immediately: `curl https://api.swasth.health/health/ready` → expect `{"status":"ready"}`; `curl …/health` → 200; a real `check-account` → 200.
**Done when:** prod readiness green, `pm2 jlist` shows `swasth-backend cwd=/var/www/swasth/prod/backend`, login works.
**Rollback (fast):** `pm2 delete swasth-backend && cd /var/www/swasth/backend && pm2 start "python3 -B main.py" --name swasth-backend` — the legacy shared dir is still intact and at schema head, so this restores the last-known-good in seconds.
**Blocks:** Step 4.

### Step 4: Rewrite `pipeline.yml` deploy targets (separate paths + atomic prod)
**Context brief:** `.github/workflows/pipeline.yml`. `deploy-staging-backend` scp target `/var/www/swasth/` must become `/var/www/swasth/staging/`; prod likewise `/var/www/swasth/prod/`. Each ssh step uses its own venv. Prod step already gated by `environment: production`.
**Changes:**
- **Staging job:** scp `source: "backend/"` `target: "/var/www/swasth/staging/"`; ssh: `source /var/www/swasth/staging/venv/bin/activate; cd /var/www/swasth/staging/backend; pip install -r requirements.txt -q; alembic upgrade head` (staging DB via its `.env`/secret); `pm2 restart swasth-staging`.
- **Prod job (atomic + readiness gate):** scp `target: "/var/www/swasth/prod/"`; ssh:
  ```
  set -e
  source /var/www/swasth/prod/venv/bin/activate
  cd /var/www/swasth/prod/backend
  pip install -r requirements.txt -q
  alembic upgrade head            # code + migration in ONE gated unit
  pm2 restart swasth-backend
  for i in $(seq 1 10); do
    curl -fsS https://api.swasth.health/health/ready && break || sleep 3
  done
  curl -fsS https://api.swasth.health/health/ready | grep -q '"status":"ready"' \
    || { echo "❌ readiness failed — rolling back"; pm2 restart swasth-backend; exit 1; }
  ```
- Add `smoke-prod`'s readiness assertion to depend on `/health/ready` (not just `/health`).
**Done when:** a dry-run deploy to staging writes only `staging/`; prod job fails closed if `/health/ready` ≠ ready.
**Rollback:** revert the workflow file; deploys resume to legacy paths (still present until Step 6).
**Blocks:** Step 5.

### Step 5: pm2 ecosystem file committed to the repo (no more ad-hoc `pm2 start`)
**Context brief:** Encode each process's cwd/venv/env/port in `deploy/ecosystem.config.js` so a restart can never pick the wrong dir again.
**Changes:** add `deploy/ecosystem.config.js` with two apps pinned to `prod/backend` and `staging/backend` + their interpreters/envs; deploy steps call `pm2 startOrReload deploy/ecosystem.config.js --only swasth-backend|swasth-staging`.
**Done when:** `pm2 save` reflects ecosystem; a bare `pm2 restart` uses the pinned cwd.
**Blocks:** Step 6.

### Step 6: Decommission the legacy shared dir
**Context brief:** Only after 1 week of clean operation on the new layout.
**Changes:** `chmod -R a-w /var/www/swasth/backend` (freeze) for a few days → then `mv …/backend …/backend.LEGACY` → delete after another week.
**Done when:** nothing references the shared dir; both apps healthy.
**Rollback:** un-freeze / move back (only meaningful before deletion).

## Dependency Graph
Step 1 → Step 2 → Step 3 → Step 4 → Step 5 → Step 6

## Parallel Opportunities
Mostly sequential (cutover safety). Step 4 (pipeline edits, a PR) can be drafted in parallel with Steps 1–3 but must MERGE only after Step 3 succeeds, else CI deploys to dirs that aren't live yet.

## Risks
- **Prod cutover downtime (Step 3):** mitigate — pm2 restart is ~1–2s; do it in a low-traffic window; legacy dir stays as instant rollback.
- **Wrong `.env` in new dir → points prod at staging DB (or vice-versa):** mitigate — verify `DATABASE_URL` per dir BEFORE starting the process; `/health/ready` + a `check-account` smoke confirms the right DB.
- **Disk on t3.micro (20 GB, 38% used):** two venvs + two trees add ~300–500 MB. Fine. Confirm `df -h` before Step 1.
- **pm2 picking old cwd on reboot:** mitigate — `pm2 save` after each cutover + ecosystem file (Step 5) + verify with a controlled `pm2 resurrect` test on staging.
- **CI deploys to new paths before processes are migrated:** mitigate — merge Step 4 ONLY after Step 3 is verified live.
- **Migration that fails mid prod-deploy:** the atomic block uses `set -e` so a failed `alembic upgrade head` aborts BEFORE restart; readiness gate catches a bad restart and the legacy dir is the rollback.

## Estimated Steps: 6 | Critical Path: 1→2→3→4 (5,6 are hardening/cleanup)

## How /health/ready blocks a bad deploy
`/health/ready` runs the deep DB+schema probe (connectivity + a full-row ORM read). The prod deploy's post-restart loop curls it and **fails the job (exit 1)** unless it returns `{"status":"ready"}`. So a deploy that lands code without its migration (the 2026-06-11 failure mode) now turns the deploy RED and pages via the existing `P0_db_down` alert, instead of silently serving 503s.
```
