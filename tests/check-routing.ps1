$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$stocktake = Join-Path $root '.agents/skills/workshop-stocktake/scripts/workshop-stocktake.ps1'
$scripts = Join-Path $root '.agents/skills/workshop-jev-route-job/scripts'
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('workshop-routing-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
$savedKey = $env:TYPESAFE_API_KEY

function Assert($condition, $message) { if (-not $condition) { throw $message } }
function global:codex {
    if ($global:failDiscovery) { throw 'discovery unavailable' }
    $global:LASTEXITCODE = 0
    @{ models = @(
        @{ slug='model-a'; description='Model A'; visibility='list'; supported_reasoning_levels=@(@{effort='low'},@{effort='high'}) },
        @{ slug='model-b'; description='Model B'; visibility='list'; supported_reasoning_levels=@(@{effort='medium'}) },
        @{ slug='internal'; description='Hidden'; visibility='hide'; supported_reasoning_levels=@(@{effort='low'}) }
    ) } | ConvertTo-Json -Depth 8 -Compress
}
function global:Invoke-RestMethod {
    param($Method,$Uri,$Headers,$ContentType,$Body,$TimeoutSec,$ErrorAction)
    $request = $Body | ConvertFrom-Json -AsHashtable
    Assert ($Method -eq 'Post' -and $TimeoutSec -gt 0 -and $request.model -eq 'jev-latest') 'Invalid API request.'
    Assert ($Headers.Authorization -eq 'Bearer routing-test-key') 'API key missing from request.'
    $global:lastRequest = $request
    $global:apiCalls++
    if ($global:apiFailure) { throw 'mock API unavailable' }
    $answers = @{}
    foreach ($item in $request.questions.GetEnumerator()) {
        $key = $item.Key
        $question = $item.Value
        $answer = @{ type = $question.type }
        switch ($question.type) {
            choice { $answer.choice = if ($global:unknownResource -and $key -eq 'resource') { 'unavailable-agent' } elseif ($global:nonDelegatableSelection -and $key -eq 'resource') { 'workshop-test-bench' } elseif ($global:implementSelection -and $key -eq 'resource') { 'workshop-craftsman' } elseif ($global:skillSelection -and $key -eq 'resource') { 'workshop-dispatch' } elseif ($key -eq 'resource') { 'workshop-surveyor' } elseif ($global:badModel -and $key -eq 'model_reasoning') { 'unknown-model/high' } elseif ($key -eq 'model_reasoning') { 'model-a/high' } elseif ($key -in @('Keys', 'Count')) { $key } else { @($question.criteria.GetEnumerator())[0].Key } }
            noul { $answer.noul = if ($null -ne $global:invalidNumeric) { $global:invalidNumeric } else { 0.8 } }
            score { $answer.score = if ($null -ne $global:invalidNumeric) { $global:invalidNumeric } else { 1.2 } }
        }
        $answers[$key] = $answer
    }
    if ($global:malformed) { $answers.Remove('resource') }
    @{ answers = $answers } | ConvertTo-Json -Depth 12 | ConvertFrom-Json
}

try {
    $fixtureRoot = Join-Path $temporary 'workshop'
    $agentDirectory = Join-Path $fixtureRoot '.agents/agents'
    $skillDirectory = Join-Path $fixtureRoot '.agents/skills/workshop-dispatch'
    New-Item -ItemType Directory -Path $agentDirectory, $skillDirectory | Out-Null
    Copy-Item -Path (Join-Path $root '.agents/agents/*.md') -Destination $agentDirectory
    Copy-Item -LiteralPath (Join-Path $root '.agents/skills/workshop-dispatch/SKILL.md') -Destination $skillDirectory
    $syntheticPath = Join-Path $agentDirectory 'workshop-test-bench.md'
    Set-Content -LiteralPath $syntheticPath -Value "---`nname: workshop-test-bench`ndescription: Synthetic non-delegatable role.`ndelegatable: false`n---`nThis role cannot accept delegated work."
    $catalogPath = Join-Path $temporary 'catalog.json'
    $skills = @(@{name='global-test';description='Global skill';path=(Join-Path $root 'AGENTS.md')}) | ConvertTo-Json -Compress
    & $stocktake -WorkshopRoot $fixtureRoot -CatalogPath $catalogPath -SessionSkillsJson $skills | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'Initial discovery failed.'
    $catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json -AsHashtable
    $foreman = @($catalog.agents | Where-Object name -EQ 'workshop-foreman')[0]
    $surveyor = @($catalog.agents | Where-Object name -EQ 'workshop-surveyor')[0]
    Assert ($foreman.delegatable -is [bool] -and $foreman.delegatable -eq $false) 'Foreman source boundary was not discovered as a boolean.'
    Assert ($surveyor.delegatable -is [bool] -and $surveyor.delegatable -eq $true) 'Unspecified delegatability did not default to true.'
    $foreman.delegatable = $true
    $surveyor.delegatable = $false
    Assert ($catalog.agents.Count -ge 3 -and @($catalog.skills | Where-Object name -EQ 'global-test').Count -eq 1) 'Agents or session skills missing.'
    Assert (@($catalog.models | Where-Object available).Count -eq 2 -and @($catalog.models | Where-Object name -EQ 'internal').Count -eq 0) 'Model visibility not respected.'
    $catalog.models[0].cost = 3.5
    $catalog.models[0].intelligence = 8
    $catalog.models += @{name='temporarily-absent';available=$false;cost=7;intelligence=9}
    $catalog | ConvertTo-Json -Depth 12 | Set-Content $catalogPath
    & $stocktake -WorkshopRoot $fixtureRoot -CatalogPath $catalogPath -SessionSkillsJson $skills | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'Refresh failed.'
    $catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json -AsHashtable
    $foreman = @($catalog.agents | Where-Object name -EQ 'workshop-foreman')[0]
    $surveyor = @($catalog.agents | Where-Object name -EQ 'workshop-surveyor')[0]
    Assert ($foreman.delegatable -is [bool] -and $foreman.delegatable -eq $false -and $surveyor.delegatable -eq $true) 'Refresh retained stale catalog delegatability instead of source metadata/default.'
    $rated = @($catalog.models | Where-Object name -EQ 'model-a')[0]
    $new = @($catalog.models | Where-Object name -EQ 'model-b')[0]
    $absent = @($catalog.models | Where-Object name -EQ 'temporarily-absent')[0]
    Assert ($rated.cost -eq 3.5 -and $rated.intelligence -eq 8 -and -not $new.ContainsKey('cost') -and -not $new.ContainsKey('intelligence')) 'Manual ratings not preserved or new model was rated.'
    Assert (-not $absent.available -and $absent.cost -eq 7 -and $absent.intelligence -eq 9) 'Absent model metadata lost.'
    $before = [IO.File]::ReadAllBytes($catalogPath)
    $global:failDiscovery = $true
    & $stocktake -WorkshopRoot $fixtureRoot -CatalogPath $catalogPath -SessionSkillsJson $skills 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0 -and [Convert]::ToBase64String($before) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($catalogPath))) 'Failed discovery changed the catalog.'
    $freshPath = Join-Path $temporary 'missing-catalog.json'
    & $stocktake -WorkshopRoot $fixtureRoot -CatalogPath $freshPath -SessionSkillsJson $skills 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0 -and -not (Test-Path -LiteralPath $freshPath)) 'First-run failure created a catalog.'
    $global:failDiscovery = $false

    $env:TYPESAFE_API_KEY = 'routing-test-key'
    $endpoint = 'http://127.0.0.1:1'
    foreach ($type in @('choice','noul','score')) {
        $criteria = switch ($type) { choice { @{Keys='A';Count='B';b='C'} } noul { @{true='Yes';false='No'} } score { @('Low','Medium','High') } }
        $questions = @{ Keys=@{instructions='First?';criteria=$criteria}; Count=@{instructions='Count?';criteria=$criteria}; second=@{instructions='Second?';criteria=$criteria} }
        $inputJson = @{state='test';questions=$questions} | ConvertTo-Json -Depth 8 -Compress
        $answers = & (Join-Path $scripts "workshop-jev-$type.ps1") -InputJson $inputJson -Endpoint $endpoint | ConvertFrom-Json -AsHashtable
        Assert ($answers.get_Count() -eq 3 -and $answers['Keys'].type -eq $type -and $answers['Count'].type -eq $type -and $answers.second.type -eq $type) "$type reserved-name batch failed."
        if ($type -eq 'choice') { Assert ($answers['Keys'].choice -eq 'Keys' -and $answers['Count'].choice -eq 'Count') 'Choice option keys collided with dictionary properties.' }
        $questions.Remove('Count')
        $questions.Remove('second')
        $inputJson = @{state='test';questions=$questions} | ConvertTo-Json -Depth 8 -Compress
        $answers = & (Join-Path $scripts "workshop-jev-$type.ps1") -InputJson $inputJson -Endpoint $endpoint | ConvertFrom-Json -AsHashtable
        Assert ($answers.Count -eq 1) "$type single failed."
    }
    foreach ($type in @('noul', 'score')) {
        foreach ($invalid in @($false, '0.5')) {
            $global:invalidNumeric = $invalid
            $criteria = if ($type -eq 'score') { @('Low','High') } else { @{true='Yes';false='No'} }
            $inputJson = @{state='test';questions=@{sample=@{instructions='Evaluate';criteria=$criteria}}} | ConvertTo-Json -Depth 8 -Compress
            $result = & (Join-Path $scripts "workshop-jev-$type.ps1") -InputJson $inputJson -Endpoint $endpoint 2>$null
            Assert (-not $? -and -not $result) "$type accepted nonnumeric answer $invalid."
        }
    }
    $global:invalidNumeric = $null

    $route = Join-Path $scripts 'workshop-route-job.ps1'
    $requirements = 'Read-only evidence gathering; no edits, code review, or delegation.'
    $selection = & $route -Kind agent -Assignment 'Read-only requirements investigation' -Requirements $requirements -CatalogPath $catalogPath -Endpoint $endpoint | ConvertFrom-Json
    Assert ($selection.status -eq 'selected' -and $selection.resource -eq 'workshop-surveyor' -and $selection.model -eq 'model-a' -and $selection.reasoning -eq 'high') "Usable selection changed: $($selection | ConvertTo-Json -Compress)"
    Assert ($global:lastRequest.questions.resource.criteria.Count -eq $catalog.agents.Count) 'JEV did not receive every agent.'
    Assert ($global:lastRequest.questions.model_reasoning.criteria.Count -eq 3) 'JEV did not receive every available model/effort.'
    Assert ($global:lastRequest.state.requirements -eq $requirements -and $global:lastRequest.state.assignment -eq 'Read-only requirements investigation') 'Task requirements were not passed unchanged.'
    foreach ($agent in $catalog.agents) { Assert ($global:lastRequest.questions.resource.criteria[$agent.name].Contains((Get-Content $agent.path -Raw))) 'JEV did not receive full role boundaries.' }
    $global:nonDelegatableSelection = $true
    $callsBefore = $global:apiCalls
    $fallback = & $route -Kind agent -Assignment 'Clean up task resources' -Requirements 'Release owned resources and preserve unrelated work; no orchestration.' -CatalogPath $catalogPath -Endpoint $endpoint | ConvertFrom-Json
    Assert ($fallback.status -eq 'fallback' -and $fallback.reason -eq 'Unusable agent choice: workshop-test-bench is not delegatable.') 'Non-delegatable selection did not return the original fallback reason.'
    Assert ($global:apiCalls -eq $callsBefore + 1) 'Non-delegatable selection retried or rerouted.'
    Assert ($global:lastRequest.questions.resource.criteria.Count -eq $catalog.agents.Count -and $global:lastRequest.questions.resource.criteria.ContainsKey('workshop-test-bench') -and $global:lastRequest.questions.resource.criteria.ContainsKey('workshop-foreman')) 'Non-delegatable agents were filtered from the full payload.'
    foreach ($agent in $catalog.agents) { Assert ($global:lastRequest.questions.resource.criteria[$agent.name].Contains((Get-Content $agent.path -Raw))) 'JEV did not receive full definitions for every agent.' }
    Assert ($global:lastRequest.questions.resource.criteria['workshop-test-bench'] -match 'Delegatable: False' -and $global:lastRequest.questions.resource.instructions -match 'Agents marked Delegatable: False are never eligible as delegated workers') 'Agent prompt omitted the metadata boundary.'
    Assert ($global:lastRequest.questions.model_reasoning.criteria.Count -eq 3) 'Routing changed the complete model/effort list.'
    foreach ($model in @($catalog.models | Where-Object available)) {
        foreach ($effort in $model.reasoning) { Assert ($global:lastRequest.questions.model_reasoning.criteria.ContainsKey("$($model.name)/$effort")) 'Routing omitted an available model/effort.' }
    }
    $global:nonDelegatableSelection = $false
    $global:implementSelection = $true
    $selection = & $route -Kind agent -Assignment 'Fix a scoped implementation defect' -Requirements 'Implement the scoped change and run relevant checks; no review or publication.' -CatalogPath $catalogPath -Endpoint $endpoint | ConvertFrom-Json
    Assert ($selection.status -eq 'selected' -and $selection.resource -eq 'workshop-craftsman') 'A different usable JEV agent choice was rejected or changed.'
    $global:implementSelection = $false
    $global:unknownResource = $true
    $fallback = & $route -Kind agent -Assignment 'Read-only' -Requirements $requirements -CatalogPath $catalogPath -Endpoint $endpoint | ConvertFrom-Json
    Assert ($fallback.status -eq 'fallback') 'Unavailable resource selection was accepted.'
    $global:unknownResource = $false
    $global:badModel = $true
    $fallback = & $route -Kind agent -Assignment 'Read-only' -Requirements $requirements -CatalogPath $catalogPath -Endpoint $endpoint | ConvertFrom-Json
    Assert ($fallback.status -eq 'fallback') 'Unsupported model/effort selection was accepted.'
    $global:badModel = $false
    $global:malformed = $true
    $fallback = & $route -Kind agent -Assignment 'Read-only' -Requirements $requirements -CatalogPath $catalogPath -Endpoint $endpoint | ConvertFrom-Json
    Assert ($fallback.status -eq 'fallback') 'Malformed answer was accepted.'
    $global:malformed = $false
    $global:skillSelection = $true
    $skill = & $route -Kind skill -Assignment 'Choose a workflow support skill' -Requirements 'Help coordinate a scoped development workflow.' -CatalogPath $catalogPath -Endpoint $endpoint | ConvertFrom-Json
    Assert ($skill.status -eq 'selected' -and $skill.resource -eq 'workshop-dispatch' -and $global:lastRequest.questions.resource.criteria.Count -eq $catalog.skills.Count) 'Skill routing did not use all skills.'
    $global:skillSelection = $false
    $global:apiFailure = $true
    $fallback = & $route -Kind agent -Assignment 'Read-only' -Requirements $requirements -CatalogPath $catalogPath -Endpoint $endpoint 2>$null | ConvertFrom-Json
    Assert ($fallback.status -eq 'fallback') 'API failure did not fall back.'
    Assert ($fallback.reason -eq 'TypeSafe request failed: mock API unavailable') 'Routing lost the original helper error from its structured fallback.'
    $global:apiFailure = $false
    Remove-Item Env:\TYPESAFE_API_KEY
    $fallback = & $route -Kind agent -Assignment 'Read-only' -Requirements $requirements -CatalogPath $catalogPath -Endpoint $endpoint 2>$null | ConvertFrom-Json
    Assert ($fallback.status -eq 'fallback') 'Missing key did not fall back.'
    'PASS: discovery, source-authoritative delegatability, ratings, failed refresh, reserved-name batches, numeric answers, complete route choices, generic delegation boundary, and fallback.'
} finally {
    $env:TYPESAFE_API_KEY = $savedKey
    Remove-Item Function:\codex,Function:\Invoke-RestMethod -ErrorAction SilentlyContinue
    if (([IO.Path]::GetFullPath($temporary)).StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
