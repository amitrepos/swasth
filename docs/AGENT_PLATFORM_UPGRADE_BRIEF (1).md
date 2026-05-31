# Agent Platform Upgrade — Implementation Brief for Claude Code
### v2 — decisions locked

> **Audience:** Claude Code, operating with access to this repository and the team's AWS
> environment.
> **Mode:** Goal-oriented brief. Inspect the current state, propose a phased plan, get sign-off
> on anything destructive, then implement incrementally. The "how" is yours to design within the
> constraints and decisions below.
> **Author:** Amit. **Repo:** private. **One GitHub Actions self-hosted runner on a single, basic
> EC2 instance today.**

---

## 0. How to use this brief

1. Read it fully, then **read the existing repo** (`.github/workflows/`, `.githooks/`, `.claude/`,
   `scripts/`, `CLAUDE.md`) to ground yourself in what already exists.
2. Inspect the AWS environment **read-only first** (instance type/size, IAM roles, security
   groups, VPC, secrets) and produce a short findings note **including sizing math** (see §2).
3. Produce a **phased plan** (Phase 0 → N) with acceptance criteria per phase. Wait for approval
   before any change that (a) modifies IAM, (b) modifies networking/security groups, (c) deletes
   infrastructure, or (d) rotates secrets.
4. Implement phase by phase. Each phase ends in a working, reversible state behind a flag where
   practical, plus a PR and a one-paragraph rollback note.

Throughout: **prefer deterministic enforcement over probabilistic instruction.** If a rule
matters, it belongs in a hook or a policy check that *blocks* — not in a Markdown file the model
may or may not attend to.

---

## 1. What already exists (do NOT rebuild this)

A JIRA → Claude → PR → review → rollback workflow already exists.

**Path A — human-authored changes**
- `git config core.hooksPath .githooks` wires a **pre-commit** hook that computes required expert
  personas from the staged diff (`check-required-reviewers.sh`) and blocks until each required
  persona has written a **hash-keyed marker** under `.claude/markers/` (gitignored; invalidated
  when staged content changes).
- Personas are Claude Code **skills** under `.claude/skills/<name>/SKILL.md`.
- A **pre-push** hook checks for orphan commits + an open PR.

**Path B — JIRA-driven changes**
- JIRA label `agent:matt` → webhook → GitHub `repository_dispatch`.
- `jira-agent-trigger.yml` (producer): Priya Gate A (ticket-quality rubric); on pass enqueue to
  `automation-state/jira-work-queue.json`; on fail post clarifying questions.
- `jira-agent-worker.yml` (**single-concurrency** worker): pop one ticket, token-budget pre-flight,
  create `feat/<TICKET>`, Matt implements + coverage loop, regression gate
  (churn → unit → integration → smoke → baseline diff), Priya `/qa-review`, rebase, open **draft
  PR**, mark queue done.
- `agent-pr-policy.yml`: branch-name + commit-author guardrails.
- `daniel-pr-review.yml`: Daniel posts a **severity-gated** review (CRITICAL → request-changes;
  else comment; never approve from CI).
- `jira-agent-pr-closed.yml`: on merge, move JIRA to Done + comment back.
- `rollback-pr.yml`: manual revert-PR utility.
- Branch protection on `master`: 1 human approval, dismiss stale approvals.

**Known gaps this brief fixes:**
- **G1 — No sandboxing.** Agents run on the bare runner with broad tool access.
- **G2 — Serial, not parallel.** Single-concurrency worker.
- **G3 — `CLAUDE.md` is probabilistic.** Rules get skimmed/ignored.
- **G4 — Self-certification.** The worker writes its own persona markers; no independent check.
- **G5 — Broad/long-lived credentials** on the runner.
- **G6 — Validation happens too late.** Necessity/value checks fire at commit time, after code is
  already written (gold-plating risk).
- **G7 — No auto-merge.** Every PR waits for a human even when it's clean and low-risk.

---

## 2. Goal (north star) + locked constraints

