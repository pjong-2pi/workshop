# Workshop

Workshop coordinates development work on Windows with Codex + Herdr already
installed. [PRD.md](PRD.md) defines requirements; [ROADMAP.md](ROADMAP.md)
defines milestones. This guide covers the current Milestone 1 delegation path,
not completion of the full first-version workflow.

## Start as Foreman

Open the main repository in Herdr and start Codex there. Keep that session at
the visible Spaces root. In the current Codex session, ask:

```text
Read AGENTS.md, PRD.md, ROADMAP.md, and
.agents/agents/workshop-foreman.md. Act as workshop-foreman.
Scope my request and delegate execution through workshop-dispatch.
```

Role definitions are Markdown instructions loaded explicitly into each native
session; they are not automatically registered Codex agent types.

| Location | Purpose |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Project operating instructions |
| [workshop-foreman](.agents/agents/workshop-foreman.md) | Scope, select, dispatch, and consume handoffs |
| [workshop-craftsman](.agents/agents/workshop-craftsman.md) | Implement a scoped change and verify it |
| [workshop-surveyor](.agents/agents/workshop-surveyor.md) | Investigate a scoped question read-only |
| [workshop-dispatch](.agents/skills/workshop-dispatch/SKILL.md) | Native Herdr isolation, role launch, and handoff retrieval |

While JEV routing and Stocktake are unavailable, Foreman reports that limitation
and selects directly using the PRD fallback. Use available model/reasoning
options; no particular model is required. Stocktake and bounded JEV routing
are planned for Milestone 2.

## Delegate a scoped change

For example, ask Foreman to update one document, specifying the desired outcome
and allowed files. Foreman supplies dispatch with the selected role definition,
assignment, acceptance outcomes, target repository, model/reasoning options,
and either a new branch/base/absolute task path or an existing task worktree
and session. Dispatch returns missing prerequisites as BLOCKED.

Dispatch reads `herdr --skill` for installed syntax and requires `HERDR_ENV=1`.
After selection resolves, it uses Herdr to create one implementation worktree
linked under the main repository's visible Spaces root. The native pattern
below illustrates isolation only; Foreman supplies the variables, and dispatch
checks every exit code before continuing:

```powershell
$dispatchCaller = (herdr pane current --current | ConvertFrom-Json).result.pane
$dispatchWorkspace = $dispatchCaller.workspace_id
herdr worktree list --workspace $dispatchWorkspace
$dispatchCreated = herdr worktree create --workspace $dispatchWorkspace --branch $dispatchBranch --base $dispatchBase --path $dispatchTaskPath --no-focus | ConvertFrom-Json
$dispatchPane = $dispatchCreated.result.root_pane.pane_id
herdr api snapshot
```

Use the caller/current workspace and IDs returned by native commands, never
cached session IDs or the UI-focused workspace. For an existing task, replace
creation with `herdr worktree open --workspace $dispatchWorkspace --path
$dispatchTaskPath --no-focus` and read its returned IDs. Do not substitute
`--cwd` for the caller workspace.

Before launch, dispatch verifies that caller and task share the intended
repository key, the caller is its first primary workspace, and the task is
its linked child, with main focus preserved. Unverifiable placement is BLOCKED;
dispatch retains the IDs rather than rearranging Herdr state.

Dispatch starts Craftsman in the returned shell pane with `workspace-write`,
verifies the actual runtime model/reasoning, then submits the complete role
definition and assignment together. See the dispatch skill for the full native
start/prompt/read sequence. Only one role actively operates on the task
worktree at a time; retain the worktree and sessions for sequential assignments.
Workshop definitions stay in Workshop when the target is another repository.

## Investigation and handoffs

Use a separate Surveyor session for substantive investigation. Dispatch uses
`read-only`; Surveyor reports evidence without edits or mutating checks. If no
task worktree is assigned, dispatch uses a native sibling shell pane in the
caller workspace at the assigned target path, without creating a worktree.

Craftsman returns `STATUS`, `CHANGED`, `CHECKS`, `BLOCKERS`, and `NOTES`.
Surveyor returns `STATUS`, `FINDINGS`, `EVIDENCE`, `BLOCKERS`, and `NOTES`.
Both return COMPLETE or BLOCKED and release owned transient resources while
preserving task sessions and worktrees. Workers do not reroute or redelegate;
Foreman consumes their handoffs and owns every next transition.

Craftsman runs checks relevant to the assigned change and reports commands,
actual results, and limitations. For a documentation change, check local links
and `git diff --check`, then inspect the scoped diff. Surveyor cites files and
non-mutating commands. Dispatch verifies runtime and layout evidence and
retrieves a substantive handoff: native `done`/`idle` alone does not prove
success. Missing output, model/tool errors, or unavailable prerequisites are
reported to Foreman as blockers; active work is monitored without blindly
resubmitting the assignment.

## Checks and behavioral smoke tests

Run the dependency-free fast check with PowerShell 7; it launches no agents:

```powershell
pwsh -NoProfile -File .\tests\check-workshop.ps1
```

From another directory, pass the script's absolute path. It derives the project
root from its location; `-ProjectRoot` can select an isolated test fixture.
It checks agent/skill metadata and naming, inline local Markdown file links,
and whitespace in tracked changes and new Markdown/PowerShell files. URI-escaped
paths are decoded; query strings and fragments are stripped for file checks.
Heading anchors, reference-style links, remote resources, and the local ignored
knowledgebase are outside this fast check.

Run relevant smoke scenarios when role or dispatch behavior changes, through
Foreman's assignments and the native dispatch skill:

- Surveyor: require a deliberately absent input file. Expect a substantive
  BLOCKED handoff, no substituted sources or inferred requirements, no file
  changes, and no worker delegations.
- Craftsman: assign a small, real single-file change with explicit outcomes and
  allowed scope. Expect only that file to change, relevant checks, and the
  Craftsman's own handoff contract; return genuine missing prerequisites.
- Dispatch: inspect fresh native IDs, main-root/task-child placement, preserved
  focus, actual selected model/reasoning and role sandbox. Submit the complete
  definition and assignment; verify the substantive handoff rather than treating
  `done`/`idle` as success. Return placement/model/tool errors to Foreman.

Compare file changes and native evidence before and after each scenario. Reuse
the task worktree sequentially. Model-backed smoke tests are separate from the
fast check and need only run for relevant changes.

## Planned progression

Independent Inspector review and same-session remediation/re-review are planned
for Milestone 3. Delegated publication, PR creation, explicitly user-authorized
merge, and `/workshop-clear-bench` cleanup are planned for Milestone 4. The full
end-to-end demonstration is Milestone 5. Implementation completion is neither
independent review nor permission to publish or merge.
