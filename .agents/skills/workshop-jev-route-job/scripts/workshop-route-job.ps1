[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('agent', 'skill')][string]$Kind,
    [Parameter(Mandatory)][string]$Assignment,
    [Parameter(Mandatory)][string]$Requirements,
    [string]$CatalogPath = (Join-Path $PSScriptRoot '../../../../.local/routing-catalog.json'),
    [string]$Endpoint = 'https://api.typesafe.ai/v1/systemone'
)

$ErrorActionPreference = 'Stop'
try {
    $catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json -AsHashtable
    $resources = if ($Kind -eq 'agent') { @($catalog.agents) } else { @($catalog.skills) }
    if (-not $resources.Count) { throw 'Catalog resources are empty.' }
    $options = @{}
    foreach ($resource in $resources) {
        $description = $resource.description
        if ($Kind -eq 'agent') {
            $delegatable = if ($resource.ContainsKey('delegatable')) { $resource.delegatable } else { $true }
            $description += "`nDelegatable: $delegatable`n" + (Get-Content -LiteralPath $resource.path -Raw)
        }
        $options[$resource.name] = $description
    }
    $questions = @{ resource = @{ instructions = "Select the available $Kind that satisfies state.requirements for state.assignment. Respect every supplied role boundary; select resources yourself without assuming a preferred identity."; criteria = $options } }
    if ($Kind -eq 'agent') {
        $questions.resource.instructions += ' Agents marked Delegatable: False are never eligible as delegated workers. Select a delegatable agent whose role and capabilities satisfy the assignment.'
    }
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
        $questions.model_reasoning = @{ instructions = 'For state.assignment and state.requirements, select the lowest-cost model and reasoning effort adequate for its complexity. Use manual cost/intelligence ratings where present; do not invent ratings or thresholds.'; criteria = $pairs }
    }
    $inputJson = @{ state = @{ assignment = $Assignment; requirements = $Requirements; kind = $Kind }; questions = $questions } | ConvertTo-Json -Depth 20 -Compress
    $script = Join-Path $PSScriptRoot 'workshop-jev-choice.ps1'
    $raw = & $script -InputJson $inputJson -Endpoint $Endpoint 2>&1
    if (-not $?) { throw ($raw -join [Environment]::NewLine) }
    $answers = $raw | ConvertFrom-Json -AsHashtable
    $selected = $answers.resource.choice
    if ($Kind -eq 'agent' -and @($resources | Where-Object { $_.name -eq $selected -and $_.delegatable -eq $false }).Count) {
        throw "Unusable agent choice: $selected is not delegatable."
    }
    $result = @{ status = 'selected'; kind = $Kind; resource = $selected }
    if ($Kind -eq 'agent') {
        $pair = $answers.model_reasoning.choice
        $model, $reasoning = $pair -split '/', 2
        $result.model = $model
        $result.reasoning = $reasoning
    }
    $result | ConvertTo-Json -Compress
} catch {
    @{ status = 'fallback'; reason = $_.Exception.Message } | ConvertTo-Json -Compress
}
