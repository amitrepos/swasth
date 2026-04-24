# PII Encryption Batch — Deployment Runbook (E17)

**Authorization:** Amit, 2026-04-24. Pre-pilot, zero live users. Destructive.

**Scope:** Single migration (`0006_pii_encryption_batch`) that:
1. TRUNCATEs every table containing PII or FK-dependent data.
2. Drops all plaintext PII columns.
3. Adds `*_enc` (AES-256-GCM) and `*_hash` (HMAC-SHA256) columns.
4. Adds `DoctorProfile.{phone_number, whatsapp_number}` contact cols.
5. Adds `DoctorPatientLink.is_primary` + partial unique index.
6. Replaces OTP plaintext columns with HMAC `otp_hash`.

## Prerequisites

- `PII_ENCRYPTION_KEY` set in the target env (GitHub Secret → deployed env var).
  - Generate: `python -c "import secrets; print(secrets.token_hex(32))"`
  - Dev and prod must have DIFFERENT keys — a dev leak must not expose prod.
- `ENCRYPTION_KEY` (SPDI) already exists. Do not rotate in this deploy.
- Local copy of the test-account credentials (Amit + 2 test doctors) —
  hardcoded in `backend/seeds/pii_seed.py`.

## Deploy order: **pre-prod first, then prod.**

### 1. Pre-prod (dev server `:8443`, DB `swasth_db`)

```bash
# a) Set the new secret. DO NOT use the GitHub UI — key corruption.
gh secret set PII_ENCRYPTION_KEY --env dev --body "$(python -c 'import secrets; print(secrets.token_hex(32))')"

# b) Verify the secret is applied (value not echoed, just presence)
gh api "/repos/amitrepos/swasth/actions/environments/dev/secrets" --jq '.secrets[] | .name' | grep PII_ENCRYPTION_KEY

# c) Merge the feature branch → CI auto-deploys to :8443 and runs
#    `alembic upgrade head`. The migration TRUNCATEs everything.

# d) SSH in and run the seed script
ssh -i ~/.ssh/new-server-key root@65.109.226.36 <<'EOF'
cd /var/www/swasth/backend
source venv/bin/activate
python seeds/pii_seed.py
EOF

# e) Observable verification — DO NOT stop at exit-code-0.
ssh -i ~/.ssh/new-server-key root@65.109.226.36 \
  'psql $DATABASE_URL -c "SELECT COUNT(*) FROM users; SELECT email_enc FROM users LIMIT 1;"'
# Expect: COUNT ≥ 3, email_enc is a base64 blob, not plaintext.

# f) Smoke-test login via the live API
curl -k -X POST https://65.109.226.36:8443/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"amitkumarmishra@gmail.com","password":"Test@1234"}' | jq .access_token
# Expect: a JWT. 401 means the seed or the login hash path is broken.
```

### 2. Prod (dev server `:8444`, DB `swasth_prod`)

**Only after pre-prod has run for ≥ 30 minutes with no errors** and smoke
tests pass.

```bash
# a) Set the prod secret (DIFFERENT value from dev)
gh secret set PII_ENCRYPTION_KEY --env production --body "$(python -c 'import secrets; print(secrets.token_hex(32))')"

# b) CI deploy runs alembic upgrade on swasth_prod → TRUNCATE + schema change
# c) SSH + seed
ssh -i ~/.ssh/new-server-key root@65.109.226.36 \
  'cd /var/www/swasth/backend && source venv/bin/activate && python seeds/pii_seed.py'

# d) Observable verification + smoke test on :8444
# e) Announce in team channel: "prod PII encryption at rest live, all test users reseeded"
```

## Rollback

The migration is **not reversible by Alembic downgrade** — plaintext was
dropped and data was truncated. If rollback is required:

1. Stop the backend.
2. `pg_restore` the pre-migration backup (taken automatically by CI pre-deploy).
3. Verify backup integrity via a canary query:
   `psql -c "SELECT email FROM users LIMIT 1"` — should return plaintext.
4. Re-deploy the previous code commit.
5. Post-mortem: open a ticket describing what failed and why.

## Known side-effects

- Re-issued JWTs: none (JWTs carry `sub=email`, which still resolves via the
  hash lookup). Existing tokens minted before truncate will 401 because the
  user row was deleted — expected behaviour, clients must re-login.
- WhatsApp inbound flow: reseed phone → `phone_hash` must match the number
  the patient sends from. Verify by sending a test photo post-seed.
- Doctor directory: sorts alphabetically in Python after fetch (can't
  ORDER BY on ciphertext). O(N) sort — acceptable for < 10k doctors.

## Post-deploy checks (72-hour soak)

- [ ] Login latency p95 < 500ms (hash index working).
- [ ] No 500s on `/api/auth/login`, `/api/auth/register`, `/api/profiles`.
- [ ] `psql -c "SELECT email, full_name, phone_number FROM users"` returns
      `ERROR: column "email" does not exist`. Confirms plaintext is gone.
- [ ] Alert dispatch still lands in test doctor's email + WhatsApp.
- [ ] DoctorPatientLink `is_primary` defaulting to `false` on all new rows.
