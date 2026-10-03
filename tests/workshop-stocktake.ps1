$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root '.agents/skills/workshop-stocktake/scripts/update-model-catalog.ps1'
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) "workshop-stocktake-test-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    $bin = Join-Path $fixture 'bin'
    New-Item -ItemType Directory -Path $bin | Out-Null
    Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value "@echo off`r`npwsh -NoProfile -File `"$(Join-Path $bin 'codex.ps1')`" %*`r`n"
    Set-Content -LiteralPath (Join-Path $bin 'codex.ps1') -Value @'
param()
if ($args[0] -eq '--version') { 'codex-cli test'; exit 0 }
$initialize = $input | Select-Object -First 1 | ConvertFrom-Json
if ($initialize.method -ne 'initialize') { throw 'initialize required' }
'{"id":1,"result":{}}'
$initialized = $input | Select-Object -First 1 | ConvertFrom-Json
if ($initialized.method -ne 'initialized') { throw 'initialized notification required' }
$first = $input | Select-Object -First 1 | ConvertFrom-Json
if ($first.method -ne 'model/list') { throw 'model/list required after initialized' }
if ($env:STOCKTAKE_TEST_MODE -eq 'malformed') { '{"id":2,"result":{"nextCursor":null}}'; exit 0 }
if ($env:STOCKTAKE_TEST_MODE -eq 'missing-cursor') { '{"id":2,"result":{"data":[{"id":"model-c"}]}}'; exit 0 }
'{"id":2,"result":{"data":[{"id":"model-b","inputModalities":["text"],"supportedReasoningEfforts":[{"reasoningEffort":"low"}]},{"id":"model-c"}],"nextCursor":"second"}}'
$second = $input | Select-Object -First 1 | ConvertFrom-Json
if ($second.params.cursor -ne 'second') { throw 'pagination cursor required' }
'{"id":2,"result":{"data":[{"id":"model-a","provider":"observed provider","pricing":"observed pricing","contextWindow":"observed context","displayName":"Observed name","description":"Observed description","defaultReasoningEffort":"medium","inputModalities":["text","image"],"supportedReasoningEfforts":[{"reasoningEffort":"medium"}],"multiAgentVersion":"v1","defaultServiceTier":"priority","modelSpecialty":"coding","isDefault":true}],"nextCursor":null}}'
'@
    $catalog = Join-Path $fixture 'models.md'
    & pwsh -NoProfile -File $script -CatalogPath $catalog -CodexCommand (Join-Path $bin 'codex.cmd')
    if ($LASTEXITCODE -ne 0) { throw 'Stocktake must complete the required handshake and pagination.' }
    $first = Get-Content -LiteralPath $catalog -Raw
    if ($first -notmatch '\| model-a \| Observed description \| medium \| medium \|') { throw 'Stocktake must retain the observed description, default reasoning, and supported efforts.' }
    if ($first -notmatch '\| model-b \| unknown \| unknown \| low \|') { throw 'Stocktake must retain observed supported reasoning efforts.' }
    if ($first -notmatch '\| model-c \| unknown \| unknown \| unknown \|') { throw 'Stocktake must render absent compact fields as unknown.' }
    if ($first.IndexOf('model-a') -gt $first.IndexOf('model-b')) { throw 'Stocktake must sort model rows deterministically.' }
    & pwsh -NoProfile -File $script -CatalogPath $catalog -CodexCommand (Join-Path $bin 'codex.cmd')
    if ((Get-Content -LiteralPath $catalog -Raw) -ne $first) { throw 'Unchanged inventory must not rewrite its timestamp.' }
    $oldMode = $env:STOCKTAKE_TEST_MODE
    try {
        foreach ($mode in @('malformed', 'missing-cursor')) {
            $env:STOCKTAKE_TEST_MODE = $mode
            & pwsh -NoProfile -File $script -CatalogPath $catalog -CodexCommand (Join-Path $bin 'codex.cmd') 2>$null
            if ($LASTEXITCODE -eq 0) { throw "$mode model/list data must fail discovery." }
            if ((Get-Content -LiteralPath $catalog -Raw) -ne $first) { throw 'Failed discovery must preserve the prior catalog byte-for-byte.' }
        }
    } finally { $env:STOCKTAKE_TEST_MODE = $oldMode }
} finally { Remove-Item -LiteralPath $fixture -Recurse -Force }

Write-Host 'Workshop stocktake tests passed.'
