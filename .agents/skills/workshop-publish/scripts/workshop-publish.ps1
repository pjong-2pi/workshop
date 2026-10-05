[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Worktree,
    [Parameter(Mandatory)][string]$Branch,
    [Parameter(Mandatory)][string[]]$Files,
    [Parameter(Mandatory)][ValidateSet('PASS','LGTM')][string]$ReviewVerdict,
    [Parameter(Mandatory)][string]$CommitMessage,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Body,
    [Parameter(Mandatory)][string]$Base
)

$ErrorActionPreference = 'Stop'
$committed = $false
$pushed = $false
function Invoke-PublishGit {
    param([string[]]$Arguments)
    $output = & git -C $Worktree @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments[0]) failed (exit $LASTEXITCODE)." }
    $output
}
try {
    $Worktree = [IO.Path]::GetFullPath($Worktree).TrimEnd('\','/')
    $root = Invoke-PublishGit @('rev-parse','--show-toplevel')
    if ([IO.Path]::GetFullPath($root).TrimEnd('\','/') -ne $Worktree) { throw 'Worktree must be the exact repository root.' }
    Invoke-PublishGit @('check-ref-format','--branch',$Branch) | Out-Null
    Invoke-PublishGit @('check-ref-format','--branch',$Base) | Out-Null
    if ((Invoke-PublishGit @('branch','--show-current')) -ne $Branch -or $Branch -eq $Base) { throw 'Task branch mismatch or task branch equals base.' }
    Invoke-PublishGit @('rev-parse','--verify',"refs/remotes/origin/$Base") | Out-Null
    $origin = Invoke-PublishGit @('remote','get-url','--push','origin')
    & gh auth status *> $null
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI authentication unavailable.' }
    $repository = & gh repo view $origin --json url --jq .url
    if ($LASTEXITCODE -ne 0 -or -not $repository) { throw 'Cannot resolve the origin push repository with GitHub CLI.' }
    if (-not $Files.Count) { throw 'An explicit scoped file list is required.' }
    $scoped = foreach ($file in $Files) {
        if (-not $file -or [IO.Path]::IsPathRooted($file)) { throw 'Scoped files must be repository-relative.' }
        $absolute = [IO.Path]::GetFullPath((Join-Path $Worktree $file))
        if (-not $absolute.StartsWith($Worktree + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Scoped path escapes worktree: $file" }
        $relative = [IO.Path]::GetRelativePath($Worktree,$absolute).Replace('\','/')
        if ($relative -eq '.git' -or $relative.StartsWith('.git/', [StringComparison]::OrdinalIgnoreCase)) { throw 'Git metadata cannot be published.' }
        if (Test-Path -LiteralPath $absolute -PathType Container) { throw 'Scoped paths must be files, not directories.' }
        $relative
    }
    $branchFiles = @(Invoke-PublishGit @('-c','core.quotePath=false','diff','--name-only','--no-renames',"refs/remotes/origin/$Base...HEAD",'--'))
    if (@($branchFiles | Where-Object { $_ -notin $scoped }).Count) { throw 'Committed branch changes exceed the scoped file list; publication stopped before staging.' }
    $staged = @(Invoke-PublishGit @('-c','core.quotePath=false','diff','--cached','--name-only','--no-renames'))
    if (@($staged | Where-Object { $_ -notin $scoped }).Count) { throw 'Unrelated staged changes exist; publication stopped before staging.' }
    Invoke-PublishGit (@('--literal-pathspecs','add','--') + $scoped) | Out-Null
    $staged = @(Invoke-PublishGit @('-c','core.quotePath=false','diff','--cached','--name-only','--no-renames'))
    if (-not $staged.Count -or @($staged | Where-Object { $_ -notin $scoped }).Count) { throw 'No scoped staged changes or staging exceeded scope.' }
    Invoke-PublishGit @('commit','-m',$CommitMessage) | Out-Null
    $committed = $true
    Invoke-PublishGit @('push','origin',"HEAD:refs/heads/$Branch") | Out-Null
    $pushed = $true
    $bodyPath = Join-Path ([IO.Path]::GetTempPath()) ('workshop-pr-' + [guid]::NewGuid().ToString('N') + '.md')
    try {
        [IO.File]::WriteAllText($bodyPath,$Body)
        Push-Location -LiteralPath $Worktree
        try {
            $url = & gh pr create --repo $repository --base $Base --head $Branch --title $Title --body-file $bodyPath
            if ($LASTEXITCODE -ne 0) { throw "gh pr create failed (exit $LASTEXITCODE)." }
        } finally { Pop-Location }
    } finally { if (Test-Path -LiteralPath $bodyPath) { Remove-Item -LiteralPath $bodyPath } }
    @{ status='published'; branch=$Branch; pr=($url -join "`n"); committed=$committed; pushed=$pushed } | ConvertTo-Json -Compress
} catch {
    [Console]::Error.WriteLine("Publication failed; committed=$committed pushed=${pushed}: $($_.Exception.Message)")
    exit 1
}
