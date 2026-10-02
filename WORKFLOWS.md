# Workflow observations

Record reusable outcomes and recurring friction, not command transcripts.
Use an existing skill before adding one. Promote a diagnostic hiccup into durable
infrastructure only when repeated real usage shows a material reliability benefit.

| Workflow | Observed | Evidence or boundary | Decision |
|---|---:|---|---|
| Coordinate project work | 3 | Small tasks consumed disproportionate model usage while defensive state management still produced coordination failures. | Foreman delegates every implementation, using a cheap worker and proportional checks for small work, then a mechanics-only Fitter. |
| Create a GitHub PR | 2 | Scope, dedicated branch, base/head and observed PR result matter; independent engineering review is a readiness choice. | Reuse `github-create-pr` through `fitter`; no lifecycle gatekeeper or claims. |
| Check a GitHub PR | 1 | Findings and checks refer to the intended PR and head SHA. | Reuse `github-check-pr`; keep inspection read-only. |
| Merge a GitHub PR | 1 | Explicit authorization and fresh checks must respect repository protection. | Reuse `github-merge-pr`; branch deletion stays separate. |
| Bootstrap Workshop | 3 | Initial setup needs prerequisite checks and local initialization state. | `workshop-setup` owns bootstrap; do not run it routinely. |
| Dispatch Herdr work | 3 | Installed CLI rejects both workspace and CWD selectors on creation. An internal sub-agent did implementation after workspace creation, leaving no visible Codex worker in its pane. | Create from CWD, then start and prompt an actual Herdr Codex session; workspace creation alone is not dispatch. Consult help only on drift. |
| Clear completed work | 8 | Repeated validation and auxiliary disposal still encountered Windows directory locks. | Verify intended clean linked worktree and completion/discard, then normal Herdr cleanup; report failures for later without recovery machinery. |
| Evaluate Workshop | 3 | Exact prose/CLI tests froze incidental implementation instead of proving outcomes. | Keep metadata/syntax/authority invariants and representative outcome definitions; no universal maximal checks or repeated release passes. |
| Advise routing with JEV | 5 | Sanitized task text, current choices, confidence checks and ordinary fallback suffice. | Keep the skill/role/model helper with one observed model@reasoning choice; no new orchestration infrastructure. |
| Inventory Codex models | 2 | Available models are account-specific. | Keep on-demand `workshop-stocktake` inventory; defer scheduling and ranking. |

A single hiccup is evidence, not a mandate for a validator, state machine, skill,
or recovery mechanism. Fix simple bugs directly.
