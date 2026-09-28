function Get-JevFallbackDecision {
    param([string] $DecisionType)
    [PSCustomObject]@{ decision_type = $DecisionType; value = $null; source = 'foreman-fallback' }
}

function Test-JevChoice {
    param([object] $Answer, [string[]] $Allowed, [double] $Floor)
    $Answer -and $Answer.type -eq 'choice' -and $Answer.choice -is [string] -and $Allowed -contains $Answer.choice -and ($Answer.confidence -is [double] -or $Answer.confidence -is [long] -or $Answer.confidence -is [int]) -and $Answer.confidence -ge $Floor -and $Answer.confidence -le 1 -and $null -ne $Answer.probabilities
}

function Write-JevRoutingTelemetry {
    param([string] $Root, [guid] $TaskId, [guid] $RoutingId, [object] $Decision, [string] $Reason, [int] $LatencyMs, [object] $Usage, [string] $JevModel, [object] $Confidence)
    try {
        $directory = Join-Path $Root '.local'; New-Item -ItemType Directory -Force -Path $directory | Out-Null
        [PSCustomObject]@{ event = 'routing'; task_id = $TaskId; routing_id = $RoutingId; timestamp_utc = [DateTime]::UtcNow.ToString('o'); decision_type = $Decision.decision_type; decision_value = $Decision.value; source = $Decision.source; reason = $Reason; latency_ms = $LatencyMs; jev_input_tokens = if ($Usage) { $Usage.input_tokens } else { $null }; jev_output_tokens = if ($Usage) { $Usage.output_tokens } else { $null }; jev_response_model = $JevModel; confidence = if ($Confidence) { $Confidence.confidence } else { $null } } | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $directory 'jev-routing.jsonl')
    } catch {}
}

function Complete-WorkshopJevTelemetry {
    param(
        [Parameter(Mandatory)][string] $Root, [Parameter(Mandatory)][guid] $TaskId,
        [Parameter(Mandatory)][string] $FinalRoute, [Parameter(Mandatory)][bool] $FinalDelegation,
        [string] $FinalRole, [string] $FinalModel,
        [Parameter(Mandatory)][ValidateSet('completed', 'blocked', 'error', 'cancelled')][string] $Outcome,
        [Nullable[long]] $BaselineActualTotalTokens, [Nullable[long]] $ObservedDownstreamTaskTokens, [Nullable[long]] $DownstreamTaskLatencyMs
    )
    try {
        $directory = Join-Path $Root '.local'; New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $rows = @(Get-Content -LiteralPath (Join-Path $directory 'jev-routing.jsonl') | ConvertFrom-Json | Where-Object { $_.event -eq 'routing' -and $_.task_id -eq $TaskId })
        $observed = $rows.Count -gt 0 -and @($rows | Where-Object { $null -eq $_.jev_input_tokens -or $null -eq $_.jev_output_tokens }).Count -eq 0
        $jevAssistedTotalTokens = if ($null -ne $ObservedDownstreamTaskTokens -and $observed) { $ObservedDownstreamTaskTokens + ($rows | Measure-Object -Property jev_input_tokens -Sum).Sum + ($rows | Measure-Object -Property jev_output_tokens -Sum).Sum } else { $null }
        [PSCustomObject]@{ event = 'completion'; task_id = $TaskId; timestamp_utc = [DateTime]::UtcNow.ToString('o'); final_route = $FinalRoute; final_delegation = $FinalDelegation; final_role = $FinalRole; final_model = $FinalModel; outcome = $Outcome; baseline_actual_total_tokens = $BaselineActualTotalTokens; jev_assisted_total_tokens = $jevAssistedTotalTokens; downstream_task_latency_ms = $DownstreamTaskLatencyMs } | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $directory 'jev-routing.jsonl')
    } catch {}
}

