---
name: jev-choose-model
description: Optionally ask JEV to choose one caller-supplied model and reasoning pair.
---

# JEV Choose Model

Use only when optional resource advice is useful. The caller supplies observed
Stocktake inventory as `model@reasoning` choices with descriptions and asks for the
lowest-resource pair likely to complete the work. This skill does not parse a
catalog or invent combinations. A no-result leaves safe profile defaults and
ordinary caller resource judgment.

```powershell
. (Join-Path $WorkshopRoot 'scripts/jev-choose.ps1')
$advice = Get-JevChoice -State $State -Choices $Choices -Instructions 'Choose the lowest-resource pair likely to complete the work.'
```
