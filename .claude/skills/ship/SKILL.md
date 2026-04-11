---
name: ship
description: "Master pipeline: verify → security → phi-compliance → review → commit → PR → audit → learn"
---

# Ship Pipeline — Stages 4 through 7

Run this after implementation is complete. Executes every remaining pipeline stage in order with gates between them.

**This is not a shortcut. Every stage runs. Every gate must pass.**

## Stage 4: VERIFY (6-phase quality gate)

Run all 6 phases. Report results as a table.

### Phase 1 — BUILD
```bash
# Frontend
flutter analyze --no-pub 2>&1

# Backend (if Python files changed)
cd backend && source venv/bin/activate && python -c "import main" 2>&1
```

### Phase 2 — LINT
```bash
flutter analyze 2>&1
cd backend && python -m ruff check . 2>&1 || true
```

### Phase 3 — TESTS
```bash
cd backend && source venv/bin/activate && TESTING=true python -m pytest tests/ -v --tb=short 2>&1
flutter test 2>&1
```

### Phase 4 — COVERAGE
```bash
cd backend && source venv/bin/activate && TESTING=true python -m pytest tests/ --cov=. --cov-config=.coveragerc --cov-report=term-missing -q 2>&1
```

### Phase 5 — SECURITY GREP
```bash
# Hardcoded secrets
grep -rn "password\s*=\s*['\"]" --include="*.py" --include="*.dart" | grep -v test | grep -v ".env"

# Print statements in backend production code
grep -rn "print(" backend/*.py | grep -v test | grep -v "# "

# Debug prints in frontend production code
grep -rn "debugPrint\|print(" lib/ | grep -v test | grep -v "// "
```

### Phase 6 — DIFF REVIEW
```bash
git diff --stat
git diff --name-only
```
Check: only intended files changed, no leftover debug code, no TODOs.

### VERIFY GATE
Print the verification table:
```
┌──────────┬──────────┬─────────────────────┐
│ Phase    │ Status   │ Details             │
├──────────┼──────────┼─────────────────────┤
│ Build    │ ✅/❌    │                     │
│ Lint     │ ✅/❌    │                     │
│ Tests    │ ✅/❌    │ N/N passed          │
│ Coverage │ ✅/⚠️/❌ │ X% (target 85%)     │
│ Security │ ✅/❌    │                     │
│ Diff     │ ✅/❌    │ N files, +X -Y      │
└──────────┴──────────┴─────────────────────┘
```
**If ANY phase is ❌ → STOP. Fix the issue. Re-run /ship from the beginning.**
**If ⚠️ only → note it, continue.**

---

## Stage 5: SECURITY AUDIT

### 5a — OWASP Scan
Run the full `/security-audit` checklist on all changed files:
- Read each changed file completely
- Check OWASP Top 10: injection, auth, XSS, secrets, data exposure, SSRF
- Report: CRITICAL / HIGH / MEDIUM / LOW

### 5b — PHI Compliance (conditional)
**Trigger condition:** Did any changed file touch health data?
Check if changed files include any of:
- `routes_health.py`, `models.py`, `encryption_service.py`, `ai_service.py`
- `health_utils.py`, `routes_chat.py` (health context in chat)
- Any Dart file in `lib/screens/` that displays health readings
- Any Dart file in `lib/services/` that sends/receives health data

If YES → run the full `/phi-compliance` checklist:
- Data at rest encryption, data in transit, access control
- Consent, audit trail, common leak vectors, AI-specific

### SECURITY GATE
**If CRITICAL or HIGH → STOP. Fix. Re-run from Stage 4.**
**If MEDIUM only → list in PR description under "Known Issues". Continue.**

---

## Stage 6: DOMAIN EXPERT REVIEW (conditional auto-triggers)

**Run `git diff --name-only` to get the changed file list, then check each trigger rule.**

### Trigger Decision:
```
changed_files = $(git diff --name-only)

UI_TRIGGER:    any file in lib/screens/, lib/widgets/, app_theme.dart, .arb files?
DOCTOR_TRIGGER: commit is feat:* OR files touch dashboard/health/AI/alerts?
LEGAL_TRIGGER:  files touch user data, consent, AI advice, sharing, or non-code docs?
SAFETY_TRIGGER: commands involve destructive ops OR DB schema changes?
```

### 6a — UX Review (`/aditya`) — if UI_TRIGGER
- Bihar grandmother test, Singapore daughter test
- Touch targets ≥48dp, fonts ≥14sp, solid colors, color-blind safe
- GATE: no "Must Fix" issues

### 6b — Doctor Feedback (`/doctor-feedback`) — if DOCTOR_TRIGGER
- Will Bihar patients use this daily?
- Clinical accuracy, NMC liability
- GATE: no showstopper concerns

### 6c — Legal Review (`/legal-check`) — if LEGAL_TRIGGER
- DPDPA 2023, NMC guidelines, AI disclaimer, data sharing
- GATE: no HIGH risk findings

### 6d — Safety Guard (`/safety-guard`) — if SAFETY_TRIGGER
- Is there a safer alternative? Is it reversible?
- GATE: user explicitly confirms destructive operations

### DOMAIN EXPERT GATE
All triggered experts must pass their gates before proceeding.

---

## Stage 7: CODE REVIEW (Daniel)

Run Daniel's full review on `git diff`:
1. Read every changed file completely (not just the diff)
2. Check: correctness, security, error handling, performance, maintainability, test coverage, architecture
3. Also review any issues flagged by Stage 6 domain experts
4. Categorize: CRITICAL / MEDIUM / MINOR
5. For each issue: file:line, what's wrong, suggested fix

### REVIEW GATE
- **CRITICAL found → STOP.** Fix the issue. Re-run from Stage 4 (full pipeline restart).
- **MEDIUM found → fix if <10 minutes.** Otherwise note in PR as "Follow-up: [issue]".
- **MINOR found → note but proceed.**
- **Daniel's verdict must be APPROVE or CONDITIONAL APPROVE to proceed.**

---

## Stage 8: SHIP

Execute all of these in order:

### 8a — Commit
```bash
git add [specific changed files — never .env, .coverage, build/]
git commit -m "feat(module): description"
```

### 8b — Push + PR
```bash
git push -u origin [branch]
gh pr create --title "..." --body "$(cat <<'EOF'
## Summary
- [what changed]

## Test Plan
- [x] Backend: N tests pass
- [x] Frontend: N tests pass
- [x] Coverage: X%

## Security
- OWASP: PASS/CONDITIONAL
- PHI Compliance: PASS/N/A
- Known MEDIUM issues: [list or "none"]

## Domain Expert Reviews
- UX (Aditya): TRIGGERED/SKIPPED — verdict
- Doctor (Dr. Rajesh): TRIGGERED/SKIPPED — verdict
- Legal: TRIGGERED/SKIPPED — verdict
- Safety: TRIGGERED/SKIPPED — verdict

## Code Review
- Daniel: APPROVE/CONDITIONAL

🤖 Generated with Claude Code
EOF
)"
```

### 8c — Housekeeping
1. Update `WORKING-CONTEXT.md` — add new PR to Open PRs table
2. Update `AUDIT.md` — append session summary
3. Run `/learn` — capture any non-obvious patterns from this work
4. Report: "Pipeline complete. PR #N created: [URL]"

---

## Error Recovery

If the pipeline fails at any stage:
1. Report which stage failed and why
2. Fix the issue
3. **Always re-run from Stage 4** (verify), not from the failed stage
   — because a fix might break something earlier in the pipeline
4. Maximum 3 retry cycles. If still failing after 3, stop and ask the user.

$ARGUMENTS
