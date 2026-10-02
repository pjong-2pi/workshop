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
pwsh -NoProfile -File .agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1 -Workspace $Workspace -Repository $Repository -GitHubRepository $GitHubRepository -PullRequest $PullRequest -Base $Base -Confirm:$false
```

For explicit discard, replace the GitHub parameters with
`-DiscardAuthorization <user authorization>`. Merge cleanup uses canonical
`OWNER/REPO` from `gh repo view --json nameWithOwner`; verified integration
requires no second permission prompt. Ensure assigned workers have stopped.

The script verifies identity, cleanliness, and disposition, then uses normal
`herdr worktree remove --workspace <id> --trust-repository`. It does not close
unrelated workspaces, force-delete, delete branches, or substitute filesystem/Git
deletion. If the OS/tool holds the directory or cleanup otherwise fails, report
the failure and leave it for later/manual cleanup. This does not invalidate the
completed implementation or PR.
