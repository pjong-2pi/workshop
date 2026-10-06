---
name: workshop-jev-route-job
description: Request a bounded agent, skill, model, or reasoning selection from JEV using the Stocktake catalog and return a validated result or the original failure.
---

# Route Job

Supply the scoped assignment, capability requirements, and Stocktake catalog path. Describe the required capabilities rather than a preferred concrete identity. Use the existing `workshop-jev-choice.ps1` helper directly; it requests bounded choices and returns JSON without executing the selected work. Use JEV only when there are meaningful alternatives; each choice question needs 2 to 255 options. Otherwise select directly.

Live calls send the assignment, requirements, full role definitions, and available skill/model metadata to `https://api.typesafe.ai/v1/systemone`, authenticated with the existing `TYPESAFE_API_KEY`. Disclose this normal routing payload and destination when obtaining authorization; reuse existing authorization for that scope and never print the key. When the standing routing consent is loaded from `C:/Users/Perkins Jon/.codex/AGENTS.md`, surface it before routing and cite that source, scope, and endpoint in the approval justification. That consent covers routing metadata only, not arbitrary source files or unrelated secrets; other destinations or payload scope need fresh consent.

Invoke live helpers through the harness's approved network-enabled path. Never alter proxies, bypass the sandbox, or try alternate network paths. If network-enabled execution is unavailable or authorization is rejected, respect that result and return the original failure or rejection reason without retrying.

For agent and model/effort selection, send all catalog agents with full definitions and delegatability, plus every available model's supported efforts, in **one request**. The catalog retains absent models for manual ratings; only `available` models enter routing. Run this example from any project directory using an explicit Workshop path in the approved execution context:

```powershell
$workshopRoot = 'absolute path to Workshop checkout'
$catalog = Get-Content -LiteralPath "$workshopRoot/.local/routing-catalog.json" -Raw | ConvertFrom-Json -AsHashtable
$agents = @{}
foreach ($agent in $catalog.agents) {
    $delegatable = if ($agent.ContainsKey('delegatable')) { $agent.delegatable } else { $true }
    $definition = Get-Content -LiteralPath $agent.path -Raw
    $agents[$agent.name] = "$($agent.description)`nDelegatable: $delegatable`n$definition"
}
$pairs = @{}
foreach ($model in @($catalog.models | Where-Object available)) {
    $ratings = foreach ($rating in @('cost', 'intelligence')) {
        $value = if ($model.ContainsKey($rating)) { $model[$rating] } else { 'unknown' }
        "manual $rating rating=$value"
    }
    foreach ($effort in $model.reasoning) {
        $pairs["$($model.name)/$effort"] = "$($model.description); Reasoning=$effort; $($ratings -join '; ')"
    }
}
$inputJson = @{
    state = @{
        assignment = 'Read-only requirements investigation'
        requirements = 'Gather cited evidence read-only; no edits, code review, or delegation.'
    }
    questions = @{
        resource = @{
            instructions = 'Select a delegatable agent satisfying state.assignment and state.requirements. Respect every role boundary. Agents marked Delegatable: False are never eligible as delegated workers.'
            criteria = $agents
        }
        model_reasoning = @{
            instructions = 'Select the cheapest model/effort pair adequate for state.assignment and state.requirements. Prefer lower existing manual cost ratings among adequate choices; justify higher cost by needed capability. Ratings describe models, not measured prices or effort-level cost. Unknown ratings stay unknown; do not invent ratings or thresholds.'
            criteria = $pairs
        }
    }
} | ConvertTo-Json -Depth 20 -Compress
$raw = & "$workshopRoot/.agents/skills/workshop-jev-route-job/scripts/workshop-jev-choice.ps1" -InputJson $inputJson
$answers = if ($?) { $raw | ConvertFrom-Json -AsHashtable }
```

On success, `$answers.resource.choice` is the agent and `$answers.model_reasoning.choice` is the `model/effort` pair. The helper validates answer types and membership in the supplied criteria. Foreman checks semantic suitability and delegatability against the assignment before dispatch; the helper does not enforce role boundaries. Agent frontmatter's optional boolean `delegatable` defaults to `true`, and Stocktake refreshes it. Keep non-delegatable agents in the payload. If JEV selects one, report why it is unusable and select directly without retrying. Honor successful, usable selections unchanged, including a higher-cost pair; do not override them with a preferred model, quota, or cost filter.

For skill selection, give JEV all catalog skills in one request:

```powershell
$workshopRoot = 'absolute path to Workshop checkout'
$catalog = Get-Content -LiteralPath "$workshopRoot/.local/routing-catalog.json" -Raw | ConvertFrom-Json -AsHashtable
$skills = @{}
foreach ($skill in $catalog.skills) { $skills[$skill.name] = $skill.description }
$inputJson = @{
    state = @{
        assignment = 'Choose a workflow support skill'
        requirements = 'Execute a Foreman-selected assignment through native Herdr.'
    }
    questions = @{
        resource = @{
            instructions = 'Select the skill satisfying state.assignment and state.requirements.'
            criteria = $skills
        }
    }
} | ConvertTo-Json -Depth 20 -Compress
$raw = & "$workshopRoot/.agents/skills/workshop-jev-route-job/scripts/workshop-jev-choice.ps1" -InputJson $inputJson
$answers = if ($?) { $raw | ConvertFrom-Json -AsHashtable }
```

On success, check `$answers.resource.choice` for suitability before use. On helper failure, it emits the original error and exits nonzero; report that error with available execution evidence, then select directly without retries. Do not convert a failure into an answer or add a routing response envelope. A denied approval or sandbox permission/proxy block is an execution-context failure, not evidence of a JEV service outage. An HTTP error returned by the endpoint is a service/API failure; a connection failure without a response is a transport failure with service availability unverified. Do not infer an outage from the generic request-failed prefix. Approval rejection occurs outside the helper and must be reported from the tool result.

For other bounded decisions, the request-agnostic `workshop-jev-choice.ps1`, `workshop-jev-noul.ps1`, and `workshop-jev-score.ps1` scripts in `scripts/` each take `-InputJson` with `{state: ..., questions: {name: {instructions: ..., criteria: ...}}}`. They read `TYPESAFE_API_KEY`, accept one or several named questions of their own type, and output JSON answers under the same names. Choice criteria map options to descriptions; noul criteria are optional true/false meanings; score criteria are ordered levels. Errors exit nonzero. The [TypeSafe API reference](https://docs.typesafe.ai/api) specifies the shapes.
