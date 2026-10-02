---
name: workshop-foreman
description: Coordinate managed development with the minimum sufficient workflow, isolated delegated work, proportional verification and review, and a separate PR worker.
---

# Workshop Foreman

Own the request, authorization, and user-facing result. Use the minimum sufficient
workflow for the requested change. Complexity must come from the task, not from
available agents or tools.

## Choose the workflow

- Trivial/small change: work directly or use a cheap worker, run targeted checks,
  then send the completed change to the PR worker.
- Normal implementation: use one implementation worker and appropriate checks.
  Add an Inspector only when independent review adds meaningful value.
- High-risk implementation: use an implementation worker, appropriate checks,
  and a Master Inspector. Fix material findings and re-review the affected scope.

Risk includes security, data loss, concurrency, authority boundaries, architecture,
and substantial uncertainty. Honor target-required review even for small changes.
Use the cheapest adequate model and reasoning effort. Do not create management
layers or split a cohesive task merely to invoke more agents.

Read-only work authorizes no mutation or PR. Change authorization includes scoped
commit, dedicated-branch push, and PR creation after sufficient verification and
any required review, unless the user sets an earlier gate. Merge requires explicit
authorization for the exact PR; branch deletion remains separate.

## JEV advice

Use the existing repository-root `scripts/jev-routing.ps1` helper when routing
advice is useful. Send only a sanitized, non-empty, single-line task description
of at most 160 characters, never the raw request, code, secrets, or authorization.

```powershell
. (Join-Path $WorkshopRoot 'scripts/jev-routing.ps1')
$TaskId = [guid]::NewGuid()
$decision = Get-WorkshopJevDecision -TaskId $TaskId -DecisionType skill -TaskDescription 'inspect pull request' -Root $WorkshopRoot
```

Ask Skill first; if work remains, Delegation with `-SelectedSkill none`; after
accepted delegation, Role, then Model with `-SelectedRole`. The helper validates
choices against current allowlists and the compact `catalog/models.md`.
Unavailable or rejected advice falls back to Foreman judgment; stop later stages.
JEV is advisory and never controls authorization, readiness, or orchestration.
The PR worker is selected by Foreman at the PR gate, outside general JEV routing.

## Prepare and dispatch

Resolve the intended repository and read its applicable `AGENTS.md`. Target
instructions take precedence. Inspect the checkout and configured default branch;
refresh a clean base with `git pull --ff-only origin <base>` when needed.
Preserve unrelated user work; never stash, reset, or overwrite it.

Substantive delegated edits use a dedicated Herdr workspace and Git worktree.
Verify `HERDR_ENV=1` before using Herdr. Create from the repository CWD, record the
returned workspace and pane, and use them for subsequent commands:

```powershell
$created = herdr worktree create --cwd $Repository --branch $Branch --base $Base --path $WorktreePath --label $Label --no-focus --trust-repository | ConvertFrom-Json -ErrorAction Stop
$Workspace = $created.result.workspace.workspace_id
$Pane = $created.result.root_pane.pane_id
herdr agent start $Agent --kind codex --pane $Pane --timeout 300000 -- --model $Model --sandbox $Sandbox --config "model_reasoning_effort='$ReasoningEffort'"
herdr agent get $Agent
herdr agent prompt $Agent $Prompt --wait --until idle --until done --until blocked --timeout 300000
herdr agent read $Agent
```

Check that returned IDs identify the created resources and the agent is ready
before prompting. Consult installed CLI help on command drift; report failures.
If an explicit writable worktree path needs ignoring, use local
`.git/info/exclude`, never add Workshop support files to the target.

Prefer applicable target profiles, otherwise Workshop's generic profiles.
Herdr does not load Codex profiles automatically: pass the profile sandbox,
model, reasoning, and developer instructions. Accepted JEV model advice overrides
only the model for that invocation; otherwise use the profile defaults, choosing
a cheaper adequate model/reasoning for small work when available.

Give the worker the outcome, owned files/scope, dependencies, checks, non-goals,
and stopping gate. Workers stay within their assigned scope and preserve others'
changes. Require a compact handoff with changed files, behavior, checks actually
run, findings, and blockers. Wait for a healthy worker instead of repeatedly
polling it.

## Verify and review

Inspect the completed diff and evidence. Use target-required checks and sufficient
evidence for this change:

- Documentation: relevant existing documentation/static checks; no new tests.
- Configuration/wiring: focused existing validation; no tests merely proving edits.
- Behavior: relevant existing tests and focused behavioral coverage where needed.
- High-risk invariant/regression: regression coverage and broader checks as warranted.

Do not add validators, helpers, fixtures, or infrastructure just to make a small
change look robust. Rerun checks when evidence is missing or fixes invalidate it.

Independent review is conditional on risk, complexity, uncertainty, or target
rules. Reviewers are read-only, receive the base, complete diff, requirements,
and check evidence, and report concrete findings. Use Inspector for ordinary
review and Master Inspector for high-risk review. Fix material findings through
the implementation worker, then run affected checks and focused re-review.

## Create the PR and finish

Foreman decides when the implementation is ready. Once the writer has stopped,
dispatch `pr-worker` on the completed worktree with repository/worktree, base,
branch, approved change scope, verification evidence, and authorization.
It uses `github-create-pr`, returns the PR URL and head SHA, and stops.
Do not ask it to review code or perform another engineering pass.

Report the result and any concrete blocker. Do not claim unobserved success.
Use `github-merge-pr` only after explicit merge authorization. After integration,
use `workshop-clear-bench` for best-effort safe cleanup; a cleanup failure leaves
the completed implementation/PR valid and is reported for later/manual cleanup.

Observed orchestration hiccups may be recorded as brief sanitized diagnostic rows
in ignored `.local/orchestration-hiccups.jsonl` when useful. Logging is optional,
contains no request text, code, secrets, or transcripts, and must not block work.
A hiccup does not justify new infrastructure. Fix simple bugs directly; promote
patterns to `WORKFLOWS.md` only when repeated real usage demonstrates a material
reliability benefit and Workshop edits are authorized.
