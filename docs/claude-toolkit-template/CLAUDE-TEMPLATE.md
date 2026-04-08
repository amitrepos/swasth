# [PROJECT NAME] — Claude Code Instructions

## Project Overview
<!-- Replace with your project description -->
[Tech stack]. [Target audience]. [One-line purpose].

## Key Files (read these first)
- `WORKING-CONTEXT.md` — **live sprint board** (current branch, PRs, blockers, priorities)
- `RULES.md` — **Must Always / Must Never rules**, commit style, agent routing
- `AUDIT.md` — change log (update on every session)

## Slash Commands
- `/review` — Senior engineer code review
- `/tdd` — Test-driven development workflow
- `/security-audit` — OWASP security scan on changed files
- `/ship` — Full pipeline: test → security → review → PR

## Development Lifecycle (MANDATORY)

**Every feature or bug fix MUST follow this lifecycle. Do NOT skip steps.**

### Step 1: UNDERSTAND
- Read `WORKING-CONTEXT.md` for current sprint context
- Ask clarifying questions ONLY if the requirement is genuinely ambiguous

### Step 2: PLAN
- For non-trivial work (>50 lines of change), enter Plan mode
- Identify all files that need to change
- List the approach in 3-5 bullet points
- Get user approval before proceeding

### Step 3: IMPLEMENT
- Write code following `RULES.md`
- Keep changes minimal — do what was asked, nothing more

### Step 4: TEST
- Write tests for ALL new/changed code paths
- Run the full test suite — ensure nothing is broken
- If tests fail, fix the code (not the tests) unless the test is wrong

### Step 5: SECURITY CHECK
- Scan changed files for OWASP Top 10 issues
- Check: SQL injection, XSS, auth bypasses, hardcoded secrets, data leaks
- Check: input validation at system boundaries

### Step 6: CODE REVIEW
- Run `/review` on all changes
- Fix all CRITICAL issues before proceeding
- Fix MEDIUM issues unless user explicitly defers them

### Step 7: SHIP
- Create a commit with conventional commit message
- Create PR with structured body (Summary + Test Plan)
- Update `WORKING-CONTEXT.md` with new PR
- Update `AUDIT.md` with session changes

**Shortcut:** User can say `/ship` to trigger Steps 4-7 automatically.

## Architecture Decisions (do not change without discussion)
<!-- Replace with your architecture decisions -->
- Auth: [your auth approach]
- DB: [your database]
- API: [your API pattern]
- Secrets never committed — `.env` is gitignored

## Code Rules
See `RULES.md` for the full list.

## Mandatory: Audit Log
**Every session, before ending, append a summary of all changes made to `AUDIT.md`.**

Format:
```
## YYYY-MM-DD — <one line summary>
- Changed `file/path`: what and why
- Created `file/path`: what and why
```
