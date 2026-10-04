---
name: workshop-publish
description: Commit and push an independently approved implementation task and create its PR using an explicit scoped file list.
---

# Publish

The selected Fitter invokes this deterministic skill after Foreman supplies
the independent Inspector's PASS/LGTM and reviewed scope for the current
change. Confirm that verdict covers the files being published and that blocking
findings are resolved. Foreman selects Fitter and coordinates its handoff;
Craftsman and Inspector do not execute publication. This skill never edits
implementation, merges, or cleans task resources.

Run the helper using its absolute Workshop path from any project directory:

```powershell
& "$workshopRoot/.agents/skills/workshop-publish/scripts/workshop-publish.ps1" `
    -Worktree $taskPath -Branch $taskBranch -Files $scopedFiles `
    -ReviewVerdict PASS -CommitMessage $commitMessage `
    -Title $prTitle -Body $prBody -Base $targetBase
```

When Foreman identifies an existing PR for this reviewed update, pass its
explicit URL or number with `-Pr $existingPr`. The helper verifies that it is
open, belongs to origin's push repository, and has the requested head branch
and base before staging. It then updates that PR's title and body after the
scoped commit and push. Omit `-Pr` to create a new PR as usual.

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
