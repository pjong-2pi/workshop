# Security

## Supported versions

Security fixes target only the latest revision of `main`. Older revisions are
not supported.

## Reporting a vulnerability

Do not post credentials, private routing payloads, or exploitable vulnerability
details in public issues or pull requests.

Use GitHub's [private vulnerability reporting form](https://github.com/pjong-2pi/workshop/security/advisories/new).
The maintainer must enable private vulnerability reporting when the repository
becomes public. This document does not confirm that reporting is already enabled.
If the form is unavailable, do not disclose sensitive details in public issues
or pull requests.

Include the affected revision, impact, and minimal reproduction steps. Redact
credentials and unrelated private data.

## Local data

Keep API keys in environment variables and private runtime state in ignored
local files. Live JEV routing sends task descriptions, requirements, full role
definitions, and available skill/model metadata to TypeSafe AI; authorize that
scope before use. Never include unrelated secrets in routing metadata.
