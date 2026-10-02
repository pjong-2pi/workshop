# Workshop

A portable workspace for coordinating Codex agents inside Herdr. Managed
repositories own their instructions, dependencies, verification, and Git history.

Use the minimum orchestration, implementation, testing, and review necessary for
the task. All implementation delegates; substantive delegated work uses isolated
worktrees; high-risk changes receive independent review. Foreman owns the request
and readiness decision. A cheap Fitter performs authorized GitHub mechanics.

```text
User -> Foreman (optional JEV advice)
          -> implementation worker
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

JEV cheaply advises skill, role, then one `model@reasoning` pair where applicable.
The existing helper validates allowlisted choices and falls back to Foreman
judgment; advice never permits Foreman implementation.
It sends only a sanitized single-line task description of at most 160 characters,
never request/code contents, secrets, or authorization. Model advice uses the
compact current `catalog/models.md`; authorization remains with Foreman.
The Fitter is dispatched at the PR gate, outside general routing.

Ignored `.local/jev-routing.jsonl` contains attempted decision metadata, not task
text. Optional `.local/orchestration-hiccups.jsonl` contains brief sanitized
diagnostics. Hiccups justify durable infrastructure only when repeated usage
demonstrates improved reliability.

Tracked `.codex/config.toml` enables network in trusted workspace-write sessions;
managed policy may override it.

## Layout and evaluation

- `.agents/skills/`: Foreman, bootstrap, cleanup, inventory, and GitHub mechanics.
- `.codex/agents/`: implementation, optional reviewers, and cheap Fitter.
- `scripts/`: bootstrap, environment checks, and advisory JEV helper.
- `catalog/models.md`: observed model inventory.
- `tests/`: structural invariants and existing disposable behavior checks.
- `evals/`: representative outcome-level behavioral definitions.
- `WORKFLOWS.md`: observed recurring workflows.

Managed repositories normally live in ignored `projects/`; explicit external
repositories are also supported without installing Workshop files there.
Behavioral eval definitions are not claims of executed agent runs. A future
isolated harness supplies traces and grading; no universal release-pass ceremony
is required by the MVP.
