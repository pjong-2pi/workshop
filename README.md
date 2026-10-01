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

Foreman consults JEV as a confidence-gated, on-demand advisory classifier: first
for a specialized skill (never Foreman itself), then delegation only if work
remains, then role and independently cheapest-capable available model only after
delegation is accepted. It sends a bounded single-line sanitized task description
composed only of the helper's small allowlisted semantic vocabulary; if that cannot
express the task, Foreman safely falls back without asking JEV. Authorization is not
sent to JEV and remains solely with Foreman. It sends only
`selected_skill=none` for delegation or the selected role for model; it
never sends the raw prompt or Foreman risk/effort classifications. It uses the fixed
TypeSafe endpoint only when `TYPESAFE_API_KEY` is present, and falls back to Foreman
judgment on any unavailable, malformed, low-confidence, or disallowed result.
Run JEV in the configured network-enabled context. Only a returned `sandbox-tls`
reason permits Foreman to retry the identical sanitized stage once through approved
network execution via its explicit `ApprovedJevExecution` callback; the helper never
requests escalation; every call is a separate telemetry row under the same task ID.
Ignored `.local/jev-routing.jsonl` correlates each task/stage with the
Foreman's final decision and explicit observed baseline comparison; JEV-assisted
totals are null unless both explicit observed downstream and router counters exist.
It uses no prices or token estimator.

At the user-facing gate, Foreman records observed orchestration hiccups (CLI/tool
drift, avoidable retries, coordination failures, or permission/instruction
ambiguity) as sanitized rows in ignored `.local/orchestration-hiccups.jsonl` and
mentions them in its handoff. Product defects and normal review findings are excluded.

Tracked `.codex/config.toml` enables network access for new trusted Workshop
sessions; managed policy may override it.

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
- `.agents/skills/workshop-clear-bench/` — guarded cleanup of completed Herdr workspaces
- `.agents/skills/workshop-stocktake/` — on-demand local Codex model inventory
- `.agents/skills/github-*/` — create, check, and merge pull requests with `gh`
- `.codex/agents/` — generic worker, reviewer, and Fitter profiles
- `evals/` — versioned behavioral evaluation definitions and model
- `scripts/` — bootstrap and environment checks
- `catalog/models.md` — versioned observed model inventory for future routing input
- `tests/` — deterministic repository checks
- `WORKFLOWS.md` — observed workflows and skill candidates

Target repositories normally live under the ignored `projects/` directory. An
explicit external repository can also be targeted without adding Workshop files
to it. Durable output from the future `workshop-index-project` skill will remain
tracked rather than being treated as runtime state.

## Current milestone

Establish deterministic setup coverage, behavioral skill-eval definitions, and a
minimal Fitter PR gate; full disposable Foreman runs remain a later evaluation
layer.
