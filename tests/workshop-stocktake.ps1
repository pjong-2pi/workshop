$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root '.agents/skills/workshop-stocktake/scripts/update-model-catalog.ps1'
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) "workshop-stocktake-test-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    $bin = Join-Path $fixture 'bin'
    New-Item -ItemType Directory -Path $bin | Out-Null
    Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value @(
        '@echo off',
        'if "%1"=="--version" echo codex-cli test',
        'if "%1"=="--version" exit /b 0',
        'echo {"id":1,"result":{}}',
        'echo {"id":2,"result":{"data":[{"id":"model-b","inputModalities":["text"],"supportedReasoningEfforts":[{"reasoningEffort":"low"}]},{"id":"model-a","inputModalities":["text","image"],"supportedReasoningEfforts":[{"reasoningEffort":"medium"}],"multiAgentVersion":"v1"}],"nextCursor":null}}',
        'more > nul'
    )
    $catalog = Join-Path $fixture 'models.md'
    $version = & (Join-Path $bin 'codex.cmd') --version
    if ($LASTEXITCODE -ne 0 -or $version -ne 'codex-cli test') { throw 'Fake Codex version command is invalid.' }
    & pwsh -NoProfile -File $script -CatalogPath $catalog -CodexCommand (Join-Path $bin 'codex.cmd')
    if ($LASTEXITCODE -ne 0) { throw 'Stocktake must succeed with a valid Codex model response.' }
    $first = Get-Content -LiteralPath $catalog -Raw
    if ($first -notmatch '\| model-a \| OpenAI \| available to current Codex account \| unknown \| unknown \| input: text, image; reasoning: medium; multi-agent: v1 \|') { throw 'Stocktake must render discovered metadata and explicit unknowns.' }
    if ($first.IndexOf('model-a') -gt $first.IndexOf('model-b')) { throw 'Stocktake must sort model rows deterministically.' }
    Start-Sleep -Milliseconds 20
    & pwsh -NoProfile -File $script -CatalogPath $catalog -CodexCommand (Join-Path $bin 'codex.cmd')
    if ((Get-Content -LiteralPath $catalog -Raw) -ne $first) { throw 'Unchanged inventory must not rewrite its timestamp.' }
} finally { Remove-Item -LiteralPath $fixture -Recurse -Force }

Write-Host 'Workshop stocktake tests passed.'
