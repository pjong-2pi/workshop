---
name: workshop-jev-route-job
description: Request a bounded agent, skill, model, or reasoning selection from JEV using the Stocktake catalog and return a validated result or the original failure.
---

# Route Job

Supply the scoped assignment, capability requirements, and Stocktake catalog path. Describe the required capabilities rather than a preferred concrete identity. The helper requests a bounded selection and returns JSON; it does not execute the selected work.

Live calls send the assignment, requirements, full role definitions, and available skill/model metadata to `https://api.typesafe.ai/v1/systemone`, authenticated with the existing `TYPESAFE_API_KEY`. Disclose this normal routing payload and destination when obtaining authorization; reuse existing authorization for that scope and never print the key.

Invoke live helpers through the harness's approved network-enabled path. Never alter proxies, bypass the sandbox, or try alternate network paths. If network-enabled execution is unavailable or authorization is rejected, respect that result and return the original failure or rejection reason without retrying.

Call the helper from any project directory using explicit Workshop paths in that approved execution context:

```powershell
$workshopRoot = 'absolute path to Workshop checkout'
$route = & "$workshopRoot/.agents/skills/workshop-jev-route-job/scripts/workshop-route-job.ps1" `
    -Kind agent -Assignment 'scoped assignment and complexity' `
    -Requirements 'Gather cited evidence read-only; no edits, code review, or delegation.' `
    -CatalogPath "$workshopRoot/.local/routing-catalog.json" | ConvertFrom-Json
```

Use `-Kind skill` for skill selection. The helper gives JEV **all catalog agents or skills**, plus all available model/reasoning pairs for agent routing, in one request. Full agent definitions supply role boundaries. It validates response answer types and choices against the supplied catalog resources and supported model/effort options. A successful result has `status: selected` and the resource, plus model and reasoning for agent routing. A failure has `status: fallback` and the original helper error in `reason`.

Report the fallback's original `reason` with the available execution evidence. A denied approval or sandbox permission/proxy block is an execution-context failure, not evidence of a JEV service outage. An HTTP error returned by the endpoint is a service/API failure; a connection failure without a response is a transport failure with service availability unverified. Do not infer an outage from the generic request-failed prefix. Approval rejection occurs outside the helper and must be reported from the tool result.

The catalog keeps absent models for manual ratings, but only `available` models enter routing.

For other bounded decisions, the request-agnostic `workshop-jev-choice.ps1`, `workshop-jev-noul.ps1`, and `workshop-jev-score.ps1` scripts in `scripts/` each take `-InputJson` with `{state: ..., questions: {name: {instructions: ..., criteria: ...}}}`. They read `TYPESAFE_API_KEY`, accept one or several named questions of their own type, and output JSON answers under the same names. Choice criteria map options to descriptions; noul criteria are optional true/false meanings; score criteria are ordered levels. Errors exit nonzero. The [TypeSafe API reference](https://docs.typesafe.ai/api) specifies the shapes.