function Get-WorkshopJevDecision {
    param(
        [Parameter(Mandatory)][guid] $TaskId,
        [Parameter(Mandatory)][ValidateSet('skill', 'delegation', 'role', 'model')][string] $DecisionType,
        [Parameter(Mandatory)][string] $DecisionValue, [Parameter(Mandatory)][string] $Root, [scriptblock] $Request
    )
    $fallback = Get-JevFallbackDecision $DecisionType; $routingId = [guid]::NewGuid(); $endpoint = 'https://api.typesafe.ai/v1/systemone'; $floor = 0.40
    $allowed = @{ skill = @('none', 'workshop-setup', 'workshop-clear-bench', 'github-create-pr', 'github-check-pr', 'github-merge-pr'); delegation = @('true', 'false'); role = @('master-craftsman', 'inspector', 'master-inspector') }
    $valuePatterns = @{ skill = 'setup|bench-cleanup|pull-request|none'; delegation = 'trivial|substantive'; role = 'implementation|investigation|routine-review|high-risk-review'; model = 'well-defined|demanding' }
    $watch = [Diagnostics.Stopwatch]::StartNew(); $reason = 'api-unavailable'; $response = $null; $jevModel = $null; $confidence = $null
    try {
        if ($DecisionValue -notmatch "\A(?:$($valuePatterns[$DecisionType]))\z") { throw 'JEV decision value is invalid.' }
        if (-not $Request -and [string]::IsNullOrWhiteSpace($env:TYPESAFE_API_KEY)) { throw 'TYPESAFE_API_KEY is not set.' }
        $instructions = @{ skill = 'Select an applicable specialized workflow skill only. Never select workshop-foreman; choose none when no listed specialized skill applies.'; delegation = 'Recommend whether remaining work should be delegated. Foreman decides whether work remains and retains authority.'; role = 'Choose Master Craftsman for implementation or investigation, Inspector for routine review, or Master Inspector for high-risk review.'; model = 'Choose the cheapest capable available model independently of role from the current inventory characteristics.' }
        $criteria = @{ skill = @{ none = 'No specialized skill applies.'; 'workshop-setup' = 'Explicit first-time Workshop bootstrap.'; 'workshop-clear-bench' = 'Explicit cleanup of a completed Herdr workspace.'; 'github-create-pr' = 'Create a pull request after authorization.'; 'github-check-pr' = 'Inspect an exact pull request.'; 'github-merge-pr' = 'Merge an exact pull request after authorization.' }; delegation = @{ true = 'Substantive independent work.'; false = 'Trivial direct work.' }; role = @{ 'master-craftsman' = 'Implementation or investigation.'; inspector = 'Routine review.'; 'master-inspector' = 'High-risk review.' } }
        if ($DecisionType -eq 'model') {
            $catalog = Join-Path $Root 'catalog/models.md'
            if (-not (Test-Path -LiteralPath $catalog -PathType Leaf)) { throw 'JEV model inventory is unavailable.' }
            $criteria.model = @{}
            foreach ($line in Get-Content -LiteralPath $catalog) {
                $columns = $line.Trim().Trim('|').Split('|') | ForEach-Object Trim
                if ($columns.Count -ge 6 -and $columns[0] -match '^gpt-' -and $columns[2].Trim() -eq 'available to current Codex account' -and -not [string]::IsNullOrWhiteSpace($columns[5]) -and $columns[5].Trim() -ne 'unknown') { $criteria.model[$columns[0].Trim()] = $columns[5].Trim() }
            }
            if ($criteria.model.Count -eq 0) { throw 'JEV model inventory is unusable.' }
            $allowed.model = @($criteria.model.Keys)
        }
        $body = @{ state = "decision=$DecisionType;value=$DecisionValue"; model = 'jev-latest'; questions = @{ decision = @{ type = 'choice'; instructions = $instructions[$DecisionType]; criteria = $criteria[$DecisionType] } } } | ConvertTo-Json -Depth 8 -Compress
        if ($Request) { $response = & $Request $body } else { $response = Invoke-RestMethod -Method Post -Uri $endpoint -Headers @{ Authorization = "Bearer $env:TYPESAFE_API_KEY" } -ContentType 'application/json' -Body $body -TimeoutSec 5 }
        $answer = $response.answers.decision
        if (($null -ne $response.model -and $response.model -isnot [string]) -or -not (Test-JevChoice $answer $allowed[$DecisionType] $floor)) { throw 'JEV response failed routing validation.' }
        $decision = [PSCustomObject]@{ decision_type = $DecisionType; value = if ($DecisionType -eq 'delegation') { [System.Convert]::ToBoolean($answer.choice) } else { $answer.choice }; source = 'jev'; task_id = $TaskId; routing_id = $routingId }
        $jevModel = $response.model; $confidence = $answer; $reason = 'accepted'
    } catch {
        $decision = $fallback; $decision | Add-Member task_id $TaskId; $decision | Add-Member routing_id $routingId
        if ($_.Exception.Message -eq 'JEV response failed routing validation.') { $reason = 'rejected-response' }
        if ($_.Exception.Message -eq 'JEV decision value is invalid.') { $reason = 'context-rejected' }
    } finally {
        $watch.Stop(); Write-JevRoutingTelemetry -Root $Root -TaskId $TaskId -RoutingId $routingId -Decision $decision -Reason $reason -LatencyMs $watch.ElapsedMilliseconds -Usage $(if ($response) { $response.usage } else { $null }) -JevModel $jevModel -Confidence $confidence
    }
    $decision
}
