# Workshop

A portable agentic development workspace for coordinating coding agents without
coupling managed projects to Workshop.

Workshop currently targets Codex running inside Herdr. Managed repositories keep
their own instructions, dependencies, checks, and Git history; Workshop's Foreman
supplies the orchestration workflow and generic worker profiles.

## Requirements

- Git
- GitHub CLI (`gh`)
- Codex CLI
- Herdr
- PowerShell 7 for the current bootstrap and validation scripts

Bootstrap a new Workshop checkout:

```powershell
pwsh -NoProfile -File scripts/setup.ps1
```

Setup creates the ignored `projects/` and `.local/` directories, validates the
toolchain and authentication, checks Herdr configuration, reports Codex integration
status, and records successful initialization in `.local/setup-complete`. It is
safe to rerun intentionally, but is not part of routine Foreman operation.

Run the lower-level environment diagnostic directly when needed:

```powershell
pwsh -NoProfile -File scripts/check-environment.ps1
```

Run the deterministic test suite:

```powershell
pwsh -NoProfile -File tests/run.ps1
```

`tests/validate.ps1` remains the fast static check used by the suite and when
editing repository structure or eval definitions.

## Evaluation model

Workshop uses three layers: deterministic disposable-fixture tests; behavioral
skill definitions that a harness later executes, traces, and grades; and full
workflow evaluations once disposable Herdr orchestration is available. The
versioned definitions in `evals/skill-evals.json` are inputs to a harness, not
claims that Codex has been run.

```text
Deterministic tests -> every change and pull request
Behavioral skill evals -> harness execution -> trace -> grading
Full workflow evals -> later
```

## Layout

- `.agents/skills/workshop-foreman/` — primary Herdr orchestration skill
- `.agents/skills/workshop-setup/` — explicit first-time local bootstrap
- `.agents/skills/github-*/` — create, check, and merge pull requests with `gh`
- `.codex/agents/` — generic worker and reviewer profiles
- `evals/` — versioned behavioral evaluation definitions and model
- `scripts/` — bootstrap and environment checks
- `tests/` — deterministic repository checks
- `WORKFLOWS.md` — observed workflows and skill candidates

Target repositories normally live under the ignored `projects/` directory. An
explicit external repository can also be targeted without adding Workshop files
to it. Durable output from the future `workshop-index-project` skill will remain
tracked rather than being treated as runtime state.

## Current milestone

Establish deterministic setup coverage and behavioral skill-eval definitions;
full disposable Foreman runs remain a later evaluation layer.
