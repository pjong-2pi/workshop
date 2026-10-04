# Workshop Roadmap

Build the smallest workflow that can add to and modify Workshop itself, then
use it to develop Workshop further. This roadmap follows [PRD.md](PRD.md),
the source of truth for product requirements. The Workshop knowledgebase
captures the broader design history and reasoning.

Milestones describe capabilities and evidence of completion, not dates or a
prescribed implementation topology. The initial environment is Windows with
Codex + Herdr installed; helper scripts are `.ps1` files.

Milestones 1 and 2 are complete. Milestone 2 passed capability checks, real
routing/delegation demonstrations, and independent Inspector review with
same-session remediation and re-review. Milestones 3–5 remain separately planned.

## Milestone 1 — Foreman and Delegated Execution

Outcome: the Foreman agent can turn a scoped request into delegated work and
consume its result without doing the substantive work itself.

Capabilities:

- Foreman as the primary interface and sole orchestrator.
- Delegation through Herdr, including its worktree creation capabilities.
- Craftsman execution with relevant verification and a role-specific handoff.
- Separate Surveyor investigation with read-only execution and an evidence handoff.
- Blocked handoffs returned to Foreman without worker redelegation.

Completion evidence:

- Foreman coordinates a scoped Workshop change in one isolated task worktree.
- The Craftsman returns changed scope, verification results, and any blockers
  through the contract in its agent definition.
- A delegated Surveyor investigation returns a read-only report without creating a PR.
- Foreman does not implement, substantively investigate, or manage Git/worktrees.

Routing may use the PRD's direct-selection fallback while JEV is unavailable.
This milestone does not constitute the complete first version.

Recorded demonstration evidence:

- Native Herdr dispatch loaded a separate read-only Surveyor, which returned
  COMPLETE with working-directory and requirements evidence.
- Foreman delegated a real README usage-guide change to Craftsman in the same
  isolated task worktree. Craftsman returned COMPLETE; local links and diff
  checks passed, and only README changed within that assignment.
- The same Surveyor returned BLOCKED when an explicitly required input file
  was missing, without substituting sources, inventing requirements, modifying
  files, or launching other agents.

The native sequence used explicit caller-workspace isolation, returned pane
IDs, full role-definition prompts, and substantive handoff retrieval. Main
remained the visible Spaces root, focus was preserved, and actual selected
runtime settings and role sandboxes were verified. Final independent review
of the implementation and guide returned PASS/LGTM with no blocking findings.

## Milestone 2 — Stocktake and Bounded JEV Decisions

Outcome: routing uses discovered resources and JEV instead of spending Codex
tokens on routine bounded selections.

Capabilities:

- Session-start Stocktake and a durable routing catalog.
- Discovery of agents, skills, models, and reasoning options.
- Preservation of manual model cost and intelligence ratings.
- JEV-backed agent, skill, model, reasoning, and reviewer selection.
- Direct Foreman selection when JEV fails or returns an unusable choice.
- A dedicated read-only Inspector and independently routed review of this change.

Completion evidence:

- A real assignment uses a usable JEV selection drawn from available resources.
- JEV receives all available agents and models; successful selections are honored.
- A failed or unusable JEV result takes the direct fallback without elaborate retries.
- A Stocktake refresh preserves manual metadata; a failed refresh retains the
  previous catalog and reports failure.
- Task worktree creation occurs after routing resolves.
- Foreman honors a usable reviewer selection and receives a real Inspector verdict.

Recorded demonstration evidence:

- Before Stocktake and JEV were available, Foreman resolved routing through the
  documented direct fallback: `workshop-craftsman` with `gpt-6-sol/high`.
  Dispatch then used Herdr `worktree create --workspace w12Z --branch
  workshop-milestone-2 --base main --path
  E:/projects/workshop/.worktrees/workshop-milestone-2 --no-focus`. Native output
  confirmed the branch/path, workspace `w131`, and Craftsman pane `w131:p1`;
  main `w12Z` remained the visible root. This establishes worktree creation
  after routing resolved without creating a second worktree for the proof.
- Stocktake discovered Workshop agents and current-session global, plugin, and
  Workshop skills from their sources, plus native-listed model/reasoning pairs.
  Focused checks preserved manual numeric ratings and prior catalog bytes on a
  failed refresh. Choice, Noul, and Score succeeded against the live TypeSafe
  API with single and batched questions; controlled checks covered complete
  candidate lists and direct fallback on unusable or failed JEV results.
