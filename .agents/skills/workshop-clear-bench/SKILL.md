---
name: workshop-clear-bench
description: Remove an intended Workshop-owned Herdr worktree after integration or explicit discard authorization; report normal cleanup failures without forced recovery.
---

# Clear a Completed Workshop Bench

Use `/workshop-clear-bench <workspace-id>`, or after a verified authorized merge.
Identify the owning workspace and repository from Herdr metadata. Require a clean
linked worktree and either exact merged PR/base/head evidence or explicit discard
authorization. Do not destroy uncommitted or unrelated user work.

```powershell
$record = herdr workspace get $Workspace | ConvertFrom-Json -ErrorAction Stop
$Repository = $record.result.workspace.worktree.repo_root
$cleanup = @{ Workspace = $Workspace; Repository = $Repository; GitHubRepository = $GitHubRepository; PullRequest = $PullRequest; Base = $Base; AuxiliaryWorkspace = @($KnownAuxiliaryWorkspaces); Confirm = $false }
& .agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1 @cleanup
```

For explicit discard, replace the GitHub parameters with
`-DiscardAuthorization <user authorization>`. Merge cleanup uses canonical
`OWNER/REPO` from `gh repo view --json nameWithOwner`; verified integration
requires no second permission prompt. Ensure assigned workers have stopped.
`KnownAuxiliaryWorkspaces` contains only the task's worker, reviewer, or Fitter
workspace IDs retained by Foreman. After validating each supplied auxiliary's
idle/done Codex pane metadata and worktree association, cleanup closes only those
workspaces, keeps the owner live, then makes one normal removal attempt.

The script verifies identity, cleanliness, and disposition, then uses normal
`herdr worktree remove --workspace <id> --trust-repository`. It does not discover
or close unrelated workspaces, force-delete, delete branches, or substitute
filesystem/Git deletion. Success requires the checkout directory, Git worktree
registration, and Herdr workspace to be gone. If Git has already lost its
registration while Herdr or the directory remains, report that concrete stale
state without forced recovery. If terminal closure, the OS, or the tool fails,
report the failure and leave it for later/manual cleanup. This does not invalidate
the completed implementation or PR.
