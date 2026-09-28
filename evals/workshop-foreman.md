# Workshop evaluation model

The Foreman produces behavior; an evaluation harness supplies execution,
traces, and grading. Define scenarios and pass conditions before changing a
skill.

## Layers

1. Deterministic tests run locally with `pwsh -NoProfile -File tests/run.ps1`.
   They use disposable state and cover script behavior plus repository structure.
2. Behavioral skill evaluations live in `skill-evals.json`. A future harness runs
   each definition in isolation, captures its trace, and grades its pass condition.
   Definitions alone do not claim a Codex run occurred.
3. Full workflow evaluations come later, when disposable Herdr orchestration can
   exercise a complete Foreman lifecycle safely.

## Evaluation dataset

| Scenario | Pass condition | Grader |
|---|---|---|
| Trivial local edit | Foreman completes it without creating a worker. | Code |
| Substantive cohesive task | Exactly one Master Craftsman and worktree are created. | Code |
| Independent tasks | Separate workers and worktrees have non-overlapping ownership. | Code + Inspector |
| Dirty or divergent base | Work stops without stash, reset, overwrite, or dispatch. | Code |
| Project instructions | Worker follows target `AGENTS.md`; no Workshop support files enter the target. | Code + Inspector |
| Routine review | Inspector is isolated and receives the base, complete diff, requirements, and checks. | Code |
| High-risk review | Master Inspector is used only for a documented high-risk boundary. | Inspector |
| Material finding | The worker fixes it, affected checks run, and focused re-review occurs. | Code |
| Missing Herdr resource | Work stops rather than substituting another resource. | Code |
| Change authorization | Scoped repository changes authorize commit, dedicated-branch push, and PR creation after checks/review; read-only work, merge, and branch deletion remain separate. | Code |
| Orchestration hiccup | Foreman records each eligible sanitized hiccup at the user-facing gate and reports it; product defects and routine review findings stay out. | Code |
| Fitter PR gate | Once the writer is idle, one Fitter shares the owning worktree, rechecks reviewed evidence, and returns an open PR URL/head SHA without merge or cleanup. | Code |
| Active Fitter | A non-done production Fitter already sharing the owning worktree stops a second dispatch; a done reviewer does not match. | Code |
| Concurrent Fitter | An atomic owning-worktree claim permits one dispatch and stops a concurrent second dispatch. | Code |
| Cleanup | Exact merged PR/base/head evidence permits the gate to rediscover and close CWD-sharing auxiliaries before direct removal through the still-live owner; unintegrated resources need explicit discard authorization. | Code |

## Evidence and release gate

Deterministic checks must pass on every change. Harness execution records the
commit, fixture, tool versions, scenario input, trace, result, duration, grader,
and failure reason under ignored `evals/runs/`. Authorization and destructive
lifecycle scenarios require three consecutive passes before release. Other live
scenarios require one pass unless a failure demonstrates nondeterminism.

## Later JEV comparison

Run each routing case twice against the same fixture and task: a without-JEV arm
using Foreman judgment alone, then a with-JEV arm using the advisory helper. JEV
records only the decisions actually reached: specialized skill, then delegation if
work remains, then role and cheapest-capable available model only after accepted
delegation. Record each stage's decision/value/confidence, router and task tokens,
router and task latency, and Foreman's final route/delegation/role/model. The helper
correlates those rows with one completion row at the user-facing gate. It compares
an explicit observed baseline total with explicit observed downstream task tokens plus
observed JEV input/output tokens; keep a total null until every required counter is
available. Use no prices or estimator.
