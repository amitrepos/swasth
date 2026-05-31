# Agent Platform Upgrade — Phase 0 Findings

> Discovery note for the upgrade described in `docs/AGENT_PLATFORM_UPGRADE_BRIEF (1).md`.
> Read-only current-state map + sizing math + the sandbox decision. No changes made by this doc.

## 1. Current-state map

### Path A — human-authored changes
- `git config core.hooksPath .githooks` wires **pre-commit** + **pre-push**.
- **pre-commit** gates: (1) branch-hygiene (refuse commits on a branch whose PR already merged),
  (2) migration-required (`models.py` change needs an Alembic migration —
  `.claude/scripts/check-migration-required.sh`), (2.5) agent-branch policy for `feat/nuo-*`,
  (3) domain-expert review chain (`.claude/scripts/check-required-reviewers.sh`).
- **Markers:** `.claude/markers/.review-<expert>-<HASH>` where
  `HASH = sha256(git diff --cached)[:12]` (`.claude/scripts/write-review-marker.sh`). Gitignored;
  auto-invalidated when staged content changes. ~265 markers on disk today.
- **pre-push** gates: agent-branch policy (push mode), branch-hygiene, orphan-commit detection
  (`git patch-id --stable` vs last 100 master commits), open-PR check, scoped backend/Flutter tests.

### Path B — JIRA-driven changes
JIRA label `agent:matt` → `repository_dispatch` → workflows:
1. `jira-agent-trigger.yml` (producer) — Priya Gate A ticket-quality (`/priya-ticket-quality`);
   PASS/REWRITTEN → enqueue to `jira-work-queue.json`; NEEDS_INFO → post questions, drop label.
2. `jira-agent-worker.yml` (**single-concurrency** `group: jira-agent-worker`) — pop queue, token
   budget pre-flight (`scripts/check_token_budget.py`, probes Anthropic rate-limit headers, defers
   on insufficient quota), create `feat/nuo-<ticket>-<ts>` branch, Matt implements + coverage loop,
   regression gate (`scripts/check_no_regression.sh`: churn → unit → integration → smoke → baseline
   diff vs `.claude/test-baseline.json`), Priya `/qa-review`, rebase, open **draft PR**.
3. `daniel-pr-review.yml` — `/daniel-review`, severity-gated (CRITICAL → request-changes; else
   comment; never approves from CI).
4. `jira-agent-pr-closed.yml` — on merge: JIRA → Done.
5. `rollback-pr.yml` — manual revert-PR backstop.
- Queue state lives on a **remote orphan branch** `automation-state`
  (`jira-work-queue.json`, `agent-budget-log.json`, `queue-status.md`), written atomically by
  `scripts/write_to_automation_state.sh` (rebase-retry loop).

### Skills
21 skill folders in `.claude/skills/`. 9 wired to commit-time markers (aditya, daniel, doctor,
legal, phi, priya/qa, meera/reality-check, security, sunita). Only `priya-ticket-quality` ends with
a machine-parseable `VERDICT:` line. Full disposition in `SKILLS_AUDIT.md`.

### Claude Code config
- Only `.claude/settings.local.json` exists (no `settings.json`). Hooks: PreToolUse(Bash) blocks
  `--no-verify`; PreToolUse(Edit|Write) **only warns** on config/CI edits (does **not** block);
  PostToolUse auto-format + AUDIT.md log; SessionStart/Stop/PreCompact housekeeping.
- **Gap:** no deterministic hook blocks edits to gate/config files or writes outside a worktree.
- `CLAUDE.md` is 480 lines — large prose ruleset (G3: probabilistic).

## 2. Infrastructure reality (corrects the brief)

The brief assumes *"one GitHub Actions self-hosted runner on a single basic EC2."* Actual state:

- **Compute for agents:** all 19 workflows use `runs-on: ubuntu-latest` (**GitHub-hosted**,
  ephemeral). **No self-hosted runner exists.**
- **Production server:** AWS Mumbai `ap-south-1`, EC2 `swasth-prod` (`i-09f5154e94406f5f4`,
  **t3.micro** ≈ 1 GiB RAM / 2 vCPU burstable), Elastic IP `13.127.215.113`. Source of truth:
  `docs/aws/AWS_ARTIFACTS.md`.
- **Hetzner `65.109.226.36` is decommissioned.** CLAUDE.md's "Server Deployment" section still uses
  Hetzner-era wording though the IP is the AWS box — **stale, fixed in Phase 1c.**

## 3. Sizing math

| Need | vCPU | RAM |
|---|---|---|
| One agent sandbox running builds/tests | ~2 | 2–4 GB |
| cap=2 sandboxes | ~4 | 4–8 GB |
| + runner/orchestrator overhead | +1 | +1 GB |
| **Total to co-host on prod box** | **~5** | **~5–9 GB** |
| **t3.micro actually has** | 2 (burst) | **1 GiB** |

**Conclusion:** the t3.micro **cannot** host cap=2 sandboxes — and it is the production box, so it
must not co-host agents regardless. Provisioning Firecracker/Kata on it is not viable.

## 4. Sandbox decision — Option A (locked with Amit, this session)

Keep agents on **GitHub-hosted ephemeral runners** as the isolation boundary. Layer on top:
- **Default-deny egress allowlist** (proxy: GitHub API, Anthropic API, pip/pub registries only).
- **Per-task short-lived scoped credentials** via OIDC — no standing JIRA/GitHub/Anthropic/AWS
  secrets sitting in the job.
- **Writes confined to the assigned worktree**; agent cannot touch hooks/workflows/markers.
- A thin **swappable `sandbox` interface** so Firecracker / Daytona / Northflank can replace the
  GitHub-hosted backend later with a config change — no pipeline rewrite.

**Why Option A over the alternatives:**
- **B (co-host on t3.micro, gVisor, cap=1):** OOM + production contention on a 1 GiB box. Rejected.
- **C (resize to t3.large or a dedicated agent EC2, Firecracker cap=2):** ~$60/mo + new infra +
  IAM/SG work. Deferred — revisit when volume or data-sensitivity rises.

**Cost delta:** ≈ **$0** new infra now; only GitHub Actions minutes at cap=2. t3.micro untouched.

**Documented trade-off:** a GitHub-hosted runner kernel is **shared-tenant** (not a microVM-strong
boundary like Firecracker). Acceptable at cap=2 for a pre-launch pilot. The egress allowlist + OIDC
scoping are the **primary** leak controls; Security/PHI reviewers are defence-in-depth on top.

## 5. Gaps → workstream mapping
G1 sandboxing → WS1 (Option A) · G2 serial → WS3 (cap=2 worktrees) · G3 prose rules → WS2 hooks +
shrink CLAUDE.md · G4 self-cert markers → WS4 independent PR-time review · G5 broad creds → WS1 OIDC
· G6 late validation → WS5 intake gate · G7 no auto-merge → WS6 auto-merge + sensitive-tier gate.

## 6. Open items (confirm with Amit)
- Concurrency locked at **2** (t3.micro out of scope under Option A).
- JIRA status names if they differ from `Backlog → Needs Clarification → Ready for Dev →
  In Progress → In Review → Done`.
- Exact "sensitive diff" globs for WS6 (draft in Phase 5).
- `council` retired from pipeline, kept standalone — confirm.
