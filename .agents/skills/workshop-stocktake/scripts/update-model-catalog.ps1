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

function Send-CodexNotification([System.Diagnostics.Process] $Process, [string] $Method, [object] $Params) {
    $Process.StandardInput.WriteLine((@{ method = $Method; params = $Params } | ConvertTo-Json -Compress -Depth 8))
}

function Get-Property([object] $Object, [string] $Name) {
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    $property.Value
}

function Assert-ModelPage([object] $Page) {
    if ($null -eq $Page -or $null -eq $Page.PSObject.Properties['data'] -or
        $Page.data -is [string] -or $Page.data -isnot [System.Collections.IEnumerable]) {
        throw 'Codex model/list returned an invalid data page.'
    }
    if ($null -eq $Page.PSObject.Properties['nextCursor']) {
        throw 'Codex model/list omitted its pagination cursor.'
    }
    if ($null -ne $Page.nextCursor -and $Page.nextCursor -isnot [string]) {
        throw 'Codex model/list returned an invalid pagination cursor.'
    }
    foreach ($model in @($Page.data)) {
        if ($null -eq $model -or $null -eq $model.PSObject.Properties['id'] -or [string]::IsNullOrWhiteSpace([string] $model.id)) {
            throw 'Codex model/list returned a model without an id.'
        }
    }
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
        Send-CodexNotification $process 'initialized' @{}
        $models = @()
        $cursor = $null
        $seenCursors = [System.Collections.Generic.HashSet[string]]::new()
        do {
            $page = Invoke-CodexRequest $process 2 'model/list' @{ cursor = $cursor; includeHidden = $false; limit = 100 }
            Assert-ModelPage $page
            $models += @($page.data)
            $cursor = Get-Property $page 'nextCursor'
            if (-not [string]::IsNullOrWhiteSpace($cursor) -and -not $seenCursors.Add($cursor)) { throw 'Codex model/list repeated a pagination cursor.' }
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
    if (Get-Property $model 'displayName') { $capabilities += "name: $(Get-Property $model 'displayName')" }
    if (Get-Property $model 'description') { $capabilities += "description: $(Get-Property $model 'description')" }
    if ($model.inputModalities) { $capabilities += "input: $($model.inputModalities -join ', ')" }
    if (Get-Property $model 'defaultReasoningEffort') { $capabilities += "default reasoning: $(Get-Property $model 'defaultReasoningEffort')" }
    if ($model.supportedReasoningEfforts) { $capabilities += "reasoning: $(($model.supportedReasoningEfforts | ForEach-Object reasoningEffort) -join ', ')" }
    if (Get-Property $model 'defaultServiceTier') { $capabilities += "default tier: $(Get-Property $model 'defaultServiceTier')" }
    if ($null -ne $model.multiAgentVersion) { $capabilities += "multi-agent: $($model.multiAgentVersion)" }
    if ($model.serviceTiers) { $capabilities += "tiers: $(($model.serviceTiers | ForEach-Object id) -join ', ')" }
    if (Get-Property $model 'modelSpecialty') { $capabilities += "specialty: $(Get-Property $model 'modelSpecialty')" }
    if (Get-Property $model 'availableAccessPrograms') { $capabilities += "access: $((Get-Property $model 'availableAccessPrograms' | ConvertTo-Json -Compress))" }
    if ($true -eq (Get-Property $model 'isDefault')) { $capabilities += 'default' }
    if ($true -eq (Get-Property $model 'hidden')) { $capabilities += 'hidden' }
    $provider = ConvertTo-Cell (Get-Property $model 'provider')
    "| $(ConvertTo-Cell $model.id) | $provider | available to current Codex account | $(ConvertTo-Cell (Get-Property $model 'pricing')) | $(ConvertTo-Cell (Get-Property $model 'contextWindow')) | $(ConvertTo-Cell ($capabilities -join '; ')) | Codex app-server `model/list` |"
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
