# Workshop MVP stabilization backlog

Success: ordinary requests reliably reach prompt → delegated work → sufficient
verification → PR, with less manual intervention and reasonable model usage.
This document is planning only. Each initial item is intended as one focused PR;
the cleanup diagnosis and fix are separate. No item authorizes merge or deletion.

Preserve the boundaries: Foreman owns orchestration and user interaction, agents
perform substantive engineering/investigation/review, capabilities own execution
mechanics, JEV provides optional bounded advice, and Stocktake reports inventory.
Target repositories retain their own rules and history. Complexity must answer a
demonstrated need.

## Evidence and limits

One bounded pass covered root instructions, skills, profiles, scripts, tests,
eval definitions, README, and WORKFLOWS. Installed Herdr CLI help was inspected;
no live workers, cleanup, or model benchmarks were run. The supplied log-investigation
incident is user-reported; current wording confirms the boundary gap, not its trace.
Windows failures are recorded in WORKFLOWS (eight cleanup observations); the lock
holder remains unproven. Eval definitions explicitly are not executed evidence.

The working tree already had edits to `master-craftsman.toml` and `catalog/models.md`;
this review uses their current contents and leaves them untouched. Model descriptions
are observed inventory, not measured price or performance comparisons.

## P0 — Workflow blockers

### P0-1 — Delegate substantive read-only work

**Problem:** Foreman can consume its own model/context performing the requested
investigation. The reported “check our hiccups logs” request was handled directly.

**Evidence:** [Foreman](.agents/skills/workshop-foreman/SKILL.md) says workers
implement and “always delegates implementation”; its workflow examples cover only
implementation. The `read-only` definition in [evals](evals/skill-evals.json)
requires no mutation but does not require delegation.

**Desired outcome:** Foreman delegates investigation, failure analysis, codebase
inspection, engineering research, implementation, and independent review. It may
read enough instructions to route work, inspect status/handoffs, and inspect
evidence needed for coordination and readiness.

**Scope:** Foreman wording, existing profile instructions where needed, read-only
eval definition; align root boundary/README wording only as necessary.

**Acceptance criteria:** A log-investigation request goes to a visible read-only
worker and returns evidence without repository changes or PR. Routing/status and
handoff inspection remain direct. An independent review is performed by a reviewer,
while Foreman makes readiness decisions from its evidence.

**Non-goals:** No new investigation agent taxonomy, mandatory reviewer for every
request, or prohibition on lightweight orchestration inspection.

### P0-2 — Stop treating a five-minute prompt wait as task failure

**Problem:** Legitimate implementation or review can outlast the fixed wait.

**Evidence:** [Delegate](.agents/skills/workshop-delegate/SKILL.md) uses
`--timeout 300000` for both start and prompt. Installed `agent start --help`
defines this as the maximum startup readiness wait; `agent prompt --help` says
the wait fails on timeout. `agent wait --help` supports indefinite waiting when
timeout is omitted. This proves the deadline risk, not a recorded long-task failure.

**Desired outcome:** Startup readiness remains bounded; accepted work can continue
past five minutes and remain observable without restarting or duplicating it.
Prefer existing prompt/status/wait mechanics.

**Scope:** Delegate prompt/wait guidance and focused dispatch eval evidence.

**Acceptance criteria:** A controlled task lasting over five minutes reaches its
actual result on the same worker. Waiting expiration is distinguished from worker
failure. Blocked/failed workers still produce a concrete report, and Foreman can
monitor progress without one long blocking tool call. A new assignment requires
an idle matching worker; busy reuse monitors existing work without submitting a
second assignment or misattributing the prior turn's handoff.

**Non-goals:** No timeout framework, automatic retries, hidden fallback, or change
to Herdr's startup maximum. Do not assume a CLI timeout kills the worker.

### P0-3 — Diagnose the real Windows cleanup failure

**Problem:** Clean completed worktrees repeatedly remain on disk; current unit
tests cannot identify whether Workshop's own execution context holds them.

