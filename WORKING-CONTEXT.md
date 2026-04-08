# Swasth — Working Context (Live Sprint Board)

> **Updated:** 2026-04-08
> **Sprint:** Bihar Pilot Prep
> **Branch:** `feature/living-heart-widget`
> **Base:** `master`

---

## Current Focus
Living Heart widget — replacing score donut ring with animated heart visualization.

## Open PRs
| # | Title | Branch | Status |
|---|-------|--------|--------|
| 63 | Fix phone validation schema + Flutter session logic | `fix/phone_validation_and_session` | Open |
| 62 | Feature/fixed history | `feature/fixed_history` | Open |

## Active Constraints
- Bihar pilot launch imminent — stability over features
- Elderly users on budget Android phones — performance matters
- Hindi + English mandatory on all new UI strings
- No Firebase dependency (JWT auth only)

## Blockers
- **WhatsApp Business API** (D8) — Meta approval pending, 2-5 day wait
- **Offline mode** (A9) — Hive implementation rolled back for stability

## Recent Decisions
- A12 onboarding replaced with YouTube tutorial link (simpler)
- Hive offline caching rolled back 2026-03-31 to stabilize
- AI Doctor uses Gemini 2.5 Flash → DeepSeek V3 → rule-based fallback chain

## Next Up (Priority Order)
1. Merge living heart widget PR
2. D7 — Critical value alerts to family (safety critical)
3. D8 — WhatsApp API integration (waiting on Meta approval)
4. Weight tracking (B3/B6/C8) — enables BMI trends

## Session Notes
<!-- Append dated notes here during each working session -->
