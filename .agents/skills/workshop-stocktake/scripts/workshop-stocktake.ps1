[CmdletBinding()]
param(
    [string]$WorkshopRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path,
    [Parameter(Mandatory)][string]$SessionSkillsJson,
    [string]$CatalogPath
)

$ErrorActionPreference = 'Stop'
try {
    $WorkshopRoot = [System.IO.Path]::GetFullPath($WorkshopRoot)
    if (-not $CatalogPath) { $CatalogPath = Join-Path $WorkshopRoot '.local/routing-catalog.json' }
    $CatalogPath = [System.IO.Path]::GetFullPath($CatalogPath)
    $previous = if (Test-Path -LiteralPath $CatalogPath) { Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json -AsHashtable } else { @{} }

    $agents = @()
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $WorkshopRoot '.agents/agents') -Filter '*.md' -File)) {
        $body = Get-Content -LiteralPath $file.FullName -Raw
        $meta = [regex]::Match($body, '(?s)\A---\r?\n(.*?)\r?\n---')
        if (-not $meta.Success) { throw "Missing agent metadata: $($file.Name)" }
        $name = [regex]::Match($meta.Groups[1].Value, '(?m)^name:\s*(.+)$').Groups[1].Value.Trim()
        $description = [regex]::Match($meta.Groups[1].Value, '(?m)^description:\s*(.+)$').Groups[1].Value.Trim()
        if (-not $name -or -not $description) { throw "Incomplete agent metadata: $($file.Name)" }
        $agents += @{ name = $name; description = $description; path = $file.FullName }
    }
    if (-not $agents.Count) { throw 'No Workshop agents found.' }

    $sessionSkills = @(ConvertFrom-Json -InputObject $SessionSkillsJson -AsHashtable)
    if (-not $sessionSkills.Count) { throw 'Session skill metadata is empty.' }
    $skills = @($sessionSkills)
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $WorkshopRoot '.agents/skills') -Filter 'SKILL.md' -Recurse -File)) {
        $body = Get-Content -LiteralPath $file.FullName -Raw
        $meta = [regex]::Match($body, '(?s)\A---\r?\n(.*?)\r?\n---')
        if (-not $meta.Success) { throw "Missing skill metadata: $($file.FullName)" }
        $name = [regex]::Match($meta.Groups[1].Value, '(?m)^name:\s*(.+)$').Groups[1].Value.Trim()
        $description = [regex]::Match($meta.Groups[1].Value, '(?m)^description:\s*(.+)$').Groups[1].Value.Trim()
        if (-not $name -or -not $description) { throw "Incomplete skill metadata: $($file.FullName)" }
        if ($name -notin @($skills | ForEach-Object name)) { $skills += @{ name = $name; description = $description; path = $file.FullName } }
    }
    foreach ($skill in $skills) {
        if (-not $skill.name -or -not $skill.description -or -not $skill.path) { throw 'Session skill metadata requires name, description, and path.' }
    }

    $raw = & codex debug models 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Native Codex model discovery failed.' }
    $native = ($raw | ConvertFrom-Json -AsHashtable).models
    $models = @()
    foreach ($model in @($native | Where-Object { $_.visibility -eq 'list' })) {
        $efforts = @($model.supported_reasoning_levels | ForEach-Object effort)
        if (-not $model.slug -or -not $efforts.Count) { throw 'Native model metadata is incomplete.' }
        $entry = @{ name = $model.slug; description = $model.description; reasoning = $efforts; available = $true }
        $old = @($previous.models | Where-Object { $_ -and $_.name -eq $model.slug } | Select-Object -First 1)
        foreach ($rating in @('cost', 'intelligence')) {
            if ($old.Count -and $old[0].ContainsKey($rating) -and $null -ne $old[0][$rating]) {
                if ($old[0][$rating] -isnot [byte] -and $old[0][$rating] -isnot [int] -and $old[0][$rating] -isnot [long] -and $old[0][$rating] -isnot [double] -and $old[0][$rating] -isnot [decimal]) { throw "Model $($model.slug) has nonnumeric $rating." }
                $entry[$rating] = $old[0][$rating]
            }
        }
        $models += $entry
    }
    if (-not $models.Count) { throw 'Native Codex returned no selectable models.' }
    foreach ($old in @($previous.models | Where-Object { $_ -and $_.name -notin @($models | ForEach-Object name) })) {
        $absent = @{ name = $old.name; available = $false }
        foreach ($rating in @('cost', 'intelligence')) { if ($old.ContainsKey($rating)) { $absent[$rating] = $old[$rating] } }
        $models += $absent
    }
    $catalog = @{ agents = $agents; skills = $skills; models = $models; refreshedAt = (Get-Date).ToUniversalTime().ToString('o') }
    $parent = Split-Path -Parent $CatalogPath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temp = Join-Path $parent ('.routing-catalog-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $catalog | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temp -Encoding utf8
        Move-Item -LiteralPath $temp -Destination $CatalogPath -Force
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
    "PASS: $($agents.Count) agents, $($skills.Count) skills, $(@($models | Where-Object available).Count) selectable models; $CatalogPath"
} catch {
    $state = if ($CatalogPath -and (Test-Path -LiteralPath $CatalogPath)) { 'previous catalog retained' } else { 'catalog unavailable' }
    [Console]::Error.WriteLine("Stocktake failed; ${state}: $($_.Exception.Message)")
    exit 1
}
