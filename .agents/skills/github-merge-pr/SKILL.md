---
name: github-merge-pr
description: Merge an exact explicitly authorized GitHub pull request after fresh head, checks, reviews, and mergeability verification; respect repository protection and confirm success.
---

# GitHub Merge PR

Require explicit user authorization for the intended repository and exact PR.
PR creation, code approval, or JEV advice does not imply merge authorization.
Confirm identity and inspect current state immediately before merging:

```sh
gh repo view "$REPO" --json nameWithOwner,mergeCommitAllowed,rebaseMergeAllowed,squashMergeAllowed
gh pr view "$PR" --repo "$REPO" --json number,url,state,isDraft,baseRefName,headRefOid,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup
gh pr checks "$PR" --repo "$REPO" --required
```

Require an open, non-draft, mergeable PR with no blocking reviews or failed/pending
required checks. Empty checks mean none configured. Bind verification to current
`headRefOid` as `SHA`; if it changes, repeat verification.
Use the target-required merge method, otherwise the user's chosen method,
otherwise squash if enabled. Stop if the method is unavailable.

Run one merge command with that method (`--merge`, `--rebase`, or `--squash`):

```sh
gh pr merge "$PR" --repo "$REPO" --match-head-commit "$SHA" --squash
gh pr view "$PR" --repo "$REPO" --json url,state,headRefOid,mergedAt,mergeCommit
```

Never bypass repository protection or use `--admin`, `--auto`, `--delete-branch`,
or force-push. Report failure without trying another merge method.
Confirm MERGED state, merge commit, and the authorized head SHA; return the URL
and merge commit. Branch deletion needs separate authorization.
A verified merge permits safe best-effort bench cleanup without another prompt;
pass the canonical `nameWithOwner`, exact PR, and base to `workshop-clear-bench`.
