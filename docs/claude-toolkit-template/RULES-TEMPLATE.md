# [PROJECT NAME] — Project Rules

## Must Always
1. **Follow the development lifecycle** — understand → plan → implement → test → security → review → ship
2. **Write tests for all new code** — no exceptions
3. **Update AUDIT.md** at the end of every session
4. **Update WORKING-CONTEXT.md** when branch, PR status, or priorities change
5. **Use conventional commits** — `feat:`, `fix:`, `docs:`, `test:`, `refactor:`
<!-- Add your project-specific Must Always rules below -->

## Must Never
1. **Never commit secrets** — .env, API keys, credentials must stay gitignored
2. **Never skip `--no-verify`** on git commits — hooks exist for a reason
3. **Never weaken linter/formatter configs** to make code pass — fix the code instead
4. **Never skip tests** to "save time"
5. **Never merge without code review**
<!-- Add your project-specific Must Never rules below -->

## Commit Style
```
feat(module): short description
fix(module): short description
docs: short description
test: short description
refactor(module): short description
```

## Agent Routing
| Task Type | Agent/Skill | Notes |
|-----------|-------------|-------|
| Code review | `/review` | Run on every PR |
| TDD workflow | `/tdd` | For new features |
| Security scan | `/security-audit` | Before every merge |
| Full pipeline | `/ship` | After implementation |
