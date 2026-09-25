---
name: github-create-pr
description: Create a GitHub pull request with the gh CLI after verifying the branch, intended diff, repository instructions, and required checks. Use when the user asks to commit, push, publish, or open a PR; do not merge it.
---

# GitHub Create PR

Use the repository's instructions and `gh` CLI help as authoritative. Confirm
authentication with `gh auth status`, then inspect the GitHub repository, default
branch, current branch, Git author identity, worktree state, and complete diff.
Never open a PR from the default branch: create a focused branch that preserves
intended work when needed.

Run required repository checks. Stage only the approved files, review the staged
diff, commit with a concise outcome-based message, and push the exact branch with
upstream tracking. Do not force-push.

Create the PR with an explicit base, head, title, and body. The body should state
the outcome, important changes, and observed checks. Return the PR number and URL.
Creation does not authorize merge, branch deletion, unrelated fixes, or cleanup.
