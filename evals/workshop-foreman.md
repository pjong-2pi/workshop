# Workshop evaluation model

Tests should demonstrate sufficient evidence for the change. Static validation
protects core metadata, script syntax, and safety boundaries, not command spelling,
prose, or internal orchestration state.

Run `pwsh -NoProfile -File tests/validate.ps1` for Workshop skill/profile/structure
changes. Run relevant existing script checks for behavior changes; the broader
disposable suite remains available as `tests/run.ps1`.

`skill-evals.json` contains representative outcome-level definitions:

- Small implementation tasks use cheap delegation, focused checks, and Fitter PR mechanics.
- Normal implementation delegates substantive work and reviews only when useful.
- Risky changes receive stronger independent review and regression evidence.
- Authorized repository changes reach a scoped verified PR; clear contextual approval may merge one unambiguous current PR.
- Read-only work avoids mutation; merge requires explicit authorization.
- Optional JEV chooser failure falls back safely and unrelated user changes remain intact.
- Cleanup protects user work, closes only known auxiliaries, and reports ordinary failures without forced recovery.

An isolated harness must execute a definition, capture a trace, and grade its
outcome before claiming a behavioral pass. Record commit, fixture, relevant tool
versions, observed actions, result, and failure reason under ignored
`evals/runs/`. Do not impose repeated runs unless failures reveal nondeterminism.
There is no mandatory full workflow lifecycle or three-pass release gate.

Live Herdr evaluations must use named isolated sessions and disposable
repositories, proving the default session and unrelated repositories unchanged.
JEV comparisons may use the same fixture with and without advisory routing when
there is a real cost/reliability question; do not build a new harness merely to
test the existence of orchestration.
