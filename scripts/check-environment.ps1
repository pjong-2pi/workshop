$ErrorActionPreference = 'Continue'

$problems = [System.Collections.Generic.List[string]]::new()
Write-Host "OS: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
Write-Host "Shell: PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"

$commands = @{}
foreach ($name in @('git', 'gh', 'codex', 'herdr')) {
    $commands[$name] = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $commands[$name]) {
        $problems.Add("Missing required command: $name")
    }
}

if ($commands.git) {
    git --version
    if ($LASTEXITCODE -ne 0) { $problems.Add('Git could not report its version.') }
    $gitName = git config user.name
    $gitEmail = git config user.email
    if ($gitName -and $gitEmail) {
        Write-Host "Git author: $gitName <$gitEmail>"
    } else {
        $problems.Add('Git user.name and user.email must be configured before committing.')
    }
}

if ($commands.gh) {
    gh --version | Select-Object -First 1
    if ($LASTEXITCODE -ne 0) { $problems.Add('GitHub CLI could not report its version.') }
    gh auth status --active --hostname github.com
    if ($LASTEXITCODE -ne 0) {
        $problems.Add('GitHub CLI has no active authenticated account for github.com.')
    }
}

if ($commands.codex) {
    codex --version
    if ($LASTEXITCODE -ne 0) { $problems.Add('Codex could not report its version.') }
}
if ($commands.herdr) {
    herdr --version
    if ($LASTEXITCODE -ne 0) { $problems.Add('Herdr could not report its version.') }
}

if ($env:HERDR_ENV -eq '1') {
    Write-Host 'Herdr environment: compatible (HERDR_ENV=1)'
} else {
    $problems.Add('Run Workshop from a Herdr environment with HERDR_ENV=1.')
}

if ($problems.Count -gt 0) {
    Write-Host 'Problems:'
    $problems | ForEach-Object { Write-Host "- $_" }
    exit 1
}

Write-Host 'Workshop environment is ready.'
