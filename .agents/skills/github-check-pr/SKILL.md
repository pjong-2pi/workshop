---
name: github-check-pr
description: Inspect the intended GitHub pull request and report its head, diff, reviews, checks, and mergeability without changing it.
---

# GitHub Check PR

Use the supplied repository and exact PR number/URL. Confirm repository and PR
identity; never substitute a similarly named branch. If an expected head SHA was
supplied, report stale evidence when it differs.

```sh
gh pr view "$PR" --repo "$REPO" --json number,url,state,isDraft,baseRefName,headRefName,headRefOid,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup
gh pr diff "$PR" --repo "$REPO" --patch
gh pr checks "$PR" --repo "$REPO"
```

Report the observed head SHA, changed scope, concrete findings, reviews, checks,
and mergeability. Pending/failed checks are not success; empty checks mean no
configured checks. Distinguish inspection failures from pending checks.
This is read-only: do not approve, edit, close, or merge the PR.
