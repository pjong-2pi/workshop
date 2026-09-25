---
name: github-merge-pr
description: Merge an exact GitHub pull request with the gh CLI after explicit user authorization and fresh verification of its head, reviews, checks, and mergeability. Use only when the user asks to merge; never infer approval.
---

# GitHub Merge PR

Require explicit authorization for the exact PR. Immediately before merging,
verify the repository, PR number and URL, base, head, head SHA, state, review
decision, checks, and mergeability with `gh pr view` and `gh pr checks`. Stop on an
unexpected head change, failing or pending required check, blocking review,
conflict, or ambiguous PR identity.

Use a merge method allowed by the repository; prefer squash when no project rule
or user instruction selects another method. Do not enable auto-merge, bypass branch
protection, use administrator privileges, or delete the branch unless separately
authorized. After the command, query the PR again and report the observed merged
state and merge commit.
