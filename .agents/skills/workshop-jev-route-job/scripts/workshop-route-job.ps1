[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('agent', 'skill')][string]$Kind,
    [Parameter(Mandatory)][string]$Assignment,
    [Parameter(Mandatory)][string[]]$AllowedNames,
    [string]$CatalogPath = (Join-Path $PSScriptRoot '../../../../.local/routing-catalog.json'),
    [string]$Endpoint = 'https://api.typesafe.ai/v1/systemone'
)

$ErrorActionPreference = 'Stop'
try {
    $catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json -AsHashtable
    $resources = if ($Kind -eq 'agent') { @($catalog.agents) } else { @($catalog.skills) }
    if (-not $resources.Count -or -not $AllowedNames.Count) { throw 'Catalog or allowed role/capability names are empty.' }
    $options = @{}
    foreach ($resource in $resources) {
        $description = $resource.description
        if ($Kind -eq 'agent') { $description += "`n" + (Get-Content -LiteralPath $resource.path -Raw) }
        $options[$resource.name] = $description
    }
    if ($options.Count -gt 255) { throw 'JEV choice exceeds 255 resources.' }
    $questions = @{ resource = @{ instructions = "Select the available $Kind for the assignment. Required names: $($AllowedNames -join ', '). Respect every role boundary. Assignment: $Assignment"; criteria = $options } }
    $pairs = @{}
    if ($Kind -eq 'agent') {
        foreach ($model in @($catalog.models | Where-Object available)) {
            foreach ($effort in @($model.reasoning)) {
                $rating = @()
                if ($model.ContainsKey('cost')) { $rating += "manual cost rating=$($model.cost)" }
                if ($model.ContainsKey('intelligence')) { $rating += "manual intelligence rating=$($model.intelligence)" }
                if (-not $rating.Count) { $rating = @('manual cost/intelligence unrated') }
                $pairs["$($model.name)/$effort"] = "$($model.description) Reasoning=$effort; $($rating -join '; ')."
            }
        }
        if (-not $pairs.Count -or $pairs.Count -gt 255) { throw 'JEV choice has no supported model/reasoning pair or exceeds 255 pairs.' }
        $questions.model_reasoning = @{ instructions = "For the assignment, select the lowest-cost model and reasoning effort adequate for its complexity. Use manual cost/intelligence ratings where present; do not invent ratings or thresholds. Assignment: $Assignment"; criteria = $pairs }
    }
    $inputJson = @{ state = @{ assignment = $Assignment; requiredNames = $AllowedNames; kind = $Kind }; questions = $questions } | ConvertTo-Json -Depth 20 -Compress
    $script = Join-Path $PSScriptRoot 'workshop-jev-choice.ps1'
    $raw = & $script -InputJson $inputJson -Endpoint $Endpoint 2>&1
    if (-not $?) { throw 'JEV request failed.' }
    $answers = $raw | ConvertFrom-Json -AsHashtable
    $selected = $answers.resource.choice
    if ($selected -notin $AllowedNames -or -not $options.ContainsKey($selected)) { throw 'JEV selected an unavailable or wrong-role resource.' }
    $result = @{ status = 'selected'; kind = $Kind; resource = $selected }
    if ($Kind -eq 'agent') {
        $pair = $answers.model_reasoning.choice
        if (-not $pairs.ContainsKey($pair)) { throw 'JEV selected an unsupported model/reasoning pair.' }
        $model, $reasoning = $pair -split '/', 2
        $result.model = $model
        $result.reasoning = $reasoning
    }
    $result | ConvertTo-Json -Compress
} catch {
    @{ status = 'fallback'; reason = $_.Exception.Message } | ConvertTo-Json -Compress
}
