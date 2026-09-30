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
    '.agents/skills/workshop-stocktake/SKILL.md',
    '.agents/skills/workshop-stocktake/scripts/update-model-catalog.ps1',
    'catalog/models.md',
    '.codex/agents/master-craftsman.toml',
    '.codex/agents/inspector.toml',
    '.codex/agents/master-inspector.toml',
    '.codex/agents/fitter.toml',
    '.codex/config.toml',
    'scripts/check-environment.ps1', 'scripts/setup.ps1', 'scripts/jev-routing.ps1', 'tests/run.ps1', 'tests/jev-routing.ps1',
    'evals/workshop-foreman.md', 'evals/skill-evals.json'
)
$missing = $required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf) }
if ($missing) { throw "Missing required file(s): $($missing -join ', ')" }

foreach ($name in @('workshop-foreman', 'github-create-pr', 'github-check-pr', 'github-merge-pr', 'workshop-setup', 'workshop-clear-bench', 'workshop-stocktake')) {
    $content = Get-Content -LiteralPath (Join-Path $root ".agents/skills/$name/SKILL.md") -Raw
    if ($content -notmatch "(?s)^---\r?\nname: $name\r?\ndescription: .+?\r?\n---") {
        throw "$name has invalid or incomplete frontmatter."
    }
}

foreach ($profile in @('master-craftsman.toml', 'inspector.toml', 'master-inspector.toml', 'fitter.toml')) {
    $content = Get-Content -LiteralPath (Join-Path $root ".codex/agents/$profile") -Raw
    foreach ($field in @('name', 'description', 'sandbox_mode', 'model', 'model_reasoning_effort', 'developer_instructions')) {
        if ($content -notmatch "(?m)^$field\s*=") { throw "$profile is missing $field." }
    }
}

$setup = Get-Content -LiteralPath (Join-Path $root 'scripts/setup.ps1') -Raw
if ($setup -match 'SetEnvironmentVariable') { throw 'Setup must not persist environment variables.' }

$definitions = Get-Content -LiteralPath (Join-Path $root 'evals/skill-evals.json') -Raw | ConvertFrom-Json
if ($definitions.version -ne 1 -or $definitions.executable -or $null -eq $definitions.evaluations) { throw 'Skill eval definitions have an invalid schema.' }
$expected = @('explicit-setup', 'uninitialized-clone', 'foreman-task', 'pr-review', 'routine-development', 'initialized-workshop', 'clear-completed-bench', 'jev-pr-review', 'jev-pr-create', 'jev-pr-merge', 'jev-substantive-task', 'jev-trivial-task', 'jev-fallback', 'fitter-pr', 'active-fitter', 'concurrent-fitter', 'traversal-fitter-claim', 'foreman-hiccup', 'stocktake-models')
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

