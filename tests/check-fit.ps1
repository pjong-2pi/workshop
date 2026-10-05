$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '../.agents/skills/workshop-fit/scripts/workshop-fit.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('workshop-fit-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $temp 'task'),(Join-Path $temp 'main') | Out-Null
$global:fitPaths = @{task=(Join-Path $temp 'task');main=(Join-Path $temp 'main')}
$global:fitCalls = [Collections.Generic.List[object]]::new()
$global:realGitExe = (Get-Command git.exe -CommandType Application | Select-Object -First 1).Source
function Assert($ok,$message) { if (-not $ok) { throw $message } }
function Set-Exit([int]$value) { [void](Set-Variable -Scope Global -Name LASTEXITCODE -Value $value) }
function Invoke-RealGit([string]$Path,[string[]]$GitArgs,[switch]$AllowFailure) {
    $output = & $global:realGitExe -C $Path @GitArgs 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFailure) { throw "Real git $($GitArgs -join ' ') failed: $($output -join ' ')" }
    @{exit_code=$code;output=($output -join "`n")}
}
function global:git {
    $a=@($args); $global:fitCalls.Add(@('git')+$a); Set-Exit 0
    $path=$a[1]; $op=$a[2]
    switch ($op) {
        'rev-parse' { if ($a[3] -eq '--show-toplevel') { return $path }; if ($a[3] -eq 'HEAD') { return $(if($global:changedHead){'different-head'}else{'reviewed-head'}) } }
        'branch' { if ($a[3] -eq '--show-current') { return 'task-branch' }; if ($global:branchDeleteFails) { Set-Exit 1 }; return }
        'remote' { return 'https://github.com/example/project.git' }
        'status' { return $(if ($global:dirtyMain -and $path -eq $global:fitPaths.main) {' M dirty.txt'}else{''}) }
        'fetch' { if ($global:fetchFails) { Set-Exit 1; return }; $global:freshBase=$true; return }
        'merge' { if ($global:ffFails -or -not $global:freshBase) { Set-Exit 1 }; return }
        default { throw "Unexpected git $($a -join ' ')" }
    }
}
function global:gh {
    $a=@($args); $global:fitCalls.Add(@('gh')+$a); Set-Exit 0
    if ($a[0] -eq 'repo') { return 'https://github.com/example/project' }
    if ($a[0] -eq 'api') {
        if ($a -notcontains 'PUT' -or $a -notcontains 'repos/example/project/pulls/26/merge' -or $a -notcontains 'sha=reviewed-head' -or $a -notcontains 'merge_method=squash' -or $a -contains 'repos/example/project/pulls/26/merge-async') { throw "Unexpected merge API: $($a -join ' ')" }
        if ($global:mergeFails) { Set-Exit 1; return }
        if ($global:mergeResponseFalse) { return '{"merged":false,"sha":""}' }
        $global:mergeDone=$true; return '{"merged":true,"sha":"merge-sha"}'
    }
    if ($a[0] -eq 'pr' -and $a[1] -eq 'view') {
        if ($global:confirmFails) { Set-Exit 1; return }
        if ($global:mergeDone) { if($global:notMerged){return [string]::Join([char]9, @('OPEN',''))}; return [string]::Join([char]9, @('MERGED','merge-sha')) }
        if ($global:changedPrHead) { return [string]::Join([char]9, @('https://github.com/example/project/pull/26','OPEN','task-branch','different-head','main','example/project')) }
        return [string]::Join([char]9, @('https://github.com/example/project/pull/26','OPEN','task-branch','reviewed-head','main','example/project'))
    }
    throw "Unexpected gh $($a -join ' ')"
}
function global:herdr {
    $a=@($args); $global:fitCalls.Add(@('herdr')+$a); Set-Exit 0
    if ($a[0] -eq 'worktree' -and $a[1] -eq 'list') {
        if ($global:badProvenance) { $sourceId='wrong-main' } else { $sourceId='w-main' }
        return @{result=@{source=@{source_workspace_id=$sourceId;repo_root="\\?\$($global:fitPaths.main)"};worktrees=@(
            @{branch='main';path=$global:fitPaths.main;open_workspace_id='w-main';is_linked_worktree=$false},
            @{branch='task-branch';path=$global:fitPaths.task;open_workspace_id='w-task';is_linked_worktree=$true},
            @{branch='other';path=(Join-Path $global:fitPaths.main 'other');open_workspace_id='w-other';is_linked_worktree=$true}
        )}}
    }
    if ($a[0] -eq 'pane' -and $a[1] -eq 'get') { return @{result=@{pane=@{pane_id='p-runner';workspace_id=$(if($global:badRunner){'w-task'}else{'w-main'})}}} }
    if ($a[0] -eq 'worktree' -and $a[1] -eq 'remove') { if($a -contains '--force'){throw 'Force removal used.'}; if($a -notcontains 'w-task'){throw 'Wrong workspace removed.'}; if($global:removeFails){Set-Exit 1}; return }
    throw "Unexpected herdr $($a -join ' ')"
}
function Reset-Fit {
    $global:fitCalls.Clear(); $global:changedHead=$false; $global:dirtyMain=$false; $global:mergeFails=$false; $global:mergeResponseFalse=$false; $global:confirmFails=$false; $global:changedPrHead=$false; $global:ffFails=$false; $global:fetchFails=$false; $global:freshBase=$false; $global:mergeDone=$false; $global:notMerged=$false; $global:branchDeleteFails=$false; $global:removeFails=$false; $global:badProvenance=$false; $global:badRunner=$false
}
$p=@{Authorized=$true;Pr='26';ReviewedHead='reviewed-head';HeadBranch='task-branch';Base='main';TaskWorkspace='w-task';MainWorkspace='w-main';RunnerPane='p-runner';TaskPath=$global:fitPaths.task;MainPath=$global:fitPaths.main}
try {
    Reset-Fit; $p.Remove('Authorized') | Out-Null; $r=& $script @p | ConvertFrom-Json; Assert ($r.status -eq 'BLOCKED' -and $global:fitCalls.Count -eq 0) 'Unauthorized request mutated state.'; $p.Authorized=$true
    Reset-Fit; $global:changedHead=$true; $r=& $script @p | ConvertFrom-Json; Assert ($r.status -eq 'BLOCKED' -and @($global:fitCalls|Where-Object {$_[0] -eq 'gh' -and $_[1] -eq 'api'}).Count -eq 0) 'Changed task HEAD was accepted.'
    Reset-Fit; $p.Base='release'; $r=& $script @p | ConvertFrom-Json; Assert ($r.status -eq 'BLOCKED' -and $global:fitCalls.Count -eq 0) 'Base mismatch reached native commands.'; $p.Base='main'
    Reset-Fit; $global:changedPrHead=$true; $r=& $script @p | ConvertFrom-Json; Assert ($r.status -eq 'BLOCKED' -and @($global:fitCalls|Where-Object {$_[0] -eq 'gh' -and $_[1] -eq 'api'}).Count -eq 0) 'Changed PR head was accepted.'
    foreach($failure in @('merge','merge-response','confirm')) {
        Reset-Fit; if($failure -eq 'merge'){$global:mergeFails=$true}elseif($failure -eq 'merge-response'){$global:mergeResponseFalse=$true}else{$global:confirmFails=$true}; $r=& $script @p | ConvertFrom-Json
        Assert ($r.status -eq 'BLOCKED' -and -not $r.merge_confirmed -and @($global:fitCalls|Where-Object {$_[0] -eq 'herdr' -and $_[1] -eq 'worktree' -and $_[2] -eq 'remove'}).Count -eq 0) "$failure failure ran cleanup."
    }
    Reset-Fit; $global:notMerged=$true; $r=& $script @p | ConvertFrom-Json; Assert ($r.status -eq 'BLOCKED' -and -not $r.merge_confirmed -and @($global:fitCalls|Where-Object {$_[0] -eq 'herdr' -and $_[1] -eq 'worktree' -and $_[2] -eq 'remove'}).Count -eq 0) 'Unconfirmed merge ran cleanup.'
    Reset-Fit; $r=& $script @p | ConvertFrom-Json; Assert ($r.status -eq 'COMPLETE' -and $r.merge_confirmed -and @($global:fitCalls|Where-Object {$_[0] -eq 'herdr' -and $_[1] -eq 'worktree' -and $_[2] -eq 'remove' -and $_[4] -eq 'w-task'}).Count -eq 1 -and $global:freshBase -and @($global:fitCalls|Where-Object {$_[0] -eq 'git' -and $_[3] -eq 'fetch'}).Count -eq 1) "Successful flow failed: $($r|ConvertTo-Json -Compress); calls=$($global:fitCalls|ConvertTo-Json -Compress -Depth 6)"
    Assert (@($global:fitCalls|Where-Object {$_ -contains '--force'}).Count -eq 0 -and @($global:fitCalls|Where-Object {$_[0] -eq 'herdr' -and $_[1] -eq 'workspace' -and $_[2] -eq 'close'}).Count -eq 0) 'Runner forced removal or closed a workspace.'
    Reset-Fit; $global:branchDeleteFails=$true; $r=& $script @p | ConvertFrom-Json; Assert ($r.merge_confirmed -and $r.task_cleanup -eq 'worktree-removed-branch-retained' -and $r.status -eq 'COMPLETE_WITH_RETAINED_BRANCH' -and -not $r.blocker -and @($global:fitCalls|Where-Object {$_ -contains '--force'}).Count -eq 0) 'Ordinary branch deletion refusal was not reported as successful worktree cleanup with a retained branch.'
    Reset-Fit; $global:removeFails=$true; $r=& $script @p | ConvertFrom-Json; Assert ($r.merge_confirmed -and $r.task_cleanup -eq 'retained-remove-failed' -and $r.status -eq 'BLOCKED') 'Task worktree removal failure was not blocked.'
    Reset-Fit; $global:dirtyMain=$true; $r=& $script @p | ConvertFrom-Json; Assert ($r.merge_confirmed -and $r.main_update -eq 'skipped-dirty' -and @($global:fitCalls|Where-Object {$_[0] -eq 'git' -and $_[3] -eq 'fetch'}).Count -eq 0) 'Dirty main was updated.'
    Reset-Fit; $global:fetchFails=$true; $r=& $script @p | ConvertFrom-Json; Assert ($r.status -eq 'BLOCKED' -and $r.merge_confirmed -and $r.main_update -eq 'blocked-fetch-failed' -and @($global:fitCalls|Where-Object {$_[0] -eq 'git' -and $_[3] -eq 'merge'}).Count -eq 0) 'Failed fetch was hidden or followed by a stale fast-forward.'
    Reset-Fit; $global:ffFails=$true; $r=& $script @p | ConvertFrom-Json; Assert ($r.status -eq 'BLOCKED' -and $r.merge_confirmed -and $r.main_update -eq 'blocked-fast-forward-failed' -and $r.task_cleanup -ne 'retained-remove-failed') 'Fast-forward failure did not report the confirmed-merge partial handoff.'

    $realRepo = Join-Path $temp 'real-git'
    New-Item -ItemType Directory -Path $realRepo | Out-Null
    Invoke-RealGit $realRepo @('init') | Out-Null
    Invoke-RealGit $realRepo @('config','user.name','Fit Check') | Out-Null
    Invoke-RealGit $realRepo @('config','user.email','fit-check@example.invalid') | Out-Null
    Invoke-RealGit $realRepo @('checkout','-b','main') | Out-Null
    Set-Content -LiteralPath (Join-Path $realRepo 'change.txt') -Value 'base'
    Invoke-RealGit $realRepo @('add','change.txt') | Out-Null
    Invoke-RealGit $realRepo @('commit','-m','base') | Out-Null
    Invoke-RealGit $realRepo @('checkout','-b','task-branch') | Out-Null
    Set-Content -LiteralPath (Join-Path $realRepo 'change.txt') -Value 'task change'
    Invoke-RealGit $realRepo @('commit','-am','task change') | Out-Null
    Invoke-RealGit $realRepo @('checkout','main') | Out-Null
    Invoke-RealGit $realRepo @('merge','--squash','task-branch') | Out-Null
    Invoke-RealGit $realRepo @('commit','-m','squash task') | Out-Null
    $upstream = Invoke-RealGit $realRepo @('rev-parse','--abbrev-ref','task-branch@{upstream}') -AllowFailure
    $delete = Invoke-RealGit $realRepo @('branch','-d','task-branch') -AllowFailure
    $branchExists = Invoke-RealGit $realRepo @('show-ref','--verify','--quiet','refs/heads/task-branch') -AllowFailure
    $isAncestor = Invoke-RealGit $realRepo @('merge-base','--is-ancestor','task-branch','main') -AllowFailure
    Assert ($upstream.exit_code -ne 0 -and $delete.exit_code -ne 0 -and $branchExists.exit_code -eq 0 -and $isAncestor.exit_code -ne 0) 'Real squash ancestry did not reproduce safe no-upstream branch deletion refusal.'
    'PASS: authorization, immediate squash and confirmation, fresh-base handling, partial failure reporting, retained-branch outcome, task-only cleanup, and real squash/no-upstream -d behavior.'
} finally {
    Remove-Item Function:\git,Function:\gh,Function:\herdr -ErrorAction SilentlyContinue
    if ([IO.Path]::GetFullPath($temp).StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
