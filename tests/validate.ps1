$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$required = @(
    'AGENTS.md', 'README.md', 'WORKFLOWS.md', '.gitignore',
    '.agents/skills/workshop-foreman/SKILL.md',
    '.agents/skills/github-create-pr/SKILL.md',
    '.agents/skills/github-check-pr/SKILL.md',
    '.agents/skills/github-merge-pr/SKILL.md',
    '.agents/skills/workshop-setup/SKILL.md',
    '.agents/skills/workshop-clear-bench/SKILL.md',
    '.agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1',
    '.codex/agents/master-craftsman.toml',
    '.codex/agents/inspector.toml',
    '.codex/agents/master-inspector.toml',
    'scripts/check-environment.ps1', 'scripts/setup.ps1', 'scripts/jev-routing.ps1', 'tests/run.ps1', 'tests/jev-routing.ps1',
    'evals/workshop-foreman.md', 'evals/skill-evals.json'
)
$missing = $required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf) }
if ($missing) { throw "Missing required file(s): $($missing -join ', ')" }

foreach ($name in @('workshop-foreman', 'github-create-pr', 'github-check-pr', 'github-merge-pr', 'workshop-setup', 'workshop-clear-bench')) {
    $content = Get-Content -LiteralPath (Join-Path $root ".agents/skills/$name/SKILL.md") -Raw
    if ($content -notmatch "(?s)^---\r?\nname: $name\r?\ndescription: .+?\r?\n---") {
        throw "$name has invalid or incomplete frontmatter."
    }
}

foreach ($profile in @('master-craftsman.toml', 'inspector.toml', 'master-inspector.toml')) {
    $content = Get-Content -LiteralPath (Join-Path $root ".codex/agents/$profile") -Raw
    foreach ($field in @('name', 'description', 'sandbox_mode', 'model', 'model_reasoning_effort', 'developer_instructions')) {
        if ($content -notmatch "(?m)^$field\s*=") { throw "$profile is missing $field." }
    }
}

$setup = Get-Content -LiteralPath (Join-Path $root 'scripts/setup.ps1') -Raw
if ($setup -match 'SetEnvironmentVariable') { throw 'Setup must not persist environment variables.' }

$definitions = Get-Content -LiteralPath (Join-Path $root 'evals/skill-evals.json') -Raw | ConvertFrom-Json
if ($definitions.version -ne 1 -or $definitions.executable -or $null -eq $definitions.evaluations) { throw 'Skill eval definitions have an invalid schema.' }
$expected = @('explicit-setup', 'uninitialized-clone', 'foreman-task', 'pr-review', 'routine-development', 'initialized-workshop', 'clear-completed-bench', 'jev-pr-review', 'jev-substantive-task', 'jev-trivial-task', 'jev-fallback')
foreach ($id in $expected) {
    $evaluation = @($definitions.evaluations | Where-Object id -eq $id)
    if ($evaluation.Count -ne 1 -or [string]::IsNullOrWhiteSpace($evaluation[0].prompt) -or
        [string]::IsNullOrWhiteSpace($evaluation[0].pass_condition) -or
        [string]::IsNullOrWhiteSpace($evaluation[0].trace) -or $null -eq $evaluation[0].expect -or
        $evaluation[0].expect.skill_invoked -isnot [System.Array] -or
        $evaluation[0].expect.skill_not_invoked -isnot [System.Array]) {
        throw "Skill eval '$id' is incomplete."
    }
}
if (@($definitions.evaluations).Count -ne $expected.Count) { throw 'Skill eval definitions contain unexpected scenarios.' }

foreach ($id in @('explicit-setup', 'uninitialized-clone')) {
    $evaluation = $definitions.evaluations | Where-Object id -eq $id
    if ($evaluation.expect.skill_invoked -notcontains 'workshop-setup') { throw "Skill eval '$id' must invoke workshop-setup." }
}
foreach ($id in @('foreman-task', 'pr-review', 'routine-development', 'initialized-workshop')) {
    $evaluation = $definitions.evaluations | Where-Object id -eq $id
    if ($evaluation.expect.skill_not_invoked -notcontains 'workshop-setup') { throw "Skill eval '$id' must avoid workshop-setup." }
}

function Assert-CommandContract {
    param([string] $Content, [string] $Expected, [string] $Name)
    if (-not $Content.Contains($Expected)) { throw "$Name is missing its command contract." }
}

$create = Get-Content -LiteralPath (Join-Path $root '.agents/skills/github-create-pr/SKILL.md') -Raw
foreach ($command in @('gh pr create --repo "$REPO" --base "$BASE" --head "$BRANCH"', 'gh pr view "$BRANCH" --repo "$REPO" --json', 'headRefOid', 'test "$HEAD_SHA" = "$REMOTE_SHA"')) {
    Assert-CommandContract $create $command 'github-create-pr'
}

$check = Get-Content -LiteralPath (Join-Path $root '.agents/skills/github-check-pr/SKILL.md') -Raw
foreach ($command in @('gh pr view "$PR" --repo "$REPO" --json', 'gh pr diff "$PR" --repo "$REPO" --name-only', 'gh pr checks "$PR" --repo "$REPO" --required --json', 'EXPECTED_SHA')) {
    Assert-CommandContract $check $command 'github-check-pr'
}

