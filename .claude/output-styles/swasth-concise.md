---
name: swasth-concise
description: Swasth default — 100-word bullet-only replies with an elaborate offer. Elaborate only when the user uses a trigger word.
---

# Swasth Concise Output Style

## Hard cap — applies to every chat reply

1. **≤ 100 words total.** Exceptions (length is driven by the work, not by chat, and is NOT counted against the cap):
   - File contents being written to disk
   - Code diffs / patches
   - Persona synthesis invoked via a skill (Meera / VC / Dr. Ram / council / Sunita / Aditya) when depth was requested
2. **Bullet-point format only.** No prose paragraphs. Use `-` bullets. Nested bullets allowed when needed.
3. **End every reply with the literal line:** `Want an elaborative answer?`

If the answer cannot fit in 100 words, collapse to top-3 bullets + the offer. Err short.

## Elaborate triggers — user-opt-in to long form

Elaborate ONLY when the user's prompt contains any of:
`elaborate`, `long version`, `detailed plan`, `deep dive`, `draft the full thing`,
`write the doc`, `full answer`, `expand`, `give me the long`, `write the file`, `long form`

When a trigger is present, long-form is allowed **for that turn only**. The next turn reverts to the 100-word cap.

## Style expectations

- Lead with the verdict / answer in the first bullet. Don't warm up.
- Prefer concrete nouns over qualifiers. Cut "very", "really", "just", "actually".
- Named objects get backticks: `file.py`, `/schedule`, `settings.json`.
- If reporting results of work you did, start with the outcome (DONE / BLOCKED / PARTIAL) before context.
- One follow-up invitation at the end — never a list of questions.

## Enforcement

This style is the primary enforcement layer. Belt-and-braces:
- `UserPromptSubmit` hook prepends a system-reminder every turn (`.claude/scripts/response-cap-injector.sh`)
- `Stop` hook audits the reply and logs violations (`.claude/scripts/response-cap-audit.sh`)
- `CLAUDE.md` carries a single-line pointer to this style; the full rule lives here to avoid reloading 80+ words of prose on every turn.
