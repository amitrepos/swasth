# Claude Code Developer Toolkit — Portable Template

A reusable Claude Code configuration that enforces a professional development lifecycle on any project. Copy this into any new repo to get automated testing, security scanning, code review, and PR workflows out of the box.

## Quick Setup

```bash
# 1. Copy the template files into your project root
cp -r docs/claude-toolkit-template/.claude-template/ .claude/
cp docs/claude-toolkit-template/CLAUDE-TEMPLATE.md CLAUDE.md
cp docs/claude-toolkit-template/RULES-TEMPLATE.md RULES.md
cp docs/claude-toolkit-template/WORKING-CONTEXT-TEMPLATE.md WORKING-CONTEXT.md
cp docs/claude-toolkit-template/.mcp-template.json .mcp.json

# 2. Customize CLAUDE.md with your project details
# 3. Customize RULES.md with your tech stack rules
# 4. Update WORKING-CONTEXT.md with your current sprint
# 5. Restart Claude Code to load MCP servers
```

## What's Included

### Files
| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project instructions + mandatory development lifecycle |
| `RULES.md` | Must Always / Must Never guardrails |
| `WORKING-CONTEXT.md` | Live sprint board (branch, PRs, blockers) |
| `.mcp.json` | MCP servers (GitHub + Context7 live docs) |
| `.claude/settings.local.json` | Hooks (block-no-verify, auto-format, config-protection, audit log, pre-compact-save) |
| `.claude/skills/tdd-workflow/` | `/tdd` — test-driven development |
| `.claude/skills/security-audit/` | `/security-audit` — OWASP Top 10 scan |
| `.claude/skills/ship/` | `/ship` — full pipeline: test → security → review → PR |
| `.claude/skills/daniel-review/` | `/review` — senior engineer code review |

### Development Lifecycle (auto-enforced)
```
Requirement → Plan → Implement → Test → Security → Review → PR
```

Every conversation where Claude receives a feature/bugfix request will follow this lifecycle automatically — no user intervention needed between steps.

### Hooks (fire automatically)
- **block-no-verify** — prevents `--no-verify` on git commits
- **config-protection** — warns when editing linter/CI configs
- **auto-format** — formats code after every edit
- **audit-log** — logs every file change to AUDIT.md
- **pre-compact-save** — saves state before context compaction

## Customization Points

1. **CLAUDE.md** — Replace project overview, architecture decisions, and code rules with your own
2. **RULES.md** — Adjust Must Always/Must Never for your tech stack
3. **settings.local.json** — Change auto-format commands for your language (dart format, black, prettier, etc.)
4. **daniel-review skill** — Customize the reviewer persona and project-specific rules
5. **security-audit skill** — Add/remove checklist items for your domain (healthcare, fintech, etc.)
6. **.mcp.json** — Add/remove MCP servers as needed

## Tech-Stack Specific Adaptations

### Python + FastAPI (current)
- Auto-format: `black`
- Tests: `pytest`
- Linter: `pyproject.toml`

### Node.js / TypeScript
- Auto-format: `prettier`
- Tests: `jest` or `vitest`
- Linter: `eslint.config.js`

### Go
- Auto-format: `gofmt`
- Tests: `go test ./...`
- Linter: `.golangci.yml`

### React Native / Swift
- Auto-format: `prettier` / `swiftformat`
- Tests: `jest` / `XCTest`
