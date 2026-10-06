# Workshop Product Requirements

## Purpose

Workshop is a Git-clonable, project-independent development workspace for coordinating reusable agents, skills, instructions, and tools. It should make software engineering more efficient while keeping orchestration simple.

The first version must let Workshop add to and modify itself through a workflow orchestrated by the Foreman agent. Real usage then determines what to improve.

## Requirements Baseline

This document is the source of truth for Workshop product requirements, clarified with the user on 2026-10-04. The [Workshop knowledgebase](knowledgebase/01%20Projects/01%20Workshop/Workshop.md) captures the broader design history and reasoning.

- Support Windows development with Codex + Herdr.
- Assume Codex and Herdr are already installed.
- Write helper scripts as PowerShell `.ps1` files.
- Use Herdr's capabilities for task worktree creation.
- Support TypeSafe AI's JEV as an optional optimization for bounded agent, skill, model, and reasoning selection.
- Keep project repositories independent of Workshop.

The knowledgebase is local and excluded from Git. This tracked PRD makes the product requirements available in a Workshop clone.

## Goals

- Complete ordinary development work without the user coordinating routine handoffs.
- Keep Foreman responsible for orchestration, with only the narrow direct incident-recording exception below.
- Delegate execution, including investigation, implementation, review, PR creation, merging, and cleanup.
- Reduce Codex tokens spent on bounded decisions through JEV.
- Preserve independent review, task isolation, and explicit user merge authorization.
- Reach useful end-to-end operation quickly and improve from observed problems.

## Responsibilities

| Role or capability | Responsibility | Boundary |
| --- | --- | --- |
| User | Define intent, clarify requirements, authorize merges, redirect or stop work | Merge authorization belongs to the user |
| Foreman agent | Scope, invoke routing, delegate, consume handoffs, coordinate progression and routine orchestration failures; directly maintain the private incident report | Only the incident-recording exception below permits direct operational writes; does not implement, substantively investigate, review, publish, merge, or clean up directly |
| JEV routing skills | Make bounded selections using available resources and task context | Do not execute the selected work |
| Stocktake | Discover available routing resources and maintain the durable catalog | Agent definitions remain the source of agent metadata |
| Delegation capability | Execute assignments through Herdr and arrange task isolation | Foreman retains workflow decisions |
| Surveyor | Investigate the assigned question read-only and report evidence | Does not modify files, implement, review changes, or delegate further |
| Craftsman | Implement/test the assigned scope; after Inspector PASS, publish that approved scope when Foreman returns the same task | Does not modify implementation during publication or merge |
| Inspector | Independently review read-only and assess test sufficiency | Does not fix findings or publish |
| `workshop-publish` | Commit/push the approved scope and create a PR or update an existing one through its branch | Invoked by Craftsman only after Foreman's publication assignment with Inspector PASS/LGTM |
| Fitter | Execute an explicitly user-authorized PR merge, confirm it, then invoke Clear Bench | Does not infer authorization from review or PR creation |
| Clear Bench | Clean task resources after successful authorized merge and verify cleanup | Does not force deletion or discard unrelated work |

Foreman remains the workflow orchestrator. The same Craftsman publishes after
independent Inspector approval; Fitter owns only the separately authorized
merge and cleanup stage.

## Workflow

Foreman owns progression throughout the standard implementation route:

1. Scope the user request and resolve genuine requirements ambiguity.
2. Use `workshop-jev-route-job` when available for fresh selections with meaningful alternatives. Otherwise, select directly.
3. Delegate Herdr-backed task worktree creation and the implementation assignment.
4. Consume the Craftsman's implementation and verification handoff.
5. Select a reviewer under the same routing rule and delegate independent Inspector review.
6. Send blocking findings to the same Craftsman session, then arrange re-review in the same Inspector session until PASS/LGTM.
7. After Inspector PASS/LGTM, return the same task to the same Craftsman to publish the approved scope and receive the PR result.
8. Wait for explicit user merge authorization, then dispatch Fitter for merge confirmation and Clear Bench; consume its handoff.

The standard route is not mandatory for every request. Read-only investigation or planning may finish with a report, without implementation or publication. The user may alter or stop any workflow at any stage.

