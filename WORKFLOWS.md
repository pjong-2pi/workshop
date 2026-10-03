# Workflow observations

Record reusable outcomes and recurring friction, not command transcripts.
Use an existing skill before adding one. Promote a diagnostic hiccup into durable
infrastructure only when repeated real usage shows a material reliability benefit.

| Workflow | Observed | Evidence or boundary | Decision |
|---|---:|---|---|
| Coordinate project work | 3 | Small tasks consumed disproportionate model usage while defensive state management still produced coordination failures. | Foreman delegates every implementation, using a cheap worker and proportional checks for small work, then a mechanics-only Fitter. |
| Create a GitHub PR | 2 | Scope, dedicated branch, base/head and observed PR result matter; independent engineering review is a readiness choice. | Reuse `github-create-pr` through `fitter`; no lifecycle gatekeeper or claims. |
| Check a GitHub PR | 1 | Findings and checks refer to the intended PR and head SHA. | Reuse `github-check-pr`; keep inspection read-only. |
| Merge a GitHub PR | 2 | A sandbox approval gate rejected LGTM after a PR-only preparation stop, although the exact PR had been handed off for a decision. | Reuse `github-merge-pr`; that stop ends at handoff, then clear approval authorizes the one exact current PR and safe verified postmerge cleanup. Continuing no-merge constraints remain until revoked; branch deletion stays separate. |
| Bootstrap Workshop | 3 | Initial setup needs prerequisite checks and local initialization state. | `workshop-setup` owns bootstrap; do not run it routinely. |
| Dispatch Herdr work | 5 | Generic workspace creation from a completed checkout has no worktree metadata and appears outside its repository group. `worktree open --cwd <repository> --path <checkout>` repairs its canonical workspace, but one checkout cannot back separate role workspaces. | Give every role a distinct worktree-backed sibling. After implementation commits and verifies, create reviewer and Fitter worktrees from its exact HEAD; keep the reviewer read-only and give Fitter its final publishing branch. Clean role checkouts separately; never treat one as another checkout's cleanup auxiliary. |
| Clear completed work | 9 | A detached process started by a completed worker can hold its checkout and leave Git partially deregistered after normal removal fails. | Workers stop their own known background resources before handoff; cleanup makes one normal removal, requires directory, Git registration, and Herdr workspace absence, and reports stale partial removal without forced recovery. |
| Evaluate Workshop | 3 | Exact prose/CLI tests froze incidental implementation instead of proving outcomes. | Keep metadata/syntax/authority invariants and representative outcome definitions; no universal maximal checks or repeated release passes. |
| Advise routing with JEV | 5 | Sanitized state, caller-supplied choices, confidence checks and ordinary fallback suffice. | Keep generic one-choice advice and independent chooser skills; no fixed pipeline, telemetry, or orchestration infrastructure. |
| Inventory Codex models | 2 | Available models are account-specific. | Keep on-demand `workshop-stocktake` inventory; defer scheduling and ranking. |

A single hiccup is evidence, not a mandate for a validator, state machine, skill,
or recovery mechanism. Fix simple bugs directly.