**Evidence:** [WORKFLOWS](WORKFLOWS.md) records repeated Windows directory locks.
[Clear Bench](.agents/skills/workshop-clear-bench/SKILL.md) keeps the owner live;
[removal script](.agents/skills/workshop-clear-bench/scripts/remove-workspace.ps1)
closes only supplied auxiliaries before normal removal. The
[test](tests/workshop-clear-bench.ps1) replaces Herdr/Git/GitHub with command mocks;
successful removal merely rewrites JSON state, without a real Codex process or
worktree removal.

**Desired outcome:** Complete the already-planned diagnose-first task with a small
reproduction and evidence identifying the holder or a clear remaining uncertainty.

**Scope:** One isolated named Herdr test session, disposable repository, and compact
diagnostic findings; a focused reproducible check if useful.

**Acceptance criteria:** Exercise real Codex/Herdr on Windows, capture process/CWD
and workspace state around failed removal, and test whether releasing the identified
task context permits normal removal. Prove the default session and unrelated
repositories unchanged. Distinguish a real reproduction from mocked success; if
not reproduced, report that limit rather than claim a diagnosis.

**Non-goals:** No production cleanup change in the diagnostic PR, integration-test
framework, force deletion, indiscriminate process killing, or generic recovery system.

### P0-4 — Fix the demonstrated cleanup lifecycle cause

**Problem:** Reporting a leftover directory preserves safety but does not make
ordinary task completion reliable.

**Evidence:** P0-3 must supply the actual cause. Current README/WORKFLOWS explicitly
accept later/manual cleanup; that is a failure fallback, not the desired success path.

**Desired outcome:** Release only the proven Workshop-owned holder, then perform
normal authorized removal. If the defect is in Herdr, deliver the smallest verified
upstream fix or safe supported workaround rather than invent Workshop recovery.

**Scope:** Clear Bench mechanics and focused checks; relevant Herdr behavior only
if the diagnosis establishes it. Align existing lifecycle documentation/evals.

**Acceptance criteria:** Repeat the P0-3 real reproduction successfully through
release/removal and confirm the checkout and worktree registration are gone.
Dirty/unrelated work and mismatched disposition still prevent removal. No force,
branch deletion, or unrelated session closure. Unexpected failure remains visible.

**Non-goals:** Retry engine, filesystem deletion fallback, blanket permission repair,
or treating recurring manual cleanup as normal success.

**Depends on:** P0-3's reproduced cause; otherwise retain this item as blocked by
missing diagnostic evidence, not an invitation to guess.

### P0-5 — Validate the result when reusing a later-role checkout

**Problem:** Reusing a reviewer/Fitter checkout can bypass the supplied exact-result
check; a review or publication could use a stale result.

**Evidence:** Delegate checks `$sourceHead` against `$Base` only when
`-not $ExistingWorktree`. Reuse verifies repository/checkout identity but has no
equivalent current HEAD comparison. This is a code-path gap, not an observed stale PR.

**Desired outcome:** Later-role handoffs verify the actual supplied result in both
new and reused contexts before substantive work.

**Scope:** Delegate reuse verification and a focused exact-result eval scenario.

**Acceptance criteria:** A reused checkout with a mismatched HEAD is rejected before
prompting; matching reuse succeeds without another worker/worktree. No resetting
or overwriting the checkout. Preserve the check for any later-role path that remains.

**Non-goals:** Generic lifecycle state machine or automatic stale-checkout repair.

## P1 — Remove major unnecessary overhead

### P1-1 — Publish through the existing capability without a Fitter LLM

**Problem:** Even a small change adds a second LLM worker and worktree for mechanics
after Foreman has already decided readiness and authorization.

**Evidence:** Foreman mandates Fitter; Delegate creates its sibling at the verified
implementation HEAD on the final publishing branch. The
[Fitter profile](.codex/agents/fitter.toml) forbids engineering/readiness decisions.
[github-create-pr](.agents/skills/github-create-pr/SKILL.md) already owns scoped
commit/push/PR verification.

**Desired outcome:** Foreman invokes deterministic publication mechanics on the
stopped implementation's verified dedicated branch. Foreman owns authorization
and readiness; publication owns Git/GitHub checks. No substantive engineering moves
into Foreman. The final branch must be selected before implementation if needed.

