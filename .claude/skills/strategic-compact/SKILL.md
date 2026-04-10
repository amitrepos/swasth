---
name: compact-now
description: "Save full working state and suggest optimal compaction point"
---

# Strategic Compact

Saves your full working state before compaction so nothing is lost, then triggers compaction at a logical workflow boundary.

## When to Compact (logical boundaries)

**Good times to compact:**
- After research phase, before implementation begins
- After completing a feature, before starting the next one
- After a PR is created and merged
- When switching between backend and frontend work
- After a long debugging session is resolved

**Bad times to compact:**
- Mid-implementation (you'll lose function signatures, variable names)
- During a review cycle (you'll lose the review context)
- While debugging (you'll lose the stack trace analysis)

## What Gets Saved (before compaction)

The PreCompact hook already saves git diff stat. This skill does a richer save:

1. **Working state summary:**
   - What was being worked on
   - What's done vs. what remains
   - Key decisions made
   - Files currently being modified

2. **Append to `.claude/compact-state.md`:**
```markdown
## [timestamp] — Pre-compact state
**Working on:** [current task]
**Done:** [completed items]
**Remaining:** [what's left]
**Key files:** [files in progress]
**Decisions:** [any decisions made this session]
**Resume by:** [instruction for next context window]
```

3. **Update `.claude/sessions/latest.md`** with the same info

## Instructions

When invoked:
1. Summarize current working state
2. Write the summary to `.claude/compact-state.md`
3. Update the session file
4. Tell the user: "State saved. You can now run /compact safely."
5. After compaction, read `.claude/compact-state.md` to restore context

$ARGUMENTS
