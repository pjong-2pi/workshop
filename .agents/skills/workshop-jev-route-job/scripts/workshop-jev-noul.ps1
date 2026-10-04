[CmdletBinding()]
param([Parameter(Mandatory)][string]$InputJson, [string]$Endpoint = 'https://api.typesafe.ai/v1/systemone')
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'workshop-jev-request.ps1')
    Invoke-WorkshopJev -InputJson $InputJson -ExpectedType 'noul' -Endpoint $Endpoint
} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }
