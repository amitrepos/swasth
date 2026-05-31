# Independent PR-time Review (WS4) — the gate of record

> Phase 4. A change cannot merge on markers its author (human or agent) wrote. The reviewer personas
> run **in CI against the PR diff**, independent of whoever produced the code, and each emits a
> **commit status check**. Fixes G4 (self-certification).

## Why this is the gate of record
- Local markers (`.claude/markers/.review-*`) gate only the **local pre-commit** hook. They are
  **gitignored and never pushed**, so they cannot influence what merges. An agent that tampers with
  its own markers changes nothing about the PR's mergeability.
- `pr-persona-review.yml` recomputes the required reviewers from the diff and runs each persona
  fresh in CI. Those status checks — not any author artifact — are what branch protection consults.

## How it works
1. **select** job: `git diff base..head` → `scripts/compute_required_reviewers.py` reads the
   data-driven matrix (`.claude/reviewers-matrix.json` `globs`) → the required expert set (Daniel
   excluded; he keeps `daniel-pr-review.yml`).
2. **review** matrix job (one leg per expert): reads `.claude/skills/<skill>/SKILL.md` (source of
   truth), reviews `.agent-tmp/pr.diff`, writes `VERDICT: PASS|BLOCK`, posts the review as a PR
   comment, and emits a commit status `persona-review/<expert>`.
   - `PASS` → status **success**; `BLOCK` → status **failure**.
   - **Mandatory-blocking** experts (`security`, `phi`, per the matrix) **fail closed** if no verdict
     is produced. Others also surface a failure status if they don't complete.
3. Each persona runs the **cheap model** (sonnet) per the model-tiering decision.

## Making them required (Phase 5 / WS6)
Status checks are emitted now but are **advisory** until branch protection is updated to **require**
`persona-review/security` and `persona-review/phi` on sensitive diffs (auth/data/PHI/migrations).
That, plus auto-merge, is Phase 5. Until then they inform reviewers without blocking.

## Known follow-ups
- **Re-sync comment noise:** each push re-posts persona comments. Consider updating a single comment
  per persona instead of appending. (Concurrency cancels in-flight runs, limiting duplication.)
- **Fork PRs:** the default `GITHUB_TOKEN` is read-only for fork PRs and cannot write statuses. Agent
  PRs are internal branches, so this is fine; revisit if external contributors arrive.
- **Daniel de-dup:** if `daniel-pr-review.yml` is ever folded in here, drop the `grep -v '^daniel$'`.
