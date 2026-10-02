$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/jev-routing.ps1')
function Assert-True { param([bool] $Condition, [string] $Message) if (-not $Condition) { throw $Message } }
function New-Response([string] $Choice, [double] $Confidence = 0.9) { [PSCustomObject]@{ answers = [PSCustomObject]@{ decision = [PSCustomObject]@{ type = 'choice'; choice = $Choice; confidence = $Confidence } }; usage = [PSCustomObject]@{ input_tokens = 12; output_tokens = 3 } } }
$root = Join-Path ([IO.Path]::GetTempPath()) "workshop-jev-test-$([guid]::NewGuid())"
try {
    New-Item -ItemType Directory -Path (Join-Path $root 'catalog') -Force | Out-Null
    @('| Model | Description | Default reasoning | Supported reasoning |', '|---|---|---|---|', '| model-small | Fast \| affordable. | low | low |', '| model-large | Demanding work. | high | medium, high |') | Set-Content -LiteralPath (Join-Path $root 'catalog/models.md')
    $calls = [Collections.Generic.List[object]]::new(); $responses = [Collections.Generic.Queue[object]]@((New-Response none), (New-Response master-craftsman), (New-Response model-small@low))
    $request = { param($body) $calls.Add((ConvertFrom-Json $body)); $responses.Dequeue() }
    $task = [guid]::NewGuid()
    $skill = Get-WorkshopJevDecision -TaskId $task -DecisionType skill -TaskDescription 'Review pull request 42' -Root $root -Request $request
    $role = Get-WorkshopJevDecision -TaskId $task -DecisionType role -TaskDescription 'Review pull request 42' -Root $root -Request $request
    $model = Get-WorkshopJevDecision -TaskId $task -DecisionType model -TaskDescription 'Review pull request 42' -SelectedRole master-craftsman -Root $root -Request $request
    Assert-True ($skill.value -eq 'none' -and $role.value -eq 'master-craftsman' -and $model.value.model -eq 'model-small' -and $model.value.reasoning -eq 'low' -and $calls.Count -eq 3) 'Accepted skill, role, and model/reasoning choices must use exactly three calls.'
    Assert-True ($calls[2].questions.decision.criteria.'model-small@low' -match 'Fast \\| affordable' -and $calls[2].questions.decision.instructions -match 'lowest-resource') 'Model choice must retain escaped-pipe descriptions in observed model/reasoning combinations.'
    $stopped = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -TaskDescription 'Create a pull request' -Root $root -Request { param($body) New-Response github-create-pr }
    Assert-True ($stopped.value -eq 'github-create-pr') 'A specialized skill may stop later stages.'
    $fallback = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -TaskDescription 'Fix service endpoint' -Root $root -Request { param($body) New-Response github-check-pr 0.39 }
    $unsafe = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -TaskDescription "Fix`nendpoint" -Root $root -Request { throw 'must not run' }
    $failed = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType skill -TaskDescription 'Fix service endpoint' -Root $root -Request { throw 'network failure' }
    Assert-True ($fallback.source -eq 'foreman-fallback' -and $unsafe.source -eq 'foreman-fallback' -and $failed.source -eq 'foreman-fallback') 'Unsafe, low-confidence, and failed decisions must use ordinary fallback.'
    $unsupported = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType model -TaskDescription 'Fix service endpoint' -SelectedRole master-craftsman -Root $root -Request { param($body) New-Response model-small@high }
    $lowModel = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType model -TaskDescription 'Fix service endpoint' -SelectedRole master-craftsman -Root $root -Request { param($body) New-Response model-small@low 0.39 }
    @('| Model | Description | Default reasoning | Supported reasoning |', '|---|---|---|---|', '| model-small | Fast and affordable. | low | unknown |') | Set-Content -LiteralPath (Join-Path $root 'catalog/models.md')
    $missingInventory = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType model -TaskDescription 'Fix service endpoint' -SelectedRole master-craftsman -Root $root -Request { throw 'must not run' }
    Assert-True ($unsupported.source -eq 'foreman-fallback' -and $lowModel.source -eq 'foreman-fallback' -and $missingInventory.source -eq 'foreman-fallback') 'Unsupported, low-confidence, or missing observed model/reasoning inventory must fall back.'
    foreach ($forbiddenRole in @('foreman', 'fitter')) {
        $rejected = Get-WorkshopJevDecision -TaskId ([guid]::NewGuid()) -DecisionType role -TaskDescription 'Fix service endpoint' -Root $root -Request { param($body) New-Response $forbiddenRole }
        Assert-True ($rejected.source -eq 'foreman-fallback') 'JEV must not choose orchestration or PR mechanics roles.'
    }
    $telemetry = Get-Content -LiteralPath (Join-Path $root '.local/jev-routing.jsonl') -Raw
    Assert-True ($telemetry -notmatch 'Review pull request|Fix service endpoint|network failure' -and $telemetry -match '"accepted":true' -and $telemetry -match '"latency_ms":') 'Telemetry must be per decision and private.'
} finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction Ignore }
Write-Host 'Workshop JEV routing tests passed.'