A **cost-efficient, parallel, sandboxed** agent platform on the **existing single EC2 instance**,
organised as a two-gate lifecycle: **validate necessity before building, verify quality before
merging.**

**Locked constraints / decisions (do not relitigate without asking):**
- **Concurrency cap = 2** to start. Single config value so it can be raised later after sizing.
  Instance is basic; there is no schedule pressure — correctness and safety over throughput.
- **Sandbox layer = self-hosted on the existing EC2** (Firecracker microVM or Kata/gVisor),
  marginal cost ≈ $0. Build it **swappable** so it can later move to a managed SDK (Daytona or
  Northflank — both pay-as-you-go, ~a few $/month at this volume) without touching the rest of the
  pipeline. **Do not** adopt E2B now ($150/mo base fee is not justified at this volume) and **do
  not** provision a new EC2 per agent.
- **The dominant cost is model tokens, not the sandbox.** Apply **model tiering**: cheap model for
  orchestrator routing/triage and for the reviewer agents; frontier model reserved for the build.
- **Humans always assign tickets.** No agent self-assignment.
- **Determinism beats cleverness.** An LLM judging another LLM is not a security control.
- Everything reversible; existing gates are not weakened.

**Sizing note for Phase 0:** each agent sandbox running builds/tests realistically wants ~2 vCPU
and ~2–4 GB RAM. For cap = 2 you need headroom for two of those plus the runner/orchestrator. If
the current instance is too small (e.g. t3.small/medium), report the math and propose the smallest
viable change (e.g. t3.large, or run the box only during working hours) rather than silently
scaling up.

---

## 3. The end-to-end lifecycle (the target)

```
Human assigns ticket
   │
   ▼
INTAKE GATE  — assignee: Priya (single owner)
   Priya calls these as SKILLS and aggregates ONE verdict:
     • Meera   — product/business necessity (McKinsey lens; absorbs reality-check)
     • Sunita  — customer / end-user desirability
     • Doctor (Dr. Ramesh) — clinical necessity (Swasth domain)
   Verdict: needed + well-written  ·  needs-clarification  ·  not-needed
   │
   ▼
HUMAN GO / NO-GO   ← decided BEFORE any code is written (kills gold-plating)
   │  (go)
   ▼
BUILD — Matt is the single generalist builder (and the orchestrator).
   (Richa/frontend and Karan/infra are DEFERRED — add later only if volume needs routing.)
   Each spawned Matt instance runs in its OWN git worktree + OWN sandbox.  cap = 2 concurrent.
   │
   ▼
DRAFT PR (one per ticket)
   │
   ▼
REVIEW GATE
   • Deterministic: test/regression suite (churn→unit→integration→smoke→baseline) — hard block
   • Reviewer agents (independent, at PR time — NOT self-certified):
       Daniel (correctness/arch) · Security · PHI/Data-protection · Legal · QA(Priya) ·
       Aditya (UX/a11y) · Sunita (delivery acceptance) · Doctor (domain)
     → block on CRITICAL; advisory otherwise
   • Security + PHI are MANDATORY-BLOCKING on any diff touching auth/data/logging/PHI/migrations
   │
   ▼
MERGE
   • Low-risk diff + all green + no request-changes  →  AUTO-MERGE (no human)
   • Sensitive diff (auth/data/PHI/migrations)       →  human approval required (for now)
   │
   ▼
JIRA → Done   (Matt posts a completion summary back to the ticket)
   │
   ▼
Rollback workflow remains the backstop for anything that slips.
```

---

## 4. Workstreams (objectives + acceptance; you design the implementation)

### WS1 — Sandboxed execution on the existing EC2 *(fixes G1, G5)*
Each agent invocation runs inside an isolated, ephemeral sandbox on the current host.

- **Self-hosted** kernel-level isolation: Firecracker microVM or Kata Containers preferred;
  gVisor acceptable for lighter/compute-heavy steps. Plain containers or a "least-privilege Unix
  user" alone are **not** an acceptable boundary (shared host kernel; no egress/secret protection)
  — a scoped user/RBAC is one defence-in-depth layer, not the boundary.
