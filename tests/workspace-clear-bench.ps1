$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$gate = Join-Path $root '.agents/skills/workspace-clear-bench/scripts/remove-workspace.ps1'
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) "workspace-clear-bench-test-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $fixture, (Join-Path $fixture 'bin'), (Join-Path $fixture 'repository'), (Join-Path $fixture 'worktree') | Out-Null
try {
    $state = Join-Path $fixture 'herdr-state.txt'
    $log = Join-Path $fixture 'herdr.log'
    $gitCalls = Join-Path $fixture 'git-calls.txt'
    Set-Content -LiteralPath (Join-Path $fixture 'bin/herdr.cmd') -Value @'
@echo off
echo %*>> "%HERDR_LOG%"
if "%2"=="remove" > "%HERDR_STATE%" echo {"id":"cli:worktree:list","result":{"source":{},"type":"worktree_list","worktrees":[]}}
type "%HERDR_STATE%"
exit /b 0
'@
    Set-Content -LiteralPath (Join-Path $fixture 'bin/git.cmd') -Value "@echo off`r`necho  M changed.txt`r`nexit /b 0"
    $oldPath = $env:PATH
    try {
        function Set-WorktreeState([object[]]$Worktrees) {
            Set-Content -LiteralPath $state -Value (@{ id = 'cli:worktree:list'; result = @{ source = @{}; type = 'worktree_list'; worktrees = $Worktrees } } | ConvertTo-Json -Compress -Depth 4)
        }
        $env:PATH = "$(Join-Path $fixture 'bin');$oldPath"
        $env:HERDR_STATE = $state
        $env:HERDR_LOG = $log
        $env:GIT_CALLS = $gitCalls
        Set-WorktreeState @(@{ open_workspace_id = 'bench-12'; path = (Join-Path $fixture 'worktree') })
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -WorktreePath (Join-Path $fixture 'worktree') -IntegrationEvidence integrated -RemovalAuthorization now -WhatIf 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'uncommitted changes') { throw 'Cleanup gate must reject a dirty worktree before removal.' }
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -WorktreePath (Join-Path $fixture 'worktree') -IntegrationEvidence integrated -DiscardAuthorization discard -RemovalAuthorization now -WhatIf 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'exactly one') { throw 'Cleanup gate must require one completion disposition.' }
        Set-Content -LiteralPath (Join-Path $fixture 'bin/git.cmd') -Value "@echo off`r`nexit /b 0"
        Set-Content -LiteralPath $state -Value (@{ worktrees = @(@{ open_workspace_id = 'bench-12'; path = (Join-Path $fixture 'worktree') }) } | ConvertTo-Json -Compress)
        Set-Content -LiteralPath $log -Value ''
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -WorktreePath (Join-Path $fixture 'worktree') -IntegrationEvidence integrated -RemovalAuthorization now -WhatIf 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'inconsistent' -or (Get-Content -LiteralPath $log -Raw) -match 'worktree remove') { throw 'Cleanup gate must reject top-level worktrees instead of parsing the Herdr result wrapper.' }
        Set-WorktreeState @(@{ open_workspace_id = 'bench-12'; path = (Join-Path $fixture 'repository') })
        Set-Content -LiteralPath $log -Value ''
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -WorktreePath (Join-Path $fixture 'worktree') -IntegrationEvidence integrated -RemovalAuthorization now -WhatIf 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'does not match' -or (Get-Content -LiteralPath $log -Raw) -match 'worktree remove') { throw 'Cleanup gate must reject an ID/path mismatch before removal.' }
        Set-WorktreeState @(@{ open_workspace_id = 'bench-12'; path = (Join-Path $fixture 'worktree') })
        Set-Content -LiteralPath $gitCalls -Value '0'
        Set-Content -LiteralPath (Join-Path $fixture 'bin/git.cmd') -Value @'
@echo off
set /p calls=<"%GIT_CALLS%"
set /a calls=%calls%+1
echo %calls%>"%GIT_CALLS%"
if %calls% GEQ 2 echo  M changed.txt
exit /b 0
'@
        Set-Content -LiteralPath $log -Value ''
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -WorktreePath (Join-Path $fixture 'worktree') -IntegrationEvidence integrated -RemovalAuthorization now -Confirm:`$false 2>&1
        if ($LASTEXITCODE -eq 0 -or ($result | Out-String) -notmatch 'uncommitted changes' -or (Get-Content -LiteralPath $log -Raw) -match 'worktree remove') { throw 'Cleanup gate must recheck cleanliness immediately before removal.' }
        Set-Content -LiteralPath (Join-Path $fixture 'bin/git.cmd') -Value "@echo off`r`nexit /b 0"
        $result = & pwsh -NoProfile -File $gate -Workspace bench-12 -Repository (Join-Path $fixture 'repository') -WorktreePath (Join-Path $fixture 'worktree') -IntegrationEvidence integrated -RemovalAuthorization now -Confirm:`$false 2>&1
        $finalState = Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0 -or $finalState.result.worktrees.Count -ne 0 -or (Get-Content -LiteralPath $log -Raw) -notmatch 'worktree remove --workspace bench-12 --trust-repository') { throw 'Cleanup gate must remove only the recorded clean workspace and verify its absence.' }
    } finally { $env:PATH = $oldPath }
} finally { Remove-Item -LiteralPath $fixture -Recurse -Force }

Write-Host 'Workspace cleanup gate tests passed.'
