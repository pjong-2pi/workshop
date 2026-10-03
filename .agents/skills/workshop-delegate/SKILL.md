---
name: workshop-delegate
description: Start, verify, prompt, and read one Foreman-selected visible Codex worker in Herdr.
---

# Workshop Delegate

Use only with a Foreman-selected role, worker, outcome, scope, constraints, profile,
model, reasoning effort, sandbox, checks, and stopping gate. Execute that one
decision only: do not choose roles, resources, reviewers, readiness, publication,
additional workers, or routing.

Verify `HERDR_ENV=1` before controlling Herdr. If Foreman supplies an existing
worktree and execution reference for reused implementation, review, or Fitter
work, use it without creating another worktree or starting it again. Reuse only a
matching live worker when the returned existing-worktree pane is occupied;
otherwise start the selected worker in its unused role shell. Never replace an
unrelated existing session. Every role workspace must be a
worktree-backed sibling grouped by Herdr under the canonical target repository.
Foreman supplies a distinct `WorktreePath`, `Branch`, and `Base` for every new
role. Implementation starts from its safe base; after its scoped commit and
verification, reviewer and Fitter worktrees start from that exact implementation
HEAD. The Fitter's branch is the supplied final publishing branch. Use generic
`workspace create` for none of these roles. A supplied `ExistingWorktree` is
only the same role's already-created checkout: open it with `worktree open --cwd
<Repository> --path <ExistingWorktree>`. Start the selected worker when its
returned role shell is unused; when occupied, reuse only a matching live worker.
Never replace its agent.

Apply the selected profile's sandbox, model, reasoning effort, and developer
instructions explicitly; Herdr does not load Codex profiles automatically.

```powershell
if ($env:HERDR_ENV -ne '1') { throw 'Herdr environment is not active.' }
if ($ExecutionReference) {
    $workspace = $ExecutionReference.workspace_id
    $pane = $ExecutionReference.pane_id
    $selectedWorktree = $ExistingWorktree
    if ([string]::IsNullOrWhiteSpace($selectedWorktree)) { throw 'An execution reference requires its existing worktree.' }
    $status = herdr agent get $Worker | ConvertFrom-Json -ErrorAction Stop
} else {
    if ($ExistingWorktree) {
        $created = herdr worktree open --cwd $Repository --path $ExistingWorktree --label $Label --no-focus --trust-repository | ConvertFrom-Json -ErrorAction Stop
        $selectedWorktree = $ExistingWorktree
    } else {
        $created = herdr worktree create --cwd $Repository --branch $Branch --base $Base --path $WorktreePath --label $Label --no-focus --trust-repository | ConvertFrom-Json -ErrorAction Stop
        $selectedWorktree = $WorktreePath
    }
    $workspace = $created.result.workspace.workspace_id
    $pane = $created.result.root_pane.pane_id
    $paneState = ((herdr pane list --workspace $workspace | ConvertFrom-Json -ErrorAction Stop).result.panes | Where-Object pane_id -ceq $pane)
    if ($ExistingWorktree -and $created.result.already_open -and -not [string]::IsNullOrWhiteSpace($paneState.agent)) {
        $status = herdr agent get $Worker | ConvertFrom-Json -ErrorAction Stop
    } else {
        herdr agent start $Worker --kind codex --pane $pane --timeout 300000 -- --model $Model --sandbox $Sandbox --config "model_reasoning_effort='$ReasoningEffort'" --config "developer_instructions='$ProfileDeveloperInstructions'"
        $status = herdr agent get $Worker | ConvertFrom-Json -ErrorAction Stop
    }
}
$sourceHead = if (-not $ExistingWorktree -and $Role -in @('reviewer', 'fitter')) { (git -C $selectedWorktree rev-parse HEAD).Trim() }
if ($Role -in @('reviewer', 'fitter') -and -not $ExistingWorktree -and ($LASTEXITCODE -ne 0 -or $sourceHead -cne $Base)) {
    throw 'Role worktree does not start at the supplied implementation HEAD.'
}
$record = (herdr workspace get $workspace | ConvertFrom-Json -ErrorAction Stop).result.workspace
if ([string]::IsNullOrWhiteSpace($record.worktree.repo_key) -or
    (Resolve-Path -LiteralPath $record.worktree.repo_root).Path -ine (Resolve-Path -LiteralPath $Repository).Path -or
    (Resolve-Path -LiteralPath $record.worktree.checkout_path).Path -ine (Resolve-Path -LiteralPath $selectedWorktree).Path) {
    throw 'Workspace is not grouped with the intended repository and worktree.'
}
```

Before prompting, verify the expected worker name, `codex` kind, workspace and
pane IDs, and `interactive_ready`, including the canonical repository and selected
checkout metadata above. Verify an actual session when metadata exposes one. When
newly idle metadata omits it, `herdr pane process-info --pane <pane-id>` may
instead verify the visible foreground Codex process, task CWD, and selected
configuration. A workspace or pane alone is not a started worker. If startup or
verification fails, stop and report; never substitute a hidden/internal worker.

```powershell
herdr agent prompt $Worker $Prompt --wait --until idle --until done --until blocked --timeout 300000
$handoff = herdr agent read $Worker
```

Report only orchestration-level `started`, `completed`, `blocked`, or `failed`,
the selected worker identity, compact handoff, and concrete blocker. Keep
workspace/pane IDs opaque. Never pass a role workspace as an auxiliary for a
different checkout: cleanup is separate for each role checkout and only with its
own matching merged evidence or explicit discard. Report an old review-head
cleanup limit rather than forcing it. Consult installed CLI help only for command
drift.
