[CmdletBinding()]
param(
    [switch] $InstallCodexIntegration
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$projects = Join-Path $root 'projects'
$local = Join-Path $root '.local'
$marker = Join-Path $local 'setup-complete'

Write-Host "Workshop root: $root"
Write-Host "Initialization state: $(if (Test-Path -LiteralPath $marker -PathType Leaf) { 'complete' } else { 'not initialized' })"

foreach ($path in @($projects, $local)) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        throw "Required directory path is occupied by a file: $path"
    }
    if (Test-Path -LiteralPath $path -PathType Container) {
        Write-Host "Unchanged directory: $path"
    } else {
        New-Item -ItemType Directory -Path $path | Out-Null
        Write-Host "Created directory: $path"
    }
}

Write-Host 'Persistent Workshop environment variables: none required.'
Write-Host 'Herdr supplies HERDR_ENV and related values to managed processes.'

if ($InstallCodexIntegration) {
    foreach ($name in @('codex', 'herdr')) {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
            throw "Cannot configure the Codex integration because $name is not installed."
        }
    }
}

$check = Join-Path $PSScriptRoot 'check-environment.ps1'
& $check
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Workshop setup is incomplete; resolve the reported prerequisites and rerun setup.'
    exit $LASTEXITCODE
}

$integrationOutput = @(herdr integration status 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect Herdr integrations: $($integrationOutput -join [Environment]::NewLine)"
}
$codexIntegration = $integrationOutput |
    ForEach-Object { $_.ToString() } |
    Where-Object { $_ -match '^codex:' } |
    Select-Object -First 1
if (-not $codexIntegration) {
    throw 'Herdr did not report a Codex integration state.'
}

if ($codexIntegration -notmatch '^codex: current') {
    if ($InstallCodexIntegration) {
        herdr integration install codex
        if ($LASTEXITCODE -ne 0) { throw 'Herdr could not install the Codex integration.' }
        $codexIntegration = @(herdr integration status 2>&1) |
            ForEach-Object { $_.ToString() } |
            Where-Object { $_ -match '^codex:' } |
            Select-Object -First 1
        if ($codexIntegration -notmatch '^codex: current') {
            throw "Codex integration verification failed: $codexIntegration"
        }
        Write-Host 'Configured Codex/Herdr integration.'
    } else {
        Write-Host "Optional Codex/Herdr integration: $codexIntegration"
        Write-Host 'Explicit authorization is required before using -InstallCodexIntegration.'
    }
} else {
    Write-Host "Codex/Herdr integration: $codexIntegration"
}

if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
    New-Item -ItemType File -Path $marker | Out-Null
    Write-Host "Created initialization marker: $marker"
} else {
    Write-Host "Unchanged initialization marker: $marker"
}

if (-not (Test-Path -LiteralPath $projects -PathType Container) -or
    -not (Test-Path -LiteralPath $marker -PathType Leaf)) {
    throw 'Workshop setup verification failed.'
}

Write-Host 'Workshop setup is complete.'
