$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$gate = Join-Path $root '.agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1'
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) "workshop-clear-bench-test-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $fixture, (Join-Path $fixture 'bin'), (Join-Path $fixture 'repository'), (Join-Path $fixture 'worktree') | Out-Null
try {
    $state = Join-Path $fixture 'herdr-worktree-state.json'
    $metadata = Join-Path $fixture 'herdr-metadata.json'
    $workspaces = Join-Path $fixture 'herdr-workspaces.json'
    $workspacesAfter = Join-Path $fixture 'herdr-workspaces-after.json'
    $panes = Join-Path $fixture 'herdr-panes.json'
    $log = Join-Path $fixture 'herdr.log'
    $closed = Join-Path $fixture 'closed.txt'
    $ghState = Join-Path $fixture 'gh.json'
    $ghRepositoryState = Join-Path $fixture 'gh-repository.json'
    Set-Content -LiteralPath (Join-Path $fixture 'bin/herdr.cmd') -Value @'
@echo off
echo %*>> "%HERDR_LOG%"
if "%1"=="worktree" if "%2"=="list" type "%HERDR_WORKTREE_STATE%"
if "%1"=="worktree" if "%2"=="list" exit /b 0
if "%1"=="worktree" if "%2"=="remove" > "%HERDR_WORKTREE_STATE%" echo {"id":"cli:worktree:list","result":{"source":{},"type":"worktree_list","worktrees":[]}}
if "%1"=="worktree" if "%2"=="remove" exit /b 0
if "%1"=="workspace" if "%2"=="get" type "%HERDR_METADATA%"
if "%1"=="workspace" if "%2"=="get" exit /b 0
if "%1"=="workspace" if "%2"=="list" if exist "%HERDR_CLOSED%" type "%HERDR_WORKSPACES_AFTER%"
if "%1"=="workspace" if "%2"=="list" if exist "%HERDR_CLOSED%" exit /b 0
if "%1"=="workspace" if "%2"=="list" type "%HERDR_WORKSPACES%"
if "%1"=="workspace" if "%2"=="list" exit /b 0
if "%1"=="workspace" if "%2"=="close" if "%HERDR_CLOSE_FAILURE%"=="1" exit /b 1
if "%1"=="workspace" if "%2"=="close" echo %3>"%HERDR_CLOSED%"
if "%1"=="workspace" if "%2"=="close" exit /b 0
if "%1"=="pane" if "%2"=="list" type "%HERDR_PANES%"
if "%1"=="pane" if "%2"=="list" exit /b 0
exit /b 1
'@
    Set-Content -LiteralPath (Join-Path $fixture 'bin/git.cmd') -Value @'
@echo off
if "%3"=="status" if "%GIT_DIRTY%"=="1" echo  M changed.txt
if "%3"=="status" exit /b 0
if "%3"=="rev-parse" echo 0123456789012345678901234567890123456789
if "%3"=="rev-parse" exit /b 0
exit /b 1
'@
    Set-Content -LiteralPath (Join-Path $fixture 'bin/gh.cmd') -Value "@echo off`r`nif `"%1`"==`"repo`" type `"%GH_REPOSITORY_STATE%`"`r`nif `"%1`"==`"repo`" exit /b 0`r`ntype `"%GH_STATE%`"`r`nexit /b 0"
    $oldPath = $env:PATH
    try {
        function Set-WorktreeState([object[]]$Worktrees) {
            Set-Content -LiteralPath $state -Value (@{ id = 'cli:worktree:list'; result = @{ source = @{}; type = 'worktree_list'; worktrees = $Worktrees } } | ConvertTo-Json -Compress -Depth 4)
        }
        function Set-WorkspaceState([bool]$IncludeAux) {
            $items = @(@{ workspace_id = 'bench-12' })
            if ($IncludeAux) { $items += @{ workspace_id = 'review-7' } }
            Set-Content -LiteralPath $workspaces -Value (@{ id = 'cli:workspace:list'; result = @{ workspaces = $items } } | ConvertTo-Json -Compress -Depth 4)
            Set-Content -LiteralPath $workspacesAfter -Value (@{ id = 'cli:workspace:list'; result = @{ workspaces = @(@{ workspace_id = 'bench-12' }) } } | ConvertTo-Json -Compress -Depth 4)
        }
        function Set-GhState([string]$State = 'MERGED', [string]$Base = 'main', [string]$Head = '0123456789012345678901234567890123456789') {
            Set-Content -LiteralPath $ghState -Value (@{ number = 42; state = $State; baseRefName = $Base; headRefOid = $Head } | ConvertTo-Json -Compress)
        }

        Set-Content -LiteralPath $metadata -Value (@{ id = 'cli:workspace:get'; result = @{ workspace = @{ workspace_id = 'bench-12'; worktree = @{ repo_root = (Join-Path $fixture 'repository') } } } } | ConvertTo-Json -Compress -Depth 5)
        Set-Content -LiteralPath $panes -Value (@{ id = 'cli:pane:list'; result = @{ panes = @(@{ workspace_id = 'review-7'; cwd = (Join-Path $fixture 'worktree') }) } } | ConvertTo-Json -Compress -Depth 5)
        Set-Content -LiteralPath $ghRepositoryState -Value (@{ nameWithOwner = 'test/repo' } | ConvertTo-Json -Compress)
        $env:PATH = "$(Join-Path $fixture 'bin');$oldPath"
        $env:HERDR_WORKTREE_STATE = $state
        $env:HERDR_METADATA = $metadata
        $env:HERDR_WORKSPACES = $workspaces
        $env:HERDR_WORKSPACES_AFTER = $workspacesAfter
        $env:HERDR_PANES = $panes
        $env:HERDR_LOG = $log
        $env:HERDR_CLOSED = $closed
        $env:GH_STATE = $ghState
        $env:GH_REPOSITORY_STATE = $ghRepositoryState
        $env:GIT_DIRTY = '1'
        Set-WorkspaceState $true
        Set-GhState
        Set-WorktreeState @(@{ open_workspace_id = 'bench-12'; path = (Join-Path $fixture 'worktree') })
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -GitHubRepository test/repo -PullRequest 42 -Base main -WhatIf 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'uncommitted changes') { throw 'Cleanup gate must reject a dirty worktree before removal.' }
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -GitHubRepository test/repo -PullRequest 42 -Base main -DiscardAuthorization discard -WhatIf 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'verified merge') { throw 'Cleanup gate must require one completion disposition.' }
        $env:GIT_DIRTY = '0'
        Set-GhState OPEN
        Set-Content -LiteralPath $log -Value ''
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -GitHubRepository test/repo -PullRequest 42 -Base main -WhatIf 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'merge evidence' -or (Get-Content -LiteralPath $log -Raw) -match 'workspace close|worktree remove') { throw 'Cleanup gate must reject mismatched GitHub merge evidence before cleanup.' }
        Set-GhState MERGED main '1111111111111111111111111111111111111111'
        Set-Content -LiteralPath $log -Value ''
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -GitHubRepository test/repo -PullRequest 42 -Base main -WhatIf 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'merge evidence' -or (Get-Content -LiteralPath $log -Raw) -match 'workspace close|worktree remove') { throw 'Cleanup gate must reject a stale PR head before cleanup.' }
        Set-GhState MERGED release
        Set-Content -LiteralPath $log -Value ''
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -GitHubRepository test/repo -PullRequest 42 -Base main -WhatIf 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'merge evidence' -or (Get-Content -LiteralPath $log -Raw) -match 'workspace close|worktree remove') { throw 'Cleanup gate must reject a wrong PR base before cleanup.' }
        Set-GhState
        Set-Content -LiteralPath $ghRepositoryState -Value (@{ nameWithOwner = 'other/repository' } | ConvertTo-Json -Compress)
        Set-Content -LiteralPath $log -Value ''
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -GitHubRepository test/repo -PullRequest 42 -Base main -WhatIf 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'repository does not match' -or (Get-Content -LiteralPath $log -Raw) -match 'workspace close|worktree remove') { throw 'Cleanup gate must reject a mismatched GitHub repository before cleanup.' }
        Set-Content -LiteralPath $ghRepositoryState -Value (@{ nameWithOwner = 'test/repo' } | ConvertTo-Json -Compress)
        Remove-Item -LiteralPath $closed -Force -ErrorAction Ignore
        Set-Content -LiteralPath $log -Value ''
        $env:HERDR_CLOSE_FAILURE = '0'
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -GitHubRepository test/repo -PullRequest 42 -Base main -Confirm:`$false 2>&1
        $calls = Get-Content -LiteralPath $log -Raw
        $finalState = Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0 -or $finalState.result.worktrees.Count -ne 0 -or $calls -notmatch 'workspace close review-7' -or $calls -match 'workspace close bench-12' -or $calls.IndexOf('workspace close review-7') -gt $calls.IndexOf('worktree remove --workspace bench-12 --trust-repository')) { throw 'Cleanup gate must close only CWD-sharing auxiliaries before direct owner removal.' }
        Set-WorktreeState @(@{ open_workspace_id = 'bench-12'; path = (Join-Path $fixture 'worktree') })
        Remove-Item -LiteralPath $closed -Force -ErrorAction Ignore
        Set-Content -LiteralPath $log -Value ''
        $env:HERDR_CLOSE_FAILURE = '1'
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -GitHubRepository test/repo -PullRequest 42 -Base main -Confirm:`$false 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'did not close auxiliary' -or (Get-Content -LiteralPath $log -Raw) -match 'worktree remove') { throw 'Auxiliary close failure must prevent owner removal.' }
    } finally { $env:PATH = $oldPath }
} finally { Remove-Item -LiteralPath $fixture -Recurse -Force }

Write-Host 'Workshop cleanup gate tests passed.'
