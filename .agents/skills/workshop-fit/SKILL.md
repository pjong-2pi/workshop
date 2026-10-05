---
name: workshop-fit
description: Squash-merge an explicitly authorized reviewed PR, then clean its assigned task worktree.
---

# Fit

Use only after the user explicitly authorizes the unambiguous reviewed PR.
Their own `lgtm` in that PR discussion counts; Inspector PASS/LGTM does not.

Foreman runs `scripts/workshop-fit.ps1` in a separate Herdr shell pane outside
the task workspace and retains the runner pane plus PR/task execution
reference. Pass the authorization flag, PR, reviewed head SHA and branch/base,
and exact task/main/runner identities and paths. The script refuses mismatched
PR or checkout identity. It squash-merges without auto-queueing, confirms
MERGED state before cleanup, then runs Clear Bench: ordinary non-force task
worktree removal, and fast-forward main only if clean after fetching the base.
Its synchronous GitHub REST merge call supplies the reviewed head SHA and fails
if an immediate squash merge cannot be performed; it does not enqueue a merge.
If ordinary `git branch -d` refuses after squash, leave the branch and report
`COMPLETE_WITH_RETAINED_BRANCH`; this means the task worktree was removed but
the branch remains. A task worktree removal failure is `BLOCKED`. Foreman must
consume and report the exact status and retained resources. Dirty or unrelated
work is preserved and reported. It never closes main or runner workspaces.

Run in a separate available pane with `herdr pane run`; collect the final
console handoff later from that retained pane. Do not retry a failed run.
