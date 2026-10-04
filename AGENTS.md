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

- Use JEV for bounded agent, skill, model, reasoning, and reviewer selections according to the routing skills. Honor successful, usable selections.
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
- Delegate publication after review. Publication must not modify implementation.
- Continue implementation tasks autonomously through review and delegated publication until a PR exists, unless blocked or the user pauses. A worker COMPLETE handoff does not finish the task.
- Wait for explicit user merge authorization, then delegate merge execution. Review approval and PR creation do not authorize merging.
- After successful authorized merge, delegate `/workshop-clear-bench` and consume its result. Release owned resources before handoff, preserve unrelated work, and avoid force deletion.
- Use shorter workflows for work such as read-only investigation when appropriate. The user may redirect or stop any workflow.

## Keep It Simple

- Distinguish intentional Workshop requirements from incidental tool behavior. Enforce the former. Do not promote the latter into new invariants, validation, recovery logic, or tests unless correctness, safety, or a demonstrated regression requires it.
- Before retaining a mechanism, ask: explicit requirement, correctness/safety need, or demonstrated failure? If none applies, defer it.
- Prefer direct solutions and existing capabilities. Build the smallest useful capability and use it on real work before adding complexity.
- Do not add speculative abstractions, dependencies, role hierarchies, harness adapters, retry frameworks, or cleanup recovery engines.
- Test required outcomes, important safety boundaries, and demonstrated regressions. Do not freeze incidental architecture or require tests that mirror implementation details.
- Add agents, skills, and defensive machinery when real usage demonstrates a need.
