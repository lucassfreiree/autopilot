---
name: sync-state
description: Sync state.json to the Spark Dashboard repo. Validates data accuracy before sync and reports differences. Use when dashboard data looks stale or after deploys.
allowed-tools: Read, Bash, Grep, Glob, Edit, Write
---

# Sync State — Dashboard State Synchronization

Validate and sync `state.json` from autopilot sources to the Spark Dashboard.

## Step 1: Collect Current State from Sources

Read these files (parallel where possible):

| Source | File | Key Fields |
|--------|------|------------|
| Session memory | `contracts/claude-session-memory.json` | controller/agent versions, deploy status |
| Version file | `version.json` | autopilot product version |
| Trigger | `trigger/source-change.json` | current run number, component, version |
| CAP reference | `references/controller-cap/values.yaml` | deployed image tag |
| Release state | autopilot-state: `state/workspaces/ws-default/controller-release-state.json` | release status |
| Release state | autopilot-state: `state/workspaces/ws-default/agent-release-state.json` | release status |

## Step 2: Read Current Dashboard State

Read `panel/dashboard/state.json` (local) and compare against collected sources.

Flag mismatches:
```
Source says controller=3.8.2 but dashboard shows 3.8.1 → STALE
Source says pipeline.lastRun=45 but dashboard shows 44 → STALE
```

## Step 3: Update state.json

If mismatches found:
1. Update the stale fields in `panel/dashboard/state.json`
2. Set `lastSync` to current ISO timestamp (Sao Paulo timezone)
3. Validate JSON is valid with `jq '.' panel/dashboard/state.json`

## Step 4: Trigger Sync Workflow

If local changes made:
1. Commit changes to panel/dashboard/state.json
2. The `spark-sync-state.yml` workflow will push to spark-dashboard repo automatically
3. Alternatively, manually trigger the workflow via dispatch

## Step 5: Verify Sync

After sync:
- Check spark-dashboard repo's `public/state.json` matches
- Verify `lastSync` timestamp is fresh
- Report final status

## Output Format
```
Sync Status: {SYNCED/UPDATED/FAILED}
Changes:
- controller.version: 3.8.1 → 3.8.2
- pipeline.lastRun: 44 → 45
- lastSync: {old} → {new}
Dashboard URL: https://lucassfreiree.github.io/spark-dashboard/
```
