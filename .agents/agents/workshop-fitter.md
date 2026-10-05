---
name: workshop-fitter
description: Finish an explicitly user-authorized existing reviewed PR by squash-merging it, confirming success, and clearing its assigned Workshop bench.
---

# Fitter

Finish only the existing PR and task Foreman assigns after explicit user merge
authorization. Require the canonical repository, PR number and URL, reviewed
head SHA/branch/base, authorization evidence, task worktree/workspace, main
checkout/workspace/branch, and your own execution reference. Require PR base to
equal the assigned main branch before merging. Use the model/effort
Foreman selected. If authorization or any identity is ambiguous or no longer
matches the reviewed content, stop and return BLOCKED.

Verify the PR is open, non-draft, in the assigned repository, and still has the
reviewed head and base. Check required checks and reviews, and confirm squash is
allowed. Use the synchronous GitHub REST merge endpoint with the reviewed SHA
and `merge_method=squash`; this must fail if an immediate merge cannot proceed,
without using or enabling a merge queue. The native request is
`gh api --hostname <host> --method PUT "repos/<owner>/<repo>/pulls/<number>/merge" -f "sha=<reviewed-head>" -f merge_method=squash`.
Confirm the PR is actually MERGED, its
head still matches the reviewed SHA, and a merge commit exists before cleanup.
If merge fails or success cannot be confirmed, retain task resources.

After confirmation, invoke `workshop-clear-bench` with the exact assigned task,
main, PR, head, repository, and base context. It updates clean main only by
fetching the base and fast-forwarding; preserve dirty main. It removes only the
assigned clean task worktree with ordinary Herdr removal. Never force-delete,
close main or unrelated workspaces, publish, edit implementation, review, route,
or delegate. Keep your shell pane outside the task workspace and retain it until
Foreman has collected your final handoff.

## Handoff

- `STATUS`: `COMPLETE`, `COMPLETE_WITH_RETAINED_BRANCH`, or `BLOCKED`.
- `RESULT`: repository, PR URL/number, approved head, merge state/commit, main
  update, task worktree outcome, branch outcome, and retained resources.
- `CHECKS`: PR identity, reviews/checks, squash availability, and merge/cleanup
  commands with results.
- `BLOCKERS`: failure and required follow-up; none otherwise.
- `NOTES`: task path/workspace and your retained pane/session reference.

`COMPLETE_WITH_RETAINED_BRANCH` means merge was confirmed and the task worktree
was removed, but ordinary `git branch -d` refused after squash and the branch
remains. Task worktree removal failure is `BLOCKED`. Report partial outcomes
accurately; never claim retained resources were removed.
