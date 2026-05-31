# Assignee-driven flow — assign to Priya → auto-handoff to Matt → Done

> Goal (Amit): drop the `agent:*` labels. A human just **assigns a JIRA ticket to Priya**. Priya
> gates quality + necessity; on pass the system **auto-reassigns to Matt**, builds, opens a PR, and
> on merge moves the ticket to **Done** with a completion summary — all automatic.
>
> The **repo side is built and merged, flag-gated OFF**. It activates once the JIRA-admin steps below
> are done and the repo variables are set. Until then, the existing label flow is unchanged.

## How it works once enabled
```
Human assigns ticket to Priya  (JIRA Automation rule → repository_dispatch → producer)
   → Priya quality gate + necessity (Meera/Sunita/Doctor)
        not-needed / needs-clarification → comment + hold (no build)
        PASS + needed → producer auto-assigns ticket to MATT, status → In Progress, enqueues
   → Worker (Matt) builds → draft PR → review/merge policy
   → on merge: ticket → Done + Matt completion summary (already live, WS7)
```
Assigning to Priya **is** the human GO — no labels, no separate go step.

## YOUR JIRA-admin steps (tomorrow, need admin)
1. **Create two Atlassian users** and give them access to project NUO (assignable):
   - **Priya** (intake/QA) and **Matt** (builder). Service accounts preferred.
   - Capture each **accountId** (Profile → the `…/people/<accountId>` URL, or
     `GET /rest/api/3/user/assignable/search?project=NUO&query=matt`).
2. **Statuses** — confirm or add (NUO currently has: Backlog, To Do, In Progress, On-going, On-HOLD,
   Testing, Done). The flow needs an **In Progress** equivalent and ideally **Needs Clarification**.
   You can map to existing names instead of adding new ones (see repo vars below).
3. **Automation rule:** *When* issue **assignee changes to Priya** → *Send web request*:
   - `POST https://api.github.com/repos/<owner>/<repo>/dispatches`
   - Headers: `Authorization: Bearer <PAT>`, `Accept: application/vnd.github+json`
   - Body: `{"event_type":"jira-ticket-assigned","client_payload":{"ticket_key":"{{issue.key}}"}}`
4. **Store the GitHub PAT** (repo `contents`+`actions` scope, or fine-grained dispatch) as a secret in
   that JIRA rule.

## Repo variables to set (I'll do this with you once accountIds exist)
```
gh variable set SWASTH_ASSIGNEE_FLOW --body on
gh variable set JIRA_MATT_ACCOUNT_ID --body '<matt accountId>'
# only if your status names differ from the defaults:
gh variable set SWASTH_STATUS_IN_PROGRESS --body 'In Progress'
gh variable set SWASTH_STATUS_NEEDS_CLARIFICATION --body 'Needs Clarification'
```
(`JIRA_PRIYA_ACCOUNT_ID` isn't required by the producer — the JIRA rule already fires only on
assignment to Priya.)

## What the repo side does (already merged, OFF)
- `scripts/jira_assign.sh <ticket> <accountId>` — reassign helper.
- Producer (`jira-agent-trigger.yml`): `ASSIGNEE_FLOW` flag; a single **Decide proceed-to-build**
  step (covers legacy / intake-gate / assignee modes identically); a **Hand off to Matt** step
  (reassign + In Progress) when proceeding under the assignee flow. Label flow stays as fallback.
- Completion → Done is already live (WS7, `jira-agent-pr-closed.yml`).

## Rollback
`gh variable set SWASTH_ASSIGNEE_FLOW --body off` → back to the label flow. Fully reversible.

## Smoke test (tomorrow)
Assign one real low-risk ticket to Priya → watch the producer run: quality+intake → reassign to Matt
→ In Progress → worker build → draft PR. Confirm each hop, then we widen.
