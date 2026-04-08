---
name: blueprint
description: "Turn a one-line objective into a step-by-step multi-session construction plan"
model: opus
---

# Blueprint — Multi-Session Feature Planner

Turns a high-level objective into a detailed, multi-step construction plan where each step can be executed by a fresh Claude session independently.

## When to Use
- Features that span multiple PRs (e.g., "add offline mode", "integrate WhatsApp API")
- Work that will take multiple sessions to complete
- Changes that touch 5+ files across backend and frontend

## Process

### Phase 1: RESEARCH
- Read all relevant existing code
- Check `TASK_TRACKER.md` for related features and their status
- Check `WORKING-CONTEXT.md` for active constraints and blockers
- Identify all dependencies and integration points

### Phase 2: DECOMPOSE
Break the objective into ordered steps. Each step must:
- Be completable in a single Claude session (1-2 hours of work)
- Have a clear input (what exists) and output (what's new/changed)
- Be independently testable — tests pass after each step
- Include a **self-contained context brief** so a fresh agent can execute it cold

### Phase 3: DEPENDENCY GRAPH
- Map which steps block which other steps
- Identify steps that can run in parallel (different files/modules)
- Mark the critical path

### Phase 4: ADVERSARIAL REVIEW
- Challenge each step: "What could go wrong?"
- Check for missing steps (migrations, localization, tests, config)
- Verify the plan doesn't violate any architecture decisions in CLAUDE.md

## Output Format

```markdown
# Blueprint: [Feature Name]

## Objective
[One line]

## Steps

### Step 1: [Title]
**Context brief:** [Everything a fresh agent needs to know]
**Files:** [List of files to read/create/modify]
**Changes:** [Specific changes to make]
**Tests:** [What tests to write]
**Done when:** [Clear acceptance criteria]
**Blocks:** Step 2, Step 3

### Step 2: [Title]
**Blocked by:** Step 1
...

## Dependency Graph
Step 1 → Step 2 → Step 4
Step 1 → Step 3 → Step 4

## Parallel Opportunities
Steps 2 and 3 can run in parallel (different modules)

## Risks
- [Risk 1]: [Mitigation]
- [Risk 2]: [Mitigation]

## Estimated Steps: N | Critical Path: Steps 1→2→4
```

Save the blueprint to `docs/blueprints/[feature-name].md` for future sessions.

$ARGUMENTS
