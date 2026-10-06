# Workshop Roadmap

Build the smallest workflow that can add to and modify Workshop itself, then
use it to develop Workshop further. This roadmap follows [PRD.md](PRD.md),
the source of truth for product requirements. The Workshop knowledgebase
captures the broader design history and reasoning.

Milestones describe capabilities and evidence of completion, not dates or a
prescribed implementation topology. The initial environment is Windows with
Codex + Herdr installed; helper scripts are `.ps1` files.

Milestones 1, 2, and 3 are complete. Milestone 4 is partially
implemented with publication; merge and cleanup are not implemented.
Milestone 5 remains planned.

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

Status: COMPLETE — Stocktake and bounded JEV routing.

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
- Foreman honors a usable reviewer selection and receives a real Inspector verdict.

Recorded demonstration evidence:

- Before Stocktake and JEV were available, Foreman resolved routing through the
  documented direct fallback: `workshop-craftsman` with `gpt-6-sol/high`.
  Dispatch then created the isolated task worktree through Herdr, preserving
  main as the visible root. This demonstrated worktree creation after routing
  resolved, including fallback, without creating a second worktree for proof.
- Stocktake discovered Workshop agents and current-session global, plugin, and
  Workshop skills from their sources, plus native-listed model/reasoning pairs.
  Focused checks preserved manual numeric ratings and prior catalog bytes on a
  failed refresh. Choice, Noul, and Score succeeded against the live TypeSafe
  API with single and batched questions; controlled checks covered complete
  candidate lists and direct fallback on unusable or failed JEV results.
- For a real read-only PRD/ROADMAP requirements investigation, JEV selected
  `workshop-surveyor` with `gpt-6-luna/low`. Foreman honored the result: dispatch
  reopened the same task worktree, loaded the full Surveyor definition,
  verified the selected runtime settings and read-only sandbox, and
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
  native read-only Inspector loaded the full role definition and
  reviewed the entire tracked and new-file change scope, including test sufficiency.
- Initial routing calls still constrained concrete agent identity. The PR
  correction removed that constraint in favor of task/capability requirements.
  A live capability test supplied all four agents with full role definitions
  and all eight native-listed models across 44 supported effort pairs, without
  a preferred agent. JEV selected `workshop-surveyor` with `gpt-6-luna/low` for
  generic read-only evidence gathering. This capability test did not dispatch work.

Milestone 2 covers Stocktake and bounded JEV routing. Review and publication
implementation belongs to Milestones 3 and 4 below.
Task context and catalog candidates went directly to JEV; no quantitative
token saving is claimed.

Observed friction and remedy before further roadmap features:

- Later sandbox calls encountered `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY`
  set to `http://127.0.0.1:9`, while the ordinary approved escalated shell had
  no proxies. The helper targets `https://api.typesafe.ai/v1/systemone`.
  This is execution-context friction; Milestone 2's successful live calls
  remain recorded evidence, and the sandbox failure does not establish a
  service outage.
- Routing and Foreman instructions now specify the normal approved
  network-enabled invocation, disclosure of the normal routing payload,
  respecting approval rejection, and direct selection without retries or proxy
  changes. At that time, the routing wrapper's structured fallback preserved
  the original helper error so Foreman could distinguish execution-context,
  transport, and service/API failures. A focused mocked regression covered
  error preservation.
- Foreman subsequently used the main checkout helper through the ordinary
  approved network-enabled invocation. It reached `api.typesafe.ai` and returned
  a usable reviewer selection: `workshop-inspector` with `gpt-6.1-sol/high`.
  This demonstrates the approved invocation path; it does not validate the
  changed helper in this task worktree.

## Milestone 3 — Independent Review and Remediation

Status: COMPLETE — Independent Inspector review and same-session remediation/re-review.

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

Recorded demonstration evidence:

- Real usage exposed the Surveyor/code-review boundary violation documented
  above. Inspector was added as the dedicated independent read-only reviewer;
  Surveyor must never substitute for it.
- Inspector initially found that PR creation was not bound to origin's push
  repository and committed branch changes were not checked against publication
  scope. The same Craftsman session remediated both findings with focused
  regressions. The same Inspector session independently re-reviewed and returned
  PASS/LGTM with sufficient regression coverage. Inspector made no fixes;
  roles operated sequentially in the same task worktree. Foreman coordinated
  the handoffs without performing implementation or review.

## Milestone 4 — Delegated Publication, Merge, and Cleanup

Status: PARTIALLY IMPLEMENTED — `workshop-publish` exists; merge and cleanup do not.
Milestone 2 work is in PR #22, undergoing correction before merge. PR creation
does not authorize merging; merge still requires explicit user authorization.

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
