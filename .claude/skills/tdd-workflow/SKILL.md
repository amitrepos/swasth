---
name: tdd
description: "Test-driven development — write failing tests first, then implement, then refactor"
---

# TDD Workflow

Follow strict test-driven development for the requested feature or fix.

## Process

### 1. RED — Write Failing Tests First
- Identify every code path, edge case, and error condition for the requirement
- Write tests that describe the EXPECTED behavior (they should FAIL now)
- Backend: pytest in `backend/tests/` using existing test patterns
- Frontend: flutter test in `test/` using existing widget test patterns
- Cover: happy path, error cases, boundary values, null/empty inputs, auth failures

### 2. GREEN — Write Minimal Code to Pass
- Implement the minimum code to make ALL tests pass
- Do not optimize, do not refactor, do not add extras
- Run tests: `TESTING=true python -m pytest tests/ -v --tb=short` (backend)
- Run tests: `flutter test` (frontend)
- Every test must pass before moving on

### 3. REFACTOR — Clean Up While Green
- Now improve the code: naming, DRY, performance
- Run tests after EVERY refactor step — they must stay green
- Apply project rules: AppColors, AppLocalizations, ApiClient, Depends(get_current_user)
- Remove any dead code or commented-out lines

### 4. COVERAGE CHECK
- Run `TESTING=true python -m pytest tests/ --cov=. --cov-config=.coveragerc --cov-report=term-missing -q`
- Target: 100% coverage on all NEW/CHANGED code
- If coverage gaps exist, go back to step 1 for those paths

## Output
Report at the end:
- Tests written (count, what they cover)
- Coverage percentage on changed files
- Any paths intentionally left untested (with justification)

$ARGUMENTS
