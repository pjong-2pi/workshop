$ErrorActionPreference = 'Stop'
$beforeImport = $ErrorActionPreference
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/jev-routing.ps1')

function Assert-True { param([bool] $Condition, [string] $Message) if (-not $Condition) { throw $Message } }
function New-Response([string] $Choice, [double] $Confidence = 0.9) { [PSCustomObject]@{ model = 'jev-1.13.0'; answers = [PSCustomObject]@{ decision = [PSCustomObject]@{ type = 'choice'; choice = $Choice; confidence = $Confidence; probabilities = @{} } }; usage = [PSCustomObject]@{ input_tokens = 12; output_tokens = 3 } } }
function Invoke-TestJevFlow {
    param([string] $Root, [guid] $TaskId, [Collections.Generic.Queue[object]] $Responses, [Collections.Generic.List[string]] $Calls)

    $request = {
        param($body)
        $Calls.Add(((ConvertFrom-Json $body).state.Split(';')[0].Split('=')[1]))
        $Responses.Dequeue()
    }
    $skill = Get-WorkshopJevDecision -TaskId $TaskId -DecisionType skill -DecisionValue pull-request -Root $Root -Request $request
    if ($skill.source -ne 'jev' -or $skill.value -ne 'none') { return [PSCustomObject]@{ skill = $skill } }
    $delegation = Get-WorkshopJevDecision -TaskId $TaskId -DecisionType delegation -DecisionValue substantive -Root $Root -Request $request
    if ($delegation.source -ne 'jev' -or -not $delegation.value) { return [PSCustomObject]@{ skill = $skill; delegation = $delegation } }
    $role = Get-WorkshopJevDecision -TaskId $TaskId -DecisionType role -DecisionValue implementation -Root $Root -Request $request
    if ($role.source -ne 'jev') { return [PSCustomObject]@{ skill = $skill; delegation = $delegation; role = $role } }
    $model = Get-WorkshopJevDecision -TaskId $TaskId -DecisionType model -DecisionValue well-defined -Root $Root -Request $request
    [PSCustomObject]@{ skill = $skill; delegation = $delegation; role = $role; model = $model }
}

