---
name: workshop-dispatch
description: Execute a Foreman-selected assignment through native Herdr and return the selected role's handoff.
---

# Dispatch

Foreman supplies the role definition, scoped assignment, target project,
selected model/reasoning, and new-task branch/base/path or existing execution
reference. Execute that selection; return blockers to Foreman without routing,
changing scope, or deciding the next workflow step. Read `herdr --skill` unless
already loaded; use its native commands from a Herdr-managed session.

## Execute

1. Use the explicit main caller supplied by Foreman, or discover it with
   `herdr pane current --current`. Confirm its target repository using
   `herdr worktree list --workspace <main-id>` and check the native workspace
   view for the correct visible main root. An older main for the same repo can
   become the root: return that conflict before opening task resources.
   Missing caller repository membership alone is not a conflict; native
   create/open can establish it.
2. Create implementation isolation with `herdr worktree create --workspace
   <main-id> --branch <branch> --base <ref> --path <task-path> --no-focus`, or
   reopen the SAME existing task with `herdr worktree open --workspace <main-id>
   --path <task-path> --no-focus`. Never substitute `--cwd` for the main ID.
   Use returned workspace/pane IDs and checkout/branch evidence, not inferred
   IDs. Confirm the task belongs underneath that main and uses the assigned
   repository/worktree. Explicit caller targeting, the native returned source
   and task provenance, and the workspace view establish this; use one relevant
   snapshot if association remains unclear, then return BLOCKED if unresolved.
   For read-only work without a task worktree, use a sibling shell pane at the
   assigned project path instead. Preserve user focus with `--no-focus`.
3. Start the selected role in an available shell pane, or reuse its assigned
   session in the same task worktree. Never replace or prompt an unrelated
   active agent. Craftsman and Fitter use `workspace-write`; Surveyor and Inspector use `read-only`.
   Generic command execution may use a caller-selected location; place its pane
   outside any task resources the execution will remove. Only one role actively
   operates on a task worktree at a time.
   Pass the selected model/reasoning and confirm the actual startup settings
   once in visible output: launch arguments previously differed from the
   runtime selection. Return a mismatch or model error to Foreman; do not
   switch models or retry the assignment.
4. Submit the complete definition from Workshop's `.agents/agents/` plus the
   scoped assignment. These are explicit instructions, not registered native
   agent types. Waiting for a handoff or returning an execution reference is
   caller-selected. For a nonwaiting agent prompt, omit `--wait`; return the
   same agent, pane, and workspace references for later handoff collection.
   Use a stable sibling pane outside task resources that may be removed. This
   is the caller's selected dispatch behavior, not a role-specific rule.

## Native Example

Foreman supplies the variables below; check native command failures before
continuing. This reopens a task and starts a new selected role. For an assigned
existing role session, reuse it and continue at prompt submission.

```powershell
$main = (herdr pane current --current | ConvertFrom-Json).result.pane.workspace_id
herdr worktree list --workspace $main
herdr workspace list
# Confirm the target repo/main root; do not open beneath an older main.
$task = herdr worktree open --workspace $main --path $taskPath --no-focus | ConvertFrom-Json
$pane = $task.result.root_pane.pane_id
# Confirm returned task path/branch and association with the selected main.
herdr agent start $agentName --kind codex --pane $pane -- -C $taskPath --sandbox $sandbox -m $model -c "model_reasoning_effort=$reasoning"
herdr agent read $agentName --source visible
# Confirm actual selected model/reasoning and role sandbox before submitting.
$role = Get-Content -Raw -LiteralPath $definitionPath
$prompt = $role + "`n`nForeman assignment:`n" + $assignment
herdr agent prompt $agentName $prompt --wait --timeout 45000
herdr agent read $agentName --source recent-unwrapped
```

## Handoff or Blocker

Use the selected role's contract. `idle`/`done` is not a successful assignment:
an unsupported model previously settled there without a handoff. Return the
actual handoff or observed error, with any partial work and execution reference.

If waiting expires, use `herdr agent get <name>` and available output to report
whether work is still running. Keep that reference for Foreman to continue the
same session with `herdr agent wait <name> --timeout 45000`; never resubmit merely
because a wait ended. Read visible output while working, completed output once
settled. If a handoff cannot be read, return that limitation; Surveyor must not
write recovery files. Keep the task/session for sequential roles and release
owned transient resources before returning.
