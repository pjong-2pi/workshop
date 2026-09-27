function Get-JevFallbackDecision {
    [PSCustomObject]@{ skill = $null; agent = $null; model = $null; delegate = $null; source = 'foreman-fallback' }
}

function Test-JevChoice {
    param([object] $Answer, [string[]] $Allowed, [double] $Floor)

    $Answer -and $Answer.type -eq 'choice' -and $Answer.choice -is [string] -and
    $Allowed -contains $Answer.choice -and ($Answer.confidence -is [double] -or $Answer.confidence -is [long] -or $Answer.confidence -is [int]) -and
    $Answer.confidence -ge $Floor -and $Answer.confidence -le 1 -and
    $null -ne $Answer.probabilities
}

function Write-JevRoutingTelemetry {
    param([string] $Root, [guid] $RoutingId, [object] $Decision, [string] $Reason, [int] $LatencyMs, [object] $Usage, [string] $JevModel, [object] $Confidences)

    try {
        $directory = Join-Path $Root '.local'
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        [PSCustomObject]@{
            event = 'routing'
            routing_id = $RoutingId
            timestamp_utc = [DateTime]::UtcNow.ToString('o')
            source = $Decision.source
            skill = $Decision.skill
            agent = $Decision.agent
            model = $Decision.model
            delegate = $Decision.delegate
            reason = $Reason
            latency_ms = $LatencyMs
            jev_input_tokens = if ($Usage) { $Usage.input_tokens } else { $null }
            jev_output_tokens = if ($Usage) { $Usage.output_tokens } else { $null }
            jev_response_model = $JevModel
            skill_confidence = if ($Confidences) { $Confidences.skill } else { $null }
            agent_confidence = if ($Confidences) { $Confidences.agent } else { $null }
            model_confidence = if ($Confidences) { $Confidences.model } else { $null }
            delegate_confidence = if ($Confidences) { $Confidences.delegate } else { $null }
        } | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $directory 'jev-routing.jsonl')
    } catch {}
}

function Complete-WorkshopJevTelemetry {
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][guid] $RoutingId,
        [Parameter(Mandatory)][string] $FinalRoute,
        [Parameter(Mandatory)][bool] $FinalDelegation,
        [string] $FinalModel,
        [Parameter(Mandatory)][ValidateSet('completed', 'blocked', 'error', 'cancelled')][string] $Outcome,
        [Nullable[long]] $BaselineActualTotalTokens,
        [Nullable[long]] $ProjectedJevRouteTokens,
        [Nullable[long]] $DownstreamTaskLatencyMs
    )

    try {
        $directory = Join-Path $Root '.local'
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $routing = @(Get-Content -LiteralPath (Join-Path $directory 'jev-routing.jsonl') | ConvertFrom-Json | Where-Object { $_.event -eq 'routing' -and $_.routing_id -eq $RoutingId } | Select-Object -Last 1)[0]
        $projectedJevTotalTokens = if ($null -ne $ProjectedJevRouteTokens -and $routing -and $null -ne $routing.jev_input_tokens -and $null -ne $routing.jev_output_tokens) { $ProjectedJevRouteTokens + $routing.jev_input_tokens + $routing.jev_output_tokens } else { $null }
        [PSCustomObject]@{
            event = 'completion'
            routing_id = $RoutingId
            timestamp_utc = [DateTime]::UtcNow.ToString('o')
            final_route = $FinalRoute
            final_delegation = $FinalDelegation
            final_model = $FinalModel
            outcome = $Outcome
            baseline_actual_total_tokens = $BaselineActualTotalTokens
            projected_jev_total_tokens = $projectedJevTotalTokens
            downstream_task_latency_ms = $DownstreamTaskLatencyMs
        } | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $directory 'jev-routing.jsonl')
    } catch {}
}

