# Workshop

## Mission

Build a portable orchestration workspace for coding agents. Workshop coordinates
work; each managed repository remains independent and owns its project rules,
architecture, verification commands, dependencies, and Git history.

## Current scope

The current milestone is the Codex + Herdr `workshop-foreman` MVP. Read the target
repository's applicable `AGENTS.md` before dispatching work there. Target-project
instructions override Workshop's generic worker defaults for work in that target.

Do not add proposed skills, harness adapters, agents, or configuration until a
real workflow needs them.

## Boundaries

- The Foreman owns intake, delegation, monitoring, verification, review, and
  the user-facing result.
- Substantive target-project edits belong in dedicated worker worktrees.
- Never add Workshop support files to a managed repository merely to integrate it.
- Never stash, reset, force-clean, merge, push, or delete branches without the
  authorization required by the target repository and the user.
- Keep machine paths, secrets, cloned projects, worktrees, and raw eval runs out
  of Git. Keep durable skills, profiles, eval definitions, and project indexes in
  Git.

## Verification

Run `pwsh -File tests/validate.ps1` after changing Workshop skills, profiles,
eval definitions, or repository structure. Live Herdr checks must use an isolated
named test session and disposable repository; they must prove the default session
and unrelated repositories were unchanged.

## Workflow observations

Update `WORKFLOWS.md` when work reveals a reusable multi-step workflow, recurring
friction, or a repeated decision that may deserve a skill. Record outcomes and
evidence, not command transcripts. Reuse an existing skill before proposing a new
one, and create a skill only after the workflow and trigger are clear.
