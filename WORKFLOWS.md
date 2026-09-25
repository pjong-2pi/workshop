# Workflow observations

Track recurring work that may benefit from a skill. Git history and session traces
remain the detailed record; this file captures only reusable patterns.

| Workflow | Observed | Friction or invariant | Skill decision |
|---|---:|---|---|
| Orchestrate isolated project work | 1 | Preserve target autonomy, authorization, review, and safe cleanup. | `workshop-foreman` created. |
| Create a GitHub PR | 1 | Verify scope, checks, branch, commit, and explicit base/head. | `github-create-pr` created. |
| Check a GitHub PR | 1 | Bind findings and checks to the exact PR and head SHA. | `github-check-pr` created. |
| Merge a GitHub PR | 1 | Require explicit approval and fresh checks; never bypass protections. | `github-merge-pr` created. |
| Commit from a fresh clone | 1 | Missing Git author identity blocks commits late in the workflow. | Track for `workshop-setup`; environment check now fails early. |
| Run Foreman evaluations | 1 | Deterministic gate exists; disposable live Herdr runner is still missing. | Defer a runner skill until the harness exists. |

Add or increment an entry when a workflow repeats or exposes new friction. Prefer
extending an existing skill when the trigger and authorization boundary are the
same.
