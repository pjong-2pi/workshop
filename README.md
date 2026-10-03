# Workshop

A portable workspace for coordinating Codex agents inside Herdr. Managed
repositories own their instructions, dependencies, verification, and Git history.

Use the minimum orchestration, implementation, testing, and review necessary for
the task. All implementation delegates; substantive delegated work uses isolated
worktrees; high-risk changes receive independent review. Foreman owns the request
and readiness decision, while `workshop-delegate` performs visible worker
dispatch. A cheap Fitter performs authorized GitHub mechanics.

```text
User -> Foreman (optional JEV chooser advice)
          -> workshop-delegate -> implementation worker
          -> proportional verification
          -> independent reviewer when warranted
          -> Fitter -> github-create-pr
```

Merge uses `github-merge-pr`; after one unambiguous current PR awaits a decision,
clear contextual approval may authorize that PR unless a no-merge constraint
remains. Cleanup closes only Foreman-known task auxiliaries, then is safe and
best-effort; a directory held by Windows can be left for later.

## Getting started

Requires Git, GitHub CLI, Codex CLI, Herdr, and PowerShell 7.

```powershell
pwsh -NoProfile -File scripts/setup.ps1
```

Setup creates ignored `projects/` and `.local/`, checks the toolchain and
authentication, and records initialization. Run it for initial setup, not routine
development. Use `scripts/check-environment.ps1` for environment diagnostics.

After changing Workshop skills, profiles, eval definitions, or structure, run:

```powershell
pwsh -NoProfile -File tests/validate.ps1
```

Run relevant behavioral script checks when their behavior changes; the existing
disposable-fixture suite is available for broader changes:

```powershell
pwsh -NoProfile -File tests/run.ps1
```

## Routing and diagnostics

JEV chooser skills are optional independent advice, not a fixed pipeline. Their
generic helper accepts only caller-supplied sanitized state, choices, instructions,
and criteria, then either returns one allowed confident choice or no result.
Callers retain ordinary judgment and safe profile defaults. Model choices are
caller-supplied observed `model@reasoning` pairs from Stocktake; Fitter remains at
the PR gate outside general advice. No JEV telemetry is retained.

Tracked `.codex/config.toml` enables network in trusted workspace-write sessions;
managed policy may override it.

## Layout and evaluation

- `.agents/skills/`: Foreman policy, delegate mechanics, optional JEV choosers,
  bootstrap, cleanup, inventory, and GitHub mechanics.
- `.codex/agents/`: implementation, optional reviewers, and cheap Fitter.
- `scripts/`: bootstrap, environment checks, and generic advisory JEV choice.
- `catalog/models.md`: observed model inventory.
- `tests/`: structural invariants and existing disposable behavior checks.
- `evals/`: representative outcome-level behavioral definitions.
- `WORKFLOWS.md`: observed recurring workflows.

Managed repositories normally live in ignored `projects/`; explicit external
repositories are also supported without installing Workshop files there.
Behavioral eval definitions are not claims of executed agent runs. A future
isolated harness supplies traces and grading; no universal release-pass ceremony
is required by the MVP.
