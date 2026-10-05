---
name: workshop-clear-bench
description: Safely remove one clean assigned Workshop task worktree after a confirmed authorized merge.
---

# Clear Bench

Use only after the assigned PR is confirmed `MERGED`, or after explicit discard
authorization. Verify and remove only the assigned task worktree and branch.
Retain a dirty task and never force-remove or discard dirty work. Protect main,
the caller's execution workspace, and unrelated resources.

Update local main only when clean and only with a fast-forward. Otherwise leave
it untouched and report the result. Verify cleanup and report retained
resources accurately. If the task worktree is removed but ordinary branch
deletion refuses after squash, report successful worktree cleanup with the
branch retained; this is not a worktree cleanup failure. Report `BLOCKED` if
assigned task worktree removal fails.
