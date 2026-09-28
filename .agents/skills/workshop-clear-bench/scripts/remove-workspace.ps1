[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]*$')][string]$Workspace,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })][string]$Repository,
    [string]$GitHubRepository,
    [string]$PullRequest,
    [string]$Base,
    [string]$DiscardAuthorization
)

$ErrorActionPreference = 'Stop'

$mergeParameters = @($GitHubRepository, $PullRequest, $Base)
$mergeParameterCount = @($mergeParameters | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
if (($mergeParameterCount -ne 0 -and $mergeParameterCount -ne 3) -or (($mergeParameterCount -eq 3) -eq (-not [string]::IsNullOrWhiteSpace($DiscardAuthorization)))) {
    throw 'Provide GitHub repository, pull request, and base for a verified merge, or -DiscardAuthorization.'
}
if ($mergeParameterCount -eq 3 -and $PullRequest -notmatch '^[1-9][0-9]*$') {
    throw 'Pull request must be a positive numeric ID.'
}

function Get-WorkspaceRecord {
    param([switch]$RequirePresent)
    $listing = & herdr worktree list --cwd $Repository --trust-repository 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Herdr could not inspect workspace '$Workspace'; stop and report its state." }
    try { $response = ($listing | Out-String | ConvertFrom-Json -ErrorAction Stop) } catch { throw "Herdr returned malformed workspace state; stop and report." }
    if ($response.id -ne 'cli:worktree:list' -or $null -eq $response.result -or $response.result.type -ne 'worktree_list' -or $null -eq $response.result.worktrees) { throw "Herdr returned inconsistent workspace state; stop and report." }
    $matches = @($response.result.worktrees | Where-Object { $_.open_workspace_id -ceq $Workspace })
    if ($RequirePresent) {
        if ($matches.Count -ne 1 -or [string]::IsNullOrWhiteSpace($matches[0].path)) { throw "Workspace '$Workspace' is missing, duplicated, or malformed; stop and report." }
        try { return (Resolve-Path -LiteralPath $matches[0].path -ErrorAction Stop).Path } catch { throw "Workspace '$Workspace' has an invalid recorded path; stop and report." }
    }
    if ($matches.Count -ne 0) { throw "Herdr still reports workspace '$Workspace' after removal." }
}

function Assert-WorkspaceRepository {
    $metadata = & herdr workspace get $Workspace 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Herdr could not inspect workspace '$Workspace'; stop and report its state." }
    try { $response = ($metadata | Out-String | ConvertFrom-Json -ErrorAction Stop) } catch { throw "Herdr returned malformed workspace metadata; stop and report." }
    if ($response.id -ne 'cli:workspace:get' -or $null -eq $response.result.workspace -or $response.result.workspace.workspace_id -cne $Workspace -or [string]::IsNullOrWhiteSpace($response.result.workspace.worktree.repo_root)) { throw "Herdr returned inconsistent workspace metadata; stop and report." }
    try { $metadataRepository = (Resolve-Path -LiteralPath $response.result.workspace.worktree.repo_root -ErrorAction Stop).Path } catch { throw "Workspace '$Workspace' has an invalid repository root; stop and report." }
    if ($metadataRepository -ine $canonicalRepository) { throw "Workspace '$Workspace' does not match the supplied repository; stop and report." }
}

function Assert-CleanWorktree([string]$Path) {
    $status = & git -C $Path status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) { throw "'$Path' is not a working tree; stop and report Herdr state instead of deleting it." }
    if (-not [string]::IsNullOrWhiteSpace(($status | Out-String))) { throw "Workspace '$Workspace' has uncommitted changes." }
}

function Assert-MergedPullRequest([string]$Path) {
    if ($mergeParameterCount -eq 0) { return }
    $head = & git -C $Path rev-parse HEAD 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($head | Out-String))) { throw "Could not resolve HEAD for workspace '$Workspace'; stop and report." }
    $head = ($head | Out-String).Trim()
    Push-Location -LiteralPath $Path
    try { $result = & gh repo view --json nameWithOwner 2>&1; $exitCode = $LASTEXITCODE } finally { Pop-Location }
    if ($exitCode -ne 0) { throw "Could not verify repository for workspace '$Workspace'; stop and report." }
    try { $githubRepositoryRecord = ($result | Out-String | ConvertFrom-Json -ErrorAction Stop) } catch { throw 'GitHub returned malformed repository state; stop and report.' }
    $canonicalGitHubRepository = $githubRepositoryRecord.nameWithOwner
    if ($canonicalGitHubRepository -isnot [string] -or $canonicalGitHubRepository -notmatch '^[^/]+/[^/]+$' -or $canonicalGitHubRepository -ine $GitHubRepository) { throw 'GitHub repository does not match the owning worktree; stop and report.' }
    $result = & gh pr view $PullRequest --repo $canonicalGitHubRepository --json number,state,baseRefName,headRefOid 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Could not verify pull request '$PullRequest'; stop and report." }
    try { $pr = ($result | Out-String | ConvertFrom-Json -ErrorAction Stop) } catch { throw 'GitHub returned malformed pull request state; stop and report.' }
    if ($null -eq $pr -or $pr.number -isnot [int] -and $pr.number -isnot [long] -or $pr.number -ne [long]$PullRequest -or
        $pr.state -cne 'MERGED' -or $pr.baseRefName -cne $Base -or $pr.headRefOid -cne $head) {
        throw 'Pull request merge evidence does not match the owning worktree; stop and report.'
    }
}

