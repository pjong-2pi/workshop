$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$skills = @('workshop-foreman', 'workshop-setup', 'workshop-clear-bench', 'workshop-stocktake', 'github-create-pr', 'github-check-pr', 'github-merge-pr')
$profiles = @('master-craftsman', 'inspector', 'master-inspector', 'pr-worker')
$required = @('AGENTS.md', 'README.md', 'WORKFLOWS.md', '.gitignore', '.codex/config.toml', 'catalog/models.md',
    'scripts/setup.ps1', 'scripts/check-environment.ps1', 'scripts/jev-routing.ps1', 'tests/run.ps1',
    '.agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1',
    '.agents/skills/workshop-stocktake/scripts/update-model-catalog.ps1',
    'evals/skill-evals.json', 'evals/workshop-foreman.md')
$required += $skills | ForEach-Object { ".agents/skills/$_/SKILL.md" }
$required += $profiles | ForEach-Object { ".codex/agents/$_.toml" }
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $path) -PathType Leaf)) { throw "Missing core file: $path" }
}
foreach ($skill in $skills) {
    $content = Get-Content -LiteralPath (Join-Path $root ".agents/skills/$skill/SKILL.md") -Raw
    if ($content -notmatch "(?s)^---\r?\nname: $skill\r?\ndescription: [^\r\n]+\r?\n---") { throw "Invalid skill metadata: $skill" }
}
foreach ($profile in $profiles) {
    $content = Get-Content -LiteralPath (Join-Path $root ".codex/agents/$profile.toml") -Raw
    foreach ($field in @('name', 'description', 'sandbox_mode', 'model', 'model_reasoning_effort')) {
        if ($content -notmatch ('(?m)^{0}\s*=\s*"[^"]+"\s*$' -f $field)) { throw "Invalid $field metadata: $profile" }
    }
    if ($content -notmatch '(?s)developer_instructions\s*=\s*""".+?"""') { throw "Missing profile instructions: $profile" }
    $sandbox = if ($profile -in @('inspector', 'master-inspector')) { 'read-only' } else { 'workspace-write' }
    if ($content -notmatch ('sandbox_mode\s*=\s*"{0}"' -f $sandbox)) { throw "Unexpected sandbox: $profile" }
}

# Parse scripts without executing external tools or imposing implementation details.
$scriptPaths = @('scripts', 'tests', '.agents/skills') | ForEach-Object { Get-ChildItem -LiteralPath (Join-Path $root $_) -Filter *.ps1 -Recurse }
foreach ($script in $scriptPaths) {
    $tokens = $null; $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw "PowerShell parse errors in $($script.FullName): $parseErrors" }
}
$config = Get-Content -LiteralPath (Join-Path $root '.codex/config.toml') -Raw
if ($config -notmatch 'sandbox_mode\s*=\s*"workspace-write"' -or $config -match 'danger-full-access|approval_policy') { throw 'Unsafe Workshop sandbox configuration.' }

$definitions = Get-Content -LiteralPath (Join-Path $root 'evals/skill-evals.json') -Raw | ConvertFrom-Json
if ($definitions.version -ne 1 -or $definitions.executable -or -not $definitions.evaluations) { throw 'Invalid evaluation metadata.' }
$ids = @($definitions.evaluations.id)
if (@($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'Duplicate evaluation IDs.' }
foreach ($evaluation in $definitions.evaluations) {
    foreach ($field in @('id', 'prompt', 'fixture', 'pass_condition', 'trace')) {
        if ([string]::IsNullOrWhiteSpace($evaluation.$field)) { throw "Incomplete evaluation: $field" }
    }
    if ($evaluation.expect.skill_invoked -isnot [array] -or $evaluation.expect.skill_not_invoked -isnot [array]) { throw 'Invalid evaluation expectations.' }
}

# Check durable authority boundaries by meaning, not exact prose or CLI layout.
$instructions = Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw
$foreman = Get-Content -LiteralPath (Join-Path $root '.agents/skills/workshop-foreman/SKILL.md') -Raw
$merge = Get-Content -LiteralPath (Join-Path $root '.agents/skills/github-merge-pr/SKILL.md') -Raw
if ($instructions -notmatch '(?is)minimum.*orchestration.*testing.*review' -or $foreman -notmatch '(?i)review.*(conditional|risk)' -or $merge -notmatch '(?i)explicit.*(user )?authorization') { throw 'Missing proportionality or authorization boundary.' }
$cleanup = Get-Content -LiteralPath (Join-Path $root '.agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1') -Raw
if ($cleanup -match '(?im)^\s*&?\s*herdr worktree remove[^\r\n]*--force' -or $cleanup -match '(?im)^\s*(Remove-Item|git.*branch.*--delete)') { throw 'Cleanup must not force deletion or delete branches.' }
$mergeCommands = $merge -split '\r?\n' | Where-Object { $_ -match '^gh pr merge ' }
if ($mergeCommands -match '--admin|--auto|--delete-branch') { throw 'Merge must not bypass protection or delete branches.' }
Write-Host 'Workshop static validation passed.'