$workshopInstructions = Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw
foreach ($contract in @('A request authorizing repository changes also authorizes committing its scoped', 'Read-only work does not authorize mutation or a PR; PR', 'creation does not authorize merge or branch deletion.')) {
    Assert-CommandContract $workshopInstructions $contract 'AGENTS.md'
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
foreach ($contract in @('gh repo view "$REPO" --json', 'nameWithOwner', 'GITHUB_REPOSITORY', 'Squash when neither specifies a method and the repository enables squash.', 'headRefOid', 'Never add `--admin`, `--auto`, or `--delete-branch`')) {
    Assert-CommandContract $merge $contract 'github-merge-pr'
}
$mergeCommands = @($merge -split "\r?\n" | Where-Object { $_.TrimStart().StartsWith('gh pr merge ') })
if ($mergeCommands.Count -ne 3) { throw "github-merge-pr must have exactly three merge commands; found $($mergeCommands.Count)." }
foreach ($command in $mergeCommands) {
    Assert-CommandContract $command '--repo "$GITHUB_REPOSITORY"' 'github-merge-pr'
    Assert-CommandContract $command '--match-head-commit "$SHA"' 'github-merge-pr'
    if ($command -match '(?:^|\s)--(?:admin|auto|delete-branch)(?:\s|$)') { throw 'github-merge-pr contains a prohibited merge flag.' }
}

foreach ($contract in @("Join-Path `$root 'projects'", "Join-Path `$root '.local'", "Join-Path `$local 'setup-complete'", 'New-Item -ItemType Directory', 'New-Item -ItemType File', 'Workshop setup verification failed.', 'check-environment.ps1', 'InstallCodexIntegration', 'herdr integration install codex')) {
    Assert-CommandContract $setup $contract 'workshop-setup'
}

$foreman = Get-Content -LiteralPath (Join-Path $root '.agents/skills/workshop-foreman/SKILL.md') -Raw
foreach ($command in @('herdr worktree create', 'herdr agent start', 'herdr agent get', 'herdr agent prompt', 'herdr agent read', 'record it as the owning workspace', 'Auxiliary workspaces are recorded CWD-sharing workspace IDs excluding the owning', 'After verified GitHub merge, derive', 'canonical `OWNER/REPO`', 'The gate re-verifies the merge, re-discovers and closes only current auxiliary', '-GitHubRepository "$GitHubRepository" -PullRequest "$PullRequest" -Base "$Base"', 'A user request authorizing repository changes also authorizes committing the', 'Do not ask separately unless the user sets an earlier', 'Read-only answers and investigations do', 'This authorization never includes merge or branch', 'workshop-clear-bench/scripts/remove-workspace.ps1', 'Verify `HERDR_ENV=1`.')) {
    Assert-CommandContract $foreman $command 'workshop-foreman'
}
$networkConfig = (Get-Content -LiteralPath (Join-Path $root '.codex/config.toml') -Raw) -replace "`r`n", "`n"
if ($networkConfig -ne "sandbox_mode = `"workspace-write`"`n`n[sandbox_workspace_write]`nnetwork_access = true`n" -or $networkConfig -match 'danger-full-access|approval_policy') { throw 'Workshop network config must grant only workspace-write network access.' }
$worktreeCreate = @($foreman -split "`r?`n" | Where-Object { $_.Contains('herdr worktree create ') })
if ($worktreeCreate.Count -ne 1 -or $worktreeCreate[0] -notmatch '--cwd \$Repository' -or $worktreeCreate[0] -match '--workspace') { throw 'workshop-foreman must create worktrees with only the CWD selector.' }
foreach ($contract in @('ConvertFrom-Json -ErrorAction Stop', "`$created.id -ne 'cli:worktree:create'", 'result.workspace.workspace_id', 'result.root_pane.pane_id', 'result.root_pane.workspace_id -cne $created.result.workspace.workspace_id', '$Workspace = $created.result.workspace.workspace_id', '$Pane = $created.result.root_pane.pane_id')) {
    Assert-CommandContract $foreman $contract 'workshop-foreman owning workspace capture'
}
foreach ($contract in @('orchestration-hiccups.jsonl', 'ConvertTo-Json -Compress', 'Add-Content -LiteralPath', 'timestamp_utc', 'routing_id', 'sanitized_symptom', 'resolution_status', 'tool/CLI drift', 'avoidable retries', 'coordination failures', 'permission/instruction ambiguity', 'Exclude product defects', 'normal review findings', 'mention it in the required handoff', 'Promote repeated, actionable patterns')) {
    Assert-CommandContract $foreman $contract 'workshop-foreman hiccup tracker'
}
foreach ($contract in @('After the implementation writer is idle', 'auxiliary CWD-sharing Herdr workspace on the owning worktree', 'github-check-pr', 'github-create-pr', 'exact PR URL and head SHA', 'Fitter never edits product code', 'Foreman retains authorization interpretation')) {
    Assert-CommandContract $foreman $contract 'workshop-foreman fitter lifecycle'
}
$fitter = Get-Content -LiteralPath (Join-Path $root '.codex/agents/fitter.toml') -Raw
foreach ($contract in @('auxiliary CWD-sharing Herdr workspace', 'owning implementation writer is idle', 'github-check-pr', 'github-create-pr', 'exact PR URL and head SHA', 'Do not edit product code', 'Never merge, delete branches, force-push, stash, reset, or clean worktrees', 'Foreman retains authorization interpretation')) {
    Assert-CommandContract $fitter $contract 'fitter profile'
}
foreach ($id in @('jev-pr-review', 'jev-pr-create', 'jev-pr-merge', 'jev-substantive-task', 'jev-trivial-task', 'jev-fallback')) {
    $routing = ($definitions.evaluations | Where-Object id -eq $id).routing
    if ($null -eq $routing -or @($routing.PSObject.Properties.Name | Sort-Object) -join ',' -ne 'agent,delegate,model,skill') { throw "Skill eval '$id' must define exactly the routing fields." }
    if ($id -eq 'jev-fallback') {
        if ($null -ne $routing.skill -or $null -ne $routing.agent -or $null -ne $routing.model -or $null -ne $routing.delegate) { throw "Skill eval '$id' must leave unavailable routing fields null." }
    } elseif ($routing.skill -isnot [string]) {
        throw "Skill eval '$id' must define its first-stage specialized-skill expectation."
    }
}
foreach ($contract in @('Get-WorkshopJevDecision', 'scripts/jev-routing.ps1', 'JEV is an advisory, staged, on-demand classifier', 'authoritative for intake', 'catalog/models.md', 'do not ask later stages')) {
    Assert-CommandContract $foreman $contract 'workshop-foreman'
}
foreach ($contract in @('The selected profile supplies', 'role/developer instructions, sandbox, and reasoning effort.', 'its model overrides only that profile''s default model', 'in the `herdr agent start', '--model` argument for that invocation;', 'fallback or no accepted route uses the', 'current profile default.')) {
    Assert-CommandContract $foreman $contract 'workshop-foreman'
}
$jev = Get-Content -LiteralPath (Join-Path $root 'scripts/jev-routing.ps1') -Raw
foreach ($contract in @('https://api.typesafe.ai/v1/systemone', 'TYPESAFE_API_KEY', 'ConvertTo-Json', 'Invoke-RestMethod', 'TimeoutSec 5', '$floor = 0.40', 'Test-JevChoice', 'foreman-fallback', 'jev-routing.jsonl')) {
    Assert-CommandContract $jev $contract 'jev-routing'
}
foreach ($contract in @("ValidateSet('skill', 'delegation', 'role', 'model')", '[string] $TaskDescription', "`$taskWords = @('create', 'inspect', 'review', 'merge', 'pull'", "TaskDescription -notmatch '\A[a-z]+(?: [a-z]+)*\z'", 'TaskDescription.Length -gt 160', 'selected_skill=none', 'selected_role=', "`$allowed = @{ skill = @('none', 'workshop-setup', 'workshop-clear-bench', 'github-create-pr', 'github-check-pr', 'github-merge-pr')", "`$catalog = Join-Path `$Root 'catalog/models.md'", 'available to current Codex account', "`$allowed.model = @(`$criteria.model.Keys)", 'cheapest capable available model independently of role', 'task_id', 'decision_type', 'decision_value', 'ObservedDownstreamTaskTokens', 'jev_assisted_total_tokens')) {
    Assert-CommandContract $jev $contract 'jev-routing'
}
if ($jev -match 'workshop-foreman.*github-merge-pr') { throw 'JEV specialized-skill allowlist must exclude workshop-foreman.' }
if ($jev -match "'fitter'") { throw 'JEV must not route to Fitter.' }
$substantiveRouting = ($definitions.evaluations | Where-Object id -eq 'jev-substantive-task').routing
if ($substantiveRouting.skill -ne 'none' -or -not $substantiveRouting.delegate -or $substantiveRouting.agent -ne 'master-craftsman' -or $substantiveRouting.model -ne 'gpt-5.6-luna') { throw 'JEV substantive eval must cover staged no-skill, delegation, Master Craftsman, and Luna.' }
$cleanupEvaluation = $definitions.evaluations | Where-Object id -eq 'clear-completed-bench'
if ($cleanupEvaluation.expect.skill_invoked -notcontains 'workshop-clear-bench') { throw "Skill eval 'clear-completed-bench' must invoke workshop-clear-bench." }
$fitterEvaluation = $definitions.evaluations | Where-Object id -eq 'fitter-pr'
if ($fitterEvaluation.expect.skill_invoked -notcontains 'workshop-foreman' -or $fitterEvaluation.expect.skill_invoked -notcontains 'github-check-pr' -or $fitterEvaluation.expect.skill_invoked -notcontains 'github-create-pr') { throw "Skill eval 'fitter-pr' must use Foreman and the PR skills." }
foreach ($contract in @('Fitter', 'owning worktree', 'writer is idle', 'exact PR URL', 'head SHA', 'no merge', 'cleanup')) {
    Assert-CommandContract $fitterEvaluation.pass_condition $contract 'fitter-pr eval'
}
$fitterConflict = $definitions.evaluations | Where-Object id -eq 'active-fitter'
foreach ($contract in @('non-done fitter-run', 'owning worktree', 'done fitter-agent-reviewer', 'stop', 'no auxiliary workspace')) {
    Assert-CommandContract $fitterConflict.pass_condition $contract 'active-fitter eval'
}
foreach ($contract in @("`$agents.id -ne 'cli:agent:list'", 'agent_status', "'fitter-run-*'", '$_.cwd -ieq $OwningWorktree', '$_.agent_status -cne', 'active Fitter already shares the owning worktree', 'herdr workspace create --cwd $OwningWorktree', '$FitterWorkspace = $auxiliary.result.workspace.workspace_id', '$FitterPane = $auxiliary.result.root_pane.pane_id', '$FitterAgent = "fitter-run-$FitterWorkspace"')) {
    Assert-CommandContract $foreman $contract 'workshop-foreman Fitter exclusivity'
}
$claimCreate = @($foreman -split "`r?`n" | Where-Object { $_.Contains('New-Item -ItemType Directory -Path $FitterClaim -ErrorAction Stop') })
if ($claimCreate.Count -ne 1 -or $claimCreate[0] -match '-Force') { throw 'workshop-foreman must atomically create its Fitter claim without force.' }
foreach ($contract in @("`$Workspace -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$'", "`$FitterClaimParent = Join-Path `$WorkshopRoot '.local/fitter-claims'", '[IO.Path]::GetFullPath', '(Split-Path -Parent $FitterClaim) -cne $FitterClaimParent', 'Fitter claim escapes its parent; stop and report.', 'never write it into the target worktree', 'A Fitter claim already exists or is stale; stop and report.', 'Fitter is not observed terminal; retain its claim and stop.', "agent_status -notin @('done', 'blocked', 'error')", 'Get-ChildItem -LiteralPath $FitterClaim -Force', 'Fitter claim is unsafe or not empty; retain it and stop.', 'Remove-Item -LiteralPath $FitterClaim')) {
    Assert-CommandContract $foreman $contract 'workshop-foreman Fitter claim'
}
if ($foreman -match 'Remove-Item -LiteralPath \$FitterClaim -Recurse') { throw 'workshop-foreman must remove only an empty Fitter claim.' }
if (@($foreman -split "`r?`n" | Where-Object { $_.Contains('$FitterClaim') -and $_.Contains('$OwningWorktree') }).Count -ne 0) { throw 'workshop-foreman must not put Fitter claims in the target worktree.' }
$concurrentFitter = $definitions.evaluations | Where-Object id -eq 'concurrent-fitter'
foreach ($contract in @('Workshop .local', 'owner workspace', 'atomic claim', 'concurrent', 'stop', 'no auxiliary workspace', 'no PR', 'no target path/change')) {
    Assert-CommandContract $concurrentFitter.pass_condition $contract 'concurrent-fitter eval'
}
$traversalClaim = $definitions.evaluations | Where-Object id -eq 'traversal-fitter-claim'
foreach ($contract in @('traversal', 'safe leaf', 'stop', 'no claim', 'no target path/change')) {
    Assert-CommandContract $traversalClaim.pass_condition $contract 'traversal-fitter-claim eval'
}
$hiccupEvaluation = $definitions.evaluations | Where-Object id -eq 'foreman-hiccup'
foreach ($contract in @('tool/CLI drift', 'sanitized JSONL', 'routing ID', 'handoff', 'product defects', 'normal review findings', 'WORKFLOWS.md')) {
    Assert-CommandContract $hiccupEvaluation.pass_condition $contract 'foreman-hiccup eval'
}

$cleanup = Get-Content -LiteralPath (Join-Path $root '.agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1') -Raw
foreach ($contract in @('herdr workspace get $Workspace', "`$response.id -ne 'cli:workspace:get'", 'workspace_id -cne $Workspace', 'worktree.repo_root', 'herdr worktree list --cwd $Repository --trust-repository', 'ConvertFrom-Json -ErrorAction Stop', "`$response.id -ne 'cli:worktree:list'", '$response.result.type -ne', '$response.result.worktrees', 'open_workspace_id -ceq $Workspace', 'function Assert-CleanWorktree', 'git -C $Path status --porcelain', 'function Assert-MergedPullRequest', 'Push-Location -LiteralPath $Path', 'finally { Pop-Location }', 'gh repo view --json nameWithOwner', '$canonicalGitHubRepository = $githubRepositoryRecord.nameWithOwner', '$canonicalGitHubRepository -ine $GitHubRepository', 'gh pr view $PullRequest --repo $canonicalGitHubRepository --json number,state,baseRefName,headRefOid', "`$pr.number -ne [long]`$PullRequest", "`$pr.state -cne 'MERGED'", '$pr.baseRefName -cne $Base', '$pr.headRefOid -cne $head', 'function Close-CwdSharingWorkspaces', 'herdr workspace list', 'herdr pane list --workspace $candidate', 'Where-Object { $_ -cne $Workspace }', 'herdr workspace close $candidate', 'Assert-MergedPullRequest $worktreePath', 'herdr worktree remove --workspace $Workspace --trust-repository', 'GitHub repository, pull request, and base for a verified merge, or -DiscardAuthorization.', 'Release current CWD-sharing workspace locks, then recheck immediately before removal.')) {
    Assert-CommandContract $cleanup $contract 'workshop-clear-bench'
}
if ($cleanup -match '(?m)^.*herdr worktree remove.*--force' -or $cleanup -match '(?i)branch.*delete') { throw 'workshop-clear-bench must not force removal or delete branches.' }
if ($cleanup -match 'IntegrationEvidence|RemovalAuthorization') { throw 'Integration cleanup must require exact merge evidence without a second authorization.' }
if ($cleanup -match 'herdr workspace close \$Workspace') { throw 'workshop-clear-bench must keep the owning workspace live for direct removal.' }
$deprecatedParameter = 'Worktree' + 'Path'
if ($cleanup -cmatch $deprecatedParameter) { throw 'workshop-clear-bench must resolve its worktree path from Herdr.' }

$environment = Get-Content -LiteralPath (Join-Path $root 'scripts/check-environment.ps1') -Raw
foreach ($command in @('RuntimeInformation', 'PSVersionTable', 'git config user.name', 'git config user.email', 'gh auth status --active --hostname github.com', 'codex --version', 'codex login status', 'herdr --version', 'herdr config check', "Write-Host 'Herdr environment: active", "Write-Host 'Herdr environment: inactive", 'HERDR_ENV')) {
    Assert-CommandContract $environment $command 'check-environment'
}
if ($environment -match '\$problems\.Add\([^\r\n]*HERDR_ENV') { throw 'HERDR_ENV must remain informational in the environment diagnostic.' }

$stocktake = Get-Content -LiteralPath (Join-Path $root '.agents/skills/workshop-stocktake/SKILL.md') -Raw
foreach ($contract in @('Codex''s local app-server `model/list`', 'unknown', 'never select, rank, or recommend', 'No periodic refresh')) {
    Assert-CommandContract $stocktake $contract 'workshop-stocktake'
}
$stocktakeScript = Get-Content -LiteralPath (Join-Path $root '.agents/skills/workshop-stocktake/scripts/update-model-catalog.ps1') -Raw
foreach ($contract in @("'model/list'", "'initialized'", 'Assert-ModelPage', 'includeHidden = $false', 'available to current Codex account', 'Last checked (UTC)', 'Unchanged model catalog')) {
    Assert-CommandContract $stocktakeScript $contract 'workshop-stocktake script'
}

Write-Host 'Workshop static validation passed.'
