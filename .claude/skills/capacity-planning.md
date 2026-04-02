---
name: capacity-planning
description: Monitor workflow efficiency, detect scheduling contention, optimize cron schedules and resource usage.
allowed-tools: Read, Bash, Grep, Glob
---

# Capacity Planning — Workflow Optimization

## Step 1: Analyze Current Load
Read workflow run history and identify:
- Average run duration per workflow
- Peak execution times (concurrent runs)
- Failed runs due to resource contention
- Scheduled workflow overlap windows

## Step 2: Schedule Optimization
| Current Schedule | Concern | Recommendation |
|-----------------|---------|----------------|
| Multiple workflows at same cron | Resource contention | Stagger by 5-10 min |
| Health monitor every 30 min | May overlap with heavy workflows | Offset from deploy windows |
| Spark sync every 5 min | High frequency, low change rate | Use hash comparison to skip no-change pushes |
| Sentinel every 4h | Too infrequent for critical monitoring | Consider 2h during business hours |

## Step 3: Cost Analysis
| Metric | Where to Find |
|--------|--------------|
| Workflow minutes used | workflow-cost-tracker.yml output |
| Billable minutes by workflow | GitHub Actions usage page |
| Wasted runs (no-op) | Runs where nothing changed |
| Failed runs (retry cost) | workflow-health-monitor.yml output |

## Step 4: Recommendations
- Cancel stale runs: `cancel-in-progress: true` for idempotent workflows
- Skip no-op: Hash comparison before push (spark-sync-state pattern)
- Batch operations: Combine related checks into single workflow
- Right-size schedules: Business hours vs off-hours vs weekends

## GitHub Actions Limits
| Resource | Free Tier | Pro |
|----------|-----------|-----|
| Minutes/month | 2,000 | 3,000 |
| Concurrent jobs | 20 | 40 |
| Job duration max | 6 hours | 6 hours |
| Workflow run max | 35 days | 35 days |
