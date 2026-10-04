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
- Keep Foreman responsible solely for orchestration.
- Delegate execution, including investigation, implementation, review, PR creation, merging, and cleanup.
- Reduce Codex tokens spent on bounded decisions through JEV.
- Preserve independent review, task isolation, and explicit user merge authorization.
- Reach useful end-to-end operation quickly and improve from observed problems.

## Responsibilities

| Role or capability | Responsibility | Boundary |
| --- | --- | --- |
| User | Define intent, clarify requirements, authorize merges, redirect or stop work | Merge authorization belongs to the user |
| Foreman agent | Scope, invoke routing, delegate, consume handoffs, coordinate progression and routine orchestration failures | Does not implement, substantively investigate, review, manage Git/worktrees, create PRs, merge, or clean up directly |
| JEV routing skills | Make bounded selections using available resources and task context | Do not execute the selected work |
| Stocktake | Discover available routing resources and maintain the durable catalog | Agent definitions remain the source of agent metadata |
| Delegation capability | Execute assignments through Herdr and arrange task isolation | Foreman retains workflow decisions |
| Surveyor | Investigate the assigned question read-only and report evidence | Does not modify files, implement, review changes, or delegate further |
| Craftsman | Implement the assigned scope, add appropriate tests, verify, and report | Does not expand scope or delegate further |
| Inspector | Independently review read-only and assess test sufficiency | Does not fix findings |
| Publication capability | Commit/push as required and create the PR | Does not modify implementation or fix engineering findings |
| Merge capability | Execute the explicitly user-authorized merge | Does not infer authorization from review or PR creation |
| Clear Bench | Clean task resources after successful authorized merge and verify cleanup | Does not force deletion or discard unrelated work |

Publication, merge, and cleanup may use delegated agents or skills. Whether
publication needs an LLM Fitter is a decision for real usage, not a required
initial architecture.

## Workflow

Foreman owns progression throughout the standard implementation route:

1. Scope the user request and resolve genuine requirements ambiguity.
2. Use `workshop-jev-route-job` when available for fresh selections with meaningful alternatives. Otherwise, select directly.
3. Delegate Herdr-backed task worktree creation and the implementation assignment.
4. Consume the Craftsman's implementation and verification handoff.
5. Select a reviewer under the same routing rule and delegate independent Inspector review.
6. Send blocking findings to the same Craftsman session, then arrange re-review in the same Inspector session until PASS/LGTM.
7. Delegate publication and receive the PR result.
8. Wait for explicit user merge authorization.
9. Delegate merging and inspect the reported result.
10. After successful merge, delegate Clear Bench cleanup and consume its result.

The standard route is not mandatory for every request. Read-only investigation or planning may finish with a report, without implementation or publication. The user may alter or stop any workflow at any stage.

Implementation tasks continue autonomously through independent review and
delegated publication until a PR exists, unless a real blocker or user pause
prevents progression. A worker COMPLETE handoff is not task completion.
Merge execution still requires separate explicit user authorization.

## Functional Requirements

### Foreman and Delegation

- Foreman is the primary user interface and sole workflow orchestrator.
- Foreman may inspect enough context to coordinate; substantive investigation must be delegated.
- Delegate read-only investigation to a separate Surveyor agent, not to a Craftsman.
- Agents execute their assigned scope without redesigning the workflow, expanding scope, creating delegations, or rerouting work.
- An agent unable to complete its assignment returns a blocked handoff to Foreman.
- Each agent has a fixed handoff contract inside its definition. Contracts may differ by role; a universal schema is not required.
- Foreman handles routine coordination autonomously and asks the user when requirements or authorization genuinely require user input.

### JEV Routing

- Use `workshop-jev-route-job` when available for fresh selections with meaningful alternatives. Otherwise, select directly.
- Supply all available agents and all available models rather than pre-filtering those lists. Selection must respect the assignment's role and capabilities.
- Supply task/capability requirements instead of preselecting a concrete agent. Check the selected resource against role boundaries before dispatch.
- Consult JEV only for meaningful alternatives. Invoke a sole capability directly; `workshop-publish` requires Inspector PASS/LGTM and does not need JEV selection.
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

- Craftsmen own implementation tests and relevant verification.
- Inspectors review code and diffs, assess test sufficiency, and run appropriate non-mutating checks. Report PASS/LGTM, blocking findings, or non-blocking findings.
- Change review and test-sufficiency review belong only to Inspector. Surveyor investigation must not substitute for review; report an unavailable Inspector as a missing prerequisite.
- Blocking findings must be remediated and re-reviewed before publication.
- PR creation, merging, and cleanup are always delegated; Foreman only orchestrates.
- Only explicit user authorization permits merge execution. The user's own `lgtm` in a PR discussion authorizes the unambiguous current PR; Inspector PASS/LGTM and publication do not. If PR identity is ambiguous, clarify rather than guess. Authorization applies to reviewed PR content; changed content returns to review and authorization.
- After authorization, Foreman delegates a squash merge. After confirmed successful merge, Foreman delegates `/workshop-clear-bench` cleanup.
- Agents release resources they own before handing off. Cleanup fast-forwards the main checkout only when clean. Dirty work remains intact and skipped or blocked updates are reported. Preserve unrelated resources and avoid force deletion.

## First-Version Acceptance

Demonstrate a real addition or modification to Workshop itself:

- Foreman scopes the request, invokes routing, delegates execution, and controls every routine handoff and workflow transition.
- Herdr provides task isolation; implementation and independent review use the same task worktree sequentially.
- The Craftsman supplies relevant verification evidence and the Inspector independently assesses it. Any blocking findings follow the same-session remediation and re-review loop.
- Delegated publication produces a PR. Foreman waits for explicit user merge authorization before delegating the merge.
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
