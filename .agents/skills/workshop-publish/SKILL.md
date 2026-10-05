---
name: workshop-publish
description: Commit and push an independently approved implementation task and create its PR using an explicit scoped file list.
---

# Publish

Craftsman invokes this deterministic skill only after Foreman returns the same
task with the independent Inspector's PASS/LGTM and approved scope. Confirm
that verdict covers the files being published and blocking findings are
resolved. This skill never edits implementation, merges, or cleans task
resources.

Run the helper using its absolute Workshop path from any project directory:

```powershell
& "$workshopRoot/.agents/skills/workshop-publish/scripts/workshop-publish.ps1" `
    -Worktree $taskPath -Branch $taskBranch -Files $scopedFiles `
    -ReviewVerdict PASS -CommitMessage $commitMessage `
    -Title $prTitle -Body $prBody -Base $targetBase
```

For a Foreman-assigned existing PR, this helper has no update mode. Verify the
PR is open, belongs to the origin push repository, has the expected head branch
and base, and its head repository matches origin. Apply the same exact-root,
branch, repository, staged-work, and committed-scope checks above; stage only
the approved files, commit, and push to the existing head branch. That push
updates the PR. Use native
`gh pr edit <number>` only when its title or body needs changing; do not call
`gh pr create` for that existing PR.

`-Files` contains explicit repository-relative files, including reviewed new
files and deletions. The helper verifies the root and branch, rejects paths
outside the task, unrelated staged work, and committed branch changes outside
that list relative to the intended base. It stages only that list, commits,
pushes to `origin`, and explicitly binds the `gh` PR destination to origin's
push repository, independent of `GH_REPO`. Foreman supplies the reviewed
scope, commit message, title, body, base, and review verdict. Native failures
stop without retries; report any completed commit/push before the failure.
Preserve unrelated work and the task/session. A PR finishes the implementation
task's publication step; it does not authorize merging.
