# Workshop Roadmap

Build the smallest workflow that can add to and modify Workshop itself, then
use it to develop Workshop further. This roadmap follows [PRD.md](PRD.md),
the source of truth for product requirements. The Workshop knowledgebase
captures the broader design history and reasoning.

Milestones describe capabilities and evidence of completion, not dates or a
prescribed implementation topology. The initial environment is Windows with
Codex + Herdr installed; helper scripts are `.ps1` files.

Milestone 1 is complete: implementation, native demonstrations, and final
independent review passed. Milestones 2–5 remain planned.

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

Completion evidence:

- A real assignment uses a usable JEV selection drawn from available resources.
- JEV receives all available agents and models; successful selections are honored.
- A failed or unusable JEV result takes the direct fallback without elaborate retries.
- A Stocktake refresh preserves manual metadata; a failed refresh retains the
  previous catalog and reports failure.
- Task worktree creation occurs after routing resolves.

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
