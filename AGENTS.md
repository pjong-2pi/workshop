# Workshop Agent Instructions

## Read the Requirements

- [PRD.md](PRD.md) is the source of truth for product requirements. The Workshop knowledgebase captures the broader design history and reasoning; [ROADMAP.md](ROADMAP.md) defines capability milestones.
- Resolve genuine requirements ambiguity with the user; do not invent requirements.
- Name agents and skills in lowercase kebab-case with a `workshop-` prefix and workshop metaphors. Current roles are `workshop-foreman`, `workshop-craftsman`, `workshop-surveyor`, `workshop-inspector`, and `workshop-fitter`. Use `workshop-dispatch` for delegation.
- Load the selected role definition from `.agents/agents/` explicitly into its native session; definitions include each role's handoff contract. Foreman instructions are in [workshop-foreman.md](.agents/agents/workshop-foreman.md).

## Foreman Orchestrates; Incident Records Are a Narrow Exception

- Use the Foreman agent as the primary interface and sole workflow orchestrator.
- Foreman scopes requests, invokes routing, delegates work, consumes handoffs, and coordinates progression and routine orchestration failures.
- Foreman may inspect enough context to coordinate. Delegate substantive investigation, implementation, testing execution, and independent review.
- Foreman may directly append/update the canonical private `.local/incident-report.md` as the narrow operational-write exception described in PRD.md. Log known incidents immediately without investigation or an implementation/review/publication cycle per entry; briefly notify the user.
- Use the explicit known main Workshop checkout/session root, never inferred cwd, target project roots, or task worktrees. Workers report observed events through existing handoff fields within their assignment and sandbox; they do not write the central report.
- Triage runs only on user request and produces recommendations, not fixes. Follow PRD.md; the user decides which fixes to pursue through the existing workflow.
- Surveyors investigate read-only; Craftsmen implement and verify. Use the separate Surveyor role for investigation.
- Delegate Git/worktree operations, PR creation, merging, and cleanup to agents or skills. Foreman must not perform those mechanics directly.
- Workers perform only their assignment. Do not expand scope, redesign the workflow, redelegate, or reroute. Return blockers to Foreman.
- Use each agent's handoff contract from its definition.

## Route and Isolate Work

- Use `workshop-jev-route-job` when available for fresh selections with meaningful alternatives. Otherwise, select directly. Honor successful, usable selections.
- Give JEV task/capability requirements, not a preselected concrete agent. Use JEV only for meaningful alternatives; optional model selection does not gate direct Fitter dispatch or Craftsman's publication assignment.
- Provide all available agents and models. If JEV fails or returns an unusable choice, Foreman selects directly without elaborate retry logic.
- Arrange session-start `/workshop-stocktake`. Preserve the previous catalog and report failures if refresh fails.
- Target Windows with Codex + Herdr installed. Write helper scripts as `.ps1`.
- Use Herdr's capabilities to create one worktree per implementation task after routing resolves. Reuse it sequentially through implementation, review, remediation, and publication.
- Keep the main session at the visible Herdr Spaces root, with delegation sessions underneath it. Dispatch preserves this ordering using native Herdr capabilities.
- Only one role actively operates on a task worktree at a time. Keep target project repositories independent of Workshop.
- Independent tasks may proceed within harness capabilities. Pause only the workflow requiring user clarification.

## Verify, Review, and Finish

- Standing user publication authorization (2026-10-06, until revoked): implementation requests authorize same-Craftsman publication of Inspector-approved scope to the established origin push repository; Workshop destination: `https://github.com/7wwtwinkletoes/workshop`. Follow PRD.md's detailed policy for exclusions, overrides, native approval controls, and consent citations; no extra routine publication confirmation. Merge requires separate explicit user authorization.
- Craftsmen implement and run relevant checks, but do not commit, push, or create/update PRs during implementation. After Inspector PASS/LGTM, Foreman returns the same task to the same Craftsman to publish only the approved scope through `workshop-publish`.
- Inspectors review independently and read-only, including test sufficiency. Inspectors never fix findings or publish.
- Assign change/test-sufficiency review only to Inspector; Surveyor investigates and never substitutes for Inspector.
- Foreman sends blocking findings to the same Craftsman session and arranges re-review in the same Inspector session until PASS/LGTM.
- Inspector PASS/LGTM authorizes only publication of the reviewed scope. Content changed after approval returns for relevant review before publication.
- Wait for explicit user merge authorization after a PR exists; review approval and publication do not authorize merging. Changed content after merge authorization requires renewed review and user authorization.
- After authorization, dispatch Fitter for the existing merge-and-Clear-Bench lifecycle. Use a nonwaiting dispatch when work should continue, retain the execution reference, and collect the same Fitter handoff later. Preserve unrelated work and avoid force deletion.
- Continue implementation tasks through review, same-Craftsman publication, and PR creation/update unless blocked or the user pauses. A worker COMPLETE handoff does not finish the task.
- Read-only investigation and planning may finish with a report. The user may redirect or stop any workflow.

## Keep It Simple

- Optional tools remain optional: absence or failure must not block tasks achievable directly with existing agent capabilities. Prefer graceful fallback; do not add environment-specific workarounds, recovery, retries, or abstractions to make an optimization mandatory. Distinguish required outcomes from incidental environment evidence.
- Distinguish intentional Workshop requirements from incidental tool behavior. Enforce the former. Do not promote the latter into new invariants, validation, recovery logic, or tests unless correctness, safety, or a demonstrated regression requires it.
- Before retaining a mechanism, ask: explicit requirement, correctness/safety need, or demonstrated failure? If none applies, defer it.
- Prefer direct solutions and existing capabilities. Build the smallest useful capability and use it on real work before adding complexity.
- Do not add speculative abstractions, dependencies, role hierarchies, harness adapters, retry frameworks, or cleanup recovery engines.
- Test required outcomes, important safety boundaries, and demonstrated regressions. Do not freeze incidental architecture or require tests that mirror implementation details.
- Add agents, skills, and defensive machinery when real usage demonstrates a need.
