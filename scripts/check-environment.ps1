$ErrorActionPreference = 'Stop'

$missing = @('git', 'gh', 'codex', 'herdr') | Where-Object {
    -not (Get-Command $_ -ErrorAction SilentlyContinue)
}

if ($missing) {
    throw "Missing required command(s): $($missing -join ', ')"
}

$gitName = git config user.name
$gitEmail = git config user.email
if (-not $gitName -or -not $gitEmail) {
    throw 'Git user.name and user.email must be configured before committing.'
}

git --version
Write-Host "Git author: $gitName <$gitEmail>"
gh --version | Select-Object -First 1
codex --version
herdr --version
