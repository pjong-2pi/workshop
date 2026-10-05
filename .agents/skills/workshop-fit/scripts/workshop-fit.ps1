[CmdletBinding()]
param(
    [switch]$Authorized,
    [string]$Pr,
    [string]$ReviewedHead,
    [string]$HeadBranch,
    [string]$Base,
    [string]$TaskWorkspace,
    [string]$MainWorkspace,
    [string]$RunnerPane,
    [string]$TaskPath,
    [string]$MainPath,
    [string]$MainBranch = 'main'
)

$ErrorActionPreference = 'Stop'
$result = [ordered]@{ status='BLOCKED'; pr=$Pr; merge_commit=$null; merge_confirmed=$false; task_cleanup='retained'; main_update='not-run'; blocker=$null }
function Stop-Fit([string]$reason) { throw $reason }
function Invoke-Git([string]$path,[string[]]$GitArgs) {
    $output = & git -C $path @GitArgs
    if ($LASTEXITCODE -ne 0) { Stop-Fit "git $($GitArgs[0]) failed (exit $LASTEXITCODE)." }
    ($output -join "`n").Trim()
}
function Invoke-Herdr([string[]]$HerdrArgs) {
    $output = & herdr @HerdrArgs
    if ($LASTEXITCODE -ne 0) { Stop-Fit "herdr $($HerdrArgs[0]) $($HerdrArgs[1]) failed (exit $LASTEXITCODE)." }
    if ($output -is [string]) { return (ConvertFrom-Json -InputObject ($output -join "`n")) }
    return $output
}
function Resolve-ExactPath([string]$path) { $path=$path -replace '^\\\\\?\\',''; [IO.Path]::GetFullPath($path).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar) }
function Write-Result { $result | ConvertTo-Json -Compress -Depth 5 }

