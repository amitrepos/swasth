# Branch & Deployment Rules (ENFORCED BY HOOKS — NOT JUST DOCS)

> Moved out of `CLAUDE.md` (Phase 1c). The hooks are the spec; this doc is the human-readable map.
> Enforced by `.githooks/pre-commit`, `.githooks/pre-push`, `.claude/scripts/orphan-scan.sh`
> (session start), and `.github/workflows/branch-hygiene.yml` (CI). Violating any of them stops the
> commit / push / merge immediately.

## Branch Hygiene
- **ALWAYS** start from fresh master. Prefer `git scb <branch>` (creates a branch from fresh
  `origin/master`; refuses if local master is stale or the tree is dirty) over `git checkout -b`.
  ```bash
  git checkout master && git pull origin master
  git scb feature/your-feature-name
  ```
- **STOP using a branch the moment its PR merges.** The pre-commit hook refuses
  (`gh pr list --state merged --head <branch>`). Recovery: `git stash` → checkout+pull master →
  `git scb <new-branch>` → `git stash pop`.
- **Every push must have an open PR.** pre-push blocks ahead-of-origin branches with no open PR.
  First push of a fresh branch: rerun once with `SWASTH_ALLOW_BRANCHLESS_PUSH=1`, then
  immediately `gh pr create --fill`.
- **NEVER** branch from another feature branch. **NEVER** cherry-pick across feature branches.
- If master advanced: `git rebase origin/master`.

## First-time setup on a fresh clone
```bash
git config core.hooksPath .githooks
git config alias.scb '!bash .claude/scripts/scb.sh'
```
CI's `branch-hygiene.yml` blocks the PR if `.githooks/` scripts are missing or non-executable.

## Drift Prevention Protocol
**Layer 1 — deterministic hooks (strongest):**
- `git scb <branch>` — fresh-master branch creation.
- `.githooks/pre-push` — refuses a push if any branch commit's `git patch-id` is already on master
  (orphan-commit detection).
- `.githooks/pre-commit` (Gate 2) — refuses any commit changing `backend/models.py` without a new
  Alembic migration in the same commit (CI re-runs `alembic upgrade head` + `alembic check` via
  `.github/workflows/migration-check.yml`). No-op escape hatch: `SWASTH_NO_MIGRATION_NEEDED=1`.
- **WS2 config protection** (`.claude/scripts/hook-guard-config-edit.sh`) — Edit/Write to a
  gate/policy file fails closed; deliberate edits use `SWASTH_BYPASS_CONFIG_EDIT=1` (audited).

**Layer 2 — verification discipline (always):** after ANY state-changing action, run an observable
verification before the next step. `gh secret set` → hit the live endpoint. `scp` → `ssh stat`.
`pm2 restart` → curl a route. `git scb` → `git log origin/master..HEAD` is empty. **Exit code 0
does NOT prove success — the downstream surface working proves success.**

**Layer 3 — memory:** `feedback_state_verification.md`, `feedback_quality_over_speed.md` (auto-loaded).

**Meta-rule:** "Quality over speed. We handle health data." One atomic change, verified, then the next.

## Domain Expert Review Matrix
The canonical matrix is data in `.claude/reviewers-matrix.json`. It is **enforced** by
`.claude/scripts/check-required-reviewers.sh` (pre-commit), which inspects the staged diff, computes
the required experts, and blocks until each has written a content-hash-keyed marker under
`.claude/markers/` (gitignored; auto-invalidated on staged change). The bash script is the current
enforcement; the JSON is the source of truth they must stay in sync with (wiring the script to read
the JSON directly is deferred to a later phase, with tests).

- **Meera (necessity)** is **NOT** in the commit-time matrix — she runs at the **intake gate** now
  (validate before building; see `docs/agent-platform/SKILLS_AUDIT.md`).
- **Aditya vs Sunita** — not redundant. Aditya = UX heuristics (touch targets, contrast, fonts);
  Sunita = lived experience of a 55yo Ranchi patient (comprehension, Hindi naturalness, emotional
  register). Both review every patient-facing change. (`ux-review`/`ux-expert` merged into `aditya`.)
- **Daniel is always last** — final correctness/security/architecture gate.
- **Hard block on Must Fix** — any expert's Must Fix blocks the commit; fix, restage, rerun the chain.

After a PASS verdict: `.claude/scripts/write-review-marker.sh <expert>`
where `expert ∈ {sunita, aditya, doctor, daniel, phi, legal, security, priya}`.

## Server Deployment — AWS Mumbai (ap-south-1)
Production is **AWS Mumbai**, EC2 `swasth-prod` (`i-09f5154e94406f5f4`, t3.micro), Elastic IP
`13.127.215.113`. **Hetzner `65.109.226.36` is decommissioned — do not SSH it.** Source of truth for
AWS objects: `docs/aws/AWS_ARTIFACTS.md`.
- **ALWAYS** build from master (or a branch up-to-date with master). **NEVER** deploy from a stale
  feature branch (overwrites other merged PRs).
```bash
git checkout master && git pull origin master
flutter build web --release --target lib/main_production.dart --dart-define=SERVER_HOST=https://api.swasth.health
scp -i ~/.ssh/swasth-prod-key.pem -r build/web/* ec2-user@13.127.215.113:/var/www/swasth/web/
```
> Note: prod web build MUST pass `--target lib/main_production.dart`, else the bundle defaults to
> staging (2026-05-14 login-break incident).

Backend changes:
```bash
scp -i ~/.ssh/swasth-prod-key.pem backend/<changed_file>.py ec2-user@13.127.215.113:/var/www/swasth/backend/
# Apply new migrations BEFORE restart so new code never sees the old schema (alembic upgrade head is idempotent).
ssh -i ~/.ssh/swasth-prod-key.pem ec2-user@13.127.215.113 "cd /var/www/swasth/backend && alembic upgrade head"
ssh -i ~/.ssh/swasth-prod-key.pem ec2-user@13.127.215.113 "kill \$(lsof -ti :8007); sleep 2; cd /var/www/swasth/backend && nohup python3 -B main.py > /var/log/swasth-backend.log 2>&1 &"
```

## Pre-PR Checklist (run ALL before pushing)
```bash
flutter analyze --no-pub                              # Zero errors
flutter test test/flows/ --timeout 30s                # All E2E tests pass
flutter test                                          # All Flutter tests pass
cd backend && source venv/bin/activate
TESTING=true python -m pytest tests/ -v               # All backend tests pass
TESTING=true python -m pytest tests/ --cov=. --cov-report=term-missing  # Coverage >=85%
```
