---
name: daily-digest
description: Generate a daily operational digest of the autopilot control plane. Shows health, deploys, CI status, open issues, and workflow performance.
---

# Daily Digest — Operational Status Report

Generate a comprehensive daily digest of the autopilot control plane status.

## Data Collection Steps

### 1. Pipeline Health
- Read `state/workspaces/ws-default/controller-release-state.json` from autopilot-state
- Read `state/workspaces/ws-default/agent-release-state.json` from autopilot-state
- Read `state/workspaces/ws-default/health.json` from autopilot-state
- Check for active locks in `state/workspaces/ws-default/locks/`

### 2. Recent Deploys (last 7 days)
- Query GitHub Actions runs for `apply-source-change.yml`
- Get success/failure count and last deploy timestamp
- Check latest ci-logs for corporate CI status

### 3. Workflow Performance (last 24h)
- Query all workflow runs from last 24 hours
- Calculate: total runs, success rate, average duration
- Flag any workflow with >50% failure rate

### 4. Open Issues
- Query open issues with labels: `bug`, `autopilot-alert`, `continuous-improvement`
- Count by severity/label
- Flag any issue older than 7 days without activity

### 5. Compliance Status
- Last compliance-gate run result
- Last continuous-improvement health score
- Last deploy-auto-learn report

## Output Format
```markdown
# Daily Digest — {date}

## System Health: {HEALTHY/DEGRADED/CRITICAL}
| Component | Version | Status | Last Deploy |
|-----------|---------|--------|-------------|
| Controller | X.Y.Z | {status} | {date} |
| Agent | X.Y.Z | {status} | {date} |

## Workflow Performance (24h)
| Metric | Value |
|--------|-------|
| Total Runs | N |
| Success Rate | X% |
| Failed Workflows | list |

## Open Issues: N
- {count} bugs
- {count} alerts
- {count} stale (>7 days)

## Action Items
- [auto-generated recommendations based on findings]
```

## Recommended Schedule
Run daily at 09:00 BRT (12:00 UTC) via Claude Code scheduled task.
Can also be invoked manually with `/daily-digest`.
