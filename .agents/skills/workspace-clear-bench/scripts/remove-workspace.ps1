[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]*$')][string]$Workspace,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })][string]$Repository,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })][string]$WorktreePath,
    [string]$IntegrationEvidence,
    [string]$DiscardAuthorization,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RemovalAuthorization
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($IntegrationEvidence) -eq [string]::IsNullOrWhiteSpace($DiscardAuthorization)) {
    throw 'Provide exactly one of -IntegrationEvidence or -DiscardAuthorization.'
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
        try { $recordPath = (Resolve-Path -LiteralPath $matches[0].path -ErrorAction Stop).Path } catch { throw "Workspace '$Workspace' has an invalid recorded path; stop and report." }
        if ($recordPath -ine $canonicalWorktreePath) { throw "Workspace '$Workspace' does not match the supplied worktree path; stop and report." }
        return $matches[0]
    }
    if ($matches.Count -ne 0) { throw "Herdr still reports workspace '$Workspace' after removal." }
}

function Assert-CleanWorktree {
    $status = & git -C $WorktreePath status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) { throw "'$WorktreePath' is not a working tree; stop and report Herdr state instead of deleting it." }
    if (-not [string]::IsNullOrWhiteSpace(($status | Out-String))) { throw "Workspace '$Workspace' has uncommitted changes." }
}

$canonicalWorktreePath = (Resolve-Path -LiteralPath $WorktreePath -ErrorAction Stop).Path
Get-WorkspaceRecord -RequirePresent | Out-Null
Assert-CleanWorktree

# Recheck immediately before the only mutation.
Get-WorkspaceRecord -RequirePresent | Out-Null
Assert-CleanWorktree
if ($PSCmdlet.ShouldProcess($Workspace, 'remove completed Herdr workspace')) {
    & herdr worktree remove --workspace $Workspace --trust-repository
    if ($LASTEXITCODE -ne 0) { throw "Herdr did not remove workspace '$Workspace'; stop and report its state." }
    Get-WorkspaceRecord | Out-Null
}
