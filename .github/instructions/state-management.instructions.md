---
applyTo: "**"
---

# State Management Instructions

Rules for reading and writing the `autopilot-state` branch (the source of truth for all runtime state).

## Branch: `autopilot-state`

The `autopilot-state` branch is the single source of truth for:
- Workspace configurations
- Release states
- Session locks
- Audit trails
- Health scores
- Agent handoffs
- Metrics

**NEVER modify this branch directly via git push. All writes must go through workflows.**

## State Structure

```
state/workspaces/<workspace_id>/
  workspace.json              # Workspace config
  controller-release-state.json
  agent-release-state.json
  health.json
  release-freeze.json         # Created on demand
  locks/
    session-lock.json         # Multi-agent session lock
    <operation>-lock.json     # Per-operation locks
  audit/
    <operation>-<timestamp>.json  # IMMUTABLE — never delete
  handoffs/
  improvements/
  metrics/
    YYYY-MM-DD.json
```

## Workspace Access Rules

| Workspace | Access |
|---|---|
| `ws-default` | Read/write via `BBVINET_TOKEN` workflows |
| `ws-cit` | Read/write via `CIT_TOKEN` workflows |
| `ws-socnew` | **READ ONLY for emergency diagnosis — NEVER write without authorization** |
| `ws-corp-1` | **READ ONLY for emergency diagnosis — NEVER write without authorization** |

## Session Lock Protocol (MANDATORY before any write)

1. Read `state/workspaces/<ws_id>/locks/session-lock.json`
2. If `agentId != "none"` AND `expiresAt > now` → **STOP — create handoff instead**
3. Acquire lock via `session-guard.yml` before proceeding
4. Release lock after operation completes OR fails (always release)

## Audit Trail Rules

- Every state mutation MUST produce an audit entry
- Audit entries are IMMUTABLE — never delete them
- Format: `state/workspaces/<ws_id>/audit/<operation>-<timestamp>.json`
- Validate against `schemas/audit.schema.json`

## Reading State (GitHub API)

```bash
# Read any state file
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/<FILE>?ref=autopilot-state" \
  --jq '.content' | base64 -d

# Always validate jq output
jq -r '.field // "default"' 2>/dev/null || echo "fallback"
```

## Error Handling in State Operations

- Always validate jq output: `jq '.field // ""' 2>/dev/null || echo ""`
- Use `set -euo pipefail` in all bash steps
- Never silently swallow errors — log before continuing
- Use base64 encoding when passing content between workflow jobs

## Backup Before Destructive Operations

Always trigger `backup-state.yml` before:
- Restoring state (`restore-state.yml`)
- Bootstrapping a workspace
- Any operation that could delete or overwrite state files
