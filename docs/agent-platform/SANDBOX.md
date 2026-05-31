# Sandbox (WS1) — Option A, swappable

> How agent runs are isolated, and how to swap the backend later. Phase 2 of the upgrade.
> Decision + sizing rationale: `docs/agent-platform/FINDINGS.md`. Containment test:
> `docs/agent-platform/MALICIOUS_TICKET_SPEC.md`.

## The boundary (Option A — GitHub-hosted)
Each agent run executes inside a **fresh, ephemeral GitHub-hosted runner VM** (destroyed after the
job). On top of that base isolation we layer, in order of importance:

1. **Network egress allowlist** — `step-security/harden-runner` in the worker. **Primary leak
   control.** Currently `egress-policy: audit` (records every outbound connection without blocking)
   so we learn the real baseline. A later reviewed change flips it to `block` with the observed
   allowlist (GitHub API, Anthropic API, pip/PyPI, pub.dev). The Security/PHI reviewers are
   defence-in-depth on top — never the only line.
2. **Per-task scoped credentials** — *deferred* (needs AWS OIDC = IAM change, confirm-before per
   brief §7). Until then the worker uses repo secrets, with `permissions:` tightened to
   least-privilege (`contents: write`, `pull-requests: write`, `actions: read`, no `id-token`).
3. **WS2 PreToolUse guards** (`.claude/settings.json`) — set on the agent steps via env:
   - `SWASTH_AGENT_WORKTREE=${{ github.workspace }}` + `SWASTH_AGENT_WORKTREE_MODE=audit` →
     `hook-guard-worktree.sh` logs writes outside the workspace.
   - `SWASTH_AGENT_SANDBOX=audit` → `hook-guard-command.sh` logs commands outside the safe allowlist.
   - Plus the always-on `hook-guard-config-edit.sh` (gate-file edits) and `hook-guard-destructive.sh`.

### Audit-first rollout
Both the egress policy and the command/worktree guards start in **audit** mode. They observe and log
without blocking, so a false-positive can't break a live ticket. After one or two real worker runs we
read the logs, finalise the allowlists, and flip to **enforce** (egress `block`; drop the
`SWASTH_AGENT_*_MODE=audit` overrides so the guards default to blocking) in a separate reviewed PR.
This mirrors how harden-runner itself is meant to be adopted.

## The swappable seam
`.claude/scripts/sandbox/run-in-sandbox.sh` is the single indirection point. The orchestrator runs an
agent task *through* it; the `SANDBOX_BACKEND` env selects the backend:

| Backend | Status | Boundary |
|---|---|---|
| `github` (default) | implemented | ephemeral runner + egress allowlist + scoped creds + WS2 guards |
| `daytona` | reserved | pay-as-you-go managed dev sandbox |
| `northflank` | reserved | pay-as-you-go managed sandbox |
| `firecracker` | reserved | self-hosted microVM on a dedicated agent host |

Unimplemented backends **fail loud** (exit 2) — they never silently fall back to unsandboxed
execution. Swapping later = implementing one branch in that script; the rest of the pipeline is
untouched. **Do not adopt E2B** ($150/mo base) or provision a per-agent EC2 (brief §2).

## Acceptance (collected on the first audit run)
Run the `MALICIOUS_TICKET_SPEC.md` cases as a planted ticket and confirm from the run logs:
- **TC1 exfiltration** → harden-runner audit log shows the outbound attempt to the attacker host;
  once in block mode it is refused. No secret leaves.
- **TC3 gate tamper** → `hook-guard-config-edit.sh` blocks edits to `.github/workflows/*` etc.
- **TC4 worktree escape** → `hook-guard-worktree.sh` logs (audit) / blocks (enforce) the out-of-
  workspace write.
- **TC5 arbitrary shell** → `hook-guard-command.sh` logs (audit) / blocks (enforce) `curl|bash`, `nc`.
Record run IDs + log excerpts here when the first audit run completes.

## Known follow-ups (before flipping to enforce)
- **Confirm the action honors project hooks.** Verify on the first worker run that
  `AUDIT (...)` lines from `hook-guard-command.sh` / `hook-guard-worktree.sh` actually appear in the
  `claude-code-action` log. If the action does not load `.claude/settings.json` PreToolUse hooks, the
  `SWASTH_AGENT_*` env vars are inert and the guards must be invoked another way.
- **harden-runner at enforce time:** add StepSecurity's telemetry endpoint to the allowlist (or set
  `disable-telemetry: true`), consider `disable-sudo: true` if builds don't need sudo, and SHA-pin
  the action (`step-security/harden-runner@<sha>`) — it's the egress control, so pin it.
- **`actions: read`** assumes the worker never self-dispatches. If a run fails with an Actions
  permission error, revert that one line to `actions: write` (the producer-triggers-worker model
  should not need it).

