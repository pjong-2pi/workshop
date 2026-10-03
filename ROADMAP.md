# Workshop MVP stabilization backlog

Goal: reliably take ordinary requests from prompt → delegated work → sufficient
verification → PR, with less manual intervention and reasonable model usage.
This is a planning backlog; no roadmap items are implemented by this PR.

Preserve Foreman's orchestration/user-interaction role, delegated substantive work,
capability-owned mechanics, optional bounded JEV advice, inventory-only Stocktake,
and independent target repositories. Prefer removing complexity before hardening
paths that may disappear. Keep each change focused.

## Evidence and completed work

- The initial bounded review covered current skills, profiles, tests, evals, and
  workflow records. CLI help confirmed timeout semantics. No additional issues
  were discovered in this documentation revision.
- [PR #18](https://github.com/7wwtwinkletoes/workshop/pull/18) completed cleanup
  diagnosis and the focused fix: an isolated Windows proof reproduced a detached
  worker-child lock and successful normal removal after stopping that recorded child.
- PR #18 requires workers to finish their own recorded background sessions before
  handoff, guards active panes, reports stale partial removal, and verifies directory,
  Git registration, and owner/auxiliary workspace absence. Regression checks cover
  these outcomes. Do not repeat the diagnosis or rebuild those checks.
- PR #18 proved an unrelated isolated workspace remained intact; concurrent default
  activity prevented a global byte-identical snapshot claim. Cleanup reliability
  across ordinary tasks still needs the stabilization checkpoint below. Mock tests
  alone are not live-process evidence.
- [PR #16](https://github.com/7wwtwinkletoes/workshop/pull/16) completed Stocktake
  startup diagnostics and documented approved execution when sandbox access fails;
  it preserves the catalog on failure. No repeat work is planned here.
- Reported incidents and code-path gaps are not claims of executed eval passes.
  Model inventory descriptions are not measured cost or performance rankings.

## P0 — Workflow blockers

### P0-1 — Delegate substantive read-only work

- **Problem:** Foreman directly handled the reported “check our hiccups logs” investigation.
- **Evidence:** [Foreman](.agents/skills/workshop-foreman/SKILL.md) explicitly delegates
  implementation; the [read-only eval](evals/skill-evals.json) requires no mutation
  but does not require delegation.
- **Desired outcome:** Delegate investigation, failure analysis, engineering research,
  implementation, and independent review. Allow lightweight routing, status,
  handoff, and readiness-evidence inspection.
- **Scope:** Foreman guidance and the existing read-only eval/profile guidance.
- **Acceptance criteria:** A log-investigation request reaches a visible read-only
  worker and returns evidence without changes or PR; Foreman still coordinates
  directly and makes readiness decisions.
- **Non-goals:** New role taxonomy or mandatory review for every task.

### P0-2 — Let legitimate work outlast the prompt wait

- **Problem:** A five-minute wait can expire before accepted work finishes; busy reuse
  can also return a prior turn's completion.
- **Evidence:** [Delegate](.agents/skills/workshop-delegate/SKILL.md) sets
  `--timeout 300000` on startup and prompt. Installed CLI help distinguishes startup
  readiness from prompt waiting and says prompt waits do not track turns.
- **Desired outcome:** Long work remains observable without duplicate assignments
  or false failure/completion reports.
- **Scope:** Delegate's prompt/wait guidance and focused dispatch evidence.
- **Acceptance criteria:** A task exceeding five minutes finishes on the same worker;
  wait expiration is distinguished from failure. Busy reuse does not submit a second
  assignment or attribute the old handoff to it. Blockers remain visible.
- **Non-goals:** Timeout/retry framework, hidden fallback, or changing startup limits.

## P1 — Remove major unnecessary overhead

### P1-1 — Remove the Fitter LLM publication step

- **Problem:** Ordinary publication adds a worker, session, worktree, and cleanup
  after readiness and authorization have already been decided.
- **Evidence:** Foreman mandates Fitter; Delegate creates its sibling checkout.
  The [Fitter profile](.codex/agents/fitter.toml) permits mechanics only;
  [github-create-pr](.agents/skills/github-create-pr/SKILL.md) already owns them.
- **Desired outcome:** Existing publication capability handles the verified result
  without a publication LLM or extra checkout. Foreman retains readiness and
  authorization; capability mechanics retain repository/scope/result checks.
- **Scope:** Foreman, publication capability, Fitter references, and affected
  Delegate/eval/cleanup guidance.
- **Acceptance criteria:** An ordinary task reaches a verified OPEN PR using one
  implementation worker/worktree and no Fitter context. Approved scope, repository,
  branch/base, and exact head match; unrelated work remains intact. Verification
  cannot silently become stale; cleanup retains matching disposition evidence.
- **Non-goals:** Engineering during publication, automatic merge/branch deletion,
  new publication infrastructure, or generalized workspace design.

### P1-2 — Make small-task fallback explicit

- **Problem:** “Choose a cheap worker” has no clear small-task fallback.
- **Evidence:** The only [implementation profile](.codex/agents/master-craftsman.toml)
  is aimed at difficult work and defaults to medium reasoning; Foreman's no-advice
  guidance relies on profile defaults. [Inventory](catalog/models.md) reports
  available pairs, not comparative prices or adequacy.
- **Desired outcome:** Ordinary Foreman judgment selects an explicit available,
  adequate small-task pair without needing JEV.
- **Scope:** Existing fallback/profile guidance and small-task eval expectations.
- **Acceptance criteria:** With no JEV call, a representative small task starts with
  the selected supported pair and passes relevant checks; observed configuration
  matches the choice. Unavailable/unsuitable choices yield a concrete blocker or
  revised judgment, not invented rankings.
- **Non-goals:** New worker hierarchy, pricing metadata, benchmarks, or automatic scoring.

### P1-3 — Check exact results in the remaining handoff paths

- **Problem:** Reused later-role checkouts skip the supplied HEAD comparison.
- **Evidence:** Delegate applies that comparison only when `-not $ExistingWorktree`.
  This is a code-path gap, not an observed stale PR.
- **Desired outcome:** After Fitter removal, check only the exact-result handoff
  paths that remain necessary.
- **Scope:** Remaining Delegate handoffs and focused result-identity evidence.
- **Acceptance criteria:** A remaining reused review context rejects a mismatched
  result before review; matching reuse works without creating another context.
  Publication still uses the verified result. No reset or overwrite repairs stale work.
- **Non-goals:** Harden removed Fitter paths or add a lifecycle state machine.
- **Depends on:** P1-1, so removal precedes hardening.

## Stabilization checkpoint — stop architecture work

After P0/P1, run at least these five representative real tasks before further
simplification. Follow target rules and the user's stopping gate.

| Run | Task | Intended gate |
|---|---|---|
| 1 | Small implementation | Verified PR, unless stopped earlier |
| 2 | Normal implementation | Verified PR |
| 3 | Read-only investigation | Delegated evidence-backed answer; no changes/PR |
| 4 | Implementation requiring independent review | Reviewed, verified PR |
| 5 | Implementation through PR and cleanup | PR, authorized integration or discard, verified cleanup |

For each record only:

- Delegated LLM workers and worktrees created.
- Manual intervention and whether the intended gate was reached.
- Concrete failures/hiccups, including any remaining cleanup failure after PR #18.
- Rough observed model usage when readily available; otherwise “unavailable”.

Keep compact outcomes in WORKFLOWS and raw local evidence in ignored `evals/runs/`.
Use isolated named sessions/disposable repositories for live Herdr checks and prove
unrelated/default state unchanged. Static checks do not substitute for real runs.
No telemetry infrastructure; observed failures and overhead drive the next backlog.

## P2 — Simplify only where stabilization evidence warrants it

### P2-1 — Reduce remaining contexts and Delegate complexity

- **Problem:** Per-role contexts multiply lifecycle work.
- **Evidence:** Delegate owns creation/opening, grouping, role topology, startup,
  configuration, identity/readiness/HEAD checks, reuse, prompting, and handoffs.
  WORKFLOWS records the separate-checkout requirement and independent cleanup.
- **Desired outcome:** Keep only contexts and mechanics needed for isolation,
  independent review, and reliable execution after Fitter removal.
- **Scope:** Remaining Delegate topology/reuse and associated handoff guidance.
- **Acceptance criteria:** Any reduction is supported by observed Herdr behavior
  and reduces real overhead. Preserve independent read-only review, exact results,
  repository identity, visible worker readiness, and unrelated-session protection.
  Retain necessary isolation if fewer contexts would weaken it.
- **Non-goals:** Harness/workspace abstraction, hidden workers, or broad refactor.
- **Depends on:** P1-1 and checkpoint evidence of remaining context overhead.

### P2-2 — Remove residual topology-focused test expectations

- **Problem:** Some checks prescribe current roles/mechanics instead of useful outcomes.
- **Evidence:** Small-task/Fitter/dispatch evals prescribe Fitter and distinct role
  checkouts; static validation requires all four profiles. Cleanup mocks cannot
  establish live lock behavior, although PR #18 added real proof and outcome checks.
- **Desired outcome:** Keep tests for safety and product outcomes; drop stale topology
  requirements. Update directly affected checks within each earlier change.
- **Scope:** Residual existing tests/evals demonstrated to obstruct the stable workflow.
- **Acceptance criteria:** Checks preserve authorization, repository/result identity,
  clean/dirty worktree safety, unrelated-work protection, no force deletion, and no
  unauthorized merge. They accept the simplified topology and distinguish mocks
  from live evidence.
- **Non-goals:** Blanket test deletion/rewrite, new framework, or comprehensive matrix.
- **Depends on:** Checkpoint evidence and the behavior changes leaving stale checks.

## Deferred

- JEV agent selection and model-cost optimization: keep optional, with no new work
  unless stabilization runs demonstrate a concrete need. Current role choices
  largely follow Foreman's existing risk judgment; invocation value is unproven.
- Pricing metadata, performance scoring, telemetry, and further context consolidation
  without evidence. Removing extra contexts comes before fine-grained model tuning.
- Cleanup diagnosis/fixes already delivered by PR #18: reopen only for a concrete
  remaining failure, rather than repeating completed work.

## Not doing

No new orchestration layer, agents, harness abstraction, timeout/retry framework,
cleanup recovery engine, model rankings, or architecture rewrite. No roadmap
implementation or production behavior changes in this documentation pass.
