---
name: workspace-clear-bench
description: Safely remove a completed Workshop Herdr workspace after integration or explicit discard authorization. Use for bench/workspace cleanup, not recovery of inconsistent Herdr state.
---

# Clear a Completed Workshop Bench

Use this only for a completed, recorded Herdr workspace. Do not use it to
recover a worktree already changed outside Herdr.

Before removal, require the exact recorded `WORKSPACE` ID, repository and
worktree paths, a clean worktree, and exactly one of:

- concrete evidence the work is integrated, or
- explicit authorization to discard it.

Ask for explicit authorization immediately before the destructive command;
earlier task approval does not count. `RemovalAuthorization` may only be supplied
after that authorization. Then run the gate from the Workshop root:

```powershell
pwsh -NoProfile -File .agents/skills/workspace-clear-bench/scripts/remove-workspace.ps1 -Workspace "$WORKSPACE" -Repository "$REPOSITORY" -WorktreePath "$WORKTREE" -IntegrationEvidence "$EVIDENCE" -RemovalAuthorization "$AUTHORIZATION" -Confirm:$false
```

For an authorized discard, replace `-IntegrationEvidence` with
`-DiscardAuthorization "$DISCARD_AUTHORIZATION"`. The gate discovers and
rechecks with `herdr worktree list --cwd`; it never combines `--workspace` and
`--cwd`, parses the sole exact JSON workspace record and canonical path, requires
`git status --porcelain` to be empty, removes only with:

```powershell
herdr worktree remove --workspace "$WORKSPACE" --trust-repository
```

It verifies the workspace is absent afterward. Do not add `--force`, delete a
branch, substitute Git deletion, or retry with another tool. If Herdr says the
target is not a working tree or its state is inconsistent, stop and report that
condition.