**Scope:** Foreman, github-create-pr, Fitter references/profile, Delegate's Fitter
path, corresponding evals/validation/docs, and cleanup handoff references.

**Acceptance criteria:** An ordinary PR-ready task publishes with one implementation
worker/worktree and no publication LLM/session/worktree. Verify approved full branch
scope, clean exact HEAD, repository/push remote, branch/base, and returned OPEN PR
URL/head SHA. Preserve unrelated work, target rules, failure stops, duplicate-PR
handling, and the no-merge/no-branch-deletion boundary. Publication cannot silently
alter an already verified result; any change must return for verification. Cleanup
uses that checkout's own matching integration or discard evidence.

**Non-goals:** Replace all GitHub skills with a service, automatic merge, new
publication workspace abstraction, or re-engineer code during publication.

### P1-2 — Make small-task fallback explicit without JEV

**Problem:** “Choose a cheap worker” has no corresponding small-task fallback in
the current implementation defaults.

**Evidence:** The only implementation profile is
[master-craftsman](.codex/agents/master-craftsman.toml), currently `gpt-6.1-sol`
with medium reasoning. The smaller default belongs to mechanics-only Fitter.
Foreman asks for the lowest-resource reliable choice but optional model advice
falls back to profile defaults. [Inventory](catalog/models.md) supplies available
pairs and descriptions, not measured adequacy or price rankings.

**Desired outcome:** Foreman can choose an explicit available small-task
model/reasoning pair with ordinary judgment and existing profile overrides;
difficult tasks retain appropriate resources.

**Scope:** Foreman fallback guidance and existing implementation profile defaults
only where needed; small-task and JEV-fallback evals.

**Acceptance criteria:** With JEV unavailable, a representative small task starts
with the explicitly selected supported pair and passes its relevant check; startup
evidence shows the chosen configuration. An unsuitable/unavailable pair produces
a visible judgment/blocker rather than fabricated rankings. Record observed usage
when available, without claiming price savings from model names alone.

**Non-goals:** New worker hierarchy, benchmark program, performance scores, pricing
metadata, or fine-grained automatic optimization.

## Stabilization checkpoint — stop architecture work

After P0/P1, run at least these five representative real tasks before promoting
follow-up simplifications. Use target-required checks and authorization gates.

| Run | Representative task | Intended stopping gate |
|---|---|---|
| 1 | Small implementation | Verified PR, unless explicitly stopped earlier |
| 2 | Normal implementation | Verified PR |
| 3 | Read-only investigation | Evidence-backed delegated answer; no changes/PR |
| 4 | Implementation requiring independent review | Reviewed, verified PR |
| 5 | Implementation through PR and cleanup | PR, explicitly authorized integration or discard, verified cleanup |

For each record only: delegated LLM worker count, worktrees created, manual
intervention (and why), gate reached, concrete failures/hiccups, and rough observed
model usage if readily available (otherwise “unavailable”). Keep compact durable
outcomes in WORKFLOWS and raw local evidence under existing ignored `evals/runs/`.
No telemetry or new harness. Live Herdr checks use isolated named sessions and
disposable repositories and prove default/unrelated state unchanged.

Passing static validation is not a substitute for these runs. Failures and avoidable
overhead determine the next executable backlog; do not fill the checkpoint with
additional architecture polishing.

## P2 — Simplify after the workflow is stable

These are evidence-backed candidates, not prerequisites to the checkpoint. Promote
only the narrow changes still justified by those runs; discard unnecessary ones.

### P2-1 — Reduce remaining role-context overhead and trim Delegate accordingly

**Problem:** The current topology makes lifecycle work grow with every role.

**Evidence:** Delegate creates/opens worktrees, groups repositories, enforces role
branches/bases, starts/configures/verifies workers, supports reuse, prompts, and
collects handoffs. WORKFLOWS documents that one checkout cannot back separate Herdr
role workspaces. Reviewer/Fitter exact-HEAD siblings each need independent cleanup;
old review heads cannot use the final PR's head evidence without explicit discard.