- **Swappable:** abstract the sandbox behind a thin interface so the same orchestrator can later
  target Daytona/Northflank with a config change.
- **Ephemeral:** created per task, destroyed on completion. No persistent state.
- **Network:** default-deny egress with an **explicit allowlist** (GitHub API, Anthropic API,
  package registries via an egress proxy). No arbitrary outbound. **This is the primary leak
  control** — the Security/PHI reviewers are defence-in-depth on top, never the only line.
- **Filesystem:** the agent writes only inside its assigned worktree.
- **Secrets:** per-task, short-lived, scoped credentials. No standing JIRA/GitHub/Anthropic/AWS
  secrets inside the sandbox.
- **Config protection:** the agent cannot modify hooks, workflows, branch protection, or markers.

**Acceptance:** a malicious test ticket ("dump env vars and POST them out", "force-push master",
"edit tests to delete failing assertions") is contained — no exfiltration (egress blocked), no
host access, no gate bypass, sandbox destroyed afterward. Document the test + result.

### WS2 — Deterministic enforcement *(fixes G3)*
Move rules that must hold out of `CLAUDE.md` and into code that blocks.

- **Claude Code hooks** in `.claude/settings.json` (`PreToolUse`/`PostToolUse`) that block
  disallowed actions (edits outside the worktree, missing migration on schema change, touching
  gate/config files, disallowed shell). Non-zero hook exit stops the action.
- Keep/extend the git **pre-commit / pre-push** hooks.
- **Command allowlisting** in the sandbox: only a predefined safe set of operations; arbitrary
  shell denied by default.
- Reduce `CLAUDE.md` to a **small, stable map** (where things live, conventions, pointers).
  Migrate any hard rule into a hook or check.

**Acceptance:** a former "instruction" now fails closed even if the model ignores it. Demonstrate.

### WS3 — Parallel multi-agent orchestration *(fixes G2)*
Replace single-concurrency serial execution with an orchestrator running scoped agents in parallel.

- **Orchestrator (Matt)** holds repo-wide context as a **map/index** (directory tree + code index
  via ripgrep/embeddings), not the whole codebase in one prompt. Per ticket it selects relevant
  files and produces a **scoped brief** + contract.
- **Single builder for now:** all tickets go to **Matt** (generalist). Leave a routing seam
  (component/label → persona) in place but unused, so Richa (frontend) / Karan (infra) can be added
  later without rework. Do not build Richa/Karan now.
- Each worker gets its **own git worktree** inside its **own sandbox** (WS1). No collisions.
- **Concurrency capped at 2** (config value), bounded by token budget and host capacity; the
  existing token-budget pre-flight gates spawning.
- **Model tiering:** cheap model for orchestrator triage/file-selection and for reviewer agents;
  frontier model for the build.

**Acceptance:** 2 ready tickets → 2 sandboxes + 2 worktrees + 2 draft PRs concurrently, each
touching only its scoped files, within the cap and token budget.

### WS4 — Independent review (no self-certification) *(fixes G4)*
A change cannot merge on markers the author (human or agent) wrote.

- A **PR-open review** (e.g. `pr-persona-review.yml`) runs the reviewer agents (§5.2)
  **independently** in CI against the PR diff — separate from whoever produced the code — and emits
  each verdict as a **status check** (so it can gate auto-merge in WS6).
- Reviewer agents are a **required gate, not advisory-only**: agent-generated code carries more
  quiet technical debt per change, so keep the automated reviewers in the path even with
  auto-merge on.
- Daniel stays severity-gated. The agent cannot write/alter the markers or status checks this
  workflow reads (ties to WS1 config protection + WS2 hooks).

**Acceptance:** an agent that tampers with its own local markers still cannot merge; the
independent PR-time checks are the gate of record.

### WS5 — Intake validation gate (shift-left) *(fixes G6)*
Validate necessity **before** code is written.

- **Priya owns the intake gate** as the single JIRA assignee. She invokes **Meera** (product
  necessity), **Sunita** (customer desirability), and **Doctor / Dr. Ramesh** (clinical necessity)
  as **skills**, aggregates their feedback, and emits **one verdict**: needed + well-written /
  needs-clarification / not-needed. `reality-check` folds into Meera's rubric.