Assert-True ($ErrorActionPreference -eq $beforeImport) 'Importing JEV routing must not change caller error handling.'
$root = Join-Path ([IO.Path]::GetTempPath()) "workshop-jev-test-$([guid]::NewGuid())"
try {
    New-Item -ItemType Directory -Path (Join-Path $root 'catalog') -Force | Out-Null
    @'
# Workshop model catalog
| Model | Provider | Availability | Pricing | Context limit | Relevant characteristics | Source |
|---|---|---|---|---|---|---|
| gpt-5.6-luna | unknown | available to current Codex account | unknown | unknown | fast and efficient | test |
| gpt-5.6-terra | unknown | available to current Codex account | unknown | unknown | balanced for demanding work | test |
'@ | Set-Content -LiteralPath (Join-Path $root 'catalog/models.md')

    $skillTask = [guid]::NewGuid(); $skillCalls = [Collections.Generic.List[string]]::new()
    $skillFlow = Invoke-TestJevFlow -Root $root -TaskId $skillTask -Responses ([Collections.Generic.Queue[object]]@((New-Response github-check-pr))) -Calls $skillCalls
    Assert-True ($skillFlow.skill.value -eq 'github-check-pr' -and (@($skillCalls) -join ',') -eq 'skill') 'An accepted work-resolving skill must prevent delegation, role, and model calls.'

    $directTask = [guid]::NewGuid(); $directCalls = [Collections.Generic.List[string]]::new()
    $directFlow = Invoke-TestJevFlow -Root $root -TaskId $directTask -Responses ([Collections.Generic.Queue[object]]@((New-Response none), (New-Response false))) -Calls $directCalls
    Assert-True ($directFlow.skill.value -eq 'none' -and -not $directFlow.delegation.value -and (@($directCalls) -join ',') -eq 'skill,delegation') 'Skill none plus declined delegation must prevent role and model calls.'

    $delegatedTask = [guid]::NewGuid(); $delegatedCalls = [Collections.Generic.List[string]]::new()
    $delegatedFlow = Invoke-TestJevFlow -Root $root -TaskId $delegatedTask -Responses ([Collections.Generic.Queue[object]]@((New-Response none), (New-Response true), (New-Response master-craftsman), (New-Response gpt-5.6-luna))) -Calls $delegatedCalls
    Assert-True ($delegatedFlow.delegation.value -and $delegatedFlow.role.value -eq 'master-craftsman' -and $delegatedFlow.model.value -eq 'gpt-5.6-luna' -and (@($delegatedCalls) -join ',') -eq 'skill,delegation,role,model') 'Accepted delegation must reach role then model.'
    Complete-WorkshopJevTelemetry -Root $root -TaskId $delegatedTask -FinalRoute none -FinalDelegation $true -FinalRole master-craftsman -FinalModel gpt-5.6-luna -Outcome completed -BaselineActualTotalTokens 200 -ObservedDownstreamTaskTokens 100 -DownstreamTaskLatencyMs 42

    $fallbackCalls = [Collections.Generic.List[string]]::new()
    $fallbackFlow = Invoke-TestJevFlow -Root $root -TaskId ([guid]::NewGuid()) -Responses ([Collections.Generic.Queue[object]]@((New-Response none), (New-Response true 0.39))) -Calls $fallbackCalls
    Assert-True ($fallbackFlow.delegation.source -eq 'foreman-fallback' -and (@($fallbackCalls) -join ',') -eq 'skill,delegation') 'A rejected stage must fall back without subsequent JEV calls.'
    $invalidCalls = [Collections.Generic.List[string]]::new()
    $invalid = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -DecisionValue 'pull-request;account=Alice Example' -Root $root -Request { param($body) $invalidCalls.Add($body); New-Response github-check-pr }
    Assert-True ($invalid.source -eq 'foreman-fallback' -and $invalidCalls.Count -eq 0) 'Unsafe decision values must fall back without invoking JEV.'

    $missingMetricTask = [guid]::NewGuid()
    Get-WorkshopJevDecision -TaskId $missingMetricTask -DecisionType skill -DecisionValue pull-request -Root $root -Request { param($body) New-Response github-check-pr } | Out-Null
    Complete-WorkshopJevTelemetry -Root $root -TaskId $missingMetricTask -FinalRoute github-check-pr -FinalDelegation $false -Outcome completed -BaselineActualTotalTokens 10

    Remove-Item -LiteralPath (Join-Path $root 'catalog/models.md')
    $catalogCalls = [Collections.Generic.List[string]]::new()
    $catalogFallback = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType model -DecisionValue well-defined -Root $root -Request { param($body) $catalogCalls.Add($body); New-Response gpt-5.6-luna }
    Assert-True ($catalogFallback.source -eq 'foreman-fallback' -and $catalogCalls.Count -eq 0) 'Missing or unusable inventory must fall back before asking JEV.'

    $blockedRoot = Join-Path $root 'not-a-directory'; Set-Content -LiteralPath $blockedRoot -Value 'file'
    $telemetryAccepted = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -DecisionValue pull-request -Root $blockedRoot -Request { param($body) New-Response github-check-pr }
    Assert-True ($telemetryAccepted.source -eq 'jev') 'Telemetry failure must not prevent an accepted decision.'
    $rows = @(Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') | ConvertFrom-Json)
    $completion = @($rows | Where-Object { $_.event -eq 'completion' -and $_.task_id -eq $delegatedTask })[0]
    $missingMetricCompletion = @($rows | Where-Object { $_.event -eq 'completion' -and $_.task_id -eq $missingMetricTask })[0]
    $routing = @($rows | Where-Object { $_.event -eq 'routing' -and $_.task_id -eq $delegatedTask })
    Assert-True ($routing.Count -eq 4 -and @($routing.decision_type) -join ',' -eq 'skill,delegation,role,model') 'Telemetry must correlate only stages reached for one task.'
    Assert-True ($completion.final_role -eq 'master-craftsman' -and $completion.final_model -eq 'gpt-5.6-luna' -and $completion.jev_assisted_total_tokens -eq 160) 'Completion must add explicit observed downstream and router counters only.'
    Assert-True ($null -eq $missingMetricCompletion.jev_assisted_total_tokens) 'Completion must keep JEV-assisted totals null when downstream counters are unavailable.'
    Assert-True ($completion.PSObject.Properties.Name -notcontains 'projected_jev_total_tokens') 'Completion telemetry must not retain projection terminology.'
    $telemetry = Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') -Raw
    Assert-True ($telemetry -notmatch 'Alice Example|test-key|intent=|scope=|risk=|effort=' -and $telemetry -match '"decision_type":"skill"' -and $telemetry -match '"confidence":0.9' -and $telemetry -match '"baseline_actual_total_tokens":200') 'Telemetry must exclude request data and retain observed staged metrics.'
} finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'Workshop JEV routing tests passed.'
