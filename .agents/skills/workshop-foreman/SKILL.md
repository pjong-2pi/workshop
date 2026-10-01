---
name: workshop-foreman
description: Serve as Workshop's primary interface for managed development work. Analyze requests, select specialized agents, and coordinate isolated Herdr workspaces, Git worktrees, verification, and review; handle only trivial work directly.
---

# Workshop Foreman

Own the request and the user-facing result. Delegate substantive implementation
or investigation to a `master-craftsman`; one worker is enough unless scopes are
genuinely independent. Do not add a management layer or delegation chain. Handle
only incidental, obvious edits directly.

## Advisory JEV routing

JEV is an advisory, staged, on-demand classifier. Import the repository-root
script (never a skill-local `scripts` path) and give it only a deliberately
small, bounded, single-line sanitized semantic task description; never provide
the raw request, a general summary/classification, credentials, secrets,
private/customer data, authorization material, or unnecessary code/file
contents. Do not preclassify implementation/investigation/review risk,
trivial/substantive work, or well-defined/demanding work:

```powershell
. (Join-Path $WorkshopRoot 'scripts/jev-routing.ps1')
$JevTaskId = [guid]::NewGuid()
$TaskDescription = 'inspect pull request' # 160 chars max; lowercase words from the bounded semantic vocabulary
$SkillDecision = Get-WorkshopJevDecisionWithApprovedRetry -TaskId $JevTaskId -DecisionType Skill -TaskDescription $TaskDescription -Root $WorkshopRoot -ApprovedRequest $ApprovedJevExecution
```

Use only the helper's small allowlisted routing vocabulary (for example `create`,
`inspect`, `review`, `merge`, `pull`, `request`, `implement`,
`repository`, `validation`, `rule`, `one`, `cohesive`, `module`, `correct`,
`local`, and `typo`). If the task cannot be expressed with those words, do not ask
JEV; use safe Foreman fallback judgment. Authorization is never task semantics for
JEV and remains solely with Foreman.

Ask the stages only in order: first `Skill` for specialized skills only (exclude
`workshop-foreman`); if that resolves the work, stop. If work remains, ask
`Delegation` with the task plus `-SelectedSkill none`; only after Foreman accepts
that advisory delegation, ask `Role` with the task alone, then ask `Model` with
the task plus `-SelectedRole` and the independently supplied current model names
and characteristics from `catalog/models.md`. Validate every answer against current
capabilities and the existing allowlists. A rejected, unavailable, malformed, or
low-confidence answer falls back safely to Foreman judgment; do not ask later stages.
Foreman remains authoritative for intake, user interaction, authorization,
Herdr/worktrees, verification, review, escalation, cleanup, and final accept/reject
decisions.

The helper reads only `TYPESAFE_API_KEY` from the process environment, applies a
bounded API call and confidence/current-capability validation, and records ignored
local per-task, per-stage telemetry. Run JEV in the configured network-enabled
context. If and only if a stage returns `sandbox-tls`, Foreman may retry that
identical sanitized stage once through approved network execution, retaining the
same task ID; the retry is a separately observed stage call. Do not retry low
confidence, malformed/invalid choices, authentication failures, context rejection,
or general outages. `ApprovedJevExecution` is Foreman's explicit approved execution
callback; the helper never requests sandbox escalation. Foreman remains authoritative
for that tool boundary. Stocktake remains inventory-only. Do not run
it in deterministic tests with network credentials. At the user-facing gate,
including fallback, blocked, and error paths, close the task in `finally`:

```powershell
Complete-WorkshopJevTelemetry -Root $WorkshopRoot -TaskId $JevTaskId -FinalRoute $FinalRoute -FinalDelegation $FinalDelegation -FinalRole $FinalRole -FinalModel $FinalModel -Outcome $Outcome -BaselineActualTotalTokens $BaselineActualTotalTokens -ObservedDownstreamTaskTokens $ObservedDownstreamTaskTokens
```

