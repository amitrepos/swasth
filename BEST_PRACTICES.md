# Claude Code Team Harness — Best Practices

A prescriptive playbook for turning any repo into a production-grade Claude Code workspace with expert review gates, token-efficient responses, session memory, and CI-enforced hygiene.

> **For your Claude Code session:** drop this file at your repo root, then say:
>
> > *"Read `BEST_PRACTICES.md` and implement every section marked `IMPLEMENT` in this repo. Ask me before destructive changes. Skip anything marked `OPTIONAL` unless I say otherwise."*
>
> Claude will create the directory tree, write every script, wire the hooks, and leave a summary of what was installed and what was skipped.

---

## Table of Contents
1. [Why this harness](#1-why-this-harness)
2. [Quick install (5 minutes)](#2-quick-install-5-minutes)
3. [Core concepts](#3-core-concepts)
4. [IMPLEMENT: Settings + permissions](#4-implement-settings--permissions)
5. [IMPLEMENT: Output style (100-word bullet rule)](#5-implement-output-style-100-word-bullet-rule)
6. [IMPLEMENT: Response-cap hooks](#6-implement-response-cap-hooks)
7. [IMPLEMENT: Statusline with compact/fresh-session nudges](#7-implement-statusline-with-compactfresh-session-nudges)
8. [IMPLEMENT: CLAUDE.md skeleton](#8-implement-claudemd-skeleton)
9. [IMPLEMENT: Expert persona — Daniel code reviewer](#9-implement-expert-persona--daniel-code-reviewer)
10. [IMPLEMENT: Session save/load](#10-implement-session-saveload)
11. [IMPLEMENT: Branch hygiene (pre-commit + pre-push)](#11-implement-branch-hygiene-pre-commit--pre-push)
12. [IMPLEMENT: Memory system](#12-implement-memory-system)
13. [OPTIONAL: Domain expert personas](#13-optional-domain-expert-personas)
14. [OPTIONAL: Verification + security audit skills](#14-optional-verification--security-audit-skills)
15. [Principles — why it's shaped this way](#15-principles--why-its-shaped-this-way)
16. [Rollout checklist for your team](#16-rollout-checklist-for-your-team)

---

## 1. Why this harness

Out-of-the-box Claude Code is powerful but undirected. This harness adds:

- **Token efficiency** — 100-word bullet-only replies by default (hooks-enforced), output styles instead of reloaded CLAUDE.md prose, statusline nudges before auto-compaction burns tokens
- **Expert review gates** — file-type → required expert mapping, with pre-commit blocking until each expert has signed off
- **Session persistence** — session state + learnings survive across restarts; no re-explaining context
- **Branch hygiene enforced by hooks, not memory** — commit on a merged branch = blocked; push without PR = blocked; orphan commits detected
- **Reusable across projects** — the structure generalizes; swap in your domain experts

Observed impact on a real project (Swasth Health App, 9 months, ~200 PRs): caught 4 orphan-commit incidents, ~30% fewer permission round-trips after Auto Mode, and reduced average response length from ~400 to ~80 words.

---

## 2. Quick install (5 minutes)

```bash
# 1. From your repo root, open Claude Code:
claude

# 2. Paste:
```

> *"Read `BEST_PRACTICES.md` and implement every section marked `IMPLEMENT`. Use the exact file contents shown. Create directories as needed. After you finish, run `jq empty .claude/settings.local.json` to validate, then show me what you installed."*

Claude will:
1. Create `.claude/`, `.claude/scripts/`, `.claude/output-styles/`, `.githooks/`
2. Write every script with `chmod +x`
3. Merge the settings block into `.claude/settings.local.json` (or create it)
4. Add a `CLAUDE.md` skeleton
5. Wire the git hooks via `git config core.hooksPath .githooks`
6. Report what was installed

**Manual step after Claude finishes:** restart your Claude session so hooks and output style load.

---

## 3. Core concepts

| Concept | What it is | Location |
|---|---|---|
| **Output Style** | Named prompt template applied to every reply | `.claude/output-styles/<name>.md` |
| **Hooks** | Shell scripts that run on events (UserPromptSubmit, Stop, PreCompact, etc.) | `.claude/settings.local.json` → `hooks` |
| **Skills / personas** | Markdown prompts invoked via `/skill-name` | `.claude/skills/<name>/SKILL.md` or as slash-commands |
| **Memory** | Persistent facts across sessions | `~/.claude/projects/<project>/memory/` |
| **Statusline** | Bottom bar with context %, cost, nudges | `.claude/settings.local.json` → `statusLine` |
| **Auto Mode** | Safety-classifier replaces permission prompts | `.claude/settings.local.json` → `permissions.defaultMode: "auto"` |
| **Git hooks** | pre-commit / pre-push gates outside Claude | `.githooks/` + `core.hooksPath` |

---

## 4. IMPLEMENT: Settings + permissions

**File:** `.claude/settings.local.json` (create or merge). The `outputStyle`, `defaultMode`, `hooks.UserPromptSubmit`, `hooks.Stop`, and `statusLine` keys are the four load-bearing pieces.

```json
{
  "outputStyle": "team-concise",
  "permissions": {
    "defaultMode": "auto",
    "allow": []
  },
  "statusLine": {
    "type": "command",
    "command": "${CLAUDE_PROJECT_DIR}/.claude/scripts/statusline.sh",
    "padding": 0
  },
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/scripts/response-cap-injector.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/scripts/save-session.sh"
          },
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/scripts/response-cap-audit.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/scripts/load-session.sh"
          }
        ]
      }
    ]
  }
}
```

**What each key does:**
- `outputStyle: "team-concise"` → applies the 100-word bullet rule to every reply (see §5)
- `permissions.defaultMode: "auto"` → Anthropic's safety classifier replaces manual Allow/Deny prompts. Requires Opus 4.x + Max plan. Fall back to `"default"` if either is missing.
- `statusLine` → runs `statusline.sh` every UI refresh (see §7)
- Three hooks wired: inject response-cap reminder, save session on stop, audit response length on stop (see §6, §10)

**Add to `.gitignore`:**
```
.claude/statusline-state/
.claude/response-cap-violations.log
.claude/compact-state.md
```

---

## 5. IMPLEMENT: Output style (100-word bullet rule)

**File:** `.claude/output-styles/team-concise.md`

```markdown
---
name: team-concise
description: 100-word bullet-only replies with an elaborate offer. Elaborate only when the user uses a trigger word.
---

# Team Concise Output Style

## Hard cap — applies to every chat reply

1. **≤ 100 words total.** Exceptions (length driven by the work, not by chat, not counted against the cap):
   - File contents being written to disk
   - Code diffs / patches
   - Persona synthesis via a skill (code-review, security-audit, reality-check) when depth was requested
2. **Bullet-point format only.** No prose paragraphs.
3. **End every reply with the literal line:** `Want an elaborative answer?`

If the answer cannot fit in 100 words, collapse to top-3 bullets + the offer. Err short.

## Elaborate triggers — user-opt-in to long form

Elaborate ONLY when the user's prompt contains any of:
`elaborate`, `long version`, `detailed plan`, `deep dive`, `draft the full thing`,
`write the doc`, `full answer`, `expand`, `give me the long`, `write the file`, `long form`

When a trigger is present, long-form is allowed **for that turn only**. The next turn reverts to the 100-word cap.

## Style expectations

- Lead with the verdict / answer in the first bullet. Don't warm up.
- Cut "very", "really", "just", "actually".
- Named objects get backticks: `file.py`, `/schedule`, `settings.json`.
- If reporting results of work, start with DONE / BLOCKED / PARTIAL before context.
- One follow-up invitation at the end — never a list of questions.
```

---

## 6. IMPLEMENT: Response-cap hooks

Two shell scripts. The injector fires on every user prompt and prepends a reminder; the audit fires when Claude finishes and logs violations.

**File:** `.claude/scripts/response-cap-injector.sh`

```bash
#!/usr/bin/env bash
# UserPromptSubmit hook — prepends the 100-word bullet reminder.
set -euo pipefail

PROMPT="$(jq -r '.prompt // .user_prompt // ""' 2>/dev/null || true)"
PROMPT_LOWER="$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')"
TRIGGERS='elaborate|long version|detailed plan|deep dive|draft the full thing|write the doc|full answer|expand|give me the long|write the file|long form'

if echo "$PROMPT_LOWER" | grep -Eq "$TRIGGERS"; then
  cat <<'EOF'
<system-reminder>
RESPONSE LENGTH: user used an elaborate-trigger — long-form is allowed for THIS turn only. Still prefer structure (headings, bullets). Next turn reverts to the 100-word bullet cap.
</system-reminder>
EOF
else
  cat <<'EOF'
<system-reminder>
RESPONSE LENGTH RULE (HARD CAP): your next reply MUST be:
  1. ≤ 100 words total (exceptions: file writes, code diffs, persona synthesis).
  2. Bullet-point format only. No prose paragraphs.
  3. End with the literal line: "Want an elaborative answer?"
Do NOT elaborate unless the user uses a trigger (elaborate, long version, detailed plan, deep dive, expand, full answer).
</system-reminder>
EOF
fi
exit 0
```

**File:** `.claude/scripts/response-cap-audit.sh`

```bash
#!/usr/bin/env bash
# Stop hook — audits the last assistant reply against the cap.
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG="$PROJECT_DIR/.claude/response-cap-violations.log"
CAP_WORDS=100

HOOK_JSON="$(cat)"
TRANSCRIPT="$(echo "$HOOK_JSON" | jq -r '.transcript_path // ""' 2>/dev/null || true)"
LAST_PROMPT="$(echo "$HOOK_JSON" | jq -r '.prompt // .user_prompt // ""' 2>/dev/null || true)"

[[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]] && exit 0

LAST_ASSISTANT="$(
  jq -r '
    select(.type=="assistant") |
    .message.content // [] |
    map(select(.type=="text") | .text) |
    join(" ")
  ' "$TRANSCRIPT" 2>/dev/null | tail -n 1 || true
)"
[[ -z "$LAST_ASSISTANT" ]] && exit 0

TRIGGERS='elaborate|long version|detailed plan|deep dive|draft the full thing|write the doc|full answer|expand|give me the long|write the file|long form'
if echo "$LAST_PROMPT" | tr '[:upper:]' '[:lower:]' | grep -Eq "$TRIGGERS"; then
  exit 0
fi

# Skip if mostly code fences (code-diff / write-a-doc case).
CODE_CHARS="$(echo "$LAST_ASSISTANT" | grep -oE '```[^`]*```' | wc -c | tr -d ' ')"
TOTAL_CHARS="$(echo -n "$LAST_ASSISTANT" | wc -c | tr -d ' ')"
if [[ "$TOTAL_CHARS" -gt 0 && "$CODE_CHARS" -gt 0 ]]; then
  (( CODE_CHARS * 100 / TOTAL_CHARS > 40 )) && exit 0
fi

PROSE="$(echo "$LAST_ASSISTANT" | sed -E 's/```[^`]*```/ /g')"
WORD_COUNT="$(echo "$PROSE" | wc -w | tr -d ' ')"
HAS_BULLETS="no"
echo "$PROSE" | grep -Eq '^[[:space:]]*([-*•]|[0-9]+\.)[[:space:]]+' && HAS_BULLETS="yes"
HAS_OFFER="no"
echo "$PROSE" | tail -c 200 | grep -Eiq 'elaborative answer|expand any of these|want.*elaborat' && HAS_OFFER="yes"

VIOLATIONS=()
(( WORD_COUNT > CAP_WORDS )) && VIOLATIONS+=("word_count=${WORD_COUNT}>${CAP_WORDS}")
[[ "$HAS_BULLETS" == "no" ]] && VIOLATIONS+=("no_bullets")
[[ "$HAS_OFFER" == "no" ]] && VIOLATIONS+=("no_elaboration_offer")

if (( ${#VIOLATIONS[@]} > 0 )); then
  mkdir -p "$(dirname "$LOG")"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${VIOLATIONS[*]} | words=$WORD_COUNT" >> "$LOG"
  echo "⚠ response-cap: ${VIOLATIONS[*]}" >&2
fi
exit 0
```

Both scripts need `chmod +x`.

---

## 7. IMPLEMENT: Statusline with compact/fresh-session nudges

**File:** `.claude/scripts/statusline.sh`

```bash
#!/usr/bin/env bash
# Statusline — model | ctx% | $cost | branch | nudges
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="$PROJECT_DIR/.claude/statusline-state"
mkdir -p "$STATE_DIR"

INPUT="$(cat)"
get() { echo "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }

MODEL="$(get '.model.display_name')"; [[ -z "$MODEL" ]] && MODEL="$(get '.model.id')"; [[ -z "$MODEL" ]] && MODEL="claude"
SESSION_ID="$(get '.session_id')"; [[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"
CWD="$(get '.workspace.current_dir')"; [[ -z "$CWD" ]] && CWD="$PROJECT_DIR"

TOKENS="$(get '.usage.total_tokens')"
[[ -z "$TOKENS" ]] && TOKENS="$(get '.tokens.total')"
[[ -z "$TOKENS" ]] && TOKENS="$(get '.transcript.total_tokens')"
[[ -z "$TOKENS" ]] && TOKENS=0

CTX_WINDOW="$(get '.model.context_window')"
[[ -z "$CTX_WINDOW" || "$CTX_WINDOW" == "0" ]] && CTX_WINDOW=200000

COST="$(get '.cost.total_cost_usd')"; [[ -z "$COST" ]] && COST="$(get '.cost.total')"; [[ -z "$COST" ]] && COST=0
TURNS="$(get '.transcript.message_count')"; [[ -z "$TURNS" ]] && TURNS="$(get '.messages.count')"; [[ -z "$TURNS" ]] && TURNS=0

START_FILE="$STATE_DIR/${SESSION_ID}.start"
[[ ! -f "$START_FILE" ]] && date +%s > "$START_FILE"
SESSION_START="$(cat "$START_FILE" 2>/dev/null || echo 0)"
DURATION_MIN=$(( ($(date +%s) - SESSION_START) / 60 ))

CTX_PCT=0
(( CTX_WINDOW > 0 )) && CTX_PCT=$(( TOKENS * 100 / CTX_WINDOW ))
BRANCH="$(git -C "$CWD" branch --show-current 2>/dev/null || echo '-')"; [[ -z "$BRANCH" ]] && BRANCH="-"

NUDGES=""
(( CTX_PCT >= 90 )) && NUDGES="$NUDGES 🔴/compact-now NOW"
(( CTX_PCT >= 75 && CTX_PCT < 90 )) && NUDGES="$NUDGES ⚠/compact-now"
(( DURATION_MIN > 90 )) && NUDGES="$NUDGES ⏰save-session"
(( TURNS > 60 )) && NUDGES="$NUDGES 💤fresh-session"
COST_NUDGE="$(awk -v c="$COST" 'BEGIN { if (c+0 > 10.0) print "💤fresh-session(cost)"; }')"
[[ -n "$COST_NUDGE" ]] && NUDGES="$NUDGES $COST_NUDGE"

RESET=$'\033[0m'; DIM=$'\033[2m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
CTX_COLOR="$GREEN"; (( CTX_PCT >= 50 )) && CTX_COLOR="$YELLOW"; (( CTX_PCT >= 75 )) && CTX_COLOR="$RED"
COST_FMT="$(awk -v c="$COST" 'BEGIN { printf "%.2f", c+0 }')"

printf '%s%s%s %s│%s ctx %s%d%%%s %s│%s $%s %s│%s %s%s%s%s%s\n' \
  "$CYAN" "$MODEL" "$RESET" "$DIM" "$RESET" \
  "$CTX_COLOR" "$CTX_PCT" "$RESET" "$DIM" "$RESET" "$COST_FMT" \
  "$DIM" "$RESET" "$GREEN" "$BRANCH" "$RESET" \
  "${NUDGES:+ }" "$NUDGES"
```

`chmod +x` after creating. Tune `CTX_WINDOW` default per your plan (200k for most, 1M for Opus 4.7 1M).

---

## 8. IMPLEMENT: CLAUDE.md skeleton

**File:** `CLAUDE.md` (repo root)

```markdown
# <Project Name> — Claude Code Instructions

## Project Overview
<one-paragraph description of the project: tech stack, target users, current phase>

## Response Length Rule
Full rule lives in `.claude/output-styles/team-concise.md` (active via `settings.local.json` → `outputStyle`). Enforced by `UserPromptSubmit` + `Stop` hooks. TL;DR: ≤ 100 words, bullets only, end with "Want an elaborative answer?" unless user uses an elaborate trigger.

## Session Start Protocol
1. SessionStart hook loads `.claude/sessions/latest.md`
2. Read `WORKING-CONTEXT.md` for current sprint state
3. Check `.claude/compact-state.md` if resuming after compaction

## Key Files
- `WORKING-CONTEXT.md` — live sprint board
- `TASK_TRACKER.md` — feature backlog
- `AUDIT.md` — change log
- `.claude/sessions/latest.md` — previous session summary (auto-loaded)

## Pipeline (every feature / bug fix)
1. UNDERSTAND — load context
2. PLAN — propose approach, get user approval for non-trivial changes
3. IMPLEMENT — TDD: failing test → code → refactor
4. VERIFY — lint, build, test, coverage
5. REVIEW — Daniel code review (see `.claude/agents/daniel.md`)
6. SHIP — commit + PR + session save

## Branch Hygiene (ENFORCED BY HOOKS)
- Always branch from fresh `origin/master`: `git checkout master && git pull && git checkout -b <branch>`
- Stop using a branch the moment its PR merges (pre-commit hook blocks)
- Every push must have an open PR (pre-push hook blocks)
- Never `--no-verify`, never force-push to master

## Code Rules
- No hardcoded secrets, no `print()` left in prod code
- Match existing patterns — lint, format, type-check before committing
- Add to this file as rules emerge
```

---

## 9. IMPLEMENT: Expert persona — Daniel code reviewer

**File:** `.claude/agents/daniel.md`

```markdown
---
name: daniel
description: Senior engineer code reviewer. 20 years of shipping production software. Reviews for correctness, security, error handling, performance, maintainability, test coverage, architecture.
---

You are **Daniel**, a senior staff software engineer with 20 years of experience. You review code with these priorities, in order:

1. **Correctness** — does the code do what it claims? Edge cases: nulls, empty collections, concurrent access, boundary values, timezone, encoding.
2. **Security** — OWASP Top 10. SQL injection, XSS, auth bypass, secret leakage, SSRF, insecure deserialization, path traversal.
3. **Error handling** — are failures surfaced or silently swallowed? Are retries bounded? Is user-facing error messaging safe (no stack traces to end users)?
4. **Performance** — N+1 queries, O(n²) on untrusted input, missing indexes, unbounded memory growth, blocking I/O on hot path.
5. **Maintainability** — naming, function length (>50 lines is a smell), duplication, cyclomatic complexity, magic numbers.
6. **Test coverage** — new behavior must have tests. Unhappy paths must have tests. Regression tests for every bug fix.
7. **Architecture** — does this change respect module boundaries? Any new coupling that will hurt later?

## Output format (enforced)

```
## Daniel's Review — <SHA or file list>

### Critical  (must fix before merge)
- <file:line> — <issue> — <why it matters> — <suggested fix>

### Medium  (fix if straightforward; otherwise list in PR)
- ...

### Minor  (nits, not blocking)
- ...

### Verdict: APPROVE | REQUEST_CHANGES | BLOCK
```

## Rules
- Quote the exact code you're critiquing.
- Do not restate what the code does — only what's wrong and why.
- If the diff is clean, say so plainly: `No issues found. Approve.`
- Never pad with encouragement. Terse is professional.
```

Invoke with `/daniel` (place file in `.claude/commands/daniel.md` too if your team prefers slash-command style).

---

## 10. IMPLEMENT: Session save/load

Two short scripts capture the session state so the next run starts with context.

**File:** `.claude/scripts/save-session.sh`

```bash
#!/usr/bin/env bash
# Stop hook — save a session summary for next-session bootstrap.
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SESSIONS_DIR="$PROJECT_DIR/.claude/sessions"
mkdir -p "$SESSIONS_DIR"
TS="$(date '+%Y-%m-%d_%H-%M')"
OUT="$SESSIONS_DIR/session_${TS}.md"

{
  echo "# Session: $TS"
  echo "Branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo '-')"
  echo "Last commit: $(git -C "$PROJECT_DIR" log --oneline -1 2>/dev/null || echo '-')"
  echo
  echo "## Changes this session"
  git -C "$PROJECT_DIR" diff --stat 2>/dev/null | tail -20
} > "$OUT"

ln -sf "$(basename "$OUT")" "$SESSIONS_DIR/latest.md"
```

**File:** `.claude/scripts/load-session.sh`

```bash
#!/usr/bin/env bash
# SessionStart hook — prints previous session summary into context.
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LATEST="$PROJECT_DIR/.claude/sessions/latest.md"

echo "=== PREVIOUS SESSION ==="
[[ -f "$LATEST" ]] && cat "$LATEST" || echo "(no previous session)"
echo
echo "=== CURRENT STATE ==="
echo "Branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo '-')"
echo "Last commit: $(git -C "$PROJECT_DIR" log --oneline -1 2>/dev/null || echo '-')"
echo "Uncommitted: $(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ') files"
```

Both `chmod +x`. Add `.claude/sessions/` to `.gitignore` unless you want session history tracked (most teams don't).

---

## 11. IMPLEMENT: Branch hygiene (pre-commit + pre-push)

**File:** `.githooks/pre-commit`

```bash
#!/bin/bash
# Gate 1 — refuse commits on a branch whose PR has already merged.
set -e
BRANCH="$(git branch --show-current)"
[[ "$BRANCH" == "master" || "$BRANCH" == "main" ]] && exit 0

if command -v gh >/dev/null 2>&1; then
  MERGED="$(gh pr list --state merged --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null || true)"
  if [[ -n "$MERGED" ]]; then
    echo "❌ BLOCK: branch '$BRANCH' has merged PR #$MERGED."
    echo "   Branch off fresh master instead:"
    echo "   git stash && git checkout master && git pull && git checkout -b <new-branch>"
    exit 1
  fi
fi
exit 0
```

**File:** `.githooks/pre-push`

```bash
#!/bin/bash
# Gate 1 — every push must have an open PR.
# Override once for the initial push: SWASTH_ALLOW_BRANCHLESS_PUSH=1 git push
set -e
BRANCH="$(git branch --show-current)"
[[ "$BRANCH" == "master" || "$BRANCH" == "main" ]] && exit 0
[[ "${SWASTH_ALLOW_BRANCHLESS_PUSH:-}" == "1" ]] && exit 0

if command -v gh >/dev/null 2>&1; then
  OPEN="$(gh pr list --state open --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null || true)"
  if [[ -z "$OPEN" ]]; then
    echo "❌ BLOCK: no open PR for '$BRANCH'."
    echo "   Either: gh pr create --fill  OR  SWASTH_ALLOW_BRANCHLESS_PUSH=1 git push"
    exit 1
  fi
fi
exit 0
```

**Wire hooks once after clone:**
```bash
git config core.hooksPath .githooks
chmod +x .githooks/*
```

---

## 12. IMPLEMENT: Memory system

Claude Code has a built-in auto-memory directory at `~/.claude/projects/<project-slug>/memory/`. Populate it with:

- `user_role.md` — who the user is, their tech background
- `feedback_*.md` — corrections ("don't mock the database", "always use X")
- `project_*.md` — ongoing initiatives, deadlines
- `reference_*.md` — external systems (Linear project, Slack channel, Grafana dashboard)
- `MEMORY.md` — index with one-liner per memory

No script needed — Claude Code writes these automatically when you tell it to remember, and auto-loads them on session start.

**Seed a few at project start:**
- After your first "don't do X" correction → save as `feedback_*.md`
- When scope/deadline is stated → save as `project_*.md`
- External systems mentioned → save as `reference_*.md`

---

## 13. OPTIONAL: Domain expert personas

Our Swasth project uses 7 domain personas (Sunita, Aditya, Dr. Rajesh, Meera, Healthify, Legal, PHI). Most teams don't need that many. Pick 1–3 for your domain:

- **B2B SaaS:** `/enterprise-buyer` (procurement skeptic), `/power-user` (retention critic)
- **Consumer app:** `/first-time-user` (comprehension test), `/churn-risk` (value critic)
- **Dev tool:** `/hostile-stranger` (reads docs in 30s, gives up), `/expert-user` (edge cases)
- **Health / fintech / regulated:** add compliance persona (PHI, SOC 2, PCI)

Each persona is a single file at `.claude/agents/<name>.md` following the Daniel template (§9): clear priorities, structured output, terse verdict. Invoke via `/<name>`.

---

## 14. OPTIONAL: Verification + security audit skills

Two high-leverage skills to add once the basics are working:

- `/verify` — multi-phase gate: build, lint, test, coverage, security scan, diff review. Block PR if any phase fails.
- `/security-audit` — OWASP Top 10 scan on changed files. Run after every feature touching user input, auth, or secrets.

Skeletons in `.claude/commands/verify.md` and `.claude/commands/security-audit.md` (or as agents — your choice).

---

## 15. Principles — why it's shaped this way

1. **Hooks > memory for enforcement.** Memory advises; hooks block. For anything load-bearing (branch hygiene, response length, migration checks) use hooks.
2. **Deterministic > probabilistic.** File-type → required expert mapping is a lookup table, not a learned router. Debuggable, explainable, fast.
3. **Vertical > horizontal.** Don't copy a 100-agent platform. Pick 3–8 focused personas that reflect your users and reviewers.
4. **Token efficiency compounds.** 100-word replies × 40 turns/day × 250 days/year = meaningful cost reduction. Auto Mode removes per-prompt round-trips.
5. **Session continuity matters.** Save + load shaves the first 10 minutes off every session. Otherwise you re-explain context.
6. **Make the quality gate the easy path.** If the gate is friction, people bypass it. If it's a one-command install with auto-enforcement, they keep it.
7. **One atomic change, verified, then the next.** Especially for destructive ops (DB, prod, secrets). Exit code 0 ≠ success — the observable downstream surface is success.

---

## 16. Rollout checklist for your team

Share this section with teammates. They run it once per new repo.

- [ ] Drop `BEST_PRACTICES.md` at repo root
- [ ] Open Claude Code in the repo: `claude`
- [ ] Paste: *"Read BEST_PRACTICES.md and implement every IMPLEMENT section."*
- [ ] After Claude finishes, restart the session (to load output style + hooks)
- [ ] Run `git config core.hooksPath .githooks` and `chmod +x .githooks/*`
- [ ] Verify: `jq empty .claude/settings.local.json` → should print nothing
- [ ] Smoke test: type a throwaway prompt → response should be ≤ 100 words + bullet + "Want an elaborative answer?"
- [ ] Edit `CLAUDE.md` → fill in your project overview + pipeline stages
- [ ] Pick 1–3 domain personas (§13), drop into `.claude/agents/`
- [ ] Commit the whole `.claude/` + `.githooks/` + `CLAUDE.md` tree — DON'T gitignore any of it

**After 1 week of usage, review `.claude/response-cap-violations.log` — if it's long, the rule is too strict for your team; raise the cap or relax the bullet requirement in `.claude/output-styles/team-concise.md`.**

---

## Credits

Harness extracted from the Swasth Health App (production Flutter + FastAPI health-tech project, Bihar pilot). Upstream ideas: Anthropic's Claude Code docs, `shanraisshan/claude-code-best-practice` (feature map), `ruvnet/ruflo` (distribution pattern — we opted simpler, git-clone style).

Feedback welcome — this doc evolves as we learn. Tell Claude *"update BEST_PRACTICES.md — add X"* and let it revise.
