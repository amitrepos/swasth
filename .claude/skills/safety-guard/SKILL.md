---
name: safety-guard
description: "Prevent destructive operations — blocks rm -rf, force push, DROP TABLE, etc."
---

# Safety Guard

Activated to review and prevent potentially destructive operations before they execute.

## Blocked Operations (NEVER allow without explicit user confirmation)

### Filesystem
- `rm -rf` on any directory outside `/tmp/`
- `rm -r` on project root or home directory
- Deleting `.git/` directory
- Overwriting files without reading them first

### Git
- `git push --force` (especially to main/master)
- `git reset --hard` (destroys uncommitted work)
- `git clean -fd` (deletes untracked files)
- `git checkout .` (discards all changes)
- `git branch -D` on shared branches
- `git rebase` on published commits

### Database
- `DROP TABLE` / `DROP DATABASE`
- `DELETE FROM` without WHERE clause
- `TRUNCATE TABLE` on production
- Schema migrations that delete columns with data

### Process
- `kill -9` on unknown processes
- `pkill` with broad patterns
- Modifying system files (`/etc/`, `/usr/`)

### Secrets
- Committing `.env` files
- Printing API keys or tokens to stdout
- Sending secrets in URL parameters

## When This Skill is Invoked
This skill's principles should be internalized — Claude should ALWAYS check for destructive operations before executing them, not just when `/safety-guard` is called.

The explicit `/safety-guard` invocation is for:
1. Reviewing a batch of planned operations before execution
2. Auditing recent commands for safety violations
3. Setting up a "careful mode" for a risky session (e.g., database migration)

## Instructions
1. List all planned operations
2. Flag any that match the blocked operations list
3. For each flagged operation: explain the risk, suggest a safer alternative
4. Only proceed after explicit user confirmation for each flagged operation

$ARGUMENTS
