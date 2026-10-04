---
name: workshop-dispatch
description: Dispatch a Foreman-selected Workshop role through native Herdr, arranging or reusing the assigned task worktree and returning its handoff.
---

# Dispatch

Execute Foreman's selected assignment; do not select roles, route, or decide
workflow progression. Read `herdr --skill` unless already loaded and use the
installed CLI as the syntax authority. Require `HERDR_ENV=1`; otherwise return
BLOCKED. Definitions live in `.agents/agents/` relative to Workshop,
independently of the target project.

Foreman supplies the selected definition, scoped assignment, acceptance
outcomes, target path, selected model/reasoning options, and either a new
implementation branch/base/path or existing task worktree/session. Return
missing inputs instead of inventing requirements. Runtime names use the
definition name plus a short unique suffix when needed, within Herdr's
32-character limit.

## Native Sequence

1. Discover the caller using `herdr pane current --current`, unless Foreman
   supplied an explicit caller. Use its returned workspace ID, not cached IDs
   or the UI-focused workspace. Confirm the intended repository with
   `herdr worktree list --workspace <caller-id>`.
2. After selection resolves, create new implementation isolation with
   `herdr worktree create --workspace <caller-id> --branch <branch> --base <ref>
   --path <absolute-task-path> --no-focus`. For an existing task, use
   `herdr worktree open --workspace <caller-id> --path <task-path> --no-focus`.
   Read task workspace/root pane IDs from the JSON response. Never substitute
   `--cwd` for the caller: it can select an older workspace for the same repo.
   For investigation without an assigned task worktree, use the assigned
   target path and a native sibling shell pane; do not create a worktree.
3. Verify actual layout using `herdr api snapshot`: caller and task share the
   intended repository key, caller is the first primary workspace for that key
   (the visible Spaces root), and task is its linked child. For sibling
   investigation, verify its pane belongs to the caller workspace. Preserve
   main focus. If placement cannot be established, return BLOCKED with retained
   IDs; do not reorder, move, close, or rewrite Herdr state. Duplicate primary
   workspaces can affect the visible root.
4. Start the selected role in the returned available shell pane. Craftsman
   uses `workspace-write`; Surveyor uses `read-only`. Verify actual runtime
   model/reasoning from terminal output before prompting and after completion.
   Echoed arguments alone are insufficient: a mismatch, unverifiable explicit
   selection, or model error is BLOCKED. Return it to Foreman without switching,
   retrying, or rerouting.
5. Load the complete definition and assignment as one prompt. These Markdown
   definitions are explicit session instructions, not automatically registered
   Codex agent types. Consume the role's own handoff contract. Reuse the same
   worktree and appropriate role session for subsequent assignments.

This parameterized PowerShell example reopens an existing task. Foreman supplies
`$dispatchTaskPath`, `$dispatchName`, `$dispatchModel`, `$dispatchReasoning`,
`$dispatchSandbox`, `$dispatchDefinitionPath`, and `$dispatchAssignment`.
Check every native command's exit code and stop on error. Apply the checks above
at the indicated boundaries before proceeding.

```powershell
$dispatchCaller = (herdr pane current --current | ConvertFrom-Json).result.pane
$dispatchWorkspace = $dispatchCaller.workspace_id
herdr worktree list --workspace $dispatchWorkspace
$dispatchOpened = herdr worktree open --workspace $dispatchWorkspace --path $dispatchTaskPath --no-focus | ConvertFrom-Json
$dispatchPane = $dispatchOpened.result.root_pane.pane_id
herdr api snapshot
# Verify caller root, task child, and preserved focus before starting.
herdr agent start $dispatchName --kind codex --pane $dispatchPane -- -C $dispatchTaskPath --sandbox $dispatchSandbox -m $dispatchModel -c "model_reasoning_effort=$dispatchReasoning"
herdr agent read $dispatchName --source visible --lines 40
# Verify actual runtime model/reasoning before submitting.
$dispatchRole = Get-Content -Raw -LiteralPath $dispatchDefinitionPath
$dispatchPrompt = $dispatchRole + "`n`nForeman assignment:`n" + $dispatchAssignment
herdr agent prompt $dispatchName $dispatchPrompt --wait --timeout 45000
herdr agent get $dispatchName
herdr agent read $dispatchName --source recent-unwrapped --lines 160
herdr api snapshot
```

## Consume and Return

Native `done`/`idle` proves readiness, not success; model errors can settle in
those states. Report COMPLETE only with a substantive complete handoff. Return
BLOCKED for startup failure, missing handoff, or model/tool error, with the
observed error and any partial work.

If waiting expires or `get` still shows working, inspect state/output and
report whether work remains active; never blindly resubmit. Foreman may assign
continued monitoring with `herdr agent wait <name> --timeout 45000`. Use visible
text while working and recent-unwrapped output once settled. If completed
Surveyor output cannot be recovered read-only, return BLOCKED; never request
a file write from that role.

Return the role handoff, worktree path/branch when applicable, runtime name,
workspace/pane IDs, native session ID if exposed by `agent get`, and actual
runtime/layout evidence. Foreman owns the next assignment and resolves blockers.
Only one role actively operates on a task worktree at a time. Release owned
transient resources before handoff and retain sessions/worktrees for sequential
work; do not publish, merge, or clean them up.
