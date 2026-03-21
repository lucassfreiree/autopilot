# Autopilot

Web-only CI/CD control plane for multi-workspace, multi-agent release orchestration.

## Features

- **Zero local dependencies** — no PowerShell, no watchers, no local supervisor
- **100% GitHub-native** — Actions, Pages, Secrets, Variables, state branches
- **Multi-workspace** — isolated state per tenant/workspace
- **Multi-agent** — operable by Claude, ChatGPT, Codex web
- **Auditable** — every state mutation recorded
- **Observable** — health checks, drift detection, stuck run detection
- **Lockable** — workspace-level locks with automatic GC

## Architecture

```
lucassfreiree/autopilot (this repo)
├── .github/workflows/    # All automation
├── schemas/              # JSON schemas
├── contracts/            # Agent contracts
├── panel/                # GitHub Pages control plane
├── compliance/           # Data governance
└── [autopilot-state]     # Branch: runtime state
    └── state/workspaces/<id>/
        ├── workspace.json
        ├── controller-release-state.json
        ├── agent-release-state.json
        ├── health.json
        ├── locks/
        ├── audit/
        ├── handoffs/
        └── improvements/
```

## Quick Start

1. Configure `RELEASE_TOKEN` secret (PAT with `repo` scope)
2. Run **Bootstrap** workflow with a workspace ID
3. Edit `workspace.json` on `autopilot-state` to configure repos
4. Deploy release workflows to corporate source repos

## Secrets Required

| Secret | Scope | Purpose |
|--------|-------|---------|
| `RELEASE_TOKEN` | This repo | Read/write state, trigger workflows |
| `ANTHROPIC_API_KEY` | This repo (optional) | AI-powered CI failure analysis |

## Panel

The control plane UI is hosted via GitHub Pages at the repo's Pages URL.
It uses **sessionStorage only** (never localStorage) for token storage.
