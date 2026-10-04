function Invoke-WorkshopJev {
    param([string]$InputJson, [string]$ExpectedType, [string]$Endpoint = 'https://api.typesafe.ai/v1/systemone')
    if (-not $env:TYPESAFE_API_KEY) { throw 'TYPESAFE_API_KEY is unavailable.' }
    if ($Endpoint -ne 'https://api.typesafe.ai/v1/systemone' -and ([uri]$Endpoint).Host -notin @('localhost', '127.0.0.1', '[::1]')) { throw 'Endpoint override must be local.' }
    $inputData = ConvertFrom-Json -InputObject $InputJson -AsHashtable
    if (-not $inputData.ContainsKey('state') -or $inputData.questions -isnot [System.Collections.IDictionary] -or -not $inputData.questions.get_Count()) { throw 'Input requires state and named questions.' }
    $questions = @{}
    foreach ($item in $inputData.questions.GetEnumerator()) {
        $key = $item.Key
        $question = $item.Value
        if (-not $question.instructions) { throw "Question '$key' requires instructions." }
        $entry = @{ type = $ExpectedType; instructions = $question.instructions }
        if ($question.ContainsKey('criteria')) { $entry.criteria = $question.criteria }
        if ($ExpectedType -eq 'choice' -and ($entry.criteria -isnot [System.Collections.IDictionary] -or $entry.criteria.get_Count() -lt 2 -or $entry.criteria.get_Count() -gt 255)) { throw "Question '$key' needs 2 to 255 choice options." }
        if ($ExpectedType -eq 'score' -and ($entry.criteria -isnot [array] -or $entry.criteria.Count -lt 2 -or $entry.criteria.Count -gt 10)) { throw "Question '$key' needs 2 to 10 score levels." }
        $questions[$key] = $entry
    }
    $body = @{ model = 'jev-latest'; state = $inputData.state; questions = $questions } | ConvertTo-Json -Depth 30 -Compress
    try {
        $response = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers @{ Authorization = "Bearer $env:TYPESAFE_API_KEY" } -ContentType 'application/json' -Body $body -TimeoutSec 20 -ErrorAction Stop
    } catch {
        throw "TypeSafe request failed: $($_.Exception.Message)"
    }
    if (-not $response.answers) { throw 'TypeSafe response has no answers.' }
    foreach ($item in $questions.GetEnumerator()) {
        $key = $item.Key
        $answer = $response.answers.PSObject.Properties[$key].Value
        if (-not $answer -or $answer.type -ne $ExpectedType) { throw "TypeSafe response is missing a valid '$key' answer." }
        if ($ExpectedType -eq 'choice' -and ($answer.choice -isnot [string] -or -not $questions[$key].criteria.Contains($answer.choice))) { throw "TypeSafe chose an unknown option for '$key'." }
        if ($ExpectedType -in @('noul', 'score')) {
            $value = if ($ExpectedType -eq 'noul') { $answer.noul } else { $answer.score }
            $maximum = if ($ExpectedType -eq 'noul') { 1 } else { $questions[$key].criteria.Count - 1 }
            if (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [double] -and $value -isnot [decimal]) -or $value -lt 0 -or $value -gt $maximum) { throw "TypeSafe returned invalid $ExpectedType for '$key'." }
        }
    }
    $response.answers | ConvertTo-Json -Depth 30 -Compress
}
