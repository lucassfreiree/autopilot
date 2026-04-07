---
name: patrol
description: Run a full operational patrol of the autopilot control plane. Checks workflows, state health, locks, dashboard freshness, and open issues. Use for routine ops checks or at session start.
allowed-tools: Read, Bash, Grep, Glob, Agent
---

# Patrol — Full Control Plane Health Sweep

Run a comprehensive patrol of all autopilot systems. Report findings and auto-fix what's safe.

## Phase 1: Workflow Health (parallel subagents)

Launch parallel checks:

### 1a. GitHub Actions Status
- Fetch recent workflow runs (last 24h) via GitHub API
- Flag any workflow with status=failure or conclusion=failure
- Check for stuck runs (>60min in_progress)

### 1b. State Branch Health
- Read `state/workspaces/ws-default/health.json` from autopilot-state
- Read `state/workspaces/ws-default/controller-release-state.json`
- Read `state/workspaces/ws-default/agent-release-state.json`
- Verify no expired locks in `state/workspaces/ws-default/locks/`

### 1c. Dashboard Freshness
- Read `panel/dashboard/state.json` — check `lastSync` is within 15min
- Compare versions in state.json vs `version.json` and session memory
- Flag stale data

## Phase 2: Open Issues & PRs
- List open issues with labels: `bug`, `autopilot-alert`, `needs-claude`
- List open PRs from agent branches (claude/*, codex/*, copilot/*)
- Flag stale PRs (>3 days without activity)

## Phase 3: CI Pipeline Status
- Read latest `ci-logs-controller-*.txt` from autopilot-state
- Read latest `ci-logs-agent-*.txt` from autopilot-state
- Check for outstanding failures

## Phase 4: Auto-Fix (safe operations only)
| Issue | Auto-fix |
|-------|----------|
| Expired locks | Delete via workspace-lock-gc |
| Stale dashboard | Trigger spark-sync-state |
| Stuck workflow run | Cancel via API |
| Stale PR (>7 days) | Comment warning |

## Phase 5: Report

```markdown
# Patrol Report — {date} {time} BRT

## Overall: {HEALTHY/DEGRADED/CRITICAL}

### Workflows
- Total checked: N
- Healthy: N | Failed: N | Stuck: N

### State
- Controller: vX.Y.Z ({status})
- Agent: vX.Y.Z ({status})
- Active locks: N
- Expired locks: N (auto-cleaned: Y/N)

### Dashboard
- Last sync: {timestamp}
- Freshness: {OK/STALE}
- Version match: {OK/MISMATCH}

### Issues & PRs
- Open issues: N (bugs: N, alerts: N)
- Open PRs: N (stale: N)

### CI Pipeline
- Controller CI: {passed/failed/pending}
- Agent CI: {passed/failed/pending}

### Actions Taken
- {list of auto-fixes applied}

### Recommendations
- {list of items needing human attention}
```
