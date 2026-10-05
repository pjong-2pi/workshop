# Workshop Agent Instructions

## Read the Requirements

- [PRD.md](PRD.md) is the source of truth for product requirements. The Workshop knowledgebase captures the broader design history and reasoning; [ROADMAP.md](ROADMAP.md) defines capability milestones.
- Resolve genuine requirements ambiguity with the user; do not invent requirements.
- Name agents and skills in lowercase kebab-case with a `workshop-` prefix and workshop metaphors. Current roles are `workshop-foreman`, `workshop-craftsman`, `workshop-surveyor`, and `workshop-inspector`. Use `workshop-dispatch` for delegation.
- Load the selected role definition from `.agents/agents/` explicitly into its native session; definitions include each role's handoff contract. Foreman instructions are in [workshop-foreman.md](.agents/agents/workshop-foreman.md).

## Foreman Only Orchestrates

- Use the Foreman agent as the primary interface and sole workflow orchestrator.
- Foreman scopes requests, invokes routing, delegates work, consumes handoffs, and coordinates progression and routine orchestration failures.
- Foreman may inspect enough context to coordinate. Delegate substantive investigation, implementation, testing execution, and independent review.
- Surveyors investigate read-only; Craftsmen implement and verify. Use the separate Surveyor role for investigation.
- Delegate Git/worktree operations, PR creation, merging, and cleanup to agents or skills. Foreman must not perform those mechanics directly.
- Workers perform only their assignment. Do not expand scope, redesign the workflow, redelegate, or reroute. Return blockers to Foreman.
- Use each agent's handoff contract from its definition.

## Route and Isolate Work

- Use `workshop-jev-route-job` when available for fresh selections with meaningful alternatives. Otherwise, select directly. Honor successful, usable selections.
- Give JEV task/capability requirements, not a preselected concrete agent. Invoke deterministic `workshop-publish` directly after Inspector PASS/LGTM. After explicit user merge authorization, launch `workshop-fit` in a separate Herdr pane outside task resources.
- Provide all available agents and models. If JEV fails or returns an unusable choice, Foreman selects directly without elaborate retry logic.
- Arrange session-start `/workshop-stocktake`. Preserve the previous catalog and report failures if refresh fails.
- Target Windows with Codex + Herdr installed. Write helper scripts as `.ps1`.
- Use Herdr's capabilities to create one worktree per implementation task after routing resolves. Reuse it sequentially through implementation, review, remediation, and publication.
- Keep the main session at the visible Herdr Spaces root, with delegation sessions underneath it. Dispatch preserves this ordering using native Herdr capabilities.
- Only one role actively operates on a task worktree at a time. Keep target project repositories independent of Workshop.
- Independent tasks may proceed within harness capabilities. Pause only the workflow requiring user clarification.

## Verify, Review, and Finish

- Craftsmen implement and run relevant checks; Inspectors review independently and read-only, including test sufficiency. Inspectors never fix findings.
- Assign change/test-sufficiency review only to Inspector; Surveyor investigates and never substitutes for Inspector.
- Foreman sends blocking findings to the same Craftsman session and arranges re-review in the same Inspector session until PASS/LGTM.
- After review, Foreman invokes deterministic `workshop-publish` directly. After a PR exists and the user explicitly authorizes merge, run `workshop-fit` nonblocking in a separate Herdr shell pane outside the task workspace; retain its execution reference and collect its final handoff later. Clear Bench cleanup is the cleanup phase of this capability.
- Continue implementation tasks autonomously through review and direct deterministic publication until a PR exists, unless blocked or the user pauses. A worker COMPLETE handoff does not finish the task.
- Wait for explicit user merge authorization before launching the lifecycle runner. The user's own `lgtm` in an unambiguous PR discussion authorizes the reviewed current PR; Inspector PASS/LGTM and publication do not. Changed content returns to review and authorization.
- After authorization, run `workshop-fit` nonblocking in a separate Herdr shell pane outside task resources. Retain the runner pane and PR/task reference, then collect its final handoff later. It confirms squash merge before Clear Bench cleanup, fast-forwards main only when clean, preserves dirty/unrelated work, and never force-removes resources.
- Read-only investigation and planning may finish with a report. The user may redirect or stop any workflow.

## Keep It Simple

- Optional tools remain optional: absence or failure must not block tasks achievable directly with existing agent capabilities. Prefer graceful fallback; do not add environment-specific workarounds, recovery, retries, or abstractions to make an optimization mandatory. Distinguish required outcomes from incidental environment evidence.
- Distinguish intentional Workshop requirements from incidental tool behavior. Enforce the former. Do not promote the latter into new invariants, validation, recovery logic, or tests unless correctness, safety, or a demonstrated regression requires it.
- Before retaining a mechanism, ask: explicit requirement, correctness/safety need, or demonstrated failure? If none applies, defer it.
- Prefer direct solutions and existing capabilities. Build the smallest useful capability and use it on real work before adding complexity.
- Do not add speculative abstractions, dependencies, role hierarchies, harness adapters, retry frameworks, or cleanup recovery engines.
- Test required outcomes, important safety boundaries, and demonstrated regressions. Do not freeze incidental architecture or require tests that mirror implementation details.
- Add agents, skills, and defensive machinery when real usage demonstrates a need.
