---
name: github-create-pr
description: Create a GitHub pull request with explicit git and gh CLI commands after verifying the repository, branch, intended diff, and checks. Use when the user asks to commit, push, publish, or open a PR; do not merge it.
---

# GitHub Create PR

Skills own the mechanics below; use judgment only for scope, wording, and the
repository-specific checks. Freeze these values before changing external state:
`HOST`, `REPO` (`HOST/OWNER/REPO`), `REMOTE`, `BASE`, `BRANCH`, `TITLE`,
`BODY_FILE`, and `COMMIT_MESSAGE`.

## Verify

```sh
gh auth status --active --hostname "$HOST"
gh repo view "$REPO" --json nameWithOwner,url,isArchived,defaultBranchRef,viewerPermission
git branch --show-current
git status --short --branch
git config --get user.name
git config --get user.email
git diff
git diff --cached
```

Stop if authentication fails; the repository is wrong, archived, or not writable;
Git identity is missing; `BRANCH` is empty or equals `BASE`; the worktree contains
unrelated changes; or the intended scope is ambiguous. Run the target repository's
required checks before committing.

## Commit and push

Stage an explicit approved path list, never a blanket path:

```sh
git add -- "<approved-path-1>" "<approved-path-2>"
git diff --cached --check
git diff --cached
git commit -m "$COMMIT_MESSAGE"
git push --set-upstream "$REMOTE" "$BRANCH"
HEAD_SHA="$(git rev-parse HEAD)"
REMOTE_SHA="$(git rev-parse "$REMOTE/$BRANCH")"
test "$HEAD_SHA" = "$REMOTE_SHA"
```

Stop on any failure. Never force-push. The equality check binds PR creation to the
commit just pushed.

## Create and verify

```sh
gh pr create --repo "$REPO" --base "$BASE" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE"
gh pr view "$BRANCH" --repo "$REPO" --json number,url,state,isDraft,baseRefName,headRefName,headRefOid
```

Expected result: one `OPEN` PR whose base is `BASE`, head is `BRANCH`, and
`headRefOid` equals `HEAD_SHA`. Stop and report any mismatch.
Return the PR number, URL, and head SHA. PR creation does not authorize merge,
branch deletion, unrelated fixes, or cleanup.
