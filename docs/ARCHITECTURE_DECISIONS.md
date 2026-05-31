# Architecture Decisions (do not change without discussion)

> Moved out of `CLAUDE.md` (Phase 1c). `CLAUDE.md` links here.

- **Auth:** email + password + JWT (no Firebase for PoC).
- **DB:** PostgreSQL via SQLAlchemy.
- **Auth dependency:** `backend/dependencies.py → get_current_user`.
- **Shared HTTP utils:** `lib/services/api_client.dart → ApiClient`.
- **Theme:** all colors via `AppColors` in `lib/theme/app_theme.dart` — never hardcode colors.
- **Localization:** Flutter gen-l10n — strings in `lib/l10n/app_en.arb` + `app_hi.arb`; never hardcode UI strings.
- **Secrets:** never committed — `backend/.env` is gitignored.
- **Production infra:** AWS Mumbai (ap-south-1), EC2 `swasth-prod` t3.micro, Elastic IP
  `13.127.215.113`. Hetzner decommissioned. Source of truth: `docs/aws/AWS_ARTIFACTS.md`.
