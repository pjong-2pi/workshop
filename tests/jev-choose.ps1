$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/jev-choose.ps1')

function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }
function New-Response([string]$Choice, [object]$Confidence = 0.9) { [PSCustomObject]@{ answers = [PSCustomObject]@{ choice = [PSCustomObject]@{ type = 'choice'; choice = $Choice; confidence = $Confidence } } } }

$state = 'safe summarized work'
$choices = @{ small = 'Fast \| affordable choice.'; large = 'More capable choice.' }
$instructions = 'Choose the lowest resource option likely to complete the work.'
$calls = [Collections.Generic.List[object]]::new()
$accepted = Get-JevChoice -State $state -Choices $choices -Instructions $instructions -Request { param($body) $calls.Add((ConvertFrom-Json $body)); New-Response small }
Assert-True ($accepted.choice -eq 'small' -and $accepted.confidence -eq 0.9 -and $calls.Count -eq 1) 'An allowed confident answer must be returned from one request.'
Assert-True ($calls[0].state -ceq $state -and $calls[0].model -eq 'jev-latest' -and $calls[0].questions.choice.type -eq 'choice' -and $calls[0].questions.choice.instructions -ceq $instructions -and $calls[0].questions.choice.criteria.small -ceq $choices.small -and $calls[0].questions.choice.criteria.large -ceq $choices.large) 'The request must preserve supplied state, instructions, and criteria.'

$outside = Get-JevChoice -State 'safe summarized work' -Choices @{ small = 'Small choice.' } -Instructions 'Choose one.' -Request { param($body) New-Response outside }
$caseMismatch = Get-JevChoice -State 'safe summarized work' -Choices @{ small = 'Small choice.' } -Instructions 'Choose one.' -Request { param($body) New-Response SMALL }
$low = Get-JevChoice -State 'safe summarized work' -Choices @{ small = 'Small choice.' } -Instructions 'Choose one.' -Request { param($body) New-Response small 0.39 }
$wrongType = Get-JevChoice -State 'safe summarized work' -Choices @{ small = 'Small choice.' } -Instructions 'Choose one.' -Request { param($body) New-Response small $true }
$missing = Get-JevChoice -State 'safe summarized work' -Choices @{ small = 'Small choice.' } -Instructions 'Choose one.' -Request { param($body) [PSCustomObject]@{ answers = [PSCustomObject]@{} } }
$malformedRequest = $false
$malformed = Get-JevChoice -State "unsafe`nstate" -Choices @{ small = 'Small choice.' } -Instructions 'Choose one.' -Request { param($body) $script:malformedRequest = $true; New-Response small }
$networkFailure = Get-JevChoice -State 'safe summarized work' -Choices @{ small = 'Small choice.' } -Instructions 'Choose one.' -Request { throw 'network failure' }
$malformedResponse = Get-JevChoice -State 'safe summarized work' -Choices @{ small = 'Small choice.' } -Instructions 'Choose one.' -Request { param($body) '{bad json' | ConvertFrom-Json }
Assert-True ($null -eq $outside -and $null -eq $caseMismatch -and $null -eq $low -and $null -eq $wrongType -and $null -eq $missing -and $null -eq $malformed -and -not $malformedRequest -and $null -eq $networkFailure -and $null -eq $malformedResponse) 'Invalid choices, confidence, answers, input, and responses must return no result without unsafe requests.'
Write-Host 'Workshop JEV choice tests passed.'
