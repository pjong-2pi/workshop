---
name: workshop-clear-bench
description: Safely remove a completed Workshop Herdr workspace after integration or explicit discard authorization. Use only as `/workshop-clear-bench <workspace-id>`, not for inconsistent-state recovery.
---

# Clear a Completed Workshop Bench

Use `/workshop-clear-bench <workspace-id>`. The workspace ID is the only
user-supplied locator. Do not use this to recover a worktree changed outside
Herdr.

Resolve the repository from `herdr workspace get "$WORKSPACE"` metadata. Require
the exact `result.workspace.workspace_id` and nonempty
`result.workspace.worktree.repo_root`; stop on malformed or mismatched state.
Before removal, require a clean resolved worktree and exactly one of:

- concrete evidence the work is integrated, or
- explicit authorization to discard it.

Ask for explicit authorization immediately before the destructive command;
earlier task approval does not count. `RemovalAuthorization` may only be supplied
after that authorization. Then run the gate from the Workshop root:

```powershell
$workspaceRecord = herdr workspace get "$WORKSPACE" | ConvertFrom-Json
$repository = $workspaceRecord.result.workspace.worktree.repo_root
pwsh -NoProfile -File .agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1 -Workspace "$WORKSPACE" -Repository "$REPOSITORY" -IntegrationEvidence "$EVIDENCE" -RemovalAuthorization "$AUTHORIZATION" -Confirm:$false
```

For an authorized discard, replace `-IntegrationEvidence` with
`-DiscardAuthorization "$DISCARD_AUTHORIZATION"`. The gate discovers and
rechecks with `herdr worktree list --cwd`; it never combines `--workspace` and
`--cwd`, parses the sole exact JSON workspace record and resolves its path,
requires `git status --porcelain` to be empty twice, and removes only with:

```powershell
herdr worktree remove --workspace "$WORKSPACE" --trust-repository
```

It verifies the workspace is absent afterward. Do not add `--force`, delete a
branch, substitute Git deletion, or retry with another tool. If Herdr says the
target is not a working tree or its state is inconsistent, stop and report that
condition.
