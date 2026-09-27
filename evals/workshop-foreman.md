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
| Cleanup | Exact merged PR/base/head evidence permits the gate to rediscover and close CWD-sharing auxiliaries before direct removal through the still-live owner; unintegrated resources need explicit discard authorization. | Code |

## Evidence and release gate

Deterministic checks must pass on every change. Harness execution records the
commit, fixture, tool versions, scenario input, trace, result, duration, grader,
and failure reason under ignored `evals/runs/`. Authorization and destructive
lifecycle scenarios require three consecutive passes before release. Other live
scenarios require one pass unless a failure demonstrates nondeterminism.

## Later JEV comparison

Run each routing case twice against the same fixture and task: a without-JEV arm
using Foreman judgment alone, then a with-JEV arm using the advisory helper. Record
the expected route and final route to grade routing accuracy; router and task
tokens; router and task latency; recommended and final delegation/model choices;
and total tokens. The helper correlates its routing row with a completion row at
the user-facing gate. It compares an explicit observed baseline total with an
explicit JEV-route token projection plus observed JEV input/output tokens. Keep a
total null until every required counter is available; use no prices or estimator.
