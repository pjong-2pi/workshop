function Test-JevText {
    param([string]$Text, [int]$MaximumLength)

    -not [string]::IsNullOrWhiteSpace($Text) -and $Text.Length -le $MaximumLength -and
        $Text -notmatch '[\r\n]' -and $Text -match '^[\p{L}\p{N}][\p{L}\p{N} .,;:()&''""/@_+=|\\-]*$'
}

function Get-JevChoice {
    param(
        [Parameter(Mandatory)][string]$State,
        [Parameter(Mandatory)][hashtable]$Choices,
        [Parameter(Mandatory)][string]$Instructions,
        [ValidateRange(0, 1)][double]$ConfidenceFloor = 0.40,
        [scriptblock]$Request
    )

    try {
        if (-not (Test-JevText $State 160) -or -not (Test-JevText $Instructions 320) -or -not $Choices.Count) { throw 'Unsafe JEV input.' }
        foreach ($choice in $Choices.Keys) {
            if ($choice -isnot [string] -or -not (Test-JevText $choice 80) -or -not (Test-JevText ([string]$Choices[$choice]) 320)) { throw 'Unsafe JEV choice.' }
        }
        $body = @{ state = $State; model = 'jev-latest'; questions = @{ choice = @{ type = 'choice'; instructions = $Instructions; criteria = $Choices } } } | ConvertTo-Json -Depth 8 -Compress
        if ($Request) { $response = & $Request $body } else { $response = Invoke-RestMethod -Method Post -Uri 'https://api.typesafe.ai/v1/systemone' -Headers @{ Authorization = "Bearer $env:TYPESAFE_API_KEY" } -ContentType 'application/json' -Body $body -TimeoutSec 5 }
        $answer = $response.answers.choice
        $numericConfidence = $answer.confidence -is [byte] -or $answer.confidence -is [sbyte] -or $answer.confidence -is [int16] -or $answer.confidence -is [uint16] -or $answer.confidence -is [int32] -or $answer.confidence -is [uint32] -or $answer.confidence -is [int64] -or $answer.confidence -is [uint64] -or $answer.confidence -is [single] -or $answer.confidence -is [double] -or $answer.confidence -is [decimal]
        if (-not $answer -or $answer.type -ne 'choice' -or $answer.choice -isnot [string] -or $answer.choice -cnotin $Choices.Keys -or -not $numericConfidence) { throw 'Invalid JEV response.' }
        $confidence = [double]$answer.confidence
        if ([double]::IsNaN($confidence) -or [double]::IsInfinity($confidence) -or $confidence -lt $ConfidenceFloor -or $confidence -gt 1) { throw 'Unaccepted JEV confidence.' }
        [PSCustomObject]@{ choice = $answer.choice; confidence = $confidence }
    } catch { $null }
}