function Get-WorkshopJevDecision {
    param(
        [Parameter(Mandatory)][string] $RoutingContext,
        [Parameter(Mandatory)][string] $Root,
        [scriptblock] $Request
    )

    $fallback = Get-JevFallbackDecision
    $routingId = [guid]::NewGuid()
    $endpoint = 'https://api.typesafe.ai/v1/systemone'
    $floor = 0.40
    $agents = @('master-craftsman', 'inspector', 'master-inspector')
    $models = @('gpt-5.6-luna', 'gpt-5.6-terra')
    $skills = @('none', 'workshop-foreman', 'workshop-setup', 'workshop-clear-bench', 'github-create-pr', 'github-check-pr', 'github-merge-pr')
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $reason = 'api-unavailable'
    $response = $null
    $jevModel = $null
    $confidences = $null
    try {
        $match = [regex]::Match($RoutingContext, '\Aintent=(?<intent>setup|bench-cleanup|pr-create|pr-check|pr-merge|implementation|investigation|review|other);scope=(?<scope>workshop|managed-repo|pr|workspace|local);risk=(?<risk>routine|architecture|concurrency|security|data-loss|authority);effort=(?<effort>trivial|substantive)\z')
        if (-not $match.Success) { throw 'JEV routing context is invalid.' }
        $state = "intent=$($match.Groups['intent'].Value);scope=$($match.Groups['scope'].Value);risk=$($match.Groups['risk'].Value);effort=$($match.Groups['effort'].Value)"
        if (-not $Request -and [string]::IsNullOrWhiteSpace($env:TYPESAFE_API_KEY)) { throw 'TYPESAFE_API_KEY is not set.' }
        $body = @{ state = $state; model = 'jev-latest'; questions = @{
            skill = @{ type = 'choice'; instructions = 'Apply the first matching rule in this exact order: setup -> workshop-setup; bench-cleanup -> workshop-clear-bench; pr-create -> github-create-pr; pr-check or review+scope=pr -> github-check-pr; pr-merge -> github-merge-pr; otherwise substantive implementation, investigation, review, or planning in workshop or managed-repo -> workshop-foreman; none only when no earlier rule matches.'; criteria = @{ none = 'No specialized skill applies.'; 'workshop-foreman' = 'Substantive implementation, investigation, review, or planning in Workshop or a managed repository when no earlier rule matches.'; 'workshop-setup' = 'Explicit first-time Workshop bootstrap.'; 'workshop-clear-bench' = 'Explicit cleanup of a completed Herdr workspace.'; 'github-create-pr' = 'Create a pull request after authorization.'; 'github-check-pr' = 'Inspect an exact pull request.'; 'github-merge-pr' = 'Merge an exact pull request after authorization.' } }
            agent = @{ type = 'choice'; instructions = 'Choose Master Craftsman for implementation or investigation regardless of risk; Inspector only for routine review; Master Inspector only for high-risk review.'; criteria = @{ 'master-craftsman' = 'All implementation and investigation, regardless risk.'; inspector = 'Routine review only.'; 'master-inspector' = 'Review only when risk is architecture, concurrency, security, data-loss, or authority.' } }
            model = @{ type = 'choice'; instructions = 'Choose the cheapest appropriate installed model for the task capability and cost, independently of the selected agent role.'; criteria = @{ 'gpt-5.6-luna' = 'Cheaper choice for well-defined, routine work within its capability.'; 'gpt-5.6-terra' = 'Use when the task needs stronger capability or judgment.' } }
            delegate = @{ type = 'choice'; instructions = 'Should Foreman consider delegation rather than a trivial direct edit?'; criteria = @{ true = 'Substantive or independent specialist work.'; false = 'Trivial direct work may suffice.' } }
        } } | ConvertTo-Json -Depth 8 -Compress
        if ($Request) { $response = & $Request $body } else {
            for ($attempt = 0; $attempt -lt 2; $attempt++) {
                try { $response = Invoke-RestMethod -Method Post -Uri $endpoint -Headers @{ Authorization = "Bearer $env:TYPESAFE_API_KEY" } -ContentType 'application/json' -Body $body -TimeoutSec 5; break }
                catch { if ($attempt -eq 1) { throw }; Start-Sleep -Milliseconds 200 }
            }
        }
        $answers = $response.answers
        if (($null -ne $response.model -and $response.model -isnot [string]) -or -not (Test-JevChoice $answers.skill $skills $floor) -or -not (Test-JevChoice $answers.agent $agents $floor) -or -not (Test-JevChoice $answers.model $models $floor) -or -not (Test-JevChoice $answers.delegate @('true', 'false') $floor)) { throw 'JEV response failed routing validation.' }
        $decision = [PSCustomObject]@{ skill = $answers.skill.choice; agent = $answers.agent.choice; model = $answers.model.choice; delegate = [System.Convert]::ToBoolean($answers.delegate.choice); source = 'jev'; routing_id = $routingId }
        $jevModel = $response.model
        $confidences = [PSCustomObject]@{ skill = $answers.skill.confidence; agent = $answers.agent.confidence; model = $answers.model.confidence; delegate = $answers.delegate.confidence }
        $reason = 'accepted'
    } catch {
        $decision = $fallback
        $decision | Add-Member -NotePropertyName routing_id -NotePropertyValue $routingId
        if ($_.Exception.Message -eq 'JEV response failed routing validation.') { $reason = 'rejected-response' }
        if ($_.Exception.Message -eq 'JEV routing context is invalid.') { $reason = 'context-rejected' }
    } finally {
        $watch.Stop()
        Write-JevRoutingTelemetry -Root $Root -RoutingId $routingId -Decision $decision -Reason $reason -LatencyMs $watch.ElapsedMilliseconds -Usage $(if ($response) { $response.usage } else { $null }) -JevModel $jevModel -Confidences $confidences
    }
    $decision
}
