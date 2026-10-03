---
name: workshop-stocktake
description: Discover models available to the local Codex account and update Workshop's versioned model catalog. Use for on-demand model inventory; never select, rank, or recommend a model.
---

# Workshop Stocktake

Run this from the Workshop root when an observed Codex model inventory is needed:

```powershell
pwsh -NoProfile -File .agents/skills/workshop-stocktake/scripts/update-model-catalog.ps1
```

The script queries Codex's local app-server `model/list` capability for the
current account, then updates `catalog/models.md` only when inventory facts
change. The compact catalog records model, observed description, observed default
and supported reasoning efforts, and last checked time. Do not add guesses, scrape non-authoritative
sources, or turn this inventory into model-selection policy.

If discovery fails, leave the existing catalog intact and report the failure.
When a workspace-write sandbox denies Codex access to its local state, run the
same command with approved unsandboxed execution; do not substitute a separate
state directory or fabricate an inventory.
No periodic refresh is part of this skill.
