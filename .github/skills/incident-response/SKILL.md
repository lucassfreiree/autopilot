---
name: incident-response
description: Respond to P1/P2/P3/P4 incidents in Autopilot and corporate pipelines. Diagnose, isolate, remediate, and document.
---

# Incident Response Skill

## When to use
- Issue labeled `incident`, `P1`, or `P2`
- Health score below 50
- `apply-source-change.yml` failing 3+ consecutive times
- Lock active for more than 30 minutes without activity
- User says "something is broken", "pipeline down", "state corrupted"

## Severity Quick Reference

| Level | Examples | Max response |
|---|---|---|
| P1 | State corrupted, secret leaked, deploy permanently blocked | Immediate |
| P2 | Critical workflow failing 3+ times, health < 50, lock stuck 30+ min | 15 min |
| P3 | Health 50–70, non-critical workflow failing, schema warning | 2 hours |
| P4 | Improvements, docs, optimizations | 1 week |

## Phase 1: Declare

```
For P1/P2: trigger alert-notify.yml with severity and title
```

## Phase 2: Diagnose

### Check health state
```
get_file_contents(
  path: "state/workspaces/<ws_id>/health.json",
  ref: "autopilot-state"
)
→ healthScore, lastChecked, issues[]
```

### Check release state
```
get_file_contents(
  path: "state/workspaces/<ws_id>/controller-release-state.json",
  ref: "autopilot-state"
)
→ status, ciResult, lastReleasedSha, promoted
```

### Check session lock
```
get_file_contents(
  path: "state/workspaces/<ws_id>/locks/session-lock.json",
  ref: "autopilot-state"
)
→ agentId, expiresAt, operation
```

### Check real CI logs
```
list_commits(sha: "autopilot-state", per_page: 20)
→ Find: ci-logs-controller-*.txt or ci-logs-agent-*.txt
get_file_contents(path: "state/workspaces/<ws_id>/ci-logs-controller-<job_id>.txt", ref: "autopilot-state")
```

### Check known failures
```
get_file_contents(path: "contracts/claude-session-memory.json")
→ knownFailures[], errorRecovery{}
```

## Phase 3: Identify Root Cause

| Log Pattern | Root Cause | Fix |
|---|---|---|
| `error TS2769` | TypeScript type mismatch | Add cast / fix types |
| `no-use-before-define` | Function order | Move definition up |
| `no-unused-vars` | Dead code | Remove unused function |
| `FAIL src/__tests__` | Test failure | Fix test or revert patch |
| `duplicate tag` | Version already exists | Bump version |
| `lock not released` | Crash during deploy | GC via `workspace-lock-gc.yml` |
| `state: undefined` | State corruption | Restore from backup |

## Phase 4: Remediate

For CI failures → use `fix-ci-failure` skill
For lock stuck → trigger `workspace-lock-gc.yml`
For state corruption → trigger `backup-state.yml` first, then `restore-state.yml`
For workflow failing → diagnose logs, fix patch, re-deploy

## Phase 5: Validate

Confirm resolution:
```
get_file_contents(
  path: "state/workspaces/<ws_id>/controller-release-state.json",
  ref: "autopilot-state"
)
→ status: "promoted" AND promoted: true = SUCCESS
```

## Phase 6: Postmortem (P1/P2)

Create audit entry documenting:
- Timeline of incident
- Root cause
- Actions taken
- Resolution confirmed at
- Lessons learned (add to session memory)

## WORKSPACE RULE
NEVER respond to incidents in `ws-socnew` or `ws-corp-1` without explicit authorization from `lucassfreiree`.

## Full SOP: `ops/runbooks/incidents/incident-response.json`
