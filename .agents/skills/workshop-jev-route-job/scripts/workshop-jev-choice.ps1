[CmdletBinding()]
param([Parameter(Mandatory)][string]$InputJson, [string]$Endpoint = 'https://api.typesafe.ai/v1/systemone')
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'workshop-jev-request.ps1')
    $request = ConvertFrom-Json -InputObject $InputJson -AsHashtable
    foreach ($item in $request.questions.GetEnumerator()) {
        $criteria = $item.Value.criteria
        if ($criteria -isnot [System.Collections.IDictionary] -or $criteria.get_Count() -lt 2 -or $criteria.get_Count() -gt 255) { throw "Question '$($item.Key)' needs 2 to 255 choice options." }
    }
    $answers = Invoke-WorkshopJev -Request $request -ExpectedType 'choice' -Endpoint $Endpoint
    foreach ($item in $request.questions.GetEnumerator()) {
        $choice = $answers.PSObject.Properties[$item.Key].Value.choice
        if ($choice -isnot [string] -or -not $item.Value.criteria.Contains($choice)) { throw "TypeSafe chose an unknown option for '$($item.Key)'." }
    }
    $answers | ConvertTo-Json -Depth 30 -Compress
} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }
