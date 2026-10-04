[CmdletBinding()]
param([Parameter(Mandatory)][string]$InputJson, [string]$Endpoint = 'https://api.typesafe.ai/v1/systemone')
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'workshop-jev-request.ps1')
    $request = ConvertFrom-Json -InputObject $InputJson -AsHashtable
    foreach ($item in $request.questions.GetEnumerator()) {
        $criteria = $item.Value.criteria
        if ($criteria -isnot [array] -or $criteria.Count -lt 2 -or $criteria.Count -gt 10) { throw "Question '$($item.Key)' needs 2 to 10 score levels." }
    }
    $answers = Invoke-WorkshopJev -Request $request -ExpectedType 'score' -Endpoint $Endpoint
    foreach ($item in $request.questions.GetEnumerator()) {
        $value = $answers.PSObject.Properties[$item.Key].Value.score
        if (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [double] -and $value -isnot [decimal]) -or $value -lt 0 -or $value -gt ($item.Value.criteria.Count - 1)) { throw "TypeSafe returned invalid score for '$($item.Key)'." }
    }
    $answers | ConvertTo-Json -Depth 30 -Compress
} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }
