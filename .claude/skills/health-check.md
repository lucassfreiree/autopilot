---
name: health-check
description: Quick health check of a specific workspace or the entire control plane. Lighter than patrol — focused on critical metrics only. Use for fast status checks.
allowed-tools: Read, Bash, Grep, Glob
---

# Health Check — Quick System Status

Fast, focused health check. Returns status in under 30 seconds.

## Usage
- `/health-check` — check all active workspaces
- `/health-check ws-default` — check specific workspace
- `/health-check dashboard` — check dashboard health only

## Check 1: Workspace State (5s)

For the target workspace, read from autopilot-state branch:

```bash
# Quick state summary via jq
jq -c '{status,version,lastDeploy,ciResult}' state/workspaces/{ws_id}/controller-release-state.json
jq -c '{status,version,lastDeploy,ciResult}' state/workspaces/{ws_id}/agent-release-state.json
```

Evaluate:
- `status: "deployed"` → OK
- `status: "failed"` → CRITICAL
- `ciResult: "success"` → OK
- `ciResult: "failure"` → WARNING

## Check 2: Active Locks (2s)

```bash
# Check for active locks
ls state/workspaces/{ws_id}/locks/ 2>/dev/null
```

- No locks → OK
- Lock with TTL expired → WARNING (stale lock)
- Active valid lock → INFO (another agent working)

## Check 3: Dashboard Freshness (3s)

```bash
jq -r '.lastSync' panel/dashboard/state.json
```

- Within 15min → OK
- 15-60min → WARNING
- Over 60min → CRITICAL

## Check 4: Recent Workflow Failures (5s)

Check last 5 workflow runs for failures via GitHub API.

## Output Format

```
Health Check — {timestamp} BRT
Workspace: {ws_id} | Overall: {HEALTHY/WARNING/CRITICAL}

| Check | Status | Details |
|-------|--------|---------|
| Controller | {OK/WARN/CRIT} | v{version} - {status} |
| Agent | {OK/WARN/CRIT} | v{version} - {status} |
| Locks | {OK/WARN} | {count} active, {count} expired |
| Dashboard | {OK/WARN/CRIT} | Last sync {time ago} |
| Workflows | {OK/WARN} | {failures}/{total} failed (24h) |
```