try {
    if (-not $Authorized) { Stop-Fit 'Explicit user merge authorization is required.' }
    foreach ($value in @($Pr,$ReviewedHead,$HeadBranch,$Base,$TaskWorkspace,$MainWorkspace,$RunnerPane,$TaskPath,$MainPath)) { if (-not $value) { Stop-Fit 'Authorization, reviewed PR identity, and exact task/main/runner references are required.' } }
    if ($Pr -notmatch '^\d+$' -or $Base -ne $MainBranch) { Stop-Fit 'PR number and base must identify the assigned PR and main branch.' }
    $task = Resolve-ExactPath $TaskPath; $main = Resolve-ExactPath $MainPath
    if ($task -eq $main -or $TaskWorkspace -eq $MainWorkspace) { Stop-Fit 'Task and main must be distinct worktrees/workspaces.' }
    if (-not (Test-Path -LiteralPath $task -PathType Container) -or -not (Test-Path -LiteralPath $main -PathType Container)) { Stop-Fit 'Task or main path does not exist.' }

    $mainRoot = Resolve-ExactPath (Invoke-Git $main @('rev-parse','--show-toplevel'))
    $taskRoot = Resolve-ExactPath (Invoke-Git $task @('rev-parse','--show-toplevel'))
    if ($mainRoot -ne $main -or $taskRoot -ne $task) { Stop-Fit 'Supplied main/task path is not its exact Git worktree root.' }
    if ((Invoke-Git $task @('branch','--show-current')) -ne $HeadBranch -or (Invoke-Git $task @('rev-parse','HEAD')) -ne $ReviewedHead) { Stop-Fit 'Task branch or HEAD changed after review.' }
    $origin = Invoke-Git $task @('remote','get-url','--push','origin')
    if ((Invoke-Git $main @('remote','get-url','--push','origin')) -ne $origin) { Stop-Fit 'Main and task do not share the same origin push repository.' }
    $repository = & gh repo view $origin --json url --jq .url
    if ($LASTEXITCODE -ne 0 -or -not $repository) { Stop-Fit 'Cannot resolve the assigned origin repository.' }
    $repository = ($repository -join "`n").Trim()
    $prFields = 'url,state,headRefName,headRefOid,baseRefName,headRepository'
    $pullRequest = & gh pr view $Pr --repo $repository --json $prFields --jq '[.url,.state,.headRefName,.headRefOid,.baseRefName,(.headRepository.nameWithOwner // "")] | @tsv'
    if ($LASTEXITCODE -ne 0 -or -not $pullRequest) { Stop-Fit 'Cannot resolve the assigned PR.' }
    $repoName = (($repository -replace '^https?://github\.com/','').TrimEnd('/') -replace '\.git$','')
    $pullRequest = (($pullRequest -join "`n").Trim() -split "`t")
    if ($pullRequest[0] -notmatch ('^' + [regex]::Escape($repository.TrimEnd('/')) + '/pull/\d+$') -or $pullRequest[1] -ne 'OPEN' -or $pullRequest[2] -ne $HeadBranch -or $pullRequest[3] -ne $ReviewedHead -or $pullRequest[4] -ne $Base -or $pullRequest[5] -ne $repoName) { Stop-Fit 'PR repository, state, reviewed head, or base differs from the authorized assignment.' }

    $native = Invoke-Herdr @('worktree','list','--workspace',$MainWorkspace)
    $source = $native.result.source
    $trees = @($native.result.worktrees)
    $mainTree = @($trees | Where-Object { $_.open_workspace_id -eq $MainWorkspace -and (Resolve-ExactPath $_.path) -eq $main -and $_.branch -eq $MainBranch -and -not $_.is_linked_worktree })
    $taskTree = @($trees | Where-Object { $_.open_workspace_id -eq $TaskWorkspace -and (Resolve-ExactPath $_.path) -eq $task -and $_.branch -eq $HeadBranch -and $_.is_linked_worktree })
    if ($source.source_workspace_id -ne $MainWorkspace -or (Resolve-ExactPath $source.repo_root) -ne $main -or $mainTree.Count -ne 1 -or $taskTree.Count -ne 1) { Stop-Fit 'Native Herdr provenance does not match the assigned main and linked task worktree.' }
    $pane = Invoke-Herdr @('pane','get',$RunnerPane)
    if ($pane.result.pane.workspace_id -ne $MainWorkspace) { Stop-Fit 'Runner pane is not in the main workspace outside the task worktree.' }

    $apiHost = ([uri]$repository).Host
    $mergeResponse = & gh api --hostname $apiHost --method PUT "repos/$repoName/pulls/$Pr/merge" -f "sha=$ReviewedHead" -f 'merge_method=squash'
    if ($LASTEXITCODE -ne 0) { Stop-Fit "Immediate squash merge failed (exit $LASTEXITCODE); task resources retained." }
    try { $mergeResponse = ($mergeResponse -join "`n") | ConvertFrom-Json } catch { Stop-Fit 'Immediate squash merge response was invalid; task resources retained.' }
    if ($mergeResponse.merged -ne $true -or -not $mergeResponse.sha) { Stop-Fit 'Immediate squash merge was not confirmed; task resources retained.' }
    $pullRequest = & gh pr view $Pr --repo $repository --json state,mergeCommit --jq '[.state,(.mergeCommit.oid // "")] | @tsv'
    if ($LASTEXITCODE -ne 0 -or -not $pullRequest) { Stop-Fit 'Squash merge result could not be confirmed; task resources retained.' }
    $pullRequest = (($pullRequest -join "`n").Trim() -split "`t")
    if ($pullRequest[0] -ne 'MERGED' -or -not $pullRequest[1]) { Stop-Fit 'PR is not confirmed MERGED; task resources retained.' }
    $result.merge_confirmed = $true; $result.merge_commit = $pullRequest[1]

    $mainStatus = Invoke-Git $main @('status','--porcelain')
    if ($mainStatus) { $result.main_update = 'skipped-dirty' }
    else {
        & git -C $main fetch origin $Base
        if ($LASTEXITCODE -ne 0) { $result.main_update = 'blocked-fetch-failed' }
        else {
            & git -C $main merge --ff-only "origin/$Base"
            if ($LASTEXITCODE -eq 0) { $result.main_update = 'fast-forwarded' } else { $result.main_update = 'blocked-fast-forward-failed' }
        }
    }
    & herdr worktree remove --workspace $TaskWorkspace
    if ($LASTEXITCODE -eq 0) { $result.task_cleanup = 'worktree-removed' } else { $result.task_cleanup = 'retained-remove-failed' }
    if ($result.task_cleanup -eq 'worktree-removed') {
        & git -C $main branch -d $HeadBranch *> $null
        if ($LASTEXITCODE -eq 0) { $result.task_cleanup = 'worktree-and-branch-removed' } else { $result.task_cleanup = 'worktree-removed-branch-retained' }
    }
    if ($result.task_cleanup -eq 'retained-remove-failed') { Stop-Fit 'Merge was confirmed, but task worktree removal failed; resources are retained.' }
    if ($result.main_update -like 'blocked-*') { Stop-Fit "Merge and task cleanup completed, but main update failed: $($result.main_update)." }
    $result.status = if ($result.task_cleanup -eq 'worktree-removed-branch-retained') { 'COMPLETE_WITH_RETAINED_BRANCH' } else { 'COMPLETE' }
} catch { $result.blocker = $_.Exception.Message }
Write-Result