$merge = Get-Content -LiteralPath (Join-Path $root '.agents/skills/github-merge-pr/SKILL.md') -Raw
foreach ($contract in @('gh repo view "$REPO" --json', 'Squash when neither specifies a method and the repository enables squash.', 'headRefOid', 'Never add `--admin`, `--auto`, or `--delete-branch`')) {
    Assert-CommandContract $merge $contract 'github-merge-pr'
}
$mergeCommands = @($merge -split "\r?\n" | Where-Object { $_.TrimStart().StartsWith('gh pr merge ') })
if ($mergeCommands.Count -ne 3) { throw "github-merge-pr must have exactly three merge commands; found $($mergeCommands.Count)." }
foreach ($command in $mergeCommands) {
    Assert-CommandContract $command '--repo "$REPO"' 'github-merge-pr'
    Assert-CommandContract $command '--match-head-commit "$SHA"' 'github-merge-pr'
    if ($command -match '(?:^|\s)--(?:admin|auto|delete-branch)(?:\s|$)') { throw 'github-merge-pr contains a prohibited merge flag.' }
}

foreach ($contract in @("Join-Path `$root 'projects'", "Join-Path `$root '.local'", "Join-Path `$local 'setup-complete'", 'New-Item -ItemType Directory', 'New-Item -ItemType File', 'Workshop setup verification failed.', 'check-environment.ps1', 'InstallCodexIntegration', 'herdr integration install codex')) {
    Assert-CommandContract $setup $contract 'workshop-setup'
}

$foreman = Get-Content -LiteralPath (Join-Path $root '.agents/skills/workshop-foreman/SKILL.md') -Raw
foreach ($command in @('herdr worktree create', 'herdr agent start', 'herdr agent get', 'herdr agent prompt', 'herdr agent read', 'herdr worktree remove', 'Verify `HERDR_ENV=1`.')) {
    Assert-CommandContract $foreman $command 'workshop-foreman'
}
foreach ($id in @('jev-pr-review', 'jev-substantive-task', 'jev-trivial-task', 'jev-fallback')) {
    $routing = ($definitions.evaluations | Where-Object id -eq $id).routing
    if ($null -eq $routing -or @($routing.PSObject.Properties.Name | Sort-Object) -join ',' -ne 'agent,delegate,model,skill') { throw "Skill eval '$id' must define exactly the routing fields." }
    if ($id -eq 'jev-fallback') {
        if ($null -ne $routing.skill -or $null -ne $routing.agent -or $null -ne $routing.model -or $null -ne $routing.delegate) { throw "Skill eval '$id' must leave unavailable routing fields null." }
    } elseif ($routing.skill -isnot [string] -or $routing.agent -isnot [string] -or $routing.model -isnot [string] -or $routing.delegate -isnot [bool]) {
        throw "Skill eval '$id' has incomplete routing expectations."
    }
}
foreach ($contract in @('Get-WorkshopJevDecision', 'scripts/jev-routing.ps1', 'JEV is advisory only', 'authoritative for intake')) {
    Assert-CommandContract $foreman $contract 'workshop-foreman'
}
$jev = Get-Content -LiteralPath (Join-Path $root 'scripts/jev-routing.ps1') -Raw
foreach ($contract in @('https://api.typesafe.ai/v1/systemone', 'TYPESAFE_API_KEY', 'ConvertTo-Json', 'Invoke-RestMethod', 'TimeoutSec 5', '$floor = 0.40', 'Test-JevChoice', 'foreman-fallback', 'jev-routing.jsonl')) {
    Assert-CommandContract $jev $contract 'jev-routing'
}
$cleanupEvaluation = $definitions.evaluations | Where-Object id -eq 'clear-completed-bench'
if ($cleanupEvaluation.expect.skill_invoked -notcontains 'workshop-clear-bench') { throw "Skill eval 'clear-completed-bench' must invoke workshop-clear-bench." }

$cleanup = Get-Content -LiteralPath (Join-Path $root '.agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1') -Raw
foreach ($contract in @('herdr workspace get $Workspace', "`$response.id -ne 'cli:workspace:get'", 'workspace_id -cne $Workspace', 'worktree.repo_root', 'herdr worktree list --cwd $Repository --trust-repository', 'ConvertFrom-Json -ErrorAction Stop', "`$response.id -ne 'cli:worktree:list'", '$response.result.type -ne', '$response.result.worktrees', 'open_workspace_id -ceq $Workspace', 'function Assert-CleanWorktree', 'git -C $Path status --porcelain', 'Assert-CleanWorktree $worktreePath', 'herdr worktree remove --workspace $Workspace --trust-repository', 'Provide exactly one of -IntegrationEvidence or -DiscardAuthorization.', 'Recheck immediately before the only mutation.')) {
    Assert-CommandContract $cleanup $contract 'workshop-clear-bench'
}
if ($cleanup -match '(?m)^.*herdr worktree remove.*--force' -or $cleanup -match '(?i)branch.*delete') { throw 'workshop-clear-bench must not force removal or delete branches.' }
$deprecatedParameter = 'Worktree' + 'Path'
if ($cleanup -cmatch $deprecatedParameter) { throw 'workshop-clear-bench must resolve its worktree path from Herdr.' }

$environment = Get-Content -LiteralPath (Join-Path $root 'scripts/check-environment.ps1') -Raw
foreach ($command in @('RuntimeInformation', 'PSVersionTable', 'git config user.name', 'git config user.email', 'gh auth status --active --hostname github.com', 'codex --version', 'codex login status', 'herdr --version', 'herdr config check', "Write-Host 'Herdr environment: active", "Write-Host 'Herdr environment: inactive", 'HERDR_ENV')) {
    Assert-CommandContract $environment $command 'check-environment'
}
if ($environment -match '\$problems\.Add\([^\r\n]*HERDR_ENV') { throw 'HERDR_ENV must remain informational in the environment diagnostic.' }

Write-Host 'Workshop static validation passed.'
