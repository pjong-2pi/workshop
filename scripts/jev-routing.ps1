function Test-JevChoice {
    param([object] $Answer, [string[]] $Allowed, [double] $Floor)
    $Answer -and $Answer.type -eq 'choice' -and $Answer.choice -is [string] -and $Allowed -contains $Answer.choice -and $Answer.confidence -is [ValueType] -and $Answer.confidence -ge $Floor -and $Answer.confidence -le 1
}

function Write-JevRoutingTelemetry {
    param([string] $Root, [guid] $TaskId, [object] $Decision, [int] $LatencyMs, [object] $Response)
    try {
        $directory = Join-Path $Root '.local'; New-Item -ItemType Directory -Force -Path $directory | Out-Null
        [PSCustomObject]@{ task_id = $TaskId; decision_type = $Decision.decision_type; decision_value = $Decision.value; accepted = ($Decision.source -eq 'jev'); confidence = if ($Response) { $Response.answers.decision.confidence } else { $null }; input_tokens = if ($Response) { $Response.usage.input_tokens } else { $null }; output_tokens = if ($Response) { $Response.usage.output_tokens } else { $null }; latency_ms = $LatencyMs } | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $directory 'jev-routing.jsonl')
    } catch {}
}

function Get-WorkshopJevDecision {
    param(
        [Parameter(Mandatory)][guid] $TaskId,
        [Parameter(Mandatory)][ValidateSet('skill', 'delegation', 'role', 'model')][string] $DecisionType,
        [Parameter(Mandatory)][string] $TaskDescription, [string] $SelectedSkill, [string] $SelectedRole,
        [Parameter(Mandatory)][string] $Root, [scriptblock] $Request
    )
    $floor = 0.40
    $allowed = @{ skill = @('none', 'workshop-setup', 'workshop-clear-bench', 'github-create-pr', 'github-check-pr', 'github-merge-pr'); delegation = @('true', 'false'); role = @('master-craftsman', 'inspector', 'master-inspector') }
    $watch = [Diagnostics.Stopwatch]::StartNew(); $response = $null
    try {
        if ($TaskDescription.Length -gt 160 -or $TaskDescription -match '[\r\n]' -or $TaskDescription -notmatch '^[\p{L}\p{N}][\p{L}\p{N} .,;:()&''""/+-]*$') { throw 'Task description is not sanitized.' }
        if (($DecisionType -eq 'delegation' -and $SelectedSkill -ne 'none') -or ($DecisionType -eq 'model' -and $SelectedRole -notin $allowed.role) -or ($DecisionType -notin @('delegation', 'model') -and ($SelectedSkill -or $SelectedRole)) -or ($DecisionType -eq 'delegation' -and $SelectedRole) -or ($DecisionType -eq 'model' -and $SelectedSkill)) { throw 'Stage context is invalid.' }
        $instructions = @{ skill = 'Select an applicable specialized workflow skill only. Never select workshop-foreman; choose none otherwise.'; delegation = 'Recommend whether remaining work is implementation requiring a worker, or orchestration/read-only work Foreman may handle.'; role = 'Choose Master Craftsman for implementation or investigation, Inspector when routine independent review adds value, or Master Inspector for high-risk review.'; model = 'Choose the lowest-resource model and reasoning pair likely to reliably complete the task.' }
        $criteria = @{ skill = @{ none = 'No specialized skill applies.'; 'workshop-setup' = 'Explicit first-time Workshop bootstrap.'; 'workshop-clear-bench' = 'Explicit cleanup of a completed Herdr workspace.'; 'github-create-pr' = 'Create a pull request after authorization.'; 'github-check-pr' = 'Inspect an exact pull request.'; 'github-merge-pr' = 'Merge an exact pull request after authorization.' }; delegation = @{ true = 'Implementation always requires a worker.'; false = 'Orchestration or read-only work Foreman may handle.' }; role = @{ 'master-craftsman' = 'Implementation or investigation.'; inspector = 'Routine review.'; 'master-inspector' = 'High-risk review.' } }
        if ($DecisionType -eq 'model') {
            $criteria.model = @{}
            foreach ($line in Get-Content -LiteralPath (Join-Path $Root 'catalog/models.md') -ErrorAction Stop) {
                $columns = $line.Trim().Trim('|') -split '(?<!\\)\|' | ForEach-Object Trim
                if ($columns.Count -eq 4 -and $columns[0] -notin @('Model', '---') -and $columns[0]) {
                    foreach ($effort in @($columns[3] -split ',' | ForEach-Object Trim | Where-Object { $_ -and $_ -ne 'unknown' })) {
                        $choice = "$($columns[0])@$effort"
                        $criteria.model[$choice] = "model: $($columns[0]); description: $($columns[1]); reasoning: $effort"
                    }
                }
            }
            if ($criteria.model.Count -eq 0) { throw 'Model catalog is unusable.' }
            $allowed.model = @($criteria.model.Keys)
        }
        $state = "decision=$DecisionType;task=$TaskDescription"
        if ($DecisionType -eq 'delegation') { $state += ';selected_skill=none' }
        if ($DecisionType -eq 'model') { $state += ";selected_role=$SelectedRole" }
        $body = @{ state = $state; model = 'jev-latest'; questions = @{ decision = @{ type = 'choice'; instructions = $instructions[$DecisionType]; criteria = $criteria[$DecisionType] } } } | ConvertTo-Json -Depth 8 -Compress
        if ($Request) { $response = & $Request $body } else { $response = Invoke-RestMethod -Method Post -Uri 'https://api.typesafe.ai/v1/systemone' -Headers @{ Authorization = "Bearer $env:TYPESAFE_API_KEY" } -ContentType 'application/json' -Body $body -TimeoutSec 5 }
        $answer = $response.answers.decision
        if (-not (Test-JevChoice $answer $allowed[$DecisionType] $floor)) { throw 'Response is not an accepted choice.' }
        $decision = [PSCustomObject]@{ decision_type = $DecisionType; value = if ($DecisionType -eq 'delegation') { [Convert]::ToBoolean($answer.choice) } elseif ($DecisionType -eq 'model') { $pair = $answer.choice -split '@', 2; [PSCustomObject]@{ model = $pair[0]; reasoning = $pair[1] } } else { $answer.choice }; source = 'jev'; task_id = $TaskId }
    } catch {
        $decision = [PSCustomObject]@{ decision_type = $DecisionType; value = $null; source = 'foreman-fallback'; task_id = $TaskId }
    } finally {
        $watch.Stop(); Write-JevRoutingTelemetry -Root $Root -TaskId $TaskId -Decision $decision -LatencyMs $watch.ElapsedMilliseconds -Response $response
    }
    $decision
}
