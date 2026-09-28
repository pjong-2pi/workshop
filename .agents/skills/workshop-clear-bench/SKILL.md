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

- exact GitHub repository, PR, and base values that prove the PR is merged and
  its head equals the owning worktree's current `HEAD`, or
- explicit authorization to discard it.

Verified merge evidence authorizes automatic cleanup; do not request a second
immediate authorization. Discard authorization must be explicit. Then run the
gate from the Workshop root:

```powershell
$workspaceRecord = herdr workspace get "$WORKSPACE" | ConvertFrom-Json
$repository = $workspaceRecord.result.workspace.worktree.repo_root
pwsh -NoProfile -File .agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1 -Workspace "$WORKSPACE" -Repository "$REPOSITORY" -GitHubRepository "$GITHUB_REPOSITORY" -PullRequest "$PR" -Base "$BASE" -Confirm:$false
```

For an authorized discard, replace the GitHub merge parameters with
`-DiscardAuthorization "$DISCARD_AUTHORIZATION"`. `GITHUB_REPOSITORY` must be the
canonical `OWNER/REPO` derived by the merge skill, not its earlier gh command
locator. The gate uses structured `gh repo view` JSON from the worktree to bind
that canonical repository, then uses
`gh pr view` JSON to verify the exact merged PR and owning `HEAD`, discovers
current Herdr workspaces and panes, closes only auxiliary panes sharing the
worktree CWD, verifies each close, then rechecks the owner and cleanliness before
removing its worktree directly; it never combines `--workspace` and
`--cwd`, parses the sole exact JSON workspace record and resolves its path,
requires `git status --porcelain` to be empty twice, and removes only with:

```powershell
herdr worktree remove --workspace "$WORKSPACE" --trust-repository
```

It verifies the workspace is absent afterward. Do not add `--force`, delete a
branch, substitute Git deletion, or retry with another tool. If Herdr says the
target is not a working tree or its state is inconsistent, stop and report that
condition.
