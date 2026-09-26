$ErrorActionPreference = 'Stop'
$beforeImport = $ErrorActionPreference
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/jev-routing.ps1')

function Assert-True { param([bool] $Condition, [string] $Message) if (-not $Condition) { throw $Message } }
Assert-True ($ErrorActionPreference -eq $beforeImport) 'Importing JEV routing must not change caller error handling.'
function New-Response([double] $Confidence = 0.9) { [PSCustomObject]@{ model = 'jev-1.13.0'; answers = [PSCustomObject]@{
    skill = [PSCustomObject]@{ type = 'choice'; choice = 'github-check-pr'; confidence = $Confidence; probabilities = @{} }
    agent = [PSCustomObject]@{ type = 'choice'; choice = 'inspector'; confidence = $Confidence; probabilities = @{} }
    model = [PSCustomObject]@{ type = 'choice'; choice = 'gpt-5.6-luna'; confidence = $Confidence; probabilities = @{} }
    delegate = [PSCustomObject]@{ type = 'choice'; choice = 'true'; confidence = $Confidence; probabilities = @{} }
}; usage = [PSCustomObject]@{ input_tokens = 12; output_tokens = 3 } } }

$root = Join-Path ([IO.Path]::GetTempPath()) "workshop-jev-test-$([guid]::NewGuid())"
try {
    $context = 'intent=review;scope=pr;risk=routine;effort=substantive'
    $good = Get-WorkshopJevDecision -RoutingContext $context -Root $root -Request { param($body) New-Response }
    Assert-True ($good.source -eq 'jev' -and $good.skill -eq 'github-check-pr' -and $good.model -eq 'gpt-5.6-luna' -and $good.delegate) 'Valid high-confidence response must be accepted.'
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
    Assert-True ($telemetry -notmatch 'Alice Example|test-key' -and $telemetry -match 'jev_response_model":"jev-1.13.0"' -and $telemetry -match 'skill_confidence":0.9' -and $telemetry -match 'agent_confidence":0.9' -and $telemetry -match 'model_confidence":0.9' -and $telemetry -match 'delegate_confidence":0.9' -and $telemetry -match 'downstream_task_tokens":null' -and $telemetry -match 'total_task_cost":null') 'Telemetry must omit task/key and preserve observed routing metadata with unavailable downstream metrics.'
} finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'Workshop JEV routing tests passed.'
