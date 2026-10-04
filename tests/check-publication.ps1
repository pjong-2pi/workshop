$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '../.agents/skills/workshop-publish/scripts/workshop-publish.ps1'
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('workshop-publication-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
$global:testWorktree = [IO.Path]::GetFullPath($temporary)
$global:commands = [Collections.Generic.List[object]]::new()
$savedGhRepo = $env:GH_REPO
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function global:git {
    $items = @($args)
    $global:commands.Add($items)
    $global:LASTEXITCODE = 0
    switch ($items[2]) {
        'rev-parse' { if ($items[3] -eq '--show-toplevel') { $global:testWorktree } else { 'base-hash' } }
        'branch' { if ($global:wrongBranch) { 'other-task' } else { 'task' } }
        'check-ref-format' { $items[4] }
        'remote' {
            Assert ($items[3] -eq 'get-url' -and $items[4] -eq '--push' -and $items[5] -eq 'origin') 'Repository resolution used the fetch destination instead of the push destination.'
            'https://github.com/example/project.git'
        }
        '-c' {
            if ('--cached' -in $items) { $global:stagedFiles } else {
                Assert ('refs/remotes/origin/main...HEAD' -in $items) 'Committed scope was not checked against the intended PR base.'
                $global:branchFiles
            }
        }
        '--literal-pathspecs' { $global:stagedFiles = @($items | Select-Object -Skip 5) }
        'commit' { 'mock commit' }
        'push' { 'mock push' }
        default { throw "Unexpected git operation: $($items[2])" }
    }
}
function global:gh {
    $items = @($args)
    $global:commands.Add($items)
    $global:LASTEXITCODE = 0
    if ($items[0] -eq 'auth') { return }
    if ($items[0] -eq 'repo') {
        Assert ($items[1] -eq 'view' -and $items[2] -eq 'https://github.com/example/project.git') 'Repository resolution did not use origin push destination.'
        'https://github.com/example/project'
        return
    }
    Assert ($items[0] -eq 'pr' -and $items[1] -eq 'create') 'Unexpected gh operation.'
    $repoIndex = [array]::IndexOf($items,'--repo')
    Assert ($repoIndex -ge 0 -and $items[$repoIndex+1] -eq 'https://github.com/example/project') 'PR destination was affected by ambient GH_REPO.'
    Assert ((Get-Location).Path -eq $global:testWorktree) 'PR creation used the caller directory instead of the task.'
    $bodyIndex = [array]::IndexOf($items,'--body-file')
    Assert ([IO.File]::ReadAllText($items[$bodyIndex+1]) -eq "Reviewed body`nwith a second line") 'PR body was altered.'
    if ($global:failPr) { $global:LASTEXITCODE = 1; return }
    'https://github.com/example/project/pull/1'
}
try {
    [IO.File]::WriteAllText((Join-Path $temporary 'reviewed.md'),'reviewed implementation')
    [IO.File]::WriteAllText((Join-Path $temporary 'unrelated.md'),'unrelated work')
    $parameters = @{Worktree=$temporary;Branch='task';Files=@('reviewed.md');ReviewVerdict='PASS';CommitMessage='Reviewed task';Title='Reviewed task';Body="Reviewed body`nwith a second line";Base='main'}
    $parameters.ReviewVerdict = 'FINDINGS'
    $rejected = $false
    try { & $script @parameters } catch { $rejected = $true }
    Assert ($rejected -and $global:commands.Count -eq 0) 'Publication accepted an unapproved verdict.'
    $parameters.ReviewVerdict = 'PASS'
    foreach ($failure in @('branch','path','staged','committed')) {
        $global:commands.Clear()
        $global:stagedFiles = @()
        $global:branchFiles = if ($failure -eq 'committed') { @('unlisted.md') } else { @() }
        $global:wrongBranch = $failure -eq 'branch'
        if ($failure -eq 'staged') { $global:stagedFiles = @('unrelated.md') }
        $parameters.Files = if ($failure -eq 'path') { @('../outside.md') } else { @('reviewed.md') }
        $result = & $script @parameters 2>$null
        Assert (-not $? -and -not $result) "Publication accepted unsafe $failure."
        Assert (@($global:commands | Where-Object { $_[2] -in @('--literal-pathspecs','commit','push') -or ($_[0] -eq 'pr') }).Count -eq 0) "Unsafe $failure mutated publication state."
    }
    $global:wrongBranch = $false
    $global:stagedFiles = @()
    $global:branchFiles = @('reviewed.md')
    $env:GH_REPO = 'different-owner/different-repository'
    $global:commands.Clear()
    $parameters.Files = @('reviewed.md')
    $published = & $script @parameters | ConvertFrom-Json
    Assert ($published.status -eq 'published' -and $published.committed -and $published.pushed -and $published.pr -match '/pull/1$') 'Publication outcome missing.'
    Assert ($global:stagedFiles.Count -eq 1 -and $global:stagedFiles[0] -eq 'reviewed.md') 'Staging exceeded reviewed scope.'
    Assert ([IO.File]::ReadAllText((Join-Path $temporary 'reviewed.md')) -eq 'reviewed implementation' -and [IO.File]::ReadAllText((Join-Path $temporary 'unrelated.md')) -eq 'unrelated work') 'Publication changed implementation or unrelated work.'
    $global:failPr = $true
    $global:stagedFiles = @()
    $global:commands.Clear()
    $result = & $script @parameters 2>$null
    Assert (-not $? -and -not $result -and @($global:commands | Where-Object { $_[0] -eq 'pr' }).Count -eq 1) 'Native publication failure was ignored or retried.'
    'PASS: publication path/branch/committed scope, scoped staging, explicit PR repository despite GH_REPO, unchanged files, and native failure.'
} finally {
    $env:GH_REPO = $savedGhRepo
    Remove-Item Function:\git,Function:\gh -ErrorAction SilentlyContinue
    if (([IO.Path]::GetFullPath($temporary)).StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
