---
name: workshop-delegate
description: Start, verify, prompt, and read one Foreman-selected visible Codex worker in Herdr.
---

# Workshop Delegate

Use only with a Foreman-selected worker, outcome, scope, constraints, profile,
model, reasoning effort, sandbox, checks, and stopping gate. Execute that one
decision only: do not choose roles, resources, reviewers, readiness, publication,
additional workers, or routing.

Verify `HERDR_ENV=1` before controlling Herdr. If Foreman supplies an existing
worktree and execution reference for reused implementation, review, or Fitter
work, use it without creating another worktree or starting it again. Reuse only a
live worker whose expected profile, model, reasoning, sandbox, and readiness can
be verified; otherwise stop and report. For review or Fitter work on a supplied
completed worktree without a live worker, create a Herdr workspace from that
worktree, then start the selected worker there. Otherwise, for a substantive
delegated edit, create the selected worker's dedicated Herdr workspace and
worktree from the target repository.

Apply the selected profile's sandbox, model, reasoning effort, and developer
instructions explicitly; Herdr does not load Codex profiles automatically.

```powershell
if ($env:HERDR_ENV -ne '1') { throw 'Herdr environment is not active.' }
if ($ExecutionReference) {
    $workspace = $ExecutionReference.workspace_id
    $pane = $ExecutionReference.pane_id
    $status = herdr agent get $Worker | ConvertFrom-Json -ErrorAction Stop
} else {
    if ($ExistingWorktree) {
        $created = herdr workspace create --cwd $ExistingWorktree --label $Label --no-focus | ConvertFrom-Json -ErrorAction Stop
    } else {
        $created = herdr worktree create --cwd $Repository --branch $Branch --base $Base --path $WorktreePath --label $Label --no-focus --trust-repository | ConvertFrom-Json -ErrorAction Stop
    }
    $workspace = $created.result.workspace.workspace_id
    $pane = $created.result.root_pane.pane_id
    herdr agent start $Worker --kind codex --pane $pane --timeout 300000 -- --model $Model --sandbox $Sandbox --config "model_reasoning_effort='$ReasoningEffort'" --config "developer_instructions='$ProfileDeveloperInstructions'"
    $status = herdr agent get $Worker | ConvertFrom-Json -ErrorAction Stop
}
```

Before prompting, verify the expected worker name, `codex` kind, workspace and
pane IDs, and `interactive_ready`. Verify an actual session when metadata exposes
one. When newly idle metadata omits it, `herdr pane process-info --pane <pane-id>`
may instead verify the visible foreground Codex process, task CWD, and selected
configuration. A workspace or pane alone is not a started worker. If startup or
verification fails, stop and report; never substitute a hidden/internal worker.

```powershell
herdr agent prompt $Worker $Prompt --wait --until idle --until done --until blocked --timeout 300000
$handoff = herdr agent read $Worker
```

Report only orchestration-level `started`, `completed`, `blocked`, or `failed`,
the selected worker identity, compact handoff, and concrete blocker. Keep
workspace/pane IDs opaque; retain an auxiliary execution reference only when
cleanup genuinely needs it. Consult installed CLI help only for command drift.
