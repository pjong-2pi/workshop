---
name: github-create-pr
description: Commit the approved scope, push its dedicated branch, and create and verify an authorized GitHub pull request using git and gh. Do not merge.
---

# GitHub Create PR

Use the supplied repository/worktree, remote, base, dedicated branch, approved
paths, and verification evidence. Resolve the supplied `$REMOTE` push URL and
the intended `$REPO` with `gh repo view`; require their host and `nameWithOwner`
to match before pushing. Confirm the current branch is the supplied branch and
differs from base, and the complete branch diff contains only approved changes:

```sh
git remote -v
git branch --show-current
git status --short
git diff
git diff --cached
git diff "$BASE"...HEAD
gh repo view "$REPO" --json nameWithOwner,url
```

Preserve unrelated changes; stop on ambiguous scope or a failed required check.
Use the Foreman's completed verification evidence; rerun only if stale or required
by target instructions. PR mechanics do not authorize another engineering pass.

Stage only approved paths, inspect the staged diff, and commit if needed:

```sh
git add -- "<approved-path-1>" "<approved-path-2>"
git diff --cached --check
git diff --cached
git commit -m "$COMMIT_MESSAGE"
git push --set-upstream "$REMOTE" "$BRANCH"
HEAD_SHA="$(git rev-parse HEAD)"
gh pr create --repo "$REPO" --base "$BASE" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE"
gh pr view "$BRANCH" --repo "$REPO" --json number,url,state,baseRefName,headRefName,headRefOid
```

Stop on command failure. Never force-push. Write the exact PR description to
`BODY_FILE`, honoring the target template. From the returned PR, require
`state` = `OPEN`, `baseRefName` = `$BASE`, `headRefName` = `$BRANCH`, and
`headRefOid` = `$HEAD_SHA`; reject and report any repository or PR-head
mismatch. If a PR already exists, inspect and report it instead of creating a
duplicate only after these same comparisons succeed.
Return its URL and head SHA. Do not merge, delete branches, or clean worktrees.
