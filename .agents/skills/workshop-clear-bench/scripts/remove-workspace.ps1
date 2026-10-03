[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]*$')][string]$Workspace,
    [Parameter(Mandatory)][string]$Repository,
    [string]$GitHubRepository,
    [string]$PullRequest,
    [string]$Base,
    [string]$DiscardAuthorization,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]*$')][string[]]$AuxiliaryWorkspace
)

$ErrorActionPreference = 'Stop'
$mergeParameterCount = @(@($GitHubRepository, $PullRequest, $Base) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
if (($mergeParameterCount -notin @(0, 3)) -or (($mergeParameterCount -eq 3) -eq (-not [string]::IsNullOrWhiteSpace($DiscardAuthorization)))) {
    throw 'Provide GitHub repository, pull request, and base for a verified merge, or -DiscardAuthorization.'
}
if ($mergeParameterCount -eq 3 -and $PullRequest -notmatch '^[1-9][0-9]*$') { throw 'Pull request must be a positive numeric ID.' }
if (@($AuxiliaryWorkspace | Where-Object { $_ -ceq $Workspace }).Count) { throw 'Owning workspace cannot be an auxiliary workspace.' }

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
if ($matches.Count -eq 0) {
    $stalePath = $owner.worktree.checkout_path
    if ([string]::IsNullOrWhiteSpace($stalePath)) { throw 'Owning worktree is missing or ambiguous.' }
    throw "Herdr workspace '$Workspace' has no matching worktree association; checkout directory '$stalePath' requires manual resolution."
}
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

foreach ($auxiliary in @($AuxiliaryWorkspace | Select-Object -Unique)) {
    $panes = & herdr pane list --workspace $auxiliary
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect auxiliary workspace '$auxiliary'." }
    $matches = @(($panes | Out-String | ConvertFrom-Json).result.panes)
    if (-not $matches.Count -or @($matches | Where-Object { $_.workspace_id -cne $auxiliary -or [string]::IsNullOrWhiteSpace($_.pane_id) -or [string]::IsNullOrWhiteSpace($_.cwd) -or (Resolve-Path -LiteralPath $_.cwd).Path -ine $worktree -or $_.agent -cne 'codex' -or [string]::IsNullOrWhiteSpace($_.agent_session) -or $_.agent_status -notin @('idle', 'done') }).Count) {
        throw "Auxiliary workspace '$auxiliary' is not a stopped Codex task workspace for the owning worktree."
    }
}

$ownerPanes = & herdr pane list --workspace $Workspace
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect owning workspace panes.' }
if (@(($ownerPanes | Out-String | ConvertFrom-Json).result.panes | Where-Object { $_.agent_status -in @('working', 'blocked') }).Count) {
    throw 'Owning workspace has an active pane.'
}

if ($PSCmdlet.ShouldProcess($worktree, 'remove completed Herdr worktree')) {
    foreach ($auxiliary in @($AuxiliaryWorkspace | Select-Object -Unique)) {
        & herdr workspace close $auxiliary
        if ($LASTEXITCODE -ne 0) { throw "Cleanup failed for auxiliary '$auxiliary'; leave it for later/manual cleanup. Completed implementation or PR remains valid." }
    }
    & herdr worktree remove --workspace $Workspace --trust-repository
    if ($LASTEXITCODE -ne 0) {
        throw "Cleanup failed for '$Workspace'; leave it for later/manual cleanup. Completed implementation or PR remains valid."
    }
    if (Test-Path -LiteralPath $worktree) { throw "Cleanup not confirmed for '$Workspace'; checkout directory remains at '$worktree'." }
    $registrations = & git -C $Repository worktree list --porcelain
    if ($LASTEXITCODE -ne 0) { throw "Cleanup not confirmed for '$Workspace'; could not inspect Git worktree registration." }
    if (@($registrations | Where-Object { $_ -match '^worktree ' -and [IO.Path]::GetFullPath($_.Substring(9)) -ieq $worktree }).Count) {
        throw "Cleanup not confirmed for '$Workspace'; Git worktree registration remains for '$worktree'."
    }
    $workspaceList = & herdr workspace list
    if ($LASTEXITCODE -ne 0) { throw "Cleanup not confirmed for '$Workspace'; could not inspect Herdr workspaces." }
    $remainingIds = @($Workspace) + @($AuxiliaryWorkspace | Select-Object -Unique)
    foreach ($id in $remainingIds) {
        if (@(($workspaceList | Out-String | ConvertFrom-Json).result.workspaces | Where-Object { $_.workspace_id -ceq $id }).Count) { throw "Cleanup not confirmed; Herdr workspace '$id' remains." }
    }
}
