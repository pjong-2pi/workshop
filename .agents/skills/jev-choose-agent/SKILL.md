---
name: jev-choose-agent
description: Optionally ask JEV to choose one caller-supplied worker role.
---

# JEV Choose Agent

Use only when optional worker-role advice is useful. Supply the caller's eligible
roles and concise descriptions to `Get-JevChoice` from `scripts/jev-choose.ps1`.
Do not offer Foreman or Fitter: Foreman orchestrates and Fitter is a separate PR
mechanic. A no-result leaves ordinary caller judgment and does not create a worker.

```powershell
. (Join-Path $WorkshopRoot 'scripts/jev-choose.ps1')
$advice = Get-JevChoice -State $State -Choices $Choices -Instructions 'Choose the eligible worker role best suited to the work.'
```
