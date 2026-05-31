#!/usr/bin/env bash
# Thin, SWAPPABLE sandbox interface (WS1, Option A).
#
# The orchestrator/worker calls THIS script to run an agent task inside a sandbox. The point of the
# indirection is that the *backend* can change (config only) without touching the pipeline:
#
#   SANDBOX_BACKEND=github      → the GitHub-hosted ephemeral runner IS the sandbox (default, $0).
#                                 We add egress allowlist (harden-runner) + per-task scoped creds +
#                                 the WS2 PreToolUse guards on top. This is Option A.
#   SANDBOX_BACKEND=daytona     → (future) provision a Daytona dev-sandbox, run there, tear down.
#   SANDBOX_BACKEND=northflank  → (future) same shape on Northflank.
#   SANDBOX_BACKEND=firecracker → (future) self-hosted microVM on a dedicated agent host.
#
# Only `github` is implemented today. The others intentionally fail loud so nobody assumes a
# stronger boundary than exists. Adding one later means implementing its branch here — nothing else
# in the pipeline changes.
#
# Contract: receives the command to run as "$@", runs it inside the sandbox boundary, returns its
# exit code. Per-task ephemerality and teardown are the backend's responsibility.
set -euo pipefail

BACKEND="${SANDBOX_BACKEND:-github}"

case "$BACKEND" in
  github)
    # On a GitHub-hosted runner the job itself is the ephemeral sandbox: fresh VM per run, destroyed
    # after, writable area confined to the workspace. The boundary is built up by, in order:
    #   1. step-security/harden-runner (network egress allowlist)   — workflow step, primary control
    #   2. per-task scoped creds (OIDC; deferred)                   — workflow
    #   3. WS2 PreToolUse guards (worktree + command allowlist)     — .claude/settings.json
    # So here we simply execute the task; the boundary is already in place around us.
    exec "$@"
    ;;
  daytona|northflank|firecracker)
    echo "sandbox backend '$BACKEND' is not implemented yet (seam reserved — see docs/agent-platform/SANDBOX.md)." >&2
    echo "Do NOT fall back to running unsandboxed. Implement the backend or use SANDBOX_BACKEND=github." >&2
    exit 2
    ;;
  *)
    echo "unknown SANDBOX_BACKEND='$BACKEND'. Valid: github | daytona | northflank | firecracker." >&2
    exit 2
    ;;
esac
