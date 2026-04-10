# Swasth — Project Rules

## Must Always
1. **Use `AppColors.*`** for all semantic colors — never raw `Colors.*`
2. **Use `AppLocalizations.of(context).*`** for all user-facing strings — never hardcode
3. **Use `ApiClient.headers()` + `ApiClient.errorDetail()`** for all Flutter HTTP calls
4. **Use `Depends(get_current_user)`** for all authenticated backend endpoints
5. **Update `AUDIT.md`** at the end of every session with changes made
6. **Update `WORKING-CONTEXT.md`** when branch, PR status, or priorities change
7. **Check `TASK_TRACKER.md`** before starting any new feature work
8. **Run Daniel review** on every PR before merging (automated via hooks)
9. **Test on budget Android** mental model — large touch targets, solid colors, no heavy animations
10. **Encrypt health data** — AES-256-GCM for data at rest, TLS for transit

## Must Never
1. **Never commit secrets** — `.env`, API keys, credentials must stay gitignored
2. **Never use `print()` in backend** — clean up if encountered
3. **Never skip `--no-verify`** on git commits — hooks exist for a reason
4. **Never add Firebase dependencies** — JWT auth is the architecture decision
5. **Never hardcode font sizes without considering elderly users** — minimum 14sp
6. **Never use gradients** — they wash out on budget phones in sunlight
7. **Never merge without Daniel's review** — code quality is non-negotiable
8. **Never re-implement completed milestones** — check TASK_TRACKER.md first
9. **Never modify architecture decisions** in CLAUDE.md without explicit discussion
10. **Never add decorative animations** — every animation must convey meaning

## Commit Style
Use conventional commits:
```
feat(module): short description
fix(module): short description  
docs: short description
test: short description
refactor(module): short description
```
Modules: `auth`, `dashboard`, `ble`, `ai`, `charts`, `profile`, `theme`, `l10n`, `admin`

## Model Routing

Use the right model for the right task — saves cost and improves speed.

| Task | Skill | Model | Why |
|------|-------|-------|-----|
| Architecture planning | `/blueprint` | **Opus** | Complex reasoning, multi-step decomposition |
| Code review | `/review` | **Opus** | Security + correctness need deep analysis |
| Security audit | `/security-audit` | **Opus** | Must not miss vulnerabilities |
| PHI compliance | `/phi-compliance` | **Opus** | Regulatory — can't afford errors |
| Decision panel | `/council` | **Opus** | 4-voice synthesis needs strongest reasoning |
| Legal check | `/legal-check` | **Opus** | Regulatory accuracy critical |
| UX review | `/ux-review` | **Opus** | Design judgment needs experience |
| Doctor feedback | `/doctor-feedback` | **Opus** | Persona fidelity matters |
| TDD workflow | `/tdd` | **Sonnet** | Routine code generation, speed matters |
| Verification gate | `/verify` | **Sonnet** | Mostly running commands + checking output |
| Ship pipeline | `/ship` | **Sonnet** | Orchestration, not deep reasoning |
| Pattern capture | `/learn` | **Sonnet** | Lightweight extraction |
| File search / exploration | Agent(Explore) | **Haiku** | Fast, cheap, just finding files |
| Quick code edits | Direct | **Sonnet** | Routine implementation work |

**Rule of thumb:**
- **Opus** = judgment calls (review, security, architecture, compliance)
- **Sonnet** = execution (coding, testing, running pipelines)
- **Haiku** = lookup (file search, grep, quick reads)

## File Organization
- Backend routes: `backend/routes*.py`
- Backend models: `backend/models.py`
- Flutter screens: `lib/screens/*.dart`
- Flutter services: `lib/services/*.dart`
- Flutter theme: `lib/theme/app_theme.dart`
- Flutter BLE: `lib/ble/*.dart`
- Localization: `lib/l10n/app_en.arb` + `app_hi.arb`
- Tests (backend): `backend/tests/`
- Tests (Flutter): `test/`