- For a real read-only PRD/ROADMAP requirements investigation, JEV selected
  `workshop-surveyor` with `gpt-6-luna/low`. Foreman honored the result: dispatch
  reopened the same task worktree, loaded the full Surveyor definition in
  `w131:p2`, verified the selected runtime settings and read-only sandbox, and
  received a COMPLETE evidence handoff.
- A second real Foreman route for read-only implementation investigation sent
  the full catalog to JEV and selected `workshop-surveyor` with
  `gpt-6.1-sol/medium`. Foreman again honored the exact result; native startup
  verified the model and effort, and Surveyor returned concrete correctness
  observations. Assigning implementation correctness inspection to Surveyor
  violated its investigation boundary; the user corrected this. The observations
  were useful but do not count as Inspector review. This successful runtime
  supersedes the earlier planning-time model
  rejection; Workshop does not maintain an invented account blacklist.
- Reviewer routing supplied all four catalog agents to JEV, which selected
  `workshop-inspector` with `gpt-6.1-sol/high`. Foreman honored that selection;
  native read-only Inspector in `w131:p3` loaded the full role definition and
  reviewed the entire tracked and new-file change scope, including test sufficiency.
- Inspector initially returned FINDINGS: PR creation was not explicitly bound
  to origin's push repository, and committed branch changes were not checked
  against the publication scope. Craftsman `w131:p1` remediated both findings
  and added focused regressions. The same Inspector `w131:p3` independently
  re-reviewed and returned PASS/LGTM with sufficient regression coverage.
  Inspector made no fixes; roles operated sequentially in the same task worktree.

This completes expanded Milestone 2 capability and review acceptance.
Publication proceeds separately through deterministic `workshop-publish`;
the Inspector verdict does not claim PR creation or authorize merging.
Milestone 4's merge/cleanup capabilities remain future work, with explicit user
authorization required for merge. Task context and catalog candidates went
directly to JEV; no quantitative token saving is claimed.

## Milestone 3 — Independent Review and Remediation

Outcome: Foreman coordinates an independent review loop before publication.

Capabilities:

- Read-only Inspector review, including assessment of verification sufficiency.
- PASS/LGTM, blocking, and non-blocking review outcomes.
- Blocking findings returned to the same Craftsman session.
- Re-review in the same Inspector session.

Completion evidence:

- A Workshop change receives an independent review and explicit verdict.
- Blocking findings are remediated by the Craftsman and re-reviewed by the Inspector.
- Implementation, review, and remediation operate sequentially in the same task
  worktree; the Inspector does not fix findings.
- Foreman coordinates the loop without performing implementation or review.

## Milestone 4 — Delegated Publication, Merge, and Cleanup

Outcome: reviewed work reaches a PR and, following user authorization, a merged
and cleaned task without Foreman executing the mechanics.

Capabilities:

- Delegated commit/push and PR creation.
- An explicit user authorization gate before delegated merge execution.
- Delegated `/workshop-clear-bench` after successful merge.
- Resource release before handoff and essential cleanup verification.

Completion evidence:

- Delegated publication creates the PR without changing implementation.
- No merge occurs without explicit user authorization.
- An authorized merge is executed by a delegated agent or skill.
- Cleanup reports removal of task resources while preserving unrelated work,
  without force deletion.
- Foreman consumes the results and only orchestrates these operations.

Choose agent or deterministic skill execution based on the simplest useful
capability; do not require an LLM Fitter in advance.

## Milestone 5 — Workshop Develops Itself

Outcome: the first version meets the PRD's end-to-end acceptance criterion.

Completion evidence:

- A real Workshop addition or modification goes from user request through
  Foreman scoping, JEV routing, Herdr isolation, implementation, independent
  review, delegated PR creation, user approval, delegated merge, and cleanup.
- Foreman controls routine progression and handoffs. The user supplies intent,
  genuine clarification, and merge authorization without manually coordinating
  the workflow.
- Independent tasks can proceed within harness capabilities, and a workflow
  awaiting clarification does not pause unrelated workflows.
- Concrete failures or friction are recorded and addressed with focused changes
  and relevant regression protection.

Start using Workshop for further real development when this milestone is met.
Additional architecture work must be justified by observed needs.

## Later Capabilities

- Bootstrap Codex + Herdr on a new machine.
- Add useful specialized agents and skills.
- Support other harnesses or operating systems when needed.

Prioritize these from real usage. Do not schedule speculative abstraction,
recovery, or optimization infrastructure.
