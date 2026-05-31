# Skills Audit — WS9

> Reconciles the 21 inherited skills in `.claude/skills/` to the single coherent design in the
> brief's §5/§5.4. Buckets: **pipeline** (wired into JIRA→PR flow), **standalone** (user-invocable,
> not in pipeline), **retire/merge** (deleted), plus the disposition verbs from the brief
> (KEEP / KEEP+EXTEND / KEEP+REPOSITION / MERGE / STANDALONE / RETIRE).

## Disposition table

| Skill (folder) | Role | Disposition | Action |
|---|---|---|---|
| `priya-ticket-quality` | Intake gate owner | **KEEP+EXTEND** | After quality PASS, invoke Meera+Sunita+Doctor; fold into ONE `VERDICT: needed\|needs-clarification\|not-needed`. Keep verbatim-evidence + verify-script pattern. |
| `reality-check` (Meera) | Intake necessity | **KEEP+REPOSITION** | Move from commit-time marker → intake. Remove `write-review-marker.sh meera`; emit verdict to Priya; add `VERDICT: GREEN\|YELLOW\|RED`; prune founder-coaching from per-ticket path; read live state, not dated facts. |
| `sunita` | Intake desirability + delivery acceptance | **KEEP** | Runs at both stages with different questions. Add `VERDICT:` line. |
| `doctor-feedback` | Clinical necessity + domain review | **KEEP** | Dr. Ramesh. Intake (necessity) + review (domain correctness). Add `VERDICT:` line. |
| `daniel-review` | Code review (final gate) | **KEEP** | Severity-gated; emits status check (WS4/WS6). Add `VERDICT:` line. |
| `security-audit` | Security | **KEEP** | Mandatory-blocking on auth/data diffs. Add `VERDICT:` line. |
| `phi-compliance` | Data-protection | **KEEP** | Mandatory-blocking on data-touching diffs. Add `VERDICT:` line. |
| `legal-check` | Compliance | **KEEP** | Blocks on relevant diffs. Add `VERDICT:` line. |
| `qa-review` | Priya's review hat | **KEEP** | Same persona as `priya-ticket-quality`, different hat (test quality). Add `VERDICT:` line. |
| `aditya` | UX / a11y reviewer | **KEEP** | Survivor of the UX consolidation. Add `VERDICT:` line. |
| `ux-review` | UX | **MERGE → `aditya`** | Confirmed exact duplicate ("Healthify" framing, same 7-point rubric). Migrate any unique line, then delete. |
| `ux-expert` | UX (data-viz) | **MERGE → `aditya`** | 17-line truncated SKILL.md (Linear/Stripe benchmark, 8px grid, Nielsen heuristics). Migrate the unique data-viz/heuristic bullets into `aditya`, then delete. May seed Richa later — noted, not kept. |
| `vc-investor` (Vikram) | Fundraising advisor | **STANDALONE** | User-invocable; **not** wired into JIRA→PR. |
| `council` | Multi-persona convener | **RETIRE from pipeline** | Read confirms a **debate-to-consensus engine** (Architect/Skeptic/Pragmatist/Critic, adversarial synthesis) — *not* a simple "invoke N + summarize" helper. So Priya's aggregator is built directly, **not** on council. Keep council STANDALONE if desired; do not wire deliberation into the pipeline. |
| `tdd-workflow` | Build/test loop | **KEEP** | Matt's build-loop process skill. |
| `verify` | Verification | **KEEP** | Supports the WS4 independent-review gate; classify as pipeline-support. |
| `ship` | Release/merge | **KEEP+RECONCILE** | Strip the older "always-human-merge" assumption; align with WS6 auto-merge policy (done in Phase 5). |
| `blueprint` | Planning | **KEEP** | Orchestrator (Matt) planning step. |
| `safety-guard` | Guardrails | **FOLD → WS2 hooks** | Overlaps the deterministic PreToolUse guardrails (rm -rf, force-push, DROP TABLE). Logic moves into hooks; retire as a pipeline skill (may remain user-invocable). |
| `strategic-compact` | Context housekeeping | **STANDALONE** | Not pipeline. |
| `learn` | Learning/retro | **STANDALONE** | Not pipeline. |
| `matt` | Sole builder + orchestrator | **CREATE (Phase 6)** | No skill folder today; Matt is the worker agent. Add a `matt` orchestrator skill carrying generalist-build + orchestrator role (WS3). Richa/Karan **DEFERRED** — routing seam only. |

## Duplication resolved
- **Three UX skills** → one survivor `aditya`. `ux-review` (exact dup) + `ux-expert` (truncated)
  merged in and deleted.
- **council vs Priya-aggregation** → not redundant; council is deliberative, Priya is an aggregator.
  council leaves the pipeline; Priya's aggregator is implemented directly.
- **qa-review vs priya-ticket-quality** → same persona (Priya), two distinct hats — both kept.

## Verdict-format requirement
Every **pipeline** skill ends with one machine-parseable verdict line (model: the
`priya-ticket-quality` `VERDICT:` pattern), so the orchestrator and WS6 status-check gating consume
it deterministically. Reviewer skills must **not** self-certify their own markers (WS4 — enforced at
PR time in CI, not on the author's machine).

## Final shape after Phase 1
- **Pipeline (intake):** priya-ticket-quality (owner) · reality-check/Meera · sunita · doctor-feedback.
- **Pipeline (review):** daniel-review · security-audit · phi-compliance · legal-check · qa-review ·
  aditya · sunita · doctor-feedback · verify (support) · tdd-workflow (build) · blueprint (plan).
- **Standalone:** vc-investor · council · strategic-compact · learn · safety-guard (as user tool).
- **Deleted:** ux-review · ux-expert.
- **Deferred:** matt (Phase 6) · richa · karan.
