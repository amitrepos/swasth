# Merge Policy (WS6) — auto-merge on green, human gate for sensitive

> Phase 5. Fixes G7 (no auto-merge): a clean low-risk PR merges with no human; a sensitive PR holds
> for human approval. Eval-gated and reversible.

## Behaviour
- **Low-risk** diff + eligible (agent/bot) author → GitHub **native auto-merge** enabled
  (`gh pr merge --auto --squash`). GitHub merges once all required checks pass — it respects branch
  protection, so nothing merges red.
- **Sensitive** diff (auth · data/PHI · migrations · logging/serialization · infra — see
  `sensitive_globs` in `.claude/reviewers-matrix.json`) → auto-merge **not** enabled; the PR holds
  for a human. This is a **temporary, eval-gated** measure: as the Security/PHI evals mature, shrink
  the sensitive set rather than keeping a permanent human gate. Treat any escaped defect as a signal
  to strengthen the eval.
- Human-authored PRs are not auto-merged (authors merge their own).
- The **rollback workflow** (`rollback-pr.yml`) remains the backstop.

## Sensitive-diff definition (DRAFT — confirm with Amit, brief §10)
`scripts/classify_diff_sensitivity.py` reads `sensitive_globs`:
- **auth:** `backend/{auth,dependencies,routes,routes_admin}.py`
- **data_phi:** `backend/{models,schemas,encryption_service,ai_service,routes_health,health_utils,routes_meals,routes_doctor}.py`
- **migrations:** `backend/migrations/`
- **logging_serialization:** `*log*.py`, `*serial*.py`, `schemas.py`
- **infra:** `.github/workflows/`, `.githooks/`, `deploy/`, `Dockerfile`, `backend/requirements.txt`,
  `pubspec.yaml`, `.claude/settings.json`, the gate scripts.

## Rollout (feature-flagged, currently OFF)
The `auto-merge.yml` workflow is live but in **DRY-RUN** until enabled — it classifies, logs, and
comments its decision without enabling any merge. To turn it on:
1. **Confirm the sensitive globs above** (this is the brief's open item).
2. Repo setting: enable **Allow auto-merge**.
3. Branch protection on `master`: require the status checks that must gate merge — at minimum
   `persona-review/security` and `persona-review/phi` (from Phase 4 / WS4) plus existing CI. *(This
   is the operator/GitHub-config step — confirm before applying; it changes merge gating for everyone.)*
4. Set the flag: `gh variable set SWASTH_AUTO_MERGE --body on`.
   Optionally `gh variable set SWASTH_AUTOMERGE_AUTHORS --body '<bot logins>'`.

## Rollback
`gh variable set SWASTH_AUTO_MERGE --body off` (or delete it) → back to DRY-RUN; nothing auto-merges.
Fully reversible; no code revert.

## Safety notes
- `auto-merge.yml` uses `pull_request_target` but **never checks out or runs PR code** — it reads the
  changed-file *list* via the API and runs the classifier from the trusted base. Safe against
  poisoned PRs.
- Auto-merge only ever merges when **branch protection is satisfied**; it cannot bypass a required
  human review or a red check.
