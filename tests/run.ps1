$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

function New-Fixture {
    param([bool] $EnvironmentReady)

    $path = Join-Path ([System.IO.Path]::GetTempPath()) "workshop-setup-test-$([guid]::NewGuid())"
    $scripts = Join-Path $path 'scripts'
    $bin = Join-Path $path 'bin'
    New-Item -ItemType Directory -Path $scripts, $bin | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'scripts/setup.ps1') -Destination $scripts
    $exitCode = if ($EnvironmentReady) { 0 } else { 1 }
    Set-Content -LiteralPath (Join-Path $scripts 'check-environment.ps1') -Value "exit $exitCode"
    Set-Content -LiteralPath (Join-Path $bin 'herdr.cmd') -Value "@echo off`r`necho codex: current`r`nexit /b 0"
    return $path
}

function Invoke-FixtureSetup {
    param([string] $Fixture)

    $oldPath = $env:PATH
    try {
        $env:PATH = "$(Join-Path $Fixture 'bin');$oldPath"
        $output = & pwsh -NoProfile -File (Join-Path $Fixture 'scripts/setup.ps1') 2>&1
        return [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    } finally {
        $env:PATH = $oldPath
    }
}

function Use-Fixture {
    param([bool] $EnvironmentReady, [scriptblock] $Test)

    $fixture = New-Fixture $EnvironmentReady
    try { & $Test $fixture } finally { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

Use-Fixture $true {
    param($fixture)
    New-Item -ItemType Directory -Path (Join-Path $fixture '.git') | Out-Null
    Set-Content -LiteralPath (Join-Path $fixture '.git/repository-sentinel') -Value 'unrelated repository content'
    $result = Invoke-FixtureSetup $fixture
    Assert-True ($result.ExitCode -eq 0) 'Fresh setup must succeed with ready prerequisites.'
    Assert-True (Test-Path -LiteralPath (Join-Path $fixture 'projects') -PathType Container) 'Fresh setup must create projects.'
    Assert-True (Test-Path -LiteralPath (Join-Path $fixture '.local/setup-complete') -PathType Leaf) 'Fresh setup must create its marker.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $fixture '.git/repository-sentinel') -Raw) -eq 'unrelated repository content' + [Environment]::NewLine) 'Setup must preserve unrelated repository content.'
}

Use-Fixture $true {
    param($fixture)
    New-Item -ItemType Directory -Path (Join-Path $fixture 'projects') | Out-Null
    Set-Content -LiteralPath (Join-Path $fixture 'projects/keep.txt') -Value 'project content'
    New-Item -ItemType Directory -Path (Join-Path $fixture '.local') | Out-Null
    Set-Content -LiteralPath (Join-Path $fixture '.local/keep.txt') -Value 'local content'
    $first = Invoke-FixtureSetup $fixture
    $second = Invoke-FixtureSetup $fixture
    Assert-True ($first.ExitCode -eq 0 -and $second.ExitCode -eq 0) 'Setup must be idempotent.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $fixture 'projects/keep.txt') -Raw) -eq 'project content' + [Environment]::NewLine) 'Setup must preserve project content.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $fixture '.local/keep.txt') -Raw) -eq 'local content' + [Environment]::NewLine) 'Setup must preserve local content.'
    Assert-True ((Get-ChildItem -LiteralPath (Join-Path $fixture '.local') -Filter setup-complete).Count -eq 1) 'Setup must not duplicate its marker.'
}

Use-Fixture $false {
    param($fixture)
    $result = Invoke-FixtureSetup $fixture
    Assert-True ($result.ExitCode -ne 0) 'Failed required verification must fail setup.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixture '.local/setup-complete') -PathType Leaf)) 'Failed verification must not create a valid marker.'
}

& (Join-Path $PSScriptRoot 'validate.ps1')
& (Join-Path $PSScriptRoot 'workshop-clear-bench.ps1')
& (Join-Path $PSScriptRoot 'jev-choose.ps1')
& (Join-Path $PSScriptRoot 'workshop-stocktake.ps1')
Write-Host 'Workshop deterministic tests passed.'
