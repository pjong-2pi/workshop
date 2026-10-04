---
name: workshop-stocktake
description: Refresh Workshop's local routing catalog at the start of a Foreman session from native Codex models, Workshop roles, and session skills.
---

# Stocktake

Run once at session start, before routing. From the current Codex session's available-skills metadata, supply **every** skill as JSON objects with `name`, `description`, and `path` (expand any skill-root aliases). Pass that JSON to the helper as `-SessionSkillsJson`; the helper also reads Workshop skills, agents, and native Codex models. Session metadata is necessary because filesystem presence alone cannot prove a global/plugin skill is enabled in this session.

```powershell
$workshopRoot = 'absolute path to Workshop checkout'
$sessionSkills = @(
    @{ name = 'skill-name'; description = 'session description'; path = 'absolute SKILL.md path' }
    # Include every entry in this session's Available skills list.
) | ConvertTo-Json -Depth 6 -Compress
& "$workshopRoot/.agents/skills/workshop-stocktake/scripts/workshop-stocktake.ps1" -WorkshopRoot $workshopRoot -SessionSkillsJson $sessionSkills
```

Do not invent model ratings. Edit numeric `cost` and `intelligence` directly in `.local/routing-catalog.json` when actual manual ratings are available. A failed refresh reports an error and leaves the previous catalog intact; if no prior catalog exists, report routing catalog unavailable. Do not treat a failed refresh as a fresh catalog.