function Get-WorkspaceIds {
    $listing = & herdr workspace list 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Herdr could not inspect current workspaces; stop and report.' }
    try { $response = ($listing | Out-String | ConvertFrom-Json -ErrorAction Stop) } catch { throw 'Herdr returned malformed workspace list; stop and report.' }
    if ($response.id -ne 'cli:workspace:list' -or $null -eq $response.result -or $null -eq $response.result.workspaces) { throw 'Herdr returned inconsistent workspace list; stop and report.' }
    $ids = @($response.result.workspaces | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_.workspace_id)) { throw 'Herdr returned a malformed workspace ID; stop and report.' }
        $_.workspace_id
    })
    if (@($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'Herdr returned duplicate workspace IDs; stop and report.' }
    $ids
}

function Close-CwdSharingWorkspaces([string]$Path) {
    $workspaceIds = @(Get-WorkspaceIds)
    if (@($workspaceIds | Where-Object { $_ -ceq $Workspace }).Count -ne 1) { throw "Owning workspace '$Workspace' is missing or duplicated; stop and report." }
    $prefix = "$Path$([IO.Path]::DirectorySeparatorChar)"
    foreach ($candidate in $workspaceIds | Where-Object { $_ -cne $Workspace }) {
        $listing = & herdr pane list --workspace $candidate 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Herdr could not inspect workspace '$candidate'; stop and report." }
        try { $response = ($listing | Out-String | ConvertFrom-Json -ErrorAction Stop) } catch { throw 'Herdr returned malformed pane state; stop and report.' }
        if ($response.id -ne 'cli:pane:list' -or $null -eq $response.result -or $null -eq $response.result.panes) { throw 'Herdr returned inconsistent pane state; stop and report.' }
        $sharing = $false
        foreach ($pane in @($response.result.panes)) {
            if ($pane.workspace_id -cne $candidate -or [string]::IsNullOrWhiteSpace($pane.cwd)) { throw 'Herdr returned a malformed pane record; stop and report.' }
            try { $cwd = (Resolve-Path -LiteralPath $pane.cwd -ErrorAction Stop).Path } catch { throw 'Herdr returned an invalid pane CWD; stop and report.' }
            if ($cwd -ieq $Path -or $cwd.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { $sharing = $true }
        }
        if (-not $sharing) { continue }
        & herdr workspace close $candidate
        if ($LASTEXITCODE -ne 0) { throw "Herdr did not close auxiliary workspace '$candidate'; stop and report." }
        if (@(Get-WorkspaceIds | Where-Object { $_ -ceq $candidate }).Count -ne 0) { throw "Herdr still reports auxiliary workspace '$candidate' after close." }
    }
}

$canonicalRepository = (Resolve-Path -LiteralPath $Repository -ErrorAction Stop).Path
Assert-WorkspaceRepository
$worktreePath = Get-WorkspaceRecord -RequirePresent
Assert-CleanWorktree $worktreePath
Assert-MergedPullRequest $worktreePath

# Release current CWD-sharing workspace locks, then recheck immediately before removal.
Close-CwdSharingWorkspaces $worktreePath
Assert-WorkspaceRepository
$worktreePath = Get-WorkspaceRecord -RequirePresent
Assert-CleanWorktree $worktreePath
Assert-MergedPullRequest $worktreePath
if ($PSCmdlet.ShouldProcess($Workspace, 'remove completed Herdr workspace')) {
    & herdr worktree remove --workspace $Workspace --trust-repository
    if ($LASTEXITCODE -ne 0) { throw "Herdr did not remove workspace '$Workspace'; stop and report its state." }
    Get-WorkspaceRecord | Out-Null
}
