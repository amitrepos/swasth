---
name: verify
description: "6-phase pre-PR quality gate — build, lint, test, security, coverage, diff review"
---

# Verification Loop — Pre-PR Quality Gate

Run a structured 6-phase verification before creating a PR. Each phase must PASS before proceeding to the next.

## Phase 1: BUILD CHECK
```bash
# Backend
cd backend && python -c "import main" 2>&1

# Frontend
flutter analyze --no-pub 2>&1
```
- **PASS:** No import errors, no analysis errors
- **FAIL:** Fix build errors before continuing. Do NOT proceed.

## Phase 2: LINT CHECK
```bash
# Backend
cd backend && python -m ruff check . 2>&1 || true

# Frontend
flutter analyze 2>&1
```
- **PASS:** No errors (warnings are OK)
- **FAIL:** Fix lint errors. Do NOT weaken linter rules.

## Phase 3: TEST SUITE
```bash
# Backend
cd backend && TESTING=true python -m pytest tests/ -v --tb=short 2>&1

# Frontend
flutter test 2>&1
```
- **PASS:** All tests pass
- **FAIL:** Fix code (not tests) unless test is genuinely wrong

## Phase 4: COVERAGE CHECK (MANDATORY — blocks PR)
```bash
# Install pytest-cov if missing
pip3 install --break-system-packages pytest-cov 2>/dev/null || true

# Run coverage on changed backend files
cd backend && TESTING=true python -m pytest tests/ --cov=. --cov-config=.coveragerc --cov-report=term-missing -q 2>&1
```
- **PASS:** ≥85% on changed files, ≥90% on NEW code
- **FAIL:** <85% on any changed file — write tests BEFORE proceeding. Do NOT skip.
- If `pytest-cov` cannot be installed, this is a FAIL, not a WARN.
- Coverage must be checked on EACH changed backend .py file individually, not just overall.

## Phase 5: SECURITY SCAN
Quick grep scan for common issues:
```bash
# Hardcoded secrets
grep -rn "password\s*=" --include="*.py" --include="*.dart" | grep -v "test" | grep -v ".env"

# Debug/print statements in backend
grep -rn "print(" backend/*.py | grep -v "test" | grep -v "#"

# Console.log in frontend (if web)
grep -rn "debugPrint\|print(" lib/ | grep -v "test"
```
- **PASS:** No secrets, no debug prints in production code
- **FAIL:** Remove secrets/debug statements

## Phase 6: DIFF REVIEW
```bash
git diff --stat
git diff
```
- Review the full diff for: unintended changes, leftover debug code, TODO comments, large files
- Check that only relevant files are modified
- Verify conventional commit message is appropriate

## Output Format
```
┌─────────────────────────────────┐
│ VERIFICATION REPORT             │
├───────┬─────────┬───────────────┤
│ Phase │ Status  │ Details       │
├───────┼─────────┼───────────────┤
│ Build │ ✅ PASS │               │
│ Lint  │ ✅ PASS │               │
│ Tests │ ✅ PASS │ 24/24 passed  │
│ Cover │ ⚠️ WARN │ 76% (target 80%) │
│ Secur │ ✅ PASS │               │
│ Diff  │ ✅ PASS │ 3 files, +120 -15 │
├───────┴─────────┴───────────────┤
│ VERDICT: READY TO SHIP          │
└─────────────────────────────────┘
```

$ARGUMENTS
