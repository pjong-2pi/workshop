---
name: github-check-pr
description: Inspect an exact GitHub pull request with structured gh CLI commands and report its head, diff, reviews, checks, and mergeability. Use before review, update, or merge decisions; make no repository or PR changes.
---

# GitHub Check PR

Require explicit `REPO` (`HOST/OWNER/REPO`) and `PR` (number or URL). Accept an
`EXPECTED_SHA` when another workflow already selected a head. Never substitute a
similarly named branch or PR.

## Inspect

```sh
gh pr view "$PR" --repo "$REPO" --json number,url,state,isDraft,baseRefName,baseRefOid,headRefName,headRefOid,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,changedFiles,additions,deletions
gh pr diff "$PR" --repo "$REPO" --name-only
gh pr diff "$PR" --repo "$REPO" --patch
gh pr checks "$PR" --repo "$REPO" --json name,state,bucket,workflow,event,link,startedAt,completedAt
gh pr checks "$PR" --repo "$REPO" --required --json name,state,bucket,workflow,link
```

`gh pr checks` exits `8` while checks are pending. A different nonzero exit must be
reported with its output; when `statusCheckRollup` is empty, report that no checks
are configured rather than claiming CI passed.

Stop and report stale evidence if `EXPECTED_SHA` is set and differs from
`headRefOid`. A merge-ready report requires the exact head SHA, `state: OPEN`,
`isDraft: false`, no blocking review, no pending or failed required checks, and a
mergeable state. Report the complete changed-file scope and concrete findings.
This skill is read-only: never approve, update, close, or merge the PR.
