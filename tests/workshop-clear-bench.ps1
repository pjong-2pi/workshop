$ErrorActionPreference = 'Stop'
$gate = Join-Path (Split-Path -Parent $PSScriptRoot) '.agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) "workshop-clear-bench-test-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $fixture, (Join-Path $fixture 'bin'), (Join-Path $fixture 'repository'), (Join-Path $fixture 'worktree') | Out-Null
$oldPath = $env:PATH
$environmentNames = @('HERDR_STATE', 'HERDR_METADATA', 'HERDR_LOG', 'HERDR_PANES1', 'HERDR_PANES2', 'HERDR_REMOVE_FAILURE', 'HERDR_CLOSE_FAILURE', 'GH_STATE', 'GH_REPOSITORY_STATE', 'GIT_COMMON', 'GIT_DIRTY', 'WORKSHOP_CLEANUP_TEST_ARGS', 'WORKSHOP_CLEANUP_TEST_GATE')
$previousEnvironment = @{}
foreach ($name in $environmentNames) { $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    $state = Join-Path $fixture 'worktrees.json'
    $log = Join-Path $fixture 'calls.log'
    Set-Content -LiteralPath (Join-Path $fixture 'bin/herdr.cmd') -Value @'
@echo off
echo %*>> "%HERDR_LOG%"
if "%1"=="pane" goto pane
if "%1"=="workspace" if "%2"=="get" type "%HERDR_METADATA%"
if "%1"=="workspace" if "%2"=="get" exit /b 0
if "%1"=="workspace" if "%2"=="close" if "%HERDR_CLOSE_FAILURE%"=="1" exit /b 1
if "%1"=="workspace" if "%2"=="close" exit /b 0
if "%1"=="worktree" if "%2"=="list" type "%HERDR_STATE%"
if "%1"=="worktree" if "%2"=="list" exit /b 0
if "%1"=="worktree" if "%2"=="remove" if "%HERDR_REMOVE_FAILURE%"=="1" exit /b 1
if "%1"=="worktree" if "%2"=="remove" > "%HERDR_STATE%" echo {"result":{"worktrees":[]}}
if "%1"=="worktree" if "%2"=="remove" exit /b 0
exit /b 1
:pane
if "%4"=="aux-1" type "%HERDR_PANES1%"
if "%4"=="aux-2" type "%HERDR_PANES2%"
exit /b 0
'@
    Set-Content -LiteralPath (Join-Path $fixture 'bin/git.cmd') -Value @'
@echo off
if "%3"=="status" if "%GIT_DIRTY%"=="1" echo ?? user-file.txt
if "%3"=="status" exit /b 0
if "%4"=="HEAD" echo abc123
if "%4"=="HEAD" exit /b 0
if "%3"=="rev-parse" echo %GIT_COMMON%
if "%3"=="rev-parse" exit /b 0
exit /b 1
'@
    Set-Content -LiteralPath (Join-Path $fixture 'bin/gh.cmd') -Value @'
@echo off
if "%1"=="repo" type "%GH_REPOSITORY_STATE%"
if "%1"=="repo" exit /b 0
type "%GH_STATE%"
exit /b 0
'@
    $env:PATH = "$(Join-Path $fixture 'bin');$oldPath"
    $env:HERDR_STATE = $state
    $env:HERDR_METADATA = Join-Path $fixture 'metadata.json'
    $env:HERDR_LOG = $log
    $env:HERDR_PANES1 = Join-Path $fixture 'panes-1.json'
    $env:HERDR_PANES2 = Join-Path $fixture 'panes-2.json'
    $env:GH_STATE = Join-Path $fixture 'pr.json'
    $env:GH_REPOSITORY_STATE = Join-Path $fixture 'repo.json'
    $env:GIT_COMMON = Join-Path $fixture 'repository/.git'
    Set-Content -LiteralPath $env:HERDR_METADATA -Value (@{ result = @{ workspace = @{ workspace_id = 'bench-12'; worktree = @{ repo_root = (Join-Path $fixture 'repository') } } } } | ConvertTo-Json -Depth 5)
    Set-Content -LiteralPath $env:GH_REPOSITORY_STATE -Value '{"nameWithOwner":"test/repo"}'

    function Reset-State {
        Set-Content -LiteralPath $state -Value (@{ result = @{ worktrees = @(@{ open_workspace_id = 'bench-12'; path = (Join-Path $fixture 'worktree') }) } } | ConvertTo-Json -Depth 4)
        Set-Content -LiteralPath $log -Value ''
        Set-Content -LiteralPath $env:GH_STATE -Value '{"number":42,"state":"MERGED","baseRefName":"main","headRefOid":"abc123"}'
        Set-Content -LiteralPath $env:HERDR_PANES1 -Value (@{ result = @{ panes = @(@{ workspace_id = 'aux-1'; cwd = (Join-Path $fixture 'worktree'); agent = 'codex'; agent_session = 'session-1'; agent_status = 'idle' }) } } | ConvertTo-Json -Depth 5)
        Set-Content -LiteralPath $env:HERDR_PANES2 -Value (@{ result = @{ panes = @(@{ workspace_id = 'aux-2'; cwd = (Join-Path $fixture 'worktree'); agent = 'codex'; agent_session = 'session-2'; agent_status = 'idle' }) } } | ConvertTo-Json -Depth 5)
        $env:GIT_DIRTY = '0'
        $env:HERDR_REMOVE_FAILURE = '0'
        $env:HERDR_CLOSE_FAILURE = '0'
    }
    function Invoke-Gate {
        param([string[]]$AuxiliaryWorkspace, [switch]$Discard, [switch]$WhatIf)
        $parameters = @{ Workspace = 'bench-12'; Repository = (Join-Path $fixture 'repository') }
        if ($Discard) { $parameters.DiscardAuthorization = 'explicit user discard' }
        else { $parameters.GitHubRepository = 'test/repo'; $parameters.PullRequest = '42'; $parameters.Base = 'main' }
        if ($AuxiliaryWorkspace) { $parameters.AuxiliaryWorkspace = @($AuxiliaryWorkspace) }
        if ($WhatIf) { $parameters.WhatIf = $true } else { $parameters.Confirm = $false }
        $env:WORKSHOP_CLEANUP_TEST_ARGS = $parameters | ConvertTo-Json -Compress -Depth 4
        $env:WORKSHOP_CLEANUP_TEST_GATE = $gate
        $output = & pwsh -NoProfile -Command '$parameters = ConvertFrom-Json $env:WORKSHOP_CLEANUP_TEST_ARGS -AsHashtable; & $env:WORKSHOP_CLEANUP_TEST_GATE @parameters' 2>&1
        [PSCustomObject]@{ Code = $LASTEXITCODE; Output = ($output | Out-String); Calls = (Get-Content -LiteralPath $log -Raw) }
    }

    Reset-State
    $env:GIT_DIRTY = '1'
    $result = Invoke-Gate
    if ($result.Code -eq 0 -or $result.Calls -match 'worktree remove') { throw 'Uncommitted user work must prevent removal.' }

    foreach ($pr in @(
        '{"number":42,"state":"OPEN","baseRefName":"main","headRefOid":"abc123"}',
        '{"number":42,"state":"MERGED","baseRefName":"main","headRefOid":"stale"}',
        '{"number":42,"state":"MERGED","baseRefName":"release","headRefOid":"abc123"}'
    )) {
        Reset-State
        Set-Content -LiteralPath $env:GH_STATE -Value $pr
        $result = Invoke-Gate
        if ($result.Code -eq 0 -or $result.Calls -match 'worktree remove') { throw 'Mismatched integration evidence must prevent removal.' }
    }
    Reset-State
    $result = Invoke-Gate -AuxiliaryWorkspace aux-1, aux-2 -WhatIf
    if ($result.Code -ne 0 -or $result.Calls -match 'worktree remove|workspace close') { throw "WhatIf must not mutate Herdr state: $($result.Output)" }

    Reset-State
    $result = Invoke-Gate -AuxiliaryWorkspace aux-1, aux-2
    if ($result.Code -ne 0 -or $result.Calls -notmatch '(?s)workspace close aux-1.*workspace close aux-2.*worktree remove' -or $result.Calls -match '--force') { throw 'Verified integration must close supplied auxiliaries before normal removal.' }

    foreach ($case in @('owner', 'mismatched', 'unrelated', 'active')) {
        Reset-State
        $auxiliary = 'aux-1'
        if ($case -eq 'owner') { $auxiliary = 'bench-12' }
        if ($case -eq 'mismatched') { Set-Content -LiteralPath $env:HERDR_PANES1 -Value (@{ result = @{ panes = @(@{ workspace_id = 'other'; cwd = (Join-Path $fixture 'worktree'); agent = 'codex'; agent_session = 'session-1'; agent_status = 'idle' }) } } | ConvertTo-Json -Depth 5) }
        if ($case -eq 'unrelated') { Set-Content -LiteralPath $env:HERDR_PANES1 -Value (@{ result = @{ panes = @(@{ workspace_id = 'aux-1'; cwd = (Join-Path $fixture 'repository'); agent = 'codex'; agent_session = 'session-1'; agent_status = 'idle' }) } } | ConvertTo-Json -Depth 5) }
        if ($case -eq 'active') { Set-Content -LiteralPath $env:HERDR_PANES1 -Value (@{ result = @{ panes = @(@{ workspace_id = 'aux-1'; cwd = (Join-Path $fixture 'worktree'); agent = 'codex'; agent_session = 'session-1'; agent_status = 'working' }) } } | ConvertTo-Json -Depth 5) }
        $result = Invoke-Gate -AuxiliaryWorkspace $auxiliary
        if ($result.Code -eq 0 -or $result.Calls -match 'workspace close|worktree remove') { throw "$case auxiliary must prevent closure and removal." }
    }

    Reset-State
    $env:HERDR_CLOSE_FAILURE = '1'
    $result = Invoke-Gate -AuxiliaryWorkspace aux-1
    if ($result.Code -eq 0 -or $result.Output -notmatch 'later/manual cleanup' -or @($result.Calls -split '\r?\n' | Where-Object { $_ -match 'workspace close' }).Count -ne 1 -or $result.Calls -match 'worktree remove') { throw 'Auxiliary close failure must be reported without retry or removal.' }

    Reset-State
    $env:HERDR_REMOVE_FAILURE = '1'
    $result = Invoke-Gate -Discard
    if ($result.Code -eq 0 -or $result.Output -notmatch 'later/manual cleanup' -or @($result.Calls -split '\r?\n' | Where-Object { $_ -match 'worktree remove' }).Count -ne 1) { throw 'Tool/OS removal failure must be reported without retry.' }
} finally {
    $env:PATH = $oldPath
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process') }
    if ([IO.Path]::GetFullPath($fixture).StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
Write-Host 'Workshop cleanup tests passed.'
