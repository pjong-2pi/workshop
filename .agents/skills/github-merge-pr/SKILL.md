---
name: github-merge-pr
description: Merge an exact GitHub pull request with gh CLI only after explicit authorization and fresh SHA-bound verification of reviews, checks, policy, and mergeability. Use only when the user asks to merge; never infer approval.
---

# GitHub Merge PR

Require explicit authorization for `REPO` (`HOST/OWNER/REPO`) and `PR` (number or
URL). Freeze the freshly verified `headRefOid` as `SHA`. If the head changes, stop
and repeat verification; never reuse evidence from the earlier head.

## Re-verify immediately before merge

```sh
gh pr view "$PR" --repo "$REPO" --json number,url,state,isDraft,baseRefName,headRefName,headRefOid,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup
gh pr checks "$PR" --repo "$REPO" --required --json name,state,bucket,workflow,link
gh repo view "$REPO" --json nameWithOwner,mergeCommitAllowed,rebaseMergeAllowed,squashMergeAllowed,viewerPermission
```

Stop if the current `headRefOid` differs from `SHA`; the PR is not open and
mergeable; it is a draft; a required check is pending or failed; review blocks the
merge; repository policy is unclear; or permission is insufficient. Empty checks
mean no configured checks, not a successful CI run.

## Select the method

Use this precedence and no default:

1. Target repository instructions or policy.
2. Explicit user instruction.
3. Stop if neither determines one safe, repository-enabled method.

Run exactly one command matching that decision:

```sh
gh pr merge "$PR" --repo "$REPO" --match-head-commit "$SHA" --merge
gh pr merge "$PR" --repo "$REPO" --match-head-commit "$SHA" --rebase
gh pr merge "$PR" --repo "$REPO" --match-head-commit "$SHA" --squash
```

Never add `--admin`, `--auto`, or `--delete-branch`; never bypass protection,
force-push, or infer authorization. Stop rather than entering a merge queue or
enabling auto-merge in this MVP.

## Verify the result

```sh
gh pr view "$PR" --repo "$REPO" --json number,url,state,headRefOid,mergedAt,mergedBy,mergeCommit
```

Success requires `state: MERGED`, a non-null `mergedAt` and `mergeCommit`, and the
same `headRefOid` as `SHA`. Report the URL and merge commit; otherwise report the
observed state without retrying another merge method.
