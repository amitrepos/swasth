# Ticket Grooming — Anya (and how to write AI-ready tickets)

> Anya is the backlog-refinement agent. She turns a rough ticket into an **AI-ready** ticket the build
> pipeline (Priya → Matt) can run, or hands it back with a concrete next step. This doc explains how
> to use her, what "AI-ready" means, and includes a copy-paste prompt to format a ticket yourself.

## How to use Anya
- **Assign the ticket to `Anya`** in JIRA. That's it — the "assignee → Anya" Automation rule triggers
  the grooming workflow. Only assign tickets you want *built by the agent pipeline*; operational /
  non-dev tickets — just don't assign them to her.
- Anya reads the ticket + the repo, then does one of:
  | Outcome | What she does | Label |
  |---|---|---|
  | **ai-ready** | already good + one-PR-sized → just labels it | `ai-ready` |
  | **rewritten** | rewrites it into AI-ready form (posted as a comment) | `ai-ready` |
  | **needs-split** | too big → posts a split proposal (draft child tickets) for you to create | `needs-split` |
  | **needs-human** | ambiguous → posts numbered questions | `needs-human` |
- **She hands the ticket back to you** (reassigns to the reporter) every time. For `ai-ready`, you
  then **assign it to Priya** to start the build (human GO checkpoint stays).

## What "AI-ready" means (Definition of Ready)
All seven, same rubric Priya enforces:
1. User story — "as a `<role>`, I want `<outcome>`, so that `<value>`".
2. ≥2 testable acceptance criteria.
3. Explicit in-scope / out-of-scope.
4. **Affected Surfaces** — the file paths touched (the build's churn gate parses this).
5. Data shape (types/keys) if new data, else "None".
6. ≥1 edge case.
7. No vague language ("improve", "make better").

**Right size = one PR** (one vertical slice, one cohesive area, ≈ ≤5 related files). Bigger → split.

## The required Affected Surfaces format
The build gate parses an **Affected Surfaces** section with **backticked file paths**. In a JIRA
description, write it in JIRA-wiki form so it renders correctly:
```
h2. Affected Surfaces
* {{lib/utils/metric_ranges.dart}}
* {{test/utils/metric_sources_live_links_test.dart}}
```

## Copy-paste prompt — format a ticket yourself with any AI
If you'd rather format a ticket by hand (no Anya), paste this into any AI chat with your rough ticket:
```
Rewrite this ticket into an "AI-ready" JIRA ticket. Output JIRA wiki markup with these sections:
h3. User story  (as a <role>, I want <outcome>, so that <value>)
h3. Acceptance criteria  (at least 2 bullets, each testable/observable)
h3. Scope  (in scope / out of scope bullets)
h2. Affected Surfaces  (bullets, each a file path in {{double braces}} monospace)
h3. Data shape  (types/keys, or "None")
h3. Edge cases  (at least one negative path)
Rules: keep it to ONE PR of work (one cohesive area, ≈≤5 related files). If it's bigger,
instead output a split into 2–5 smaller tickets, each in the same format. Be concrete about
file paths. Don't invent scope. Here is the ticket:
<paste the rough ticket here>
```

## Labels
- `ai-ready` — passed grooming; assign to Priya to build.
- `needs-split` — too big; see Anya's split proposal comment, create the children, assign each to Anya/Priya.
- `needs-human` — product input needed; answer Anya's questions, then re-assign to Anya.

## Enabling (one-time, JIRA admin)
1. Create an **`Anya`** Atlassian user, assignable on NUO; capture her accountId.
2. Clone the `Swasth-AutoPick` automation rule → condition `assignee = Anya` → *Send web request*
   `repository_dispatch` with `event_type: jira-ticket-groom`, body
   `{"client_payload":{"ticket_key":"{{issue.key}}","reporter_account_id":"{{issue.reporter.accountId}}"}}`.
3. `gh variable set JIRA_ANYA_ACCOUNT_ID --body '<id>'` and `gh variable set SWASTH_GROOMING_ENABLED --body on`.
   Until enabled, the workflow runs DRY-RUN (classifies + logs, no JIRA writes) — test via
   `workflow_dispatch` with a `ticket_key`.

## Rollback
`gh variable set SWASTH_GROOMING_ENABLED --body off` → DRY-RUN; or remove the JIRA rule. Fully reversible.