Implementation tasks continue autonomously through independent review and
publication by the same Craftsman until a PR exists, unless a real blocker or
user pause prevents progression. Inspector PASS/LGTM authorizes only publication.
Merge execution requires separate explicit user authorization.

## Functional Requirements

### Foreman and Delegation

- Foreman is the primary user interface and sole workflow orchestrator.
- Foreman may inspect enough context to coordinate; substantive investigation must be delegated.
- Delegate read-only investigation to a separate Surveyor agent, not to a Craftsman.
- Agents execute their assigned scope without redesigning the workflow, expanding scope, creating delegations, or rerouting work.
- An agent unable to complete its assignment returns a blocked handoff to Foreman.
- Each agent has a fixed handoff contract inside its definition. Contracts may differ by role; a universal schema is not required.
- Foreman handles routine coordination autonomously and asks the user when requirements or authorization genuinely require user input.

### Incident Recording and User-Triggered Triage

- Maintain one canonical private `.local/incident-report.md` under the explicit known main Workshop checkout/session root. Do not infer this root from cwd or use a target project/task worktree. Create the parent and file when absent; preserve existing records. Keep the report Git-ignored by the existing `/.local/` rule. Keep the report out of PR content and omit secrets and unnecessary payloads.
- Foreman may directly append/update this report as a narrow quick operational-write exception. Capture observed Workshop orchestration failures or friction across projects immediately when known, and briefly notify the user. Logging requires neither root-cause investigation nor an implementation/review/publication cycle per entry; the cause may remain unknown.
- Capture significant unexpected failures requiring recovery or user intervention. Ordinary expected review findings or clarifications are not automatically incidents. Workers remain within their assignment and sandbox; Foreman's assignments ask them to report observed events through existing handoff fields, without central writes or changed handoff schemas.
- Use stable date/sequence headings (for example, `2026-10-06 / 1`) and plain Markdown covering context/project, what failed, impact/evidence, recovery, and follow-up status. Keep recovery separate from whether follow-up is addressed. Add dated later updates without rewriting the event account. Record repeat observed occurrences as new entries; group them at triage without a deduplication framework.
- Triage only on a user request: read open incidents, group related causes, assess recurrence and impact, and recommend follow-up for the user to decide which fixes to pursue. Record dispositions as deferred, planned, or addressed with reasons and links to related incidents or implementation tasks/PRs. Delegate substantive investigation if needed; no scheduled or automatic triage.
- Recommendations do not start fixes. Only user-selected fixes enter the existing workflow: normal routing, isolated Craftsman implementation, independent Inspector review, publication, and explicit user merge authorization. A proposed fix or recovered incident alone authorizes neither implementation nor merge.

### JEV Routing

- Use `workshop-jev-route-job` when available for fresh selections with meaningful alternatives. Otherwise, select directly.
- Supply all available agents and all available models rather than pre-filtering those lists. Selection must respect the assignment's role and capabilities.
- Supply task/capability requirements instead of preselecting a concrete agent. Check the selected resource against role boundaries before dispatch.
- JEV is not required to select a role or skill for publication or authorized finishing; Foreman returns publication to the same Craftsman and dispatches Fitter directly. Optional model/effort selection may use the bounded catalog.
- Agent, model, and reasoning effort may be selected in one query.
- Successful, usable JEV selections are authoritative.
- If JEV fails, is unavailable, or returns an unusable choice, Foreman selects directly. Do not introduce elaborate retries or recovery.

