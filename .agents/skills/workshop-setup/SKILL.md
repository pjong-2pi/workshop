---
name: workshop-setup
description: Check whether the local machine is ready to run Workshop by reporting the OS, shell, Git identity, GitHub CLI authentication, Codex, Herdr, and compatibility problems; make no configuration changes.
---

# Workshop Setup

Run this from the Workshop repository root:

```powershell
pwsh -NoProfile -File scripts/check-environment.ps1
```

Exit code `0` means the reported environment is ready. Exit code `1` means one
or more reported problems must be resolved before Workshop runs reliably.

Report the detected versions, Git identity, GitHub authentication state, and
every compatibility problem. Do not install tools, authenticate accounts, or
change Git configuration; those actions require separate user direction.