Each row carries the task ID, stage decision type/value, confidence, JEV version,
observed tokens and latency, and accepted/rejected/fallback status, but never the
task description or request content. Completion
records Foreman's final decision and the explicit observed baseline comparison.
Keep totals null when any required observed counter is missing: never estimate tokens,
latency, prices, or capabilities.

## Orchestration hiccups

At the user-facing gate, identify only observed tool/CLI drift, avoidable retries,
coordination failures, or permission/instruction ambiguity. Exclude product defects
and normal review findings. For each observed hiccup, append one sanitized row to
the ignored local tracker, then mention it in the required handoff (or state that
none were observed). `stage`, `category`, `sanitized_symptom`, and
`resolution_status` must contain no request text, code, credentials, secrets,
private/customer data, or raw command transcripts. Include `routing_id` only when
available. Use this inline PowerShell; do not create a tracker script or skill:

```powershell
foreach ($Hiccup in $ObservedHiccups) {
    $HiccupRow = [ordered]@{
        timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
        stage = $Hiccup.Stage
        category = $Hiccup.Category
        sanitized_symptom = $Hiccup.SanitizedSymptom
        resolution_status = $Hiccup.ResolutionStatus
    }
    if ($JevDecision) { $HiccupRow.routing_id = $JevDecision.routing_id }
    $HiccupRow | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $WorkshopRoot '.local/orchestration-hiccups.jsonl')
}
```

Promote repeated, actionable patterns to `WORKFLOWS.md` only when Workshop edits
are authorized; otherwise report the candidate in the handoff.

## Select and prepare the target

Resolve the exact target repository from the request or ask when ambiguity risks
the wrong repository. Managed repositories normally live under `projects/`, but
an explicit external path is valid. Never modify a target merely to make it
Workshop-aware.

Read the target's applicable instructions. Before each objective, determine its
configured default branch and exact checkout, verify that checkout is clean, and
run `git pull --ff-only origin <default-branch>`. Preserve and report a missing,
dirty, or divergent base; never stash, reset, or overwrite it.

Verify `HERDR_ENV=1`. Use the established commands below. Consult the installed
CLI help only when a command is rejected or the installed version has drifted.

## Dispatch

Create one dedicated Herdr workspace and Git worktree per worker from the refreshed
base. Parse and validate Herdr's returned workspace and root pane before using it;
stop on malformed or inconsistent state. Then record it as the owning workspace
with the returned pane.
Auxiliary workspaces are recorded CWD-sharing workspace IDs excluding the owning
workspace ID, even though the owner is also a worker workspace:

```powershell
$created = herdr worktree create --cwd $Repository --branch $Branch --base $Base --path $WorktreePath --label $Label --no-focus --trust-repository | ConvertFrom-Json -ErrorAction Stop
if ($created.id -ne 'cli:worktree:create' -or $null -eq $created.result -or $null -eq $created.result.workspace -or $null -eq $created.result.root_pane -or [string]::IsNullOrWhiteSpace($created.result.workspace.workspace_id) -or [string]::IsNullOrWhiteSpace($created.result.root_pane.workspace_id) -or [string]::IsNullOrWhiteSpace($created.result.root_pane.pane_id) -or $created.result.root_pane.workspace_id -cne $created.result.workspace.workspace_id) { throw 'Herdr returned malformed owning workspace state; stop and report.' }
$Workspace = $created.result.workspace.workspace_id
$Pane = $created.result.root_pane.pane_id
herdr worktree list --workspace $Workspace --trust-repository
```

When Herdr's normal path is not writable, use an explicit writable `--path` and
exclude it with the target repository's `.git/info/exclude`, never a tracked
ignore file.

Start the worker's Codex session and verify it is interactive-ready before
prompting:

```powershell
herdr agent start $Agent --kind codex --pane $Pane --timeout 300000 -- --model $Model --sandbox $Sandbox --config "model_reasoning_effort='$ReasoningEffort'"
herdr agent get $Agent
```

A workspace without a ready agent is not a dispatched worker.