Reference: [JEV with coding agents](https://docs.typesafe.ai/introduction/coding-agents).

### Stocktake

- Run `/workshop-stocktake` at session start to discover routing resources, including agents, descriptions, models, reasoning options, and available skills needed for skill selection.
- Maintain a durable catalog for JEV without a separate agent registry.
- Preserve manually maintained numerical model cost and intelligence ratings when refreshing discovered information. Ratings apply to models, not individual reasoning levels; do not invent ratings for unknown models.
- On refresh failure, retain the previous catalog and surface the failure.

### Task Isolation and Concurrency

- Keep the main session at the visible Herdr Spaces root, with delegation sessions underneath it.
- One implementation task uses one isolated Git worktree, created using Herdr after routing resolves, including through the documented direct fallback.
- Reuse that worktree sequentially for implementation, review, remediation, re-review, and publication. Roles do not require separate worktrees.
- Only one role actively operates on a task worktree at a time.
- Independent tasks may run concurrently within harness capabilities; Workshop adds no further concurrency limit.
- A workflow awaiting clarification pauses independently of other workflows.
- Target project repositories remain independent of Workshop.

### Review, Publication, Merge, and Cleanup

- Standing user publication authorization, granted 2026-10-06 and persistent until revoked: implementation requests authorize the same Craftsman to commit, push, and create/update PRs for Inspector-approved scoped implementation to the assigned project's established origin push repository. Workshop's explicitly approved destination is `https://github.com/7wwtwinkletoes/workshop`. Exclude private incident logs, secrets, and unrelated scope. No extra routine publication confirmation is required; explicit task-local-only instructions override this consent. Clarify changed/unclear destinations or actual new scope.
- Preserve native approval controls. Cite this standing consent in PRD.md (also summarized in AGENTS.md) and the destination in publication approval justifications; respect rejection and report the actual limitation without bypass or any guarantee that controls will approve. Publication consent does not authorize merge.
- Craftsmen own implementation tests and relevant verification; implementation assignments do not commit, push, or create/update PRs.
- Inspectors review code and diffs read-only, assess test sufficiency, and run appropriate non-mutating checks. Report PASS/LGTM, blocking findings, or non-blocking findings; never edit or publish.
- Change review and test-sufficiency review belong only to Inspector. Surveyor investigation must not substitute for review; report an unavailable Inspector as a missing prerequisite.
- Blocking findings return to the same Craftsman and same Inspector for remediation and re-review.
- Inspector PASS/LGTM is gate one: Foreman returns the same task to the same Craftsman with the approved scope, verdict, and standing publication consent to invoke `workshop-publish`, then returns the PR link to the user. Content changes after approval need relevant re-review before publication.
- Explicit user authorization after PR creation is gate two for Fitter to merge. The user's own `lgtm` in an unambiguous current PR discussion counts; Inspector PASS/LGTM and publication do not. Content changes after merge authorization require renewed review and user authorization.
- Foreman orchestrates and responds to the user, with only the direct incident-recording exception above; it does not publish, merge, or clean task resources.
- Fitter confirms the reviewed PR merge before invoking Clear Bench. Clear Bench preserves dirty main and unrelated resources and avoids force deletion.
- Agents release resources they own before handing off.

## First-Version Acceptance

Demonstrate a real addition or modification to Workshop itself:

- Foreman scopes the request, invokes routing, delegates execution, and controls every routine handoff and workflow transition.
- Herdr provides task isolation; implementation and independent review use the same task worktree sequentially.
- The Craftsman supplies relevant verification evidence and the Inspector independently assesses it. Any blocking findings follow the same-session remediation and re-review loop.
- After Inspector PASS/LGTM, the same Craftsman publishes and produces a PR. Foreman waits for explicit user merge authorization before dispatching Fitter.
- Delegated cleanup completes after successful merge and reports its result.
- The user provides intent, necessary clarification, and merge approval without manually coordinating routine operations.

Capability checks must also demonstrate JEV's direct-selection fallback, catalog preservation on Stocktake failure, and prevention of unauthorized merge. Record concrete failures and improve them from evidence rather than adding infrastructure preemptively.

## Development Guardrails

Define minimum capability outcomes, add minimal outcome and safety checks, implement the simplest solution, then use it on real work. Tests should protect required behavior, important boundaries, and demonstrated regressions rather than freeze incidental architecture or role topology.

Prefer existing capabilities and direct solutions. Add agents, skills, dependencies, abstractions, and defensive machinery only when required by a capability or demonstrated by real usage. No quantitative cost-saving target is asserted before observing actual use.

## Deferred

- A bootstrapper for a new machine.
- Other operating systems and harness support, including Claude Code and Pi.
- Additional specialized agents and skills until useful on real work.
- Harness abstraction layers, retry frameworks, and generalized cleanup recovery without demonstrated need.

See [ROADMAP.md](ROADMAP.md) for capability milestones and [AGENTS.md](AGENTS.md) for basic operating instructions.
