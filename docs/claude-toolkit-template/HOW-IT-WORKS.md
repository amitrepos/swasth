# How the Claude Code Toolkit Works

## The Problem
Without setup, Claude is reactive — you tell it each step manually. With this toolkit, Claude follows a professional development pipeline automatically. No step is optional. Every skill fires at the right point.

## What Happens When You Start a Session

```
You open Claude Code
    ↓
SessionStart hook fires → loads previous session + learnings
    ↓
Claude reads CLAUDE.md → sees the enforced pipeline
    ↓
Claude reads WORKING-CONTEXT.md → knows your sprint state
    ↓
Ready. Waiting for your requirement.
```

## The Enforced 9-Stage Pipeline

```
You say: "Add feature X"

Stage 1: UNDERSTAND (auto)
├── Reads WORKING-CONTEXT.md, TASK_TRACKER.md, learnings
├── GATE: context loaded ✅
│
Stage 2: PLAN
├── Small change → 2-3 bullet plan
├── Big change → /blueprint (multi-step plan)
├── Ambiguous choice → /council (4-voice debate)
├── GATE: you approve the plan ✅
│
Stage 3: VALIDATE ← NEW: experts review the PLAN before coding
├── /doctor-feedback → if new feature touching health/patients
├── /legal-check → if new data collection, AI advice, consent
├── GATE: no showstoppers from experts ✅
├── If Must Fix items → update plan → re-approve → then proceed
│
Stage 4: IMPLEMENT (/tdd)
├── RED: write failing tests first
├── GREEN: write minimum code to pass
├── REFACTOR: clean up, tests stay green
├── GATE: all tests pass ✅
│
Stage 5: VERIFY (/verify)
├── Build → Lint → Tests → Coverage → Security grep → Diff review
├── GATE: no failures in any of 6 phases ✅
│
Stage 6: SECURITY (/security-audit + /phi-compliance)
├── OWASP Top 10 scan on changed files
├── If health data touched → PHI compliance audit
├── GATE: no CRITICAL or HIGH findings ✅
│
Stage 7: EXPERT QA ← experts review the CODE after implementation
├── /ux-review → if UI screens/widgets changed
├── /doctor-feedback → if Stage 3 was triggered (re-validate)
├── /legal-check → if consent/data/AI files changed
├── /safety-guard → if destructive operations planned
├── GATE: no Must-Fix issues ✅
│
Stage 8: CODE REVIEW (/review — Daniel)
├── Correctness, security, performance, tests, architecture
├── CRITICAL → fix and restart from Stage 5
├── GATE: Daniel approves ✅
│
Stage 9: SHIP
├── git commit + push + gh pr create
├── Update WORKING-CONTEXT.md + AUDIT.md
├── /learn — capture patterns
├── Stop hook saves session
└── DONE ✅
```

## Why Experts Fire Twice (Stage 3 + Stage 7)

| Stage | Question | Example |
|-------|----------|---------|
| **3. Validate** | "Should we build this?" | Dr. Rajesh: "3 buttons not 5, soften tip language" |
| **7. Expert QA** | "Did we build it right?" | UX: "Touch target too small", Legal: "Disclaimer missing" |

Stage 3 prevents wasted work. Stage 7 catches implementation bugs.

## The Four File Types

| Type | Files | Role |
|------|-------|------|
| **Instructions** | `CLAUDE.md`, `RULES.md` | Tell Claude what to do and what's forbidden |
| **State** | `WORKING-CONTEXT.md`, `AUDIT.md` | Track what's happening now |
| **Skills** | `.claude/skills/*/SKILL.md` | Specialized personas and workflows |
| **Automation** | `.claude/settings.local.json` | Hooks that fire silently in background |

## All 15 Skills and When They Fire

| Skill | Stage 3 (Validate) | Stage 4 (Implement) | Stage 5-6 (Verify/Secure) | Stage 7 (Expert QA) | Stage 8-9 (Review/Ship) |
|-------|--------------------|---------------------|---------------------------|---------------------|-------------------------|
| `/blueprint` | Stage 2 | | | | |
| `/council` | Stage 2 | | | | |
| `/doctor-feedback` | **Yes** (new features) | | | **Yes** (re-validate) | |
| `/legal-check` | **Yes** (new data/AI) | | | **Yes** (code check) | |
| `/tdd` | | **Yes** (always) | | | |
| `/verify` | | | **Yes** (always) | | |
| `/security-audit` | | | **Yes** (always) | | |
| `/phi-compliance` | | | **Yes** (if health data) | | |
| `/ux-review` | | | | **Yes** (if UI changed) | |
| `/safety-guard` | | | | **Yes** (if destructive) | |
| `/review` | | | | | **Yes** (always) |
| `/learn` | | | | | **Yes** (always) |
| `/compact-now` | On demand | On demand | On demand | On demand | On demand |

## All 7 Hooks (always running)

| Hook | When | What |
|------|------|------|
| SessionStart | Session opens | Load previous session + learnings |
| block-no-verify | Any git command | Block `--no-verify` |
| config-protection | Edit linter/CI files | Warn before weakening |
| audit-log | Every file edit | Log to AUDIT.md |
| auto-format | Every file edit | dart format / black |
| pre-compact-save | Context compaction | Save working state |
| Stop | Session ends | Save session summary |

## To Use in a New Project

1. Copy these into your project root: `CLAUDE.md`, `RULES.md`, `WORKING-CONTEXT.md`
2. Copy `.claude/` directory (skills, scripts, settings.local.json)
3. Copy `.mcp.json`
4. Edit `CLAUDE.md`: replace project name, architecture, code rules
5. Edit `RULES.md`: replace tech-specific rules
6. Edit `settings.local.json`: change format commands for your language
7. Start Claude Code — pipeline enforces itself automatically
