$ErrorActionPreference = 'Stop'
$beforeImport = $ErrorActionPreference
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/jev-routing.ps1')

function Assert-True { param([bool] $Condition, [string] $Message) if (-not $Condition) { throw $Message } }
Assert-True ($ErrorActionPreference -eq $beforeImport) 'Importing JEV routing must not change caller error handling.'
function New-Response([double] $Confidence = 0.9, [string] $Agent = 'inspector', [string] $Model = 'gpt-5.6-luna') { [PSCustomObject]@{ model = 'jev-1.13.0'; answers = [PSCustomObject]@{
    skill = [PSCustomObject]@{ type = 'choice'; choice = 'github-check-pr'; confidence = $Confidence; probabilities = @{} }
    agent = [PSCustomObject]@{ type = 'choice'; choice = $Agent; confidence = $Confidence; probabilities = @{} }
    model = [PSCustomObject]@{ type = 'choice'; choice = $Model; confidence = $Confidence; probabilities = @{} }
    delegate = [PSCustomObject]@{ type = 'choice'; choice = 'true'; confidence = $Confidence; probabilities = @{} }
}; usage = [PSCustomObject]@{ input_tokens = 12; output_tokens = 3 } } }

$root = Join-Path ([IO.Path]::GetTempPath()) "workshop-jev-test-$([guid]::NewGuid())"
try {
    $context = 'intent=review;scope=pr;risk=routine;effort=substantive'
    $good = Get-WorkshopJevDecision -RoutingContext $context -Root $root -Request { param($body) New-Response }
    Assert-True ($good.source -eq 'jev' -and $good.skill -eq 'github-check-pr' -and $good.model -eq 'gpt-5.6-luna' -and $good.delegate) 'Valid high-confidence response must be accepted.'
    $withoutMetadata = Get-WorkshopJevDecision -RoutingContext $context -Root $root -Request { param($body) $response = New-Response; $response.PSObject.Properties.Remove('model'); $response }
    Assert-True ($withoutMetadata.source -eq 'jev' -and $withoutMetadata.skill -eq 'github-check-pr') 'Valid high-confidence response without optional model metadata must be accepted.'
    Complete-WorkshopJevTelemetry -Root $root -RoutingId $withoutMetadata.routing_id -FinalRoute github-check-pr -FinalDelegation $true -FinalModel gpt-5.6-luna -Outcome completed -BaselineActualTotalTokens 120 -ProjectedJevRouteTokens 100 -DownstreamTaskLatencyMs 42
    Complete-WorkshopJevTelemetry -Root $root -RoutingId $withoutMetadata.routing_id -FinalRoute safe-foreman-route -FinalDelegation $false -FinalModel safe-foreman-model -Outcome blocked
    $crossModel = Get-WorkshopJevDecision -RoutingContext $context -Root $root -Request { param($body) New-Response 0.9 'master-craftsman' 'gpt-5.6-luna' }
    Assert-True ($crossModel.source -eq 'jev' -and $crossModel.agent -eq 'master-craftsman' -and $crossModel.model -eq 'gpt-5.6-luna') 'An allowed model must be accepted independently of its agent role.'
    $disallowedModel = Get-WorkshopJevDecision -RoutingContext $context -Root $root -Request { param($body) New-Response 0.9 'master-craftsman' 'gpt-5.6-astra' }
    Assert-True ($disallowedModel.source -eq 'foreman-fallback') 'A disallowed model must fall back.'
    $low = Get-WorkshopJevDecision -RoutingContext $context -Root $root -Request { param($body) New-Response 0.39 }
    Assert-True ($low.source -eq 'foreman-fallback') 'Low confidence must fall back.'
    $bad = Get-WorkshopJevDecision -RoutingContext $context -Root $root -Request { param($body) [PSCustomObject]@{ answers = [PSCustomObject]@{} } }
    Assert-True ($bad.source -eq 'foreman-fallback') 'Malformed response must fall back.'
    $telemetry = Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') -Raw
    $calls = [Collections.Generic.List[string]]::new()
    foreach ($invalidContext in @('intent=review;scope=pr;risk=routine;effort=trivial;account=Alice Example', "intent=review;scope=pr`nrisk=routine;effort=trivial")) {
        $rejected = Get-WorkshopJevDecision -RoutingContext $invalidContext -Root $root -Request { param($body) $calls.Add($body); New-Response }
        Assert-True ($rejected.source -eq 'foreman-fallback') 'Invalid routing contexts must fall back.'
    }
    Assert-True ($calls.Count -eq 0) 'Invalid routing contexts must not invoke JEV.'
    $blockedRoot = Join-Path $root 'not-a-directory'
    Set-Content -LiteralPath $blockedRoot -Value 'file'
    $telemetryAccepted = Get-WorkshopJevDecision -RoutingContext $context -Root $blockedRoot -Request { param($body) New-Response }
    Assert-True ($telemetryAccepted.source -eq 'jev') 'Telemetry failure must not prevent an accepted decision.'
    $telemetryFailure = Get-WorkshopJevDecision -RoutingContext $context -Root $blockedRoot -Request { param($body) [PSCustomObject]@{ answers = [PSCustomObject]@{} } }
    Assert-True ($telemetryFailure.source -eq 'foreman-fallback') 'Telemetry failure must not prevent a fallback decision.'
    $telemetry = Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') -Raw
    $completion = @(Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') | ConvertFrom-Json | Where-Object event -eq 'completion')[0]
    Assert-True ($completion.routing_id -eq $withoutMetadata.routing_id -and $completion.outcome -eq 'completed') 'Completion telemetry must correlate to its routing decision.'
    $actualOutcome = @(Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') | ConvertFrom-Json | Where-Object final_route -eq 'safe-foreman-route')[0]
    Assert-True ($actualOutcome.final_model -eq 'safe-foreman-model' -and $actualOutcome.outcome -eq 'blocked') 'Completion telemetry must accept actual route and model values outside JEV allowlists.'
    Assert-True ($telemetry -notmatch 'Alice Example|test-key' -and $telemetry -match 'jev_response_model":"jev-1.13.0"' -and $telemetry -match 'skill_confidence":0.9' -and $telemetry -match 'agent_confidence":0.9' -and $telemetry -match 'model_confidence":0.9' -and $telemetry -match 'delegate_confidence":0.9' -and $telemetry -match '"event":"completion"' -and $telemetry -match '"final_route":"github-check-pr"' -and $telemetry -match '"baseline_actual_total_tokens":120' -and $telemetry -match '"projected_jev_total_tokens":115' -and $telemetry -match '"downstream_task_latency_ms":42') 'Telemetry must omit task/key and preserve observed routing and completion metrics.'
} finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'Workshop JEV routing tests passed.'
