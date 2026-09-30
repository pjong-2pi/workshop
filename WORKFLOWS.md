# Workflow observations

Track recurring work that may benefit from a skill. Git history and session traces
remain the detailed record; this file captures only reusable patterns.

| Workflow | Observed | Friction or invariant | Skill decision |
|---|---:|---|---|
| Orchestrate isolated project work | 2 | Change authorization carries through scoped commit, branch push, and PR creation after verification/review, while merge and branch deletion stay separate. | Extend `workshop-foreman`; preserve target autonomy and safe cleanup. |
| Create a GitHub PR | 1 | Verify scope, checks, branch, commit, and explicit base/head. | `github-create-pr` created. |
| Check a GitHub PR | 1 | Bind findings and checks to the exact PR and head SHA. | `github-check-pr` created. |
| Merge a GitHub PR | 1 | Require explicit approval and fresh checks; never bypass protections. | `github-merge-pr` created. |
| Bootstrap Workshop | 3 | First-time setup needs safe local structure, prerequisite checks, explicit user-config boundaries, and durable local initialization state. | `workshop-setup` owns idempotent bootstrap; routine checks stay in `check-environment.ps1`. |
| Run a Herdr worker lifecycle | 2 | Worktree, pane, agent readiness, prompt/wait, and safe cleanup use stable CLI mechanics; installed Herdr rejected both `--workspace` and `--cwd` on creation. | Keep explicit in `workshop-foreman`; create from `--cwd`, capture returned owner IDs, then use `--workspace` for follow-up. |
| Fit a reviewed change to PR | 1 | An idle writer's owning worktree can be reused by one auxiliary Fitter only after checks and independent review; bind the open PR to URL and head SHA without merge or cleanup. | Extend `workshop-foreman` with the `fitter` profile; reuse `github-check-pr` and `github-create-pr`, not a new skill. |
| Clear a completed Herdr bench | 7 | A host-qualified gh command locator is not canonical `OWNER/REPO`; derive `nameWithOwner` from structured `gh repo view`, then bind it to the owning worktree before exact PR/base/head verification and rediscover CWD-sharing auxiliaries immediately before direct owner removal. | Keep verification and auxiliary disposal in `workshop-clear-bench`; inconsistent state stops for manual investigation. |
| Run Workshop evaluations | 2 | Setup behavior needs disposable fixtures; skill behavior needs harness traces and grading distinct from static checks. | Keep `tests/run.ps1` and versioned definitions; defer a runner skill and full Foreman execution until a real isolated harness exists. |
| Advise Foreman routing with JEV | 3 | A structured, confidence-gated recommendation must remain inside existing skills/profiles and never own lifecycle or authority; restricted execution caused a false fallback. | Use the trusted Workshop network config for new sessions, allow managed policy to override it, and correlate the helper's routing row with the final user-facing outcome. |
| Inventory local Codex models | 1 | Model availability is account-specific; use Codex app-server data and preserve unknown metadata rather than inferring it. | `workshop-stocktake` owns an on-demand catalog refresh; defer scheduling and selection policy. |

Add or increment an entry when a workflow repeats or exposes new friction. Prefer
extending an existing skill when the trigger and authorization boundary are the
same.
