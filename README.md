# Workshop

Workshop, inspired by: [kunchenguid/firstmate](https://github.com/kunchenguid/firstmate), is a Git-clonable, project-independent workspace for coordinating
development on Windows with Codex + Herdr already installed. It contains role
instructions, skills, and PowerShell helpers for delegated investigation,
implementation, optional JEV routing, independent review, publication, and
explicitly authorized merge and cleanup. Target project repositories remain
independent of Workshop.

The repository is [pjong-2pi/workshop](https://github.com/pjong-2pi/workshop).
[PRD.md](PRD.md) defines requirements; [ROADMAP.md](ROADMAP.md) records milestones
and earlier demonstration evidence. Current role and skill definitions describe
the implemented workflow.

## Start as Foreman

Clone the repository, then open it in Herdr:

```powershell
git clone https://github.com/pjong-2pi/workshop.git
```

Workshop assumes Codex, Herdr, Git, and PowerShell 7 are available. Publication
and merge also require an authenticated GitHub CLI (`gh`). Workshop does not
install or configure these tools.

Open the main repository in Herdr and start Codex there. Keep that session at
the visible Spaces root. In the current Codex session, ask:

```text
Read AGENTS.md, PRD.md, ROADMAP.md, and
.agents/agents/workshop-foreman.md. Act as workshop-foreman.
Scope my request and delegate execution through workshop-dispatch.
Run workshop-stocktake at session start.
Use workshop-jev-route-job when available for fresh selections with meaningful alternatives.
Otherwise, select directly.
```

Role definitions are Markdown instructions loaded explicitly into each native
session; they are not automatically registered Codex agent types.

| Location | Purpose |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Project operating instructions |
| [workshop-foreman](.agents/agents/workshop-foreman.md) | Scope, select, dispatch, and consume handoffs |
| [workshop-craftsman](.agents/agents/workshop-craftsman.md) | Implement a scoped change and verify it |
| [workshop-surveyor](.agents/agents/workshop-surveyor.md) | Investigate a scoped question read-only |
| [workshop-inspector](.agents/agents/workshop-inspector.md) | Independently review changes and test sufficiency read-only |
| [workshop-fitter](.agents/agents/workshop-fitter.md) | Merge an explicitly authorized reviewed PR, confirm success, and invoke cleanup |
| [workshop-dispatch](.agents/skills/workshop-dispatch/SKILL.md) | Native Herdr isolation, role launch, and handoff retrieval |
| [workshop-stocktake](.agents/skills/workshop-stocktake/SKILL.md) | Discover session resources and refresh the local routing catalog |
| [workshop-jev-route-job](.agents/skills/workshop-jev-route-job/SKILL.md) | Make and validate bounded JEV selections |
| [workshop-publish](.agents/skills/workshop-publish/SKILL.md) | Publish an Inspector-approved scoped change as a PR |
| [workshop-clear-bench](.agents/skills/workshop-clear-bench/SKILL.md) | Remove the assigned clean task worktree after confirmed merge |

At session start, Stocktake takes the current Codex Available skills list,
including global and plugin skills, and reads Workshop agent/skill definitions
and the native Codex model catalog. It writes Git-ignored
`.local/routing-catalog.json`. Manually entered numeric `cost` and
`intelligence` ratings survive refreshes; new models remain unrated and absent
models stay unavailable. On refresh failure the previous catalog remains intact.

Use `workshop-jev-route-job` when available for fresh selections with meaningful alternatives.
Otherwise, select directly. When routing, give the scoped
assignment and capability requirements without preselecting a
concrete agent. JEV receives all
available agents or skills and, for an agent, all selectable model/reasoning
pairs. Foreman checks the selected role's boundaries; a usable selection goes
unchanged to dispatch. Consult JEV only for meaningful alternatives; invoke the
sole `workshop-publish` capability directly after review. Missing TypeSafe access
or an unusable answer triggers the PRD's direct-selection fallback. Set
`TYPESAFE_API_KEY` in the environment for live JEV calls; no key is stored in
Workshop. The routing skill gives the exact invocation and typed script inputs.
Live routing sends the scoped assignment, requirements, full role definitions,
and available skill/model metadata to `https://api.typesafe.ai/v1/systemone`.
Authorize that scope before routing; another user's local consent does not
grant consent for your session. Respect native network controls and use direct
selection if routing is unavailable or rejected.
Use the native picker/runtime check in dispatch to confirm the selected model
is accepted by the current account; the native catalog alone cannot prove
account entitlement for every listed model.

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

Surveyor never reviews code changes or substitutes for Inspector. Inspector
returns `VERDICT`, `FINDINGS`, `CHECKS`, `BLOCKERS`, and `NOTES`, including an
explicit PASS/LGTM or located blocking/nonblocking findings and test-sufficiency
assessment. Missing Inspector availability blocks review.

For implementation tasks, Foreman continues after Craftsman COMPLETE through
Inspector review, remediation in the same Craftsman and re-review in the same
Inspector session, then delegated publication until a PR exists, unless blocked
or the user pauses. After PASS/LGTM, Foreman returns the approved scope to the
same Craftsman, which invokes `workshop-publish`. It stages only Foreman's
explicit reviewed file list, commits, pushes, and creates the PR. Worker COMPLETE
does not finish the task; PR creation does not authorize merging.

After explicit user merge authorization, Foreman dispatches Fitter with the
reviewed PR identity and head SHA. Fitter checks that identity, required checks
and reviews, and squash availability, then requests an immediate squash merge
bound to the reviewed SHA. It confirms the merge before invoking Clear Bench;
failed or unconfirmed merges retain the task resources.

Clear Bench fast-forwards main only when clean, removes only the assigned clean
task worktree through Herdr, and preserves dirty or unrelated work. It never
force-deletes resources. If ordinary branch deletion refuses after a squash,
Fitter reports the retained branch. Foreman collects the merge and cleanup
handoff; it does not execute these operations itself.

Craftsman runs checks relevant to the assigned change and reports commands,
actual results, and limitations. For a documentation change, check local links
and `git diff --check`, then inspect the scoped diff. Surveyor cites files and
non-mutating commands. Dispatch verifies runtime and layout evidence and
retrieves a substantive handoff: native `done`/`idle` alone does not prove
success. Missing output, model/tool errors, or unavailable prerequisites are
reported to Foreman as blockers; active work is monitored without blindly
resubmitting the assignment.

## Checks and behavioral smoke tests

Run the dependency-free fast checks with PowerShell 7; they launch no agents:

```powershell
pwsh -NoProfile -File .\tests\check-workshop.ps1
pwsh -NoProfile -File .\tests\check-routing.ps1
pwsh -NoProfile -File .\tests\check-publication.ps1
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

## Local state and security

Write Workshop incident reports to `.local/incident-report.md`.

The knowledgebase, routing catalog under `.local/`, root `.env` files (except
`.env.example`), logs, raw eval runs, managed projects, temporary worktrees, and
the local incident report are excluded from Git. Keep credentials and private
notes in ignored local state; ignore rules do not remove already tracked files
or Git history. See [SECURITY.md](SECURITY.md) for security reporting status.

Workshop is licensed under the [MIT License](LICENSE).

Windows with Codex + Herdr is the current target. A new-machine bootstrapper,
other operating systems, and other harnesses remain deferred in the PRD.
Fitter and Clear Bench are implemented; earlier roadmap status text predates
those definitions. Their presence does not by itself establish completion of
the full end-to-end acceptance demonstration.
