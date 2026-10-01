$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/jev-routing.ps1')
function Assert-True { param([bool] $Condition, [string] $Message) if (-not $Condition) { throw $Message } }
function New-Response([string] $Choice, [double] $Confidence = 0.9) { [PSCustomObject]@{ answers = [PSCustomObject]@{ decision = [PSCustomObject]@{ type = 'choice'; choice = $Choice; confidence = $Confidence } }; usage = [PSCustomObject]@{ input_tokens = 12; output_tokens = 3 } } }
$root = Join-Path ([IO.Path]::GetTempPath()) "workshop-jev-test-$([guid]::NewGuid())"
try {
    New-Item -ItemType Directory -Path (Join-Path $root 'catalog') -Force | Out-Null
    @('| Model | Description | Default reasoning |', '|---|---|---|', '| model-small | Fast and affordable. | low |', '| model-large | Demanding work. | high |') | Set-Content -LiteralPath (Join-Path $root 'catalog/models.md')
    $calls = [Collections.Generic.List[object]]::new(); $responses = [Collections.Generic.Queue[object]]@((New-Response none), (New-Response true), (New-Response master-craftsman), (New-Response model-small))
    $request = { param($body) $calls.Add((ConvertFrom-Json $body)); $responses.Dequeue() }
    $task = [guid]::NewGuid()
    $skill = Get-WorkshopJevDecision -TaskId $task -DecisionType skill -TaskDescription 'Review pull request 42' -Root $root -Request $request
    $delegation = Get-WorkshopJevDecision -TaskId $task -DecisionType delegation -TaskDescription 'Review pull request 42' -SelectedSkill none -Root $root -Request $request
    $role = Get-WorkshopJevDecision -TaskId $task -DecisionType role -TaskDescription 'Review pull request 42' -Root $root -Request $request
    $model = Get-WorkshopJevDecision -TaskId $task -DecisionType model -TaskDescription 'Review pull request 42' -SelectedRole master-craftsman -Root $root -Request $request
    Assert-True ($skill.value -eq 'none' -and $delegation.value -and $role.value -eq 'master-craftsman' -and $model.value -eq 'model-small' -and $calls.Count -eq 4) 'Staged accepted choices must proceed independently.'
    Assert-True ($calls[3].questions.decision.criteria.'model-small' -match 'Fast and affordable' -and $calls[3].questions.decision.instructions -match 'least-capable') 'Model choice must use the compact current catalog.'
    $stopped = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -TaskDescription 'Create a pull request' -Root $root -Request { param($body) New-Response github-create-pr }
    Assert-True ($stopped.value -eq 'github-create-pr') 'A specialized skill may stop later stages.'
    $fallback = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -TaskDescription 'Fix service endpoint' -Root $root -Request { param($body) New-Response github-check-pr 0.39 }
    $unsafe = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -TaskDescription "Fix`nendpoint" -Root $root -Request { throw 'must not run' }
    $failed = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -TaskDescription 'Fix service endpoint' -Root $root -Request { throw 'network failure' }
    Assert-True ($fallback.source -eq 'foreman-fallback' -and $unsafe.source -eq 'foreman-fallback' -and $failed.source -eq 'foreman-fallback') 'Unsafe, low-confidence, and failed decisions must use ordinary fallback.'
    $telemetry = Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') -Raw
    Assert-True ($telemetry -notmatch 'Review pull request|Fix service endpoint|network failure' -and $telemetry -match '"accepted":true' -and $telemetry -match '"latency_ms":') 'Telemetry must be per decision and private.'
} finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction Ignore }
Write-Host 'Workshop JEV routing tests passed.'
