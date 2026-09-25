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
    '.codex/agents/master-craftsman.toml'
    '.codex/agents/inspector.toml'
    '.codex/agents/master-inspector.toml'
    'evals/workshop-foreman.md'
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

Write-Host 'Workshop validation passed.'
