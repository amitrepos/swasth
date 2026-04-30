# Swasth — Developer Spec Documents

**Version:** 1.0 · **Last updated:** 2026-04-20 · **Target audience:** New backend, frontend, and full-stack engineers joining the Swasth team.

---

## What is Swasth?

Swasth is a health monitoring app for rural and semi-urban India (Bihar pilot). It lets families log health readings (glucose, blood pressure, SpO2, weight, steps, meals), share readings with doctors and family members, and receive AI-generated health insights. The product is a Flutter client (Android + web) talking to a FastAPI + PostgreSQL backend.

**Core value propositions:**

1. **Family-first health logging** — one adult can monitor readings for elderly parents, spouse, children. Multi-profile with access control.
2. **Doctor portal** — verified doctors can receive patient readings and leave clinical notes. Consent-driven, DPDPA-compliant.
3. **AI insights** — Gemini + DeepSeek generate weekly trends, meal tips in English/Hindi.
4. **Offline-first** — readings cached locally when offline, synced when online.
5. **Critical alert fanout** — dangerous readings trigger email + WhatsApp + SMS to family in real-time.

---

## How to read these docs

Read in order if new to the project. Jump directly if you already know the stack.

| # | Document | Read if you are… |
|---|---|---|
| 1 | [Developer Onboarding](01-DEVELOPER-ONBOARDING.md) | A new hire on day 1. Setup, first PR, daily workflow. |
| 2 | [System Architecture](02-SYSTEM-ARCHITECTURE.md) | Any engineer wanting the 10,000-foot view. |
| 3 | [Backend Spec](03-BACKEND-SPEC.md) | Working on FastAPI / Python / PostgreSQL. |
| 4 | [Frontend Spec](04-FRONTEND-SPEC.md) | Working on Flutter / Dart / UI. |
| 5 | [Data Model](05-DATA-MODEL.md) | Designing migrations, queries, or new entities. |
| 6 | [API Reference](06-API-REFERENCE.md) | Building a client or integrating with the backend. |
| 7 | [Security & Compliance](07-SECURITY-AND-COMPLIANCE.md) | Touching auth, PHI, consent, or legal-sensitive code. |
| 8 | [Testing & Deployment](08-TESTING-AND-DEPLOYMENT.md) | Writing tests, CI/CD, or shipping to production. |

---

## Other canonical docs in this repo (outside specs/)

These are living operational docs — check them often:

- `CLAUDE.md` — Claude Code development pipeline and enforced gates.
- `RULES.md` — Must-always / must-never coding rules.
- `WORKING-CONTEXT.md` — Current sprint, live branches, blockers.
- `TASK_TRACKER_PENDING.md` — All incomplete tasks, prioritized.
- `TASK_TRACKER_COMPLETED.md` — Archive of shipped tasks.
- `AUDIT.md` — Session change log (append-only).
- `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` — NMC / DPDPA / SaMD legal checklist.
- `backend/migrations/README.md` — Alembic migration workflow.

---

## Who to ask

- **Product / strategy:** Amit Mishra (founder) — amitkumarmishra@gmail.com
- **Backend architecture:** Check `CLAUDE.md` and `backend/main.py` first.
- **Frontend architecture:** Check `lib/app.dart` and `lib/services/api_client.dart` first.
- **Legal / compliance:** `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` and the `/legal-check` skill.

---

## Contributing

Every change flows through the 9-stage pipeline defined in `CLAUDE.md` (understand → reality-check → plan → validate → implement → verify → secure → expert-QA → review → ship). Hooks in `.githooks/` and CI in `.github/workflows/` enforce the critical gates — you cannot commit backend model changes without a migration, cannot push without an open PR, and cannot merge without domain-expert reviews.

Read `01-DEVELOPER-ONBOARDING.md` for the full onboarding walkthrough.
