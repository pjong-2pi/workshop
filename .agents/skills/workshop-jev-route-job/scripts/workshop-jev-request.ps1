function Invoke-WorkshopJev {
    param([System.Collections.IDictionary]$Request, [string]$ExpectedType, [string]$Endpoint = 'https://api.typesafe.ai/v1/systemone')
    if (-not $env:TYPESAFE_API_KEY) { throw 'TYPESAFE_API_KEY is unavailable.' }
    if ($Endpoint -ne 'https://api.typesafe.ai/v1/systemone' -and ([uri]$Endpoint).Host -notin @('localhost', '127.0.0.1', '[::1]')) { throw 'Endpoint override must be local.' }
    if (-not $Request.Contains('state') -or $Request.questions -isnot [System.Collections.IDictionary] -or -not $Request.questions.get_Count()) { throw 'Input requires state and named questions.' }
    $questions = @{}
    foreach ($item in $Request.questions.GetEnumerator()) {
        $key = $item.Key
        $question = $item.Value
        if (-not $question.instructions) { throw "Question '$key' requires instructions." }
        $entry = @{ type = $ExpectedType; instructions = $question.instructions }
        if ($question.ContainsKey('criteria')) { $entry.criteria = $question.criteria }
        $questions[$key] = $entry
    }
    $body = @{ model = 'jev-latest'; state = $Request.state; questions = $questions } | ConvertTo-Json -Depth 30 -Compress
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
    }
    $response.answers
}