Prefer an applicable target-project profile from `.codex/agents/`; otherwise use
Workshop's generic profile for the selected role. The selected profile supplies
role/developer instructions, sandbox, and reasoning effort. When JEV is accepted,
its model overrides only that profile's default model in the `herdr agent start
--model` argument for that invocation; fallback or no accepted route uses the
current profile default. Put its developer instructions in the worker prompt
verbatim; they are prompt content, not CLI arguments. Never assume Herdr loads
Codex profile files itself. Foreman remains authoritative.

Prompt with only the outcome, owned scope, dependencies, checks, non-goals, and
authorization boundary. Point to repository paths instead of copying file contents
or Foreman history. Require the handoff: **TASK; STATUS; CHANGED; BEHAVIOR;
CHECKS; FINDINGS; BLOCKER; NEXT**.

## Supervise and review

For run-to-gate work, continue through the authorized lifecycle: dispatch, wait,
verify evidence, review, fix findings, focused re-review, integrate, and advance.
Submit and wait through Herdr's agent commands instead of repeatedly polling
healthy workers:

```powershell
herdr agent prompt $Agent $Prompt --wait --until idle --until done --until blocked --timeout 300000
herdr agent read $Agent
```

A user request authorizing repository changes also authorizes committing the
scoped changes, pushing the dedicated branch, and creating a PR after required
verification and review. Do not ask separately unless the user sets an earlier
stopping gate or says not to create a PR. Read-only answers and investigations do
not authorize mutation or a PR. This authorization never includes merge or branch
deletion; stop before either unless separately authorized. Treat a user reply of
`LGTM` to an exact PR handoff as explicit authorization to merge that PR and run
verified post-merge bench cleanup; it grants no broader authority.

Give every reviewer a separate read-only workspace. Use the target's applicable
review profile when present, otherwise Workshop's `inspector` or
`master-inspector`. Supply the base, complete diff, requirements, and check results.
Use the Master Inspector only for architecture, concurrency, security, data-loss,
or other high-risk boundaries. Material fixes require affected checks and focused
re-review.

## Fit an approved change

After the implementation writer is idle and has supplied an implemented, verified
change plus independent review evidence, Foreman may dispatch the `fitter` profile
in an auxiliary CWD-sharing Herdr workspace on the owning worktree. Record that
auxiliary workspace ID. Supply the exact repository, owning worktree, base, branch,
approved paths, checks, review evidence, and stopping gate. Fitter reuses
`github-check-pr` to verify state and `github-create-pr` only when the authorized
gate includes PR creation; it returns failures or required source edits to the
original worker. Require the exact PR URL and head SHA. Fitter never edits product code,
approves its own work, merges, deletes branches, force-pushes, stashes,
resets, or cleans worktrees. Foreman retains authorization interpretation and the
user-facing result.

Before dispatching Fitter, inspect active agents. Production Fitter names use the
`fitter-run-` prefix; reviewers do not. Stop when a non-`done` Fitter has the
owning worktree as its CWD; otherwise create one auxiliary workspace, assign its
returned ID to `$FitterWorkspace`, and record it before starting Fitter. Keep the
claim in Workshop-local runtime state; never write it into the target worktree.

```powershell
if ($Workspace -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { throw 'Owning workspace ID is not a safe claim leaf; stop and report.' }
$FitterClaimParent = Join-Path $WorkshopRoot '.local/fitter-claims'
if (-not (Test-Path -LiteralPath $FitterClaimParent -PathType Container)) { New-Item -ItemType Directory -Path $FitterClaimParent -ErrorAction Stop | Out-Null }
$FitterClaimParent = (Resolve-Path -LiteralPath $FitterClaimParent -ErrorAction Stop).Path
$FitterClaim = [IO.Path]::GetFullPath((Join-Path $FitterClaimParent $Workspace))
if ((Split-Path -Parent $FitterClaim) -cne $FitterClaimParent) { throw 'Fitter claim escapes its parent; stop and report.' }
try { New-Item -ItemType Directory -Path $FitterClaim -ErrorAction Stop | Out-Null } catch { throw 'A Fitter claim already exists or is stale; stop and report.' }
$agents = herdr agent list | ConvertFrom-Json -ErrorAction Stop
if ($agents.id -ne 'cli:agent:list' -or $null -eq $agents.result.agents) { throw 'Herdr returned malformed agent state; stop and report.' }
foreach ($agent in $agents.result.agents) {
    if ([string]::IsNullOrWhiteSpace($agent.name) -or [string]::IsNullOrWhiteSpace($agent.cwd) -or [string]::IsNullOrWhiteSpace($agent.workspace_id) -or [string]::IsNullOrWhiteSpace($agent.agent_status)) { throw 'Herdr returned malformed agent record; stop and report.' }
}
if (@($agents.result.agents | Where-Object { $_.name -clike 'fitter-run-*' -and $_.cwd -ieq $OwningWorktree -and $_.agent_status -cne 'done' }).Count) { throw 'An active Fitter already shares the owning worktree; stop and report.' }
$auxiliary = herdr workspace create --cwd $OwningWorktree --label fitter --no-focus | ConvertFrom-Json -ErrorAction Stop
if ($auxiliary.id -ne 'cli:workspace:create' -or $null -eq $auxiliary.result.workspace -or $null -eq $auxiliary.result.root_pane -or [string]::IsNullOrWhiteSpace($auxiliary.result.workspace.workspace_id) -or [string]::IsNullOrWhiteSpace($auxiliary.result.root_pane.workspace_id) -or [string]::IsNullOrWhiteSpace($auxiliary.result.root_pane.pane_id) -or $auxiliary.result.root_pane.workspace_id -cne $auxiliary.result.workspace.workspace_id) { throw 'Herdr returned malformed Fitter workspace state; stop and report.' }
$FitterWorkspace = $auxiliary.result.workspace.workspace_id
$FitterPane = $auxiliary.result.root_pane.pane_id
$FitterAgent = "fitter-run-$FitterWorkspace"
```

Hold `$FitterClaim` for the entire Fitter lifecycle. Never auto-delete an existing
or stale claim. Release it only after `herdr agent list` observes exactly one
`$FitterAgent` in a terminal `done`, `blocked`, or `error` state:

```powershell
$terminal = herdr agent list | ConvertFrom-Json -ErrorAction Stop
$fitter = @($terminal.result.agents | Where-Object { $_.name -ceq $FitterAgent })
if ($terminal.id -ne 'cli:agent:list' -or $fitter.Count -ne 1 -or $fitter[0].agent_status -notin @('done', 'blocked', 'error')) { throw 'Fitter is not observed terminal; retain its claim and stop.' }
$FitterClaimParent = (Resolve-Path -LiteralPath $FitterClaimParent -ErrorAction Stop).Path
$FitterClaim = (Resolve-Path -LiteralPath $FitterClaim -ErrorAction Stop).Path
if ((Split-Path -Parent $FitterClaim) -cne $FitterClaimParent -or @(Get-ChildItem -LiteralPath $FitterClaim -Force).Count -ne 0) { throw 'Fitter claim is unsafe or not empty; retain it and stop.' }
Remove-Item -LiteralPath $FitterClaim
```

## Finish

Inspect the complete diff and rerun checks required by the target instructions or
not adequately evidenced by workers. After verified GitHub merge, derive
`$GitHubRepository` as canonical `OWNER/REPO` from the merge skill's structured
`gh repo view` `nameWithOwner` result (keep `$Repository` as the local path), then
pass the exact PR, canonical GitHub repository, and base to the clear-bench gate
with the owning workspace ID.
The gate re-verifies the merge, re-discovers and closes only current auxiliary
CWD-sharing workspaces, then removes the clean integrated worktree while keeping
the owner live. The verified merge is sufficient authority; do not ask again. An
unintegrated worktree still needs explicit discard authorization.

```powershell
pwsh -NoProfile -File .agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1 -Workspace "$Workspace" -Repository "$Repository" -GitHubRepository "$GitHubRepository" -PullRequest "$PullRequest" -Base "$Base" -Confirm:$false
```

Never add `--force` or delete a branch without approval. Stop on inconsistent
state; do not retry with another tool. Report the reached gate or the concrete
blocker; do not claim unobserved success.
