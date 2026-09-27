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

For every task, map the request without copying its text into this exact
single-line routing context grammar:
`intent=<setup|bench-cleanup|pr-create|pr-check|pr-merge|implementation|investigation|review|other>;scope=<workshop|managed-repo|pr|workspace|local>;risk=<routine|architecture|concurrency|security|data-loss|authority>;effort=<trivial|substantive>`.
It contains only allowlisted tags: never include credentials, secrets,
private/customer data, code or file contents, or authorization material. Import
`scripts/jev-routing.ps1` and call
`Get-WorkshopJevDecision -RoutingContext $RoutingContext -Root $WorkshopRoot`.
JEV is advisory only:
use its minimal `skill`, `agent`, `model`, and `delegate` decision only when its
source is `jev`; otherwise use existing Foreman judgment. Foreman remains
authoritative for intake, user interaction, authorization, Herdr/worktrees,
verification, review, escalation, and cleanup. Never let a JEV decision bypass
these rules or select anything outside the existing skills and profiles.

The helper reads only `TYPESAFE_API_KEY` from the process environment, applies a
bounded API call and confidence/allowlist validation, and records an ignored local
telemetry row. Do not run it in deterministic tests with network credentials.

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
base, then record it as the owning workspace with its returned pane identifiers.
Auxiliary workspaces are recorded CWD-sharing workspace IDs excluding the owning
workspace ID, even though the owner is also a worker workspace:

```powershell
herdr worktree create --workspace $Workspace --cwd $Repository --branch $Branch --base $Base --path $WorktreePath --label $Label --no-focus --trust-repository
herdr worktree list --workspace $Workspace --cwd $Repository
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
deletion; stop before either unless separately authorized.

Give every reviewer a separate read-only workspace. Use the target's applicable
review profile when present, otherwise Workshop's `inspector` or
`master-inspector`. Supply the base, complete diff, requirements, and check results.
Use the Master Inspector only for architecture, concurrency, security, data-loss,
or other high-risk boundaries. Material fixes require affected checks and focused
re-review.

## Finish

Inspect the complete diff and rerun checks required by the target instructions or
not adequately evidenced by workers. After verified GitHub merge, pass the exact
PR, repository, and base to the clear-bench gate with the owning workspace ID.
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
