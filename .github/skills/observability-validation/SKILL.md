---
name: observability-validation
description: Validate Autopilot health, workflow observability, and pipeline status. Use to check if the control plane and corporate CI are healthy.
---

# Observability Validation Skill

## When to use
- Periodic health check of the control plane
- After a deploy to verify success
- When health score drops or alerts fire
- Before starting a new operation (verify system is healthy)

## Step 1: Read Health State

```
get_file_contents(
  path: "state/workspaces/<ws_id>/health.json",
  ref: "autopilot-state"
)
→ healthScore (target > 80), issues[], lastChecked
```

Health score thresholds:
| Score | Status | Action |
|---|---|---|
| > 80 | ✅ Healthy | No action |
| 70–80 | ⚠️ Degraded | Monitor, investigate |
| 50–70 | 🟡 P3 Incident | Assign to sre-devops |
| < 50 | 🔴 P2 Incident | Assign to incident-investigator |

## Step 2: Check Recent Workflow Runs

```
list_commits(sha: "autopilot-state", per_page: 10)
→ Look for recent audit commits — they confirm workflow completion
→ "audit: source-change" = apply-source-change completed
→ "state: controller source-change" = state saved
→ "lock: session released" = lock freed
```

## Step 3: Check Release State

```
get_file_contents(
  path: "state/workspaces/ws-default/controller-release-state.json",
  ref: "autopilot-state"
)
→ status: "promoted" + promoted: true = last deploy fully complete
→ status: "ci-failed" = CI failure, needs fix
→ status: "in-progress" = deploy running
```

## Step 4: Check Active Locks

```
get_file_contents(
  path: "state/workspaces/<ws_id>/locks/session-lock.json",
  ref: "autopilot-state"
)
→ agentId: "none" = no active session (healthy)
→ agentId: "claude-code", expiresAt: past = stale lock (trigger workspace-lock-gc.yml)
→ agentId: "claude-code", expiresAt: future = active session (do not interfere)
```

## Step 5: Check Corporate CI

For ws-default (Getronics):
```
list_commits(sha: "autopilot-state", per_page: 10)
→ Find latest ci-logs-controller-*.txt
get_file_contents(path: "state/workspaces/ws-default/ci-logs-controller-<job_id>.txt", ref: "autopilot-state")
→ Look for: BUILD SUCCESS, BUILD FAILURE, error patterns
```

## Step 6: Check Improvement Report

```
get_file_contents(
  path: "state/workspaces/<ws_id>/improvements/latest-report.json",
  ref: "autopilot-state"
)
→ healthScore, issues[].severity, trend (improving/degrading/stable)
```

## Observability Dashboard Summary

Output this summary after validation:
```
## Autopilot Observability Report — <timestamp>

### Control Plane
- Health Score: <N>/100 (<status>)
- Last deploy: <status> at <time>
- Active lock: <none|agent@time>
- Improvement trend: <improving|stable|degrading>

### Corporate CI (ws-default)
- Last CI result: <success|failure>
- Last CI timestamp: <time>
- Last version deployed: <version>

### Workspace Status
- ws-default: <status>
- ws-cit: <status>
- ws-socnew: LOCKED (third party)
- ws-corp-1: LOCKED (third party)

### Issues Requiring Attention
- <list any issues found, or "None">
```

## Automated Health Check
The `health-check.yml` workflow runs automatically (scheduled) and writes to `health.json`.
Trigger manually via `workflow_dispatch` on `health-check.yml` with `workspace_id` input.