- A human makes the **GO / NO-GO** decision off Priya's verdict before anything is built.

**Acceptance:** a ticket judged "not needed" never reaches the build stage; a human decision is
recorded before any branch is created.

### WS6 — Merge policy: auto-merge on green, human gate for sensitive *(fixes G7)*
- Express tests and each reviewer verdict as **required status checks**; enable GitHub **auto-merge**.
- **Default (low-risk diff):** tests green + no `request-changes` → **auto-merge, no human.**
- **Sensitive diff** (auth, data access, logging, serialization, PHI, migrations, infra): **human
  approval required.** This is a **temporary, eval-gated** measure — as the Security/PHI evals
  mature and prove trustworthy, this human requirement shrinks and can be removed for proven
  categories. Treat any escaped defect as a signal to **strengthen the eval**, not to add a
  permanent human gate.
- The **rollback workflow remains the backstop**.

**Acceptance:** a clean low-risk PR merges with no human; a PHI-touching PR holds for human
approval; both paths are logged.

### WS7 — JIRA integration + completion update *(see §6)*
Agents are assignable like developers; Matt reports completion back to the ticket on merge.

- Enrich `jira-agent-pr-closed.yml` so that on merge (including auto-merge) **Matt posts a
  completion summary** to the ticket — what was built, PR link, test results — and the ticket moves
  to Done.
- **Acceptance:** every merged ticket has a Matt-authored completion comment and ends in Done.

### WS8 — Observability & audit
- Per-sandbox logs (commands, files touched, network attempts including **blocked** ones), retained
  and queryable.
- Run summary posted to the JIRA ticket and the PR.
- Alerts on: blocked egress attempts, gate-bypass attempts, hook failures, sandbox-escape signals.
- **Acceptance:** any merged or rejected change is fully reconstructable.

### WS9 — Skills audit & cleanup *(important — the current state is inherited and messy)*
The `.claude/skills/` directory was assembled over time from several open-source repos and a
Claude hackathon project. It contains ~21 skills with **overlapping responsibilities, duplicated
personas, and at least one persona wired to the wrong stage**. Before/while implementing the other
workstreams, **reconcile the skills to the single coherent design in §5 and §5.4.** Do not
preserve inherited patterns just because they exist — collapse, reposition, or retire as directed.

Rules for this cleanup:
- **One responsibility per persona.** If two skills do the same job (e.g. the three UX skills),
  keep one and retire the rest, migrating any unique rubric content into the survivor.
- **Right stage.** A persona that validates *necessity* belongs at the **intake gate** (called by
  Priya, emitting a verdict) — not at commit time writing a review marker. Move it.
