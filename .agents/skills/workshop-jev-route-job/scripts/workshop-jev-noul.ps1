[CmdletBinding()]
param([Parameter(Mandatory)][string]$InputJson, [string]$Endpoint = 'https://api.typesafe.ai/v1/systemone')
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'workshop-jev-request.ps1')
    $request = ConvertFrom-Json -InputObject $InputJson -AsHashtable
    $answers = Invoke-WorkshopJev -Request $request -ExpectedType 'noul' -Endpoint $Endpoint
    foreach ($item in $request.questions.GetEnumerator()) {
        $value = $answers.PSObject.Properties[$item.Key].Value.noul
        if (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [double] -and $value -isnot [decimal]) -or $value -lt 0 -or $value -gt 1) { throw "TypeSafe returned invalid noul for '$($item.Key)'." }
    }
    $answers | ConvertTo-Json -Depth 30 -Compress
} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }
