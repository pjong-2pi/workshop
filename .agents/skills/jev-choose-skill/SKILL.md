---
name: jev-choose-skill
description: Optionally ask JEV to choose one caller-supplied specialized skill or none.
---

# JEV Choose Skill

Use only when optional skill-selection advice is useful. Supply sanitized state,
applicable specialized skill names plus `none`, and concise descriptions to
`Get-JevChoice` from `scripts/jev-choose.ps1`. Do not include this helper or other
JEV chooser skills among candidates: advice must not recurse. A no-result leaves
the caller to decide normally; it grants no authority.

```powershell
. (Join-Path $WorkshopRoot 'scripts/jev-choose.ps1')
$advice = Get-JevChoice -State $State -Choices $Choices -Instructions 'Choose one applicable specialized skill or none.'
```
