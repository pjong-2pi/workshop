[CmdletBinding()]
param(
    [string] $CatalogPath,
    [string] $CodexCommand = 'codex'
)

$ErrorActionPreference = 'Stop'

function ConvertTo-Cell([object] $Value) {
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string] $Value)) { return 'unknown' }
    ([string] $Value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

function Invoke-CodexRequest([System.Diagnostics.Process] $Process, [int] $Id, [string] $Method, [object] $Params) {
    $request = @{ id = $Id; method = $Method; params = $Params } | ConvertTo-Json -Compress -Depth 8
    $Process.StandardInput.WriteLine($request)
    while (-not $Process.HasExited) {
        $line = $Process.StandardOutput.ReadLine()
        if ($null -eq $line) { break }
        $response = $line | ConvertFrom-Json -ErrorAction Stop
        if ($response.id -eq $Id) {
            if ($null -ne $response.error) { throw "Codex $Method failed: $($response.error.message)" }
            return $response.result
        }
    }
    throw "Codex closed before responding to $Method."
}

function Get-CodexModels([string] $Command) {
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Command
    $start.Arguments = 'app-server --stdio'
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'Could not start Codex app-server.' }
    try {
        Invoke-CodexRequest $process 1 'initialize' @{ clientInfo = @{ name = 'workshop-stocktake'; version = '1' } } | Out-Null
        $models = @()
        $cursor = $null
        do {
            $page = Invoke-CodexRequest $process 2 'model/list' @{ cursor = $cursor; includeHidden = $false; limit = 100 }
            $models += @($page.data)
            $cursor = $page.nextCursor
        } while (-not [string]::IsNullOrWhiteSpace($cursor))
        return $models
    } finally {
        if (-not $process.HasExited) { $process.Kill() }
        $process.Dispose()
    }
}

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
if ([string]::IsNullOrWhiteSpace($CatalogPath)) { $CatalogPath = Join-Path $root 'catalog/models.md' }
$version = (& $CodexCommand --version 2>$null | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($version)) { throw 'Codex version discovery failed.' }
$models = Get-CodexModels $CodexCommand | Sort-Object { $_.id }

$rows = foreach ($model in $models) {
    $capabilities = @()
    if ($model.inputModalities) { $capabilities += "input: $($model.inputModalities -join ', ')" }
    if ($model.supportedReasoningEfforts) { $capabilities += "reasoning: $(($model.supportedReasoningEfforts | ForEach-Object reasoningEffort) -join ', ')" }
    if ($null -ne $model.multiAgentVersion) { $capabilities += "multi-agent: $($model.multiAgentVersion)" }
    if ($model.serviceTiers) { $capabilities += "tiers: $(($model.serviceTiers | ForEach-Object id) -join ', ')" }
    "| $(ConvertTo-Cell $model.id) | OpenAI | available to current Codex account | unknown | unknown | $(ConvertTo-Cell ($capabilities -join '; ')) | Codex app-server `model/list` |"
}
if (-not $rows) { $rows = '| none returned | unknown | none returned by current Codex account | unknown | unknown | unknown | Codex app-server `model/list` |' }

$body = @(
    '# Workshop model catalog'
    ''
    'Observed inventory for Workshop. It is not model-selection policy.'
    ''
    "Source: Codex app-server `model/list` via $version."
    ''
    '## Models'
    ''
    '| Model | Provider | Availability | Pricing | Context limit | Relevant characteristics | Source |'
    '|---|---|---|---|---|---|---|'
    $rows
) -join "`n"
$checked = [DateTime]::UtcNow.ToString('o')
$next = "$body`n`nLast checked (UTC): $checked`n"
if (Test-Path -LiteralPath $CatalogPath -PathType Leaf) {
    $current = Get-Content -LiteralPath $CatalogPath -Raw
    if (($current -replace 'Last checked \(UTC\): .+\r?\n?$', '') -eq ($next -replace 'Last checked \(UTC\): .+\r?\n?$', '')) {
        Write-Host "Unchanged model catalog: $CatalogPath"
        exit 0
    }
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $CatalogPath) | Out-Null
Set-Content -LiteralPath $CatalogPath -Value $next -NoNewline
Write-Host "Updated model catalog: $CatalogPath"
