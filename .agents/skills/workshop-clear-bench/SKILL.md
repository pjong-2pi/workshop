---
name: workshop-clear-bench
description: Safely remove one clean assigned Workshop task worktree after a confirmed authorized merge.
---

# Clear Bench

Use only after the assigned PR is confirmed `MERGED` with its reviewed head and
base, or after explicit discard authorization. Require the exact task workspace
and resolved path, main workspace and resolved path/branch, repository, task
branch, PR, approved head, and base. Require base to equal the assigned main
branch. Use `herdr worktree list --workspace <main-workspace>` and its native
`result.source` and `result.worktrees` fields to confirm the main root and exact
linked task entry (`open_workspace_id`, `path`, `branch`, `is_linked_worktree`).
Use `herdr pane current --current` and confirm `.result.pane.workspace_id` is
the supplied main workspace. Stop on any mismatch or if the task worktree is
dirty.

When main is clean, fetch the assigned base from `origin` and fast-forward with
`--ff-only`. Preserve dirty main and report a skipped update. If fetch or
fast-forward fails, report `BLOCKED` and the failure while continuing safe
assigned task removal. Remove only the assigned task with ordinary
`herdr worktree remove --workspace <task-workspace>`; on failure, report BLOCKED
and retain it. Never force-remove, delete unrelated workspaces, close main or
the caller's execution pane, or discard dirty work.

After worktree removal, ordinary `git branch -d <task-branch>` may refuse
because squash merge does not put the task commit in main's ancestry. Leave the
branch and report `COMPLETE_WITH_RETAINED_BRANCH` when main updated or was
skipped because it was dirty; do not force-delete it. If main update failed,
report `BLOCKED` and include branch retention separately. Report `COMPLETE` only
when the assigned task worktree and branch are both gone.
