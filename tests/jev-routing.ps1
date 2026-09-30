$ErrorActionPreference = 'Stop'
$beforeImport = $ErrorActionPreference
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/jev-routing.ps1')

function Assert-True { param([bool] $Condition, [string] $Message) if (-not $Condition) { throw $Message } }
function New-Response([string] $Choice, [double] $Confidence = 0.9) { [PSCustomObject]@{ model = 'jev-1.13.0'; answers = [PSCustomObject]@{ decision = [PSCustomObject]@{ type = 'choice'; choice = $Choice; confidence = $Confidence; probabilities = @{} } }; usage = [PSCustomObject]@{ input_tokens = 12; output_tokens = 3 } } }
function Invoke-TestJevFlow {
    param([string] $Root, [guid] $TaskId, [string] $TaskDescription, [Collections.Generic.Queue[object]] $Responses, [Collections.Generic.List[object]] $Calls)

    $request = {
        param($body)
        $Calls.Add((ConvertFrom-Json $body))
        $Responses.Dequeue()
    }
    $skill = Get-WorkshopJevDecision -TaskId $TaskId -DecisionType skill -TaskDescription $TaskDescription -Root $Root -Request $request
    if ($skill.source -ne 'jev' -or $skill.value -ne 'none') { return [PSCustomObject]@{ skill = $skill } }
    $delegation = Get-WorkshopJevDecision -TaskId $TaskId -DecisionType delegation -TaskDescription $TaskDescription -SelectedSkill none -Root $Root -Request $request
    if ($delegation.source -ne 'jev' -or -not $delegation.value) { return [PSCustomObject]@{ skill = $skill; delegation = $delegation } }
    $role = Get-WorkshopJevDecision -TaskId $TaskId -DecisionType role -TaskDescription $TaskDescription -Root $Root -Request $request
    if ($role.source -ne 'jev') { return [PSCustomObject]@{ skill = $skill; delegation = $delegation; role = $role } }
    $model = Get-WorkshopJevDecision -TaskId $TaskId -DecisionType model -TaskDescription $TaskDescription -SelectedRole $role.value -Root $Root -Request $request
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

    $createCalls = [Collections.Generic.List[object]]::new()
    $create = Invoke-TestJevFlow -Root $root -TaskId ([guid]::NewGuid()) -TaskDescription 'create pull request' -Responses ([Collections.Generic.Queue[object]]@((New-Response github-create-pr))) -Calls $createCalls
    $reviewCalls = [Collections.Generic.List[object]]::new()
    $review = Invoke-TestJevFlow -Root $root -TaskId ([guid]::NewGuid()) -TaskDescription 'inspect pull request' -Responses ([Collections.Generic.Queue[object]]@((New-Response github-check-pr))) -Calls $reviewCalls
    $mergeCalls = [Collections.Generic.List[object]]::new()
    $merge = Invoke-TestJevFlow -Root $root -TaskId ([guid]::NewGuid()) -TaskDescription 'merge pull request' -Responses ([Collections.Generic.Queue[object]]@((New-Response github-merge-pr))) -Calls $mergeCalls
    Assert-True ($create.skill.value -eq 'github-create-pr' -and $review.skill.value -eq 'github-check-pr' -and $merge.skill.value -eq 'github-merge-pr' -and $create.skill.reason -eq 'accepted' -and $createCalls.Count -eq 1 -and $reviewCalls.Count -eq 1 -and $mergeCalls.Count -eq 1) 'Task semantics must distinguish create, inspect, and merge PR skills.'
    Assert-True ($createCalls[0].state -eq 'decision=skill;task=create pull request' -and $reviewCalls[0].state -eq 'decision=skill;task=inspect pull request' -and $mergeCalls[0].state -eq 'decision=skill;task=merge pull request') 'Create, check, and merge must each send their exact semantic state.'

    $directTask = [guid]::NewGuid(); $directCalls = [Collections.Generic.List[object]]::new()
    $directFlow = Invoke-TestJevFlow -Root $root -TaskId $directTask -TaskDescription 'correct local typo' -Responses ([Collections.Generic.Queue[object]]@((New-Response none), (New-Response false))) -Calls $directCalls
    Assert-True ($directFlow.skill.value -eq 'none' -and -not $directFlow.delegation.value -and $directCalls.Count -eq 2 -and $directCalls[0].state -eq 'decision=skill;task=correct local typo' -and $directCalls[1].state -eq 'decision=delegation;task=correct local typo;selected_skill=none') 'Trivial direct work must receive task semantics then no role or model stage.'

    $delegatedTask = [guid]::NewGuid(); $delegatedCalls = [Collections.Generic.List[object]]::new()
    $delegatedFlow = Invoke-TestJevFlow -Root $root -TaskId $delegatedTask -TaskDescription 'implement repository validation rule' -Responses ([Collections.Generic.Queue[object]]@((New-Response none), (New-Response true), (New-Response master-craftsman), (New-Response gpt-5.6-luna))) -Calls $delegatedCalls
    Assert-True ($delegatedFlow.skill.value -eq 'none' -and $delegatedFlow.delegation.value -and $delegatedFlow.role.value -eq 'master-craftsman' -and $delegatedFlow.model.value -eq 'gpt-5.6-luna' -and (@($delegatedCalls.state) -join ',') -eq 'decision=skill;task=implement repository validation rule,decision=delegation;task=implement repository validation rule;selected_skill=none,decision=role;task=implement repository validation rule,decision=model;task=implement repository validation rule;selected_role=master-craftsman') 'Repository implementation must send only the current stage semantics and selected state.'
    Assert-True ($delegatedCalls[3].questions.decision.criteria.'gpt-5.6-luna' -eq 'fast and efficient') 'Model selection must receive Stocktake-backed current model names and characteristics.'
    Complete-WorkshopJevTelemetry -Root $root -TaskId $delegatedTask -FinalRoute none -FinalDelegation $true -FinalRole master-craftsman -FinalModel gpt-5.6-luna -Outcome completed -BaselineActualTotalTokens 200 -ObservedDownstreamTaskTokens 100 -DownstreamTaskLatencyMs 42

    $fallbackCalls = [Collections.Generic.List[object]]::new()
    $fallbackFlow = Invoke-TestJevFlow -Root $root -TaskId ([guid]::NewGuid()) -TaskDescription 'implement repository validation rule' -Responses ([Collections.Generic.Queue[object]]@((New-Response none), (New-Response true 0.39))) -Calls $fallbackCalls
    Assert-True ($fallbackFlow.delegation.source -eq 'foreman-fallback' -and $fallbackCalls.Count -eq 2) 'A rejected stage must fall back without subsequent JEV calls.'
    $invalidCalls = [Collections.Generic.List[string]]::new()
    foreach ($unsafeTask in @('raw prompt; account Alice Example', "multiline`nraw prompt", ('a' * 161), 'delete customer Jane Smith account 12345', 'high risk authorization merge', 'merge authorized pull request', 'raw test marker')) {
        $invalid = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -TaskDescription $unsafeTask -Root $root -Request { param($body) $invalidCalls.Add($body); New-Response github-check-pr }
        Assert-True ($invalid.source -eq 'foreman-fallback') 'Unsafe, multiline, or unbounded task descriptions must fall back.'
    }
    Assert-True ($invalidCalls.Count -eq 0) 'Rejected task descriptions must not invoke JEV.'

    function Assert-FallbackReason {
        param([string] $Reason, [scriptblock] $Request)
        $task = [guid]::NewGuid()
        $decision = Get-WorkshopJevDecision -TaskId $task -DecisionType skill -TaskDescription 'inspect pull request' -Root $root -Request $Request
        $row = @((Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') | ConvertFrom-Json) | Where-Object { $_.event -eq 'routing' -and $_.task_id -eq $task })
        Assert-True ($decision.source -eq 'foreman-fallback' -and $decision.reason -eq $Reason -and $row.Count -eq 1 -and $row[0].reason -eq $Reason) "Injected $Reason failure must return and record one stable reason."
    }
    Assert-FallbackReason sandbox-tls { param($body) throw [Security.Authentication.AuthenticationException]::new('private-tls-marker SEC_E_NO_CREDENTIALS') }
    Assert-FallbackReason timeout { param($body) throw [TimeoutException]::new('private-timeout-marker') }
    Assert-FallbackReason http-auth { param($body) throw [Net.Http.HttpRequestException]::new('private-auth-marker', $null, [Net.HttpStatusCode]::Unauthorized) }
    Assert-FallbackReason api-unavailable { param($body) throw [Net.WebException]::new('private-transport-marker') }
    $savedApiKey = $env:TYPESAFE_API_KEY
    try {
        $env:TYPESAFE_API_KEY = ''
        $missingTask = [guid]::NewGuid()
        $missing = Get-WorkshopJevDecision -TaskId $missingTask -DecisionType skill -TaskDescription 'inspect pull request' -Root $root
        $missingRow = @((Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') | ConvertFrom-Json) | Where-Object { $_.event -eq 'routing' -and $_.task_id -eq $missingTask })
        Assert-True ($missing.reason -eq 'missing-api-credential' -and $missingRow.Count -eq 1 -and $missingRow[0].reason -eq 'missing-api-credential') 'Missing credentials must return and record a stable reason without a request.'
    } finally { if ($null -eq $savedApiKey) { Remove-Item Env:TYPESAFE_API_KEY -ErrorAction Ignore } else { $env:TYPESAFE_API_KEY = $savedApiKey } }
    $rejectedTask = [guid]::NewGuid(); $contextTask = [guid]::NewGuid()
    $rejected = Get-WorkshopJevDecision -TaskId $rejectedTask -DecisionType skill -TaskDescription 'inspect pull request' -Root $root -Request { param($body) New-Response github-check-pr 0.39 }
    $context = Get-WorkshopJevDecision -TaskId $contextTask -DecisionType skill -TaskDescription 'raw test marker' -Root $root -Request { param($body) New-Response github-check-pr }
    $reasonRows = @((Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') | ConvertFrom-Json)
        | Where-Object { $_.event -eq 'routing' -and $_.task_id -in @($rejectedTask, $contextTask) })
    Assert-True ($rejected.reason -eq 'rejected-response' -and $context.reason -eq 'context-rejected' -and $reasonRows.Count -eq 2 -and (@($reasonRows.reason) -join ',') -eq 'rejected-response,context-rejected') 'Rejected responses and invalid context must return and record stable reasons.'

    $retryTask = [guid]::NewGuid(); $restrictedPayloads = [Collections.Generic.List[string]]::new(); $approvedPayloads = [Collections.Generic.List[string]]::new()
    $retried = Get-WorkshopJevDecisionWithApprovedRetry -TaskId $retryTask -DecisionType skill -TaskDescription 'inspect pull request' -Root $root -Request { param($body) $restrictedPayloads.Add($body); throw [Security.Authentication.AuthenticationException]::new('private-retry-marker SEC_E_NO_CREDENTIALS') } -ApprovedRequest { param($body) $approvedPayloads.Add($body); New-Response github-check-pr }
    $retryRows = @((Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') | ConvertFrom-Json) | Where-Object { $_.event -eq 'routing' -and $_.task_id -eq $retryTask })
    Assert-True ($retried.source -eq 'jev' -and $retried.reason -eq 'accepted' -and $restrictedPayloads.Count -eq 1 -and $approvedPayloads.Count -eq 1 -and $restrictedPayloads[0] -ceq $approvedPayloads[0] -and (ConvertFrom-Json $restrictedPayloads[0]).state -eq 'decision=skill;task=inspect pull request' -and $restrictedPayloads[0] -notmatch 'private-retry-marker|Bearer' -and $retryRows.Count -eq 2 -and (@($retryRows.reason) -join ',') -eq 'sandbox-tls,accepted' -and $retryRows[0].routing_id -ne $retryRows[1].routing_id) 'Only the explicit approved request must retry sandbox TLS once with the identical sanitized payload and same task telemetry.'

    function Assert-NoApprovedRetry {
        param([string] $Reason, [string] $TaskDescription, [scriptblock] $Request)
        $task = [guid]::NewGuid(); $approvedCalls = [Collections.Generic.List[string]]::new()
        $decision = Get-WorkshopJevDecisionWithApprovedRetry -TaskId $task -DecisionType skill -TaskDescription $TaskDescription -Root $root -Request $Request -ApprovedRequest { param($body) $approvedCalls.Add($body); New-Response github-check-pr }
        $rows = @((Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') | ConvertFrom-Json) | Where-Object { $_.event -eq 'routing' -and $_.task_id -eq $task })
        Assert-True ($decision.reason -eq $Reason -and $approvedCalls.Count -eq 0 -and $rows.Count -eq 1) "$Reason must not invoke approved retry."
    }
    Assert-NoApprovedRetry timeout 'inspect pull request' { param($body) throw [TimeoutException]::new('private-retry-timeout') }
    Assert-NoApprovedRetry http-auth 'inspect pull request' { param($body) throw [Net.Http.HttpRequestException]::new('private-retry-auth', $null, [Net.HttpStatusCode]::Forbidden) }
    Assert-NoApprovedRetry api-unavailable 'inspect pull request' { param($body) throw [Net.WebException]::new('private-retry-transport') }
    Assert-NoApprovedRetry rejected-response 'inspect pull request' { param($body) New-Response github-check-pr 0.39 }
    Assert-NoApprovedRetry rejected-response 'inspect pull request' { param($body) New-Response not-allowed }
    Assert-NoApprovedRetry context-rejected 'raw test marker' { param($body) New-Response github-check-pr }
    $savedApiKey = $env:TYPESAFE_API_KEY
    try { $env:TYPESAFE_API_KEY = ''; Assert-NoApprovedRetry missing-api-credential 'inspect pull request' $null
    } finally { if ($null -eq $savedApiKey) { Remove-Item Env:TYPESAFE_API_KEY -ErrorAction Ignore } else { $env:TYPESAFE_API_KEY = $savedApiKey } }

    $missingMetricTask = [guid]::NewGuid()
    Get-WorkshopJevDecision -TaskId $missingMetricTask -DecisionType skill -TaskDescription 'inspect pull request' -Root $root -Request { param($body) New-Response github-check-pr } | Out-Null
    Complete-WorkshopJevTelemetry -Root $root -TaskId $missingMetricTask -FinalRoute github-check-pr -FinalDelegation $false -Outcome completed -BaselineActualTotalTokens 10

    Remove-Item -LiteralPath (Join-Path $root 'catalog/models.md')
    $catalogCalls = [Collections.Generic.List[string]]::new()
    $catalogFallback = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType model -TaskDescription 'implement repository validation rule' -SelectedRole master-craftsman -Root $root -Request { param($body) $catalogCalls.Add($body); New-Response gpt-5.6-luna }
    Assert-True ($catalogFallback.source -eq 'foreman-fallback' -and $catalogCalls.Count -eq 0) 'Missing or unusable inventory must fall back before asking JEV.'

    $blockedRoot = Join-Path $root 'not-a-directory'; Set-Content -LiteralPath $blockedRoot -Value 'file'
    $telemetryAccepted = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -TaskDescription 'inspect pull request' -Root $blockedRoot -Request { param($body) New-Response github-check-pr }
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
    Assert-True ($telemetry -notmatch 'Alice Example|Jane Smith|account 12345|raw prompt|raw test marker|high risk authorization merge|inspect pull request|implement repository validation rule|correct local typo|private-tls-marker|private-timeout-marker|private-auth-marker|private-transport-marker|test-key|intent=|scope=|risk=|effort=' -and $telemetry -match '"decision_type":"skill"' -and $telemetry -match '"confidence":0.9' -and $telemetry -match '"baseline_actual_total_tokens":200') 'Telemetry must exclude task descriptions and exception markers while retaining observed staged metrics.'
} finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'Workshop JEV routing tests passed.'