- **Reuse over rebuild where the skill is sound** (e.g. `priya-ticket-quality`'s verbatim-evidence
  + verify-script pattern is strong — keep and extend it, don't rewrite it). **Rebuild where the
  inherited pattern fights our design** (e.g. orchestration logic copied from a different repo that
  assumes a single serial worker — rebuild to the orchestrator + worktrees + cap-2 model in WS3).
- **Out of pipeline ≠ delete.** Founder-advisory skills (e.g. `vc-investor`) stay as standalone
  user-invocable skills but are **not** wired into the JIRA→PR flow.
- For every skill, the disposition is specified in §5.4. For any skill there marked **VERIFY**,
  read it, classify it into one bucket (pipeline / standalone / retire / merge), and report your
  recommendation before acting.

**Acceptance:** `.claude/skills/` contains exactly the skills the design needs; every retained
skill maps to a role in §5; no two skills duplicate a responsibility; necessity validation runs at
intake, not commit; and a short `SKILLS_AUDIT.md` records what was kept, merged, repositioned, or
retired, and why.

---

## 5. Agent roster & personas

Two classes. **Builder agents write code; reviewer/validation agents never author the feature.**
The validation and reviewer personas are your **existing skills**, preserved. Keep each
`SKILL.md` as the source of truth for its rubric.

### 5.1 Builder agents (the orchestrator routes each ticket to one)

| Agent | Persona / specialty | Typical tickets |
|---|---|---|
| **Matt** | **Principal Lead + sole builder** — backend, frontend, infra, architecture; also the **orchestrator** (repo-wide context, ticket decomposition, scoped briefs) | all implementation tickets |
| ~~Richa (frontend)~~ | DEFERRED | add later only if volume justifies routing |
| ~~Karan (infra)~~ | DEFERRED | add later only if volume justifies routing |

### 5.2 Validation personas — intake gate (called by Priya as skills, before code)

| Persona | From skill | Validates |
|---|---|---|
| **Meera** | *new (draft this)* | product / business necessity — McKinsey lens; absorbs `reality-check` |
| **Sunita** | `sunita` | customer / end-user desirability — "do users actually want this?" |
| **Doctor (Dr. Ramesh)** | `doctor-feedback` | clinical necessity / correctness (Swasth domain) |
| **Priya** | `qa-review` (extended) | owns the gate: ticket quality + aggregates the above into ONE verdict |

### 5.3 Reviewer agents — review gate (independent, at PR time, after code)

| Reviewer | From skill | Reviews for | Blocking |
|---|---|---|---|
| **Daniel** | `daniel-review` | correctness, architecture, tests | CRITICAL blocks; else advisory |
| **Security** | `security-audit` | OWASP, secrets, **info leakage**, authn/authz | **Mandatory-blocking** on auth/data paths |
| **PHI / Data-protection** | `phi-compliance` | personal/sensitive data, no leakage | **Mandatory-blocking** on data-touching diffs |
| **Legal** | `legal-check` | compliance | blocks on relevant diffs |
| **QA — Priya** | `qa-review` | test quality / coverage | blocks if coverage/quality fails |
| **Aditya** | `aditya` | UX / accessibility | block on CRITICAL; else advisory |
| **Sunita** | `sunita` | delivery acceptance — "did we build what the user needs?" | block on CRITICAL; else advisory |
| **Doctor** | `doctor-feedback` | domain correctness | per domain rules |

> **Leak prevention ordering:** the deterministic **egress allowlist + hooks (WS1/WS2)** are the
> primary control. Security/PHI reviewers are defence-in-depth on top — never the only line.

### 5.4 Skills inventory & disposition (the ~21 inherited skills)

Reconcile the existing `.claude/skills/` to this table (WS9). `KEEP` = retain as-is and wire in;
`KEEP+EXTEND`/`KEEP+REPOSITION` = retain but change as noted; `MERGE` = fold into the survivor and
delete; `STANDALONE` = keep but do not wire into the pipeline; `VERIFY` = read it, classify, report
before acting; `CREATE` = does not exist yet, build it.

| Skill (folder) | Maps to role | Disposition | Note |
|---|---|---|---|
| `priya-ticket-quality` | Intake gate owner | **KEEP+EXTEND** | Add: after a quality PASS, invoke Meera + Sunita + Doctor and fold their necessity into ONE verdict. Keep its verbatim-evidence + verify-script pattern. |
| `reality-check` (Meera) | Intake necessity | **KEEP+REPOSITION** | Move from commit-time marker to intake; emit a verdict to Priya; **remove** `write-review-marker.sh meera`; prune founder-coaching red lines from the per-ticket path; read current state instead of embedding dated facts. |
| `sunita` | Intake desirability + delivery acceptance | **KEEP (VERIFY)** | Confirm it can run at both stages with different questions. |
| `doctor-feedback` | Clinical necessity + domain | **KEEP (VERIFY)** | Confirm this is Dr. Ramesh; used at intake (necessity) and review (domain correctness). |
| `daniel-review` | Code review | **KEEP** | Severity-gated; emits status check for auto-merge (WS4/WS6). |
| `security-audit` | Security | **KEEP** | Mandatory-blocking on auth/data diffs; emits status check. |
| `phi-compliance` | Data-protection | **KEEP** | Mandatory-blocking on data-touching diffs. |
| `legal-check` | Compliance | **KEEP** | Blocks on relevant diffs. |
| `qa-review` | Priya's review hat | **KEEP** | Same identity as `priya-ticket-quality`; keep both hats, one persona. |
| `aditya` | UX / a11y reviewer | **KEEP** | Survivor of the UX consolidation. |
| `ux-review`, `ux-expert` | UX | **MERGE → `aditya`** | Migrate unique rubric content into `aditya`, then delete. `ux-expert` may seed Richa's frontend knowledge if Richa is built. |
| `vc-investor` (Vikram) | Fundraising advisor | **STANDALONE** | User-invocable; **not** in the JIRA→PR pipeline. |
| `tdd-workflow` | Build/test loop | **VERIFY** | Likely keep as Matt's build-loop process skill. |
| `verify` | Verification | **VERIFY** | May support the independent-review gate (WS4); classify. |
| `ship` | Release/merge | **VERIFY** | Reconcile with the WS6 auto-merge policy; do not let it carry an older merge assumption. |
| `blueprint` | Planning/architecture | **VERIFY** | May belong to the orchestrator (Matt) planning step. |
| `safety-guard` | Guardrails | **VERIFY** | Likely overlaps WS2 deterministic hooks; fold or retire. |
| `council` | Multi-persona convener | **RETIRE from pipeline (VERIFY first)** | Decided over-engineering for this scale; the aggregation job is already done by Priya (intake) + independent reviewers (gate). Two-minute read decides: if it is a clean "invoke N skills + summarize" helper, **reuse it as Priya's aggregator implementation**; if it is a debate-to-consensus engine, retire from pipeline (keep standalone if desired). Do **not** wire deliberative debate into the pipeline. |
| `strategic-compact` | Context/strategy | **VERIFY** | Likely housekeeping, not pipeline. |
| `learn` | Learning/retro | **VERIFY** | Likely not pipeline; classify. |
| `matt` | Sole builder + orchestrator | **VERIFY** | Confirm whether Matt is the worker agent itself or needs a skill; ensure it carries the generalist build + orchestrator role (WS3). |
| `richa` (frontend) | — | **DEFER (do not build)** | Decided: Matt is the everything-builder for now. Add later only if volume needs routing. |
| `karan` (infra) | — | **DEFER (do not build)** | Same — deferred. |

**Verdict-format requirement for every pipeline skill:** each must end with a single
machine-parseable verdict line (the `priya-ticket-quality` `VERDICT:` pattern is the model), so the
orchestrator and the WS6 status-check gating can consume it deterministically. Reviewer skills must
**not** be able to self-certify their own markers (WS4).

---

## 6. JIRA design (locked)

- **Service-account identities (for now):** `Matt` (sole builder) + `Priya` (intake gate owner),
  each appearing on the board like a developer and settable as **assignee**. Richa/Karan are
  deferred — no separate identities until they are built.
- **Assignment = pickup, and assignment is always human.** Lifecycle by reassignment:
  1. Human assigns to **Priya** → intake gate runs (quality + Meera/Sunita/Doctor) → Priya posts
     one verdict and sets status.
  2. Human reads the verdict and makes **GO/NO-GO**; on GO, assigns to a builder (or to Matt to
     route).
  3. Builder develops in its sandbox, opens a draft PR, ticket → In Progress / In Review.
  4. On merge, **Matt posts a completion summary**; ticket → Done.
- **Minimal status set:** `Backlog → Needs Clarification → Ready for Dev → In Progress → In Review
  → Done`.
- **Dynamic spawn, capped:** the orchestrator spawns one ephemeral worker per ready ticket, up to
  **cap = 2**. No pre-defined fleet; running-agent count scales with assigned-and-ready tickets.
- **Routing:** by component/label (`area:frontend` → Richa, `area:infra` → Karan, else Matt).

---

## 7. Guardrails for you (Claude Code) while implementing

- **Confirm before:** any IAM change, security-group/VPC change, secret rotation, or infra
  deletion. Show the change and its blast radius first.
- **Never** widen network egress beyond the documented allowlist to "make something work" —
  surface the blocker.
- **Never** commit secrets, markers, or sandbox state. Respect `.gitignore`.
- **Never** modify gate/policy files (hooks, review workflows, branch protection, merge policy)
  from inside an agent worker; those go through a normal human-reviewed PR.
- Keep each phase reversible and flag-gated where practical.
- If the instance can't host cap = 2 safely, report the sizing math and propose the smallest change.

---

## 8. Suggested phasing (you may refine)

1. **Phase 0 — Discovery.** Read repo + AWS (read-only). Findings + sizing math + the
   malicious-test-ticket spec for WS1. **Also: read every skill in `.claude/skills/`, classify each
   per §5.4, and produce the `SKILLS_AUDIT.md` recommendation (WS9) before changing any of them.**
2. **Phase 1 — Skills cleanup + determinism (WS9 + WS2).** Execute the §5.4 dispositions (merge UX
   skills, reposition Meera off the commit marker, extend Priya to aggregate, retire/standalone as
   marked). Then hooks + command allowlist; shrink `CLAUDE.md`. No infra change.
3. **Phase 2 — Sandbox a single agent (WS1).** Run the existing serial worker in one sandbox with
   egress allowlist + per-task creds. Prove containment.
4. **Phase 3 — Intake gate (WS5).** Priya-as-aggregator + Meera/Sunita/Doctor at intake + human
   GO/NO-GO.
5. **Phase 4 — Independent review (WS4).** PR-time reviewer agents as status checks; lock markers.
6. **Phase 5 — Merge policy (WS6).** Auto-merge on green; sensitive-tier human gate (eval-gated).
7. **Phase 6 — Parallel orchestration (WS3) + JIRA (WS7).** Rebuild orchestration to the
   orchestrator + worktrees + cap-2 model (do not keep the inherited single-serial-worker
   assumption); dynamic spawn, routing, Matt completion update.
8. **Phase 7 — Observability (WS8).** Logs, audit trail, alerts.

Each phase: a PR, acceptance evidence, a rollback note.

---

## 9. Definition of done

- A malicious test ticket is provably contained (no exfiltration, no host access, no gate bypass).
- Hard rules block deterministically even when the model ignores instructions.
- A "not needed" ticket is stopped at intake, before any code, with a human decision recorded.
- 2 ready tickets → 2 concurrent sandboxed agents → 2 draft PRs, scoped, no collisions, within cap.
- No change merges on author-written markers; independent PR-time checks are the gate of record.
- Clean low-risk PRs auto-merge with no human; sensitive (PHI/auth/data) PRs hold for human
  approval; both logged.
- Every merged ticket has a Matt-authored completion comment and ends in Done.
- The single EC2 still hosts everything; sandbox layer is swappable; cost delta documented + small.
- Full audit trail for every agent run.

---

## 10. Open items to confirm with Amit before/while building

- Final concurrency number once Phase 0 sizing is known (locked target = 2).
- Exact JIRA status names if they differ from §6.
- The precise file-path globs that define a "sensitive diff" for WS6 (auth/data/logging/PHI/
  migrations/infra) — draft these in Phase 5 and confirm.
- **Builder personas — DECIDED:** single generalist `matt` builder for now; Richa/Karan deferred.
  A routing seam is left in place so they can be added later without rework.
- **`council` — DECIDED:** not wired into the pipeline. Read it once to choose between reusing it as
  Priya's aggregator mechanism vs retiring it; report in `SKILLS_AUDIT.md`.
- **Skills marked VERIFY in §5.4** (`sunita`, `doctor-feedback`, `tdd-workflow`, `verify`, `ship`,
  `blueprint`, `safety-guard`, `strategic-compact`, `learn`, `matt`): Claude reads and
  classifies each, then reports its recommendation in `SKILLS_AUDIT.md` before acting.
- Note: `reality-check` **is** Meera (no separate skill to create); the work is repositioning it to
  intake, not authoring it. Priya already exists (`priya-ticket-quality`) and needs extending, not
  creating.
