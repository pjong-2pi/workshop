---
name: github-check-pr
description: Inspect a GitHub pull request with the gh CLI and report its exact head, diff scope, reviews, checks, and mergeability. Use before review, update, or merge decisions; make no repository or PR changes.
---

# GitHub Check PR

Resolve the repository and exact PR; never substitute a similarly named branch or
PR. Use `gh pr view` to capture its number, URL, base, head, head SHA, state, review
decision, and mergeability. Inspect the complete diff and changed-file scope.

Run `gh pr checks` for the same PR. Distinguish successful, pending, failed,
skipped, and absent checks; absent checks are evidence of no configured checks, not
a successful CI run. Report actionable review findings and whether the PR is ready
to merge. This skill is read-only and never approves, updates, closes, or merges.
