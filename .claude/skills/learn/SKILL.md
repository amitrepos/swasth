---
name: learn
description: "Capture a project pattern or insight from the current session for future use"
---

# Learn — Capture Project Patterns

Extracts and saves a reusable pattern or insight from the current session so future sessions benefit from it.

## What Counts as a Learning

**Save these:**
- API quirks: "The health-score endpoint returns 404 if profile has zero readings — always check first"
- Debug patterns: "When BLE connection fails on iOS, check Background Modes in Xcode"
- Architecture insights: "The AI fallback chain order matters — Gemini must be tried before DeepSeek"
- User preferences: "Amit prefers bundled PRs over many small ones for refactors"
- Environment gotchas: "PostgreSQL must be running before backend import test works"

**Don't save these:**
- Anything already in CLAUDE.md or RULES.md
- Code patterns visible in the codebase (grep can find them)
- Temporary debugging state

## Instructions

When the user says `/learn` (or when you discover something non-obvious mid-session):

1. Identify the pattern: What did you learn? Why is it non-obvious?
2. Write it as a concise learning file:

```markdown
# [Short title]
**Discovered:** [date]
**Context:** [what you were doing when you learned this]
**Pattern:** [the actual insight, 1-3 sentences]
**Apply when:** [when future sessions should use this]
```

3. Save to `.claude/learnings/[slug].md`
4. Append to the current session file in `.claude/sessions/latest.md` under `## Learnings`

## Examples

```markdown
# Health score endpoint requires readings
**Discovered:** 2026-04-08
**Context:** /verify failed on build check — 404 from health-score API
**Pattern:** GET /api/readings/health-score returns 404 if the active profile has zero readings. Always seed at least one reading in tests, or handle 404 gracefully in the frontend.
**Apply when:** Writing tests that call health-score, or debugging empty-state dashboard issues.
```

```markdown
# Gemini before DeepSeek in AI fallback
**Discovered:** 2026-04-05
**Context:** AI insight was slow — turned out DeepSeek was being tried first
**Pattern:** The AI fallback chain must be Gemini 2.5 Flash → DeepSeek V3 → rule-based. Gemini is faster and cheaper. DeepSeek is the backup. Reversing the order adds 3-5s latency per insight.
**Apply when:** Modifying ai_service.py or debugging slow AI responses.
```

$ARGUMENTS
