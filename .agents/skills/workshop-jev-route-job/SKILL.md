---
name: workshop-jev-route-job
description: Route a fresh Workshop agent or skill selection through JEV using the Stocktake catalog, then validate the choice or return direct-selection fallback.
---

# Route Job

Use for **fresh** agent/model/reasoning or skill selections with meaningful alternatives. Supply the assignment and capability requirements, not a preferred concrete identity. If there is no choice, use the available capability directly: the sole publication capability is `workshop-publish`, invoked after Inspector PASS/LGTM without JEV. Reuse the assigned Craftsman for remediation and Inspector for re-review. Stocktake runs independently at session start.

Live calls send the assignment, requirements, full role definitions, and available skill/model metadata to `https://api.typesafe.ai/v1/systemone`, authenticated with the existing `TYPESAFE_API_KEY`. Disclose this normal routing payload and destination when obtaining authorization; reuse existing authorization for that scope and never print the key.

Invoke live helpers through Codex's normal approved network-enabled shell execution (`exec_command` with `sandbox_permissions: "require_escalated"` and a justification naming the destination and payload). The observed sandbox sets `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY` to `http://127.0.0.1:9`; the ordinary approved escalated shell has no such proxies. Do not change or unset proxies, bypass the sandbox, or retry through another path. If approval is rejected, respect it, report the rejection and stated reason, and use direct selection.

Call the helper from any project directory using explicit Workshop paths in that approved execution context:

```powershell
$workshopRoot = 'absolute path to Workshop checkout'
$route = & "$workshopRoot/.agents/skills/workshop-jev-route-job/scripts/workshop-route-job.ps1" `
    -Kind agent -Assignment 'scoped assignment and complexity' `
    -Requirements 'Gather cited evidence read-only; no edits, code review, or delegation.' `
    -CatalogPath "$workshopRoot/.local/routing-catalog.json" | ConvertFrom-Json
```

For meaningful skill alternatives use `-Kind skill` with capability requirements. The helper gives JEV **all catalog agents or skills**, plus all selectable native model/reasoning pairs for agent routing, in one request. Full agent definitions supply role boundaries. It validates catalog membership, supported model/effort, and the API contract. Foreman checks only the selected resource against the requirements and its definition before dispatch; a conflicting role boundary makes it unusable. Do not compare candidates before the call or override a usable result. Pass a usable selection unchanged to `workshop-dispatch` and verify actual runtime settings. A `fallback` or unusable result means Foreman selects directly and reports the limitation once; no retry or second opinion. Resolve selection or fallback before task worktree creation.

Report the fallback's original `reason` with the available execution evidence. A denied approval or sandbox permission/proxy block is an execution-context failure, not evidence of a JEV service outage. An HTTP error returned by the endpoint is a service/API failure; a connection failure without a response is a transport failure with service availability unverified. Do not infer an outage from the generic request-failed prefix. Approval rejection occurs outside the helper and must be reported from the tool result.

The catalog keeps absent models for manual ratings, but only `available` models enter routing. An unavailable later-stage role or skill cannot be made real by JEV: report that stage capability as pending. Review remains before publication; merging still requires explicit user authorization. The helper only selects and never dispatches.

For other bounded decisions, the request-agnostic `workshop-jev-choice.ps1`, `workshop-jev-noul.ps1`, and `workshop-jev-score.ps1` scripts in `scripts/` each take `-InputJson` with `{state: ..., questions: {name: {instructions: ..., criteria: ...}}}`. They read `TYPESAFE_API_KEY`, accept one or several named questions of their own type, and output JSON answers under the same names. Choice criteria map options to descriptions; noul criteria are optional true/false meanings; score criteria are ordered levels. Errors exit nonzero. The [TypeSafe API reference](https://docs.typesafe.ai/api) specifies the shapes.