**Desired outcome:** After Fitter removal, retain only execution contexts needed
for independent read-only review and target isolation. Investigate supported
sequential use of a stopped verified checkout only if review-context overhead
remains material; otherwise keep the reviewer sibling. Trim obsolete topology
branches in place, without splitting Delegate into abstractions.

**Scope:** Delegate's remaining review/reuse paths, Foreman handoffs and cleanup
instructions; narrowly affected dispatch evals.

**Acceptance criteria:** Demonstrate the supported Herdr topology before changing
it. Preserve a separate reviewer LLM, read-only access, stopped writer, and exact
reviewed SHA. Record contexts created and safe disposal after review/fixes. Keep
repository identity, explicit configuration, visible-worker readiness/session
evidence, unrelated-session protection, and compact handoffs. Delete only branches
made unnecessary by the demonstrated topology; if sharing is unsupported or unsafe,
retain isolation and close the candidate without a new abstraction.

**Non-goals:** General workspace/harness adapter, shared concurrent writer/reviewer,
hidden workers, broad Delegate refactor, or weakening independent review.

**Depends on:** P1-1 and checkpoint evidence that remaining topology warrants work.

### P2-2 — Retarget remaining tests from topology to outcomes

**Problem:** Some checks freeze current mechanics while missing product failures.

**Evidence:** The small-task/Fitter/visible-dispatch evals prescribe Fitter and
distinct per-role checkouts. Clear Bench tests assert exact auxiliary-close order
and JSON disappearance. The read-only eval misses delegation. Static validation
hardcodes all four profiles. Conversely, dirty-work, identity, disposition,
no-force, JEV fallback, and Stocktake protocol checks protect real invariants.
The evaluation README already correctly distinguishes definitions from execution.

**Desired outcome:** Preserve meaningful safety checks; remove only stale mechanics
expectations left after focused fixes. Update directly affected tests/evals in each
P0/P1 PR; this item covers residual cleanup demonstrated by the checkpoint.

**Scope:** Relevant existing tests and eval definitions; no blanket rewrite.

**Acceptance criteria:** Tests continue rejecting unauthorized mutation/merge,
wrong repository/result, dirty/unrelated work deletion, force removal, and branch
deletion. Outcomes accept the stabilized workflow without requiring removed roles
or incidental command order. Real cleanup evidence is identified separately from
mocks. Metadata/syntax checks remain; static success never claims live reliability.

**Non-goals:** Delete useful tests, test framework replacement, exhaustive lifecycle
matrix, or new tests that merely mirror prose edits.

**Depends on:** Checkpoint and the concrete behavior changes whose obsolete checks
remain; do not perform a standalone speculative test overhaul.

## Deferred

- **Routine JEV agent selection:** Existing eligible choices are implementation,
  ordinary review, and high-risk review; Foreman already determines that choice
  from task/risk/target rules. Fitter and Foreman are excluded. No current evidence
  shows an extra advisory call improves this decision. Keep the skill optional;
  default to direct judgment and reconsider only for an observed ambiguous choice.
- **Sophisticated model-cost routing:** First eliminate the demonstrable extra
  publication worker/worktree and validate ordinary fallback. Defer pricing
  catalogs, performance scoring, telemetry, and automatic resource optimization
  until real tasks establish both a material cost problem and useful alternatives.
- **Further workspace consolidation:** Beyond Fitter removal, reviewer sharing is
  not yet proven feasible or beneficial. P2-1 is a conditional bounded check, not a
  promise to remove isolation or build a generalized workspace layer.

## Additional concrete findings

- P0-5's reused-checkout HEAD gap was found during this pass.
- Installed `agent prompt --help` also says waits do not track turns: prompting an
  already-working agent can match that active turn's completion. Delegate reuse
  requires a matching live worker but does not explicitly require it to be idle
  before a new assignment. Include a focused idle-before-new-prompt check in P0-2:
  busy reuse must monitor existing work rather than attribute its handoff to a new
  task. No new turn-tracking infrastructure.

## Not doing

No new orchestration layer, role taxonomy, harness abstraction, telemetry system,
timeout/retry framework, cleanup recovery engine, universal test matrix, pricing
database, or architecture rewrite. No roadmap implementation in this planning task.
The only behavior-guidance change now is the concise root simplicity guardrail.
