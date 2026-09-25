# Workshop

A portable agentic development workspace for coordinating coding agents without
coupling managed projects to Workshop.

Workshop currently targets Codex running inside Herdr. Managed repositories keep
their own instructions, dependencies, checks, and Git history; Workshop's Foreman
supplies the orchestration workflow and generic worker profiles.

## Requirements

- Git
- Codex CLI
- Herdr
- PowerShell 7 for the current bootstrap and validation scripts

Check the local toolchain:

```powershell
pwsh -File scripts/check-environment.ps1
```

Validate the repository:

```powershell
pwsh -File tests/validate.ps1
```

## Layout

- `.agents/skills/workshop-foreman/` — primary Herdr orchestration skill
- `.agents/skills/workshop-setup/` — read-only environment readiness check
- `.agents/skills/github-*/` — create, check, and merge pull requests with `gh`
- `.codex/agents/` — generic worker and reviewer profiles
- `evals/` — versioned behavioral evaluation definitions
- `scripts/` — bootstrap and environment checks
- `tests/` — deterministic repository checks
- `WORKFLOWS.md` — observed workflows and skill candidates

Target repositories normally live under the ignored `projects/` directory. An
explicit external repository can also be targeted without adding Workshop files
to it. Durable output from the future `workshop-index-project` skill will remain
tracked rather than being treated as runtime state.

## Current milestone

Prove `workshop-foreman` against disposable fixture repositories: validate the
environment, create isolated workers, preserve authorization boundaries, review
the result, and clean up only resources proven safe to remove.
