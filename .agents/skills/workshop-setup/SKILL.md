---
name: workshop-setup
description: Perform the initial bootstrap of a new Workshop installation. Use only when explicitly asked to set up Workshop or when Workshop has not yet been initialized. Do not use for routine environment checks or normal Workshop operations.
---

# Workshop Setup

This is a first-time bootstrap workflow. Workshop is initialized when
`.local/setup-complete` exists. Run setup again only when the user explicitly asks.
Do not invoke it for:

- normal Foreman operations
- routine development
- every new Codex session
- routine environment checking
- merely because Workshop is in use

From the Workshop repository root, run:

```powershell
pwsh -NoProfile -File scripts/setup.ps1
```

The script safely creates `projects/` and `.local/`, preserves their contents,
checks the required tools, Git identity, Codex and GitHub authentication, validates
Herdr configuration, reports the Codex integration state, and writes the marker
only after final verification. Re-running it converges on the same state.

Herdr automatically detects Codex; its user-level integration adds native session
restore but is not required for MVP orchestration. If it is not current, report
that installing it changes the user's Codex configuration. Only after explicit authorization run:

```powershell
pwsh -NoProfile -File scripts/setup.ps1 -InstallCodexIntegration
```

Do not install tools, authenticate accounts, change Git identity, modify managed
repositories, or replace user settings. No persistent Workshop environment
variable is currently required: Herdr supplies `HERDR_ENV` and related values to
managed processes. Report automatic changes, unchanged state, manual prerequisites,
and deferred optional integration separately.
