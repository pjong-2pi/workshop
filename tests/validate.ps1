$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$required = @(
    'AGENTS.md'
    'WORKFLOWS.md'
    '.gitignore'
    '.agents/skills/workshop-foreman/SKILL.md'
    '.agents/skills/github-create-pr/SKILL.md'
    '.agents/skills/github-check-pr/SKILL.md'
    '.agents/skills/github-merge-pr/SKILL.md'
    '.agents/skills/workshop-setup/SKILL.md'
    '.codex/agents/master-craftsman.toml'
    '.codex/agents/inspector.toml'
    '.codex/agents/master-inspector.toml'
    'evals/workshop-foreman.md'
    'scripts/check-environment.ps1'
)

$missing = $required | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf)
}
if ($missing) {
    throw "Missing required file(s): $($missing -join ', ')"
}

$skills = @(
    'workshop-foreman'
    'github-create-pr'
    'github-check-pr'
    'github-merge-pr'
    'workshop-setup'
)
foreach ($name in $skills) {
    $path = Join-Path $root ".agents/skills/$name/SKILL.md"
    $content = Get-Content -LiteralPath $path -Raw
    if ($content -notmatch "(?s)^---\r?\nname: $name\r?\ndescription: .+?\r?\n---") {
        throw "$name has invalid or incomplete frontmatter."
    }
}

$genericFiles = @(
    (Join-Path $root '.agents/skills/workshop-foreman/SKILL.md')
    (Join-Path $root '.codex/agents/master-craftsman.toml')
    (Join-Path $root '.codex/agents/inspector.toml')
    (Join-Path $root '.codex/agents/master-inspector.toml')
)
foreach ($profile in $genericFiles[1..3]) {
    $content = Get-Content -LiteralPath $profile -Raw
    foreach ($field in @('name', 'description', 'sandbox_mode', 'model', 'model_reasoning_effort', 'developer_instructions')) {
        if ($content -notmatch "(?m)^$field\s*=") {
            throw "$(Split-Path $profile -Leaf) is missing $field."
        }
    }
}

function Assert-Contains {
    param(
        [string] $Content,
        [string] $Expected,
        [string] $Contract
    )

    if (-not $Content.Contains($Expected)) {
        throw "$Contract is missing: $Expected"
    }
}

$create = Get-Content -LiteralPath (Join-Path $root '.agents/skills/github-create-pr/SKILL.md') -Raw
Assert-Contains $create 'gh pr create --repo "$REPO" --base "$BASE" --head "$BRANCH"' 'github-create-pr contract'
Assert-Contains $create 'gh pr view "$BRANCH" --repo "$REPO" --json' 'github-create-pr verification'
Assert-Contains $create 'headRefOid' 'github-create-pr SHA verification'
Assert-Contains $create 'test "$HEAD_SHA" = "$REMOTE_SHA"' 'github-create-pr pushed SHA binding'

$check = Get-Content -LiteralPath (Join-Path $root '.agents/skills/github-check-pr/SKILL.md') -Raw
Assert-Contains $check 'gh pr view "$PR" --repo "$REPO" --json' 'github-check-pr structured inspection'
Assert-Contains $check 'gh pr diff "$PR" --repo "$REPO" --name-only' 'github-check-pr diff scope'
Assert-Contains $check 'gh pr checks "$PR" --repo "$REPO" --required --json' 'github-check-pr required checks'
Assert-Contains $check 'EXPECTED_SHA' 'github-check-pr SHA binding'

$merge = Get-Content -LiteralPath (Join-Path $root '.agents/skills/github-merge-pr/SKILL.md') -Raw
Assert-Contains $merge 'gh repo view "$REPO" --json' 'github-merge-pr repository policy inspection'
Assert-Contains $merge 'Use this precedence and no default' 'github-merge-pr method selection'
Assert-Contains $merge 'headRefOid' 'github-merge-pr SHA verification'
Assert-Contains $merge 'Never add `--admin`, `--auto`, or `--delete-branch`' 'github-merge-pr prohibited behavior'

$mergeCommands = @($merge -split "\r?\n" | Where-Object { $_.TrimStart().StartsWith('gh pr merge ') })
if ($mergeCommands.Count -ne 3) {
    throw "github-merge-pr must document exactly three explicit merge-method commands; found $($mergeCommands.Count)."
}
foreach ($command in $mergeCommands) {
    Assert-Contains $command '--repo "$REPO"' 'github-merge-pr explicit repository'
    Assert-Contains $command '--match-head-commit "$SHA"' 'github-merge-pr SHA guard'
    if ($command -match '(?:^|\s)--(?:admin|auto|delete-branch)(?:\s|$)') {
        throw "github-merge-pr executable command contains a prohibited bypass or cleanup flag: $command"
    }
}
if ($merge -match '(?i)prefer(?:s|red)?\s+squash|squash preference') {
    throw 'github-merge-pr must not impose a squash preference.'
}

$setup = Get-Content -LiteralPath (Join-Path $root 'scripts/check-environment.ps1') -Raw
foreach ($expected in @('RuntimeInformation', 'PSVersionTable', 'git config user.name', 'git config user.email', 'gh auth status --active --hostname github.com', 'codex --version', 'herdr --version', 'HERDR_ENV')) {
    Assert-Contains $setup $expected 'workshop-setup environment check'
}

$foreman = Get-Content -LiteralPath (Join-Path $root '.agents/skills/workshop-foreman/SKILL.md') -Raw
foreach ($expected in @('herdr worktree create', 'herdr agent start', 'herdr agent get', 'herdr agent prompt', 'herdr agent read', 'herdr worktree remove')) {
    Assert-Contains $foreman $expected 'workshop-foreman Herdr mechanics'
}

Write-Host 'Workshop validation passed.'
