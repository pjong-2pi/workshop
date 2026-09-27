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
| Run a Herdr worker lifecycle | 1 | Worktree, pane, agent readiness, prompt/wait, and safe cleanup use stable CLI mechanics. | Keep explicit in `workshop-foreman`; reconsider extraction only after repeated real runs. |
| Clear a completed Herdr bench | 6 | Bind the supplied GitHub repository to the owning worktree before exact PR/base/head verification; rediscover CWD-sharing auxiliaries immediately before direct owner removal. | Keep verification and auxiliary disposal in `workshop-clear-bench`; inconsistent state stops for manual investigation. |
| Run Workshop evaluations | 2 | Setup behavior needs disposable fixtures; skill behavior needs harness traces and grading distinct from static checks. | Keep `tests/run.ps1` and versioned definitions; defer a runner skill and full Foreman execution until a real isolated harness exists. |
| Advise Foreman routing with JEV | 1 | A structured, confidence-gated recommendation must remain inside existing skills/profiles and never own lifecycle or authority. | Keep the small PowerShell helper within Foreman; revisit only after local telemetry compares routes. |

Add or increment an entry when a workflow repeats or exposes new friction. Prefer
extending an existing skill when the trigger and authorization boundary are the
same.
