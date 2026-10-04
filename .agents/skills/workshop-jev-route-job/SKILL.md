---
name: workshop-jev-route-job
description: Route a fresh Workshop agent or skill selection through JEV using the Stocktake catalog, then validate the choice or return direct-selection fallback.
---

# Route Job

Use for each **fresh** investigation, implementation, review, publication, merge, or cleanup resource selection when that stage has an available agent or skill. Reuse the assigned Craftsman for remediation and Inspector for re-review. Stocktake runs independently at session start.

Call the helper from any project directory using explicit Workshop paths:

```powershell
$workshopRoot = 'absolute path to Workshop checkout'
$route = & "$workshopRoot/.agents/skills/workshop-jev-route-job/scripts/workshop-route-job.ps1" `
    -Kind agent -Assignment 'scoped assignment and complexity' `
    -AllowedNames @('workshop-surveyor') `
    -CatalogPath "$workshopRoot/.local/routing-catalog.json" | ConvertFrom-Json
```

For skill selection use `-Kind skill` and the allowed skill names. The helper gives JEV **all catalog agents or skills**, plus all selectable native model/reasoning pairs for agent routing, in one request. `-AllowedNames` states required role or capability; it does not filter JEV candidates. The role definitions are included as boundaries. A `selected` result is authoritative and goes unchanged to `workshop-dispatch` with the role definition, assignment, model and reasoning. Confirm actual runtime settings as dispatch requires. A `fallback` result means Foreman selects directly and reports the JEV limitation once; do not retry or seek a second opinion. Do not create a task worktree until selection or fallback resolves.

The catalog keeps absent models for manual ratings, but only `available` models enter routing. An unavailable later-stage role or skill cannot be made real by JEV: report that stage capability as pending. Review remains before publication; merging still requires explicit user authorization. The helper only selects and never dispatches.

For other bounded decisions, the request-agnostic `workshop-jev-choice.ps1`, `workshop-jev-noul.ps1`, and `workshop-jev-score.ps1` scripts in `scripts/` each take `-InputJson` with `{state: ..., questions: {name: {instructions: ..., criteria: ...}}}`. They read `TYPESAFE_API_KEY`, accept one or several named questions of their own type, and output JSON answers under the same names. Choice criteria map options to descriptions; noul criteria are optional true/false meanings; score criteria are ordered levels. Errors exit nonzero. The [TypeSafe API reference](https://docs.typesafe.ai/api) specifies the shapes.
