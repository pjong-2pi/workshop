# Workshop

A portable agentic development workspace for coordinating specialized AI agents through simple, controlled software engineering workflows.

## Goals

- Keep orchestration simple and predictable.
- Delegate work to specialized agents.
- Use JEV for lightweight routing decisions.
- Isolate implementation work with Git worktrees.
- Maintain independent review before publication.
- Keep the user in control of final merge decisions.
- Add complexity only when real usage demonstrates a need.

## Core Workflow

```text
Scope → Route → Implement → Review → PR → User Approval → Merge → Cleanup