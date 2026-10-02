[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]*$')][string]$Workspace,
    [Parameter(Mandatory)][string]$Repository,
    [string]$GitHubRepository,
    [string]$PullRequest,
    [string]$Base,
    [string]$DiscardAuthorization
)

$ErrorActionPreference = 'Stop'
$mergeParameterCount = @(@($GitHubRepository, $PullRequest, $Base) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
if (($mergeParameterCount -notin @(0, 3)) -or (($mergeParameterCount -eq 3) -eq (-not [string]::IsNullOrWhiteSpace($DiscardAuthorization)))) {
    throw 'Provide GitHub repository, pull request, and base for a verified merge, or -DiscardAuthorization.'
}
if ($mergeParameterCount -eq 3 -and $PullRequest -notmatch '^[1-9][0-9]*$') { throw 'Pull request must be a positive numeric ID.' }

$Repository = (Resolve-Path -LiteralPath $Repository).Path
$metadata = & herdr workspace get $Workspace
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect owning workspace.' }
$owner = ($metadata | Out-String | ConvertFrom-Json).result.workspace
if ($owner.workspace_id -cne $Workspace -or [string]::IsNullOrWhiteSpace($owner.worktree.repo_root) -or
    (Resolve-Path -LiteralPath $owner.worktree.repo_root).Path -ine $Repository) {
    throw 'Workspace does not match the intended repository.'
}
$listing = & herdr worktree list --cwd $Repository --trust-repository
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect owning worktree.' }
$matches = @(($listing | Out-String | ConvertFrom-Json).result.worktrees | Where-Object { $_.open_workspace_id -ceq $Workspace })
if ($matches.Count -ne 1 -or [string]::IsNullOrWhiteSpace($matches[0].path)) { throw 'Owning worktree is missing or ambiguous.' }
$worktree = (Resolve-Path -LiteralPath $matches[0].path).Path
if ($worktree -ieq $Repository) { throw 'Cleanup must not remove the repository checkout.' }
$repositoryGit = & git -C $Repository rev-parse --path-format=absolute --git-common-dir
if ($LASTEXITCODE -ne 0) { throw 'Could not identify repository Git directory.' }
$worktreeGit = & git -C $worktree rev-parse --path-format=absolute --git-common-dir
if ($LASTEXITCODE -ne 0 -or ($worktreeGit | Out-String).Trim() -ine ($repositoryGit | Out-String).Trim()) {
    throw 'Worktree is not linked to the intended repository.'
}
$status = & git -C $worktree status --porcelain --untracked-files=all
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect worktree status.' }
if (-not [string]::IsNullOrWhiteSpace(($status | Out-String))) { throw 'Worktree has uncommitted changes.' }

if ($mergeParameterCount -eq 3) {
    $head = & git -C $worktree rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Could not resolve worktree HEAD.' }
    Push-Location -LiteralPath $worktree
    try {
        $repositoryState = & gh repo view --json nameWithOwner
        if ($LASTEXITCODE -ne 0) { throw 'Could not inspect GitHub repository.' }
    } finally { Pop-Location }
    $canonical = ($repositoryState | Out-String | ConvertFrom-Json).nameWithOwner
    if ([string]::IsNullOrWhiteSpace($canonical) -or $canonical -ine $GitHubRepository) {
        throw 'GitHub repository does not match the owning worktree.'
    }
    $prState = & gh pr view $PullRequest --repo $canonical --json number,state,baseRefName,headRefOid
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect merged pull request.' }
    $pr = $prState | Out-String | ConvertFrom-Json
    if ($pr.number -ne [long]$PullRequest -or $pr.state -cne 'MERGED' -or $pr.baseRefName -cne $Base -or $pr.headRefOid -cne ($head | Out-String).Trim()) {
        throw 'Pull request merge evidence does not match the owning worktree.'
    }
}

if ($PSCmdlet.ShouldProcess($worktree, 'remove completed Herdr worktree')) {
    & herdr worktree remove --workspace $Workspace --trust-repository
    if ($LASTEXITCODE -ne 0) {
        throw "Cleanup failed for '$Workspace'; leave it for later/manual cleanup. Completed implementation or PR remains valid."
    }
    $remaining = & herdr worktree list --cwd $Repository --trust-repository
    if ($LASTEXITCODE -ne 0 -or @(($remaining | Out-String | ConvertFrom-Json).result.worktrees | Where-Object { $_.open_workspace_id -ceq $Workspace -or $_.path -ieq $worktree }).Count) {
        throw "Cleanup not confirmed for '$Workspace'; inspect later/manual cleanup."
    }
}
