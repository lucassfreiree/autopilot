# Automation Frequency Optimization

**Goal**: Reduce commits from 17/week to <8/week while maintaining reliability  
**Status**: Configuration Template Created  
**Owner**: DevOps/SRE Automation

## Current Baseline (2026-04-10)

| Workflow | Frequency | Est. Commits/Week | Issue |
|----------|-----------|------------------|-------|
| spark-sync-state.yml | Every 15 min (business hours) | ~35 | **HIGH** - Primary culprit |
| token-auto-optimize.yml | Daily 06:00 UTC | ~1 | OK |
| memory auto-save | Per PR merge | ~3 | Consider batching |
| dashboard auto-improve | Daily | ~1 | OK |
| state backups | Hourly | ~7 | Can reduce to 6h |
| **Total** | - | **~50/week** | **Needs reduction** |

## Optimization Targets

### 1. spark-sync-state (Highest Impact)
**Current**: Every 15 minutes during business hours  
**Proposed**: Every 1 hour (or 30 min for critical updates only)

```yaml
# BEFORE (current)
schedule:
  - cron: '*/15 11-19 * * 1-5'  # Every 15 min, Mon-Fri 11h-19h UTC

# AFTER (optimized)
schedule:
  - cron: '0 11-19 * * 1-5'     # Every hour, Mon-Fri 11h-19h UTC
  - cron: '0 0-10,20-23 * * 1-5' # Every hour, off-hours Mon-Fri
```

**Expected reduction**: 35 commits → ~8 commits/week = **27 commits saved**

### 2. State Backups (backup-state.yml)
**Current**: Every hour  
**Proposed**: Every 6 hours (6x/day instead of 24x/day)

```yaml
# BEFORE
schedule:
  - cron: '0 * * * *'  # Every hour

# AFTER
schedule:
  - cron: '0 0,6,12,18 * * *'  # Every 6 hours
```

**Expected reduction**: 7 commits → ~3 commits/week = **4 commits saved**

### 3. Memory Auto-Save (per PR only, not per-action)
**Current**: Every action (search-replace, deploy, etc.)  
**Proposed**: Only on PR merge + end-of-session

**Implementation**: Modify memory update hooks to batch instead of fire-on-every-action

**Expected reduction**: 3 commits → ~1 commit/week = **2 commits saved**

## Implementation Steps

### Step 1: Update spark-sync-state.yml
```bash
# File: .github/workflows/spark-sync-state.yml
# Change line with schedule cron from:
#   - cron: '*/15 11-19 * * 1-5'
# To:
#   - cron: '0 11-19 * * 1-5'
```

### Step 2: Update backup-state.yml
```bash
# File: .github/workflows/backup-state.yml
# Change schedule to run 4x/day instead of 24x/day
```

### Step 3: Review and Audit
- [ ] Verify spark-sync still updates dashboard timely
- [ ] Confirm backups are captured at critical moments
- [ ] Monitor Pages deployment status
- [ ] Track commit frequency for 1 week

## Rollback Plan
If reduced frequency causes issues:
1. Increase to 30-min spark-sync (instead of 15-min)
2. Increase backups to 4h intervals (instead of 6h)
3. Revert memory batching if session state loses fidelity

## Success Metrics

| Metric | Current | Target | Timeline |
|--------|---------|--------|----------|
| Commits/week | ~50 | < 8 | 1 week after change |
| Dashboard freshness | 15 min | 1 hour | Acceptable |
| Backup coverage | 24x/day | 4x/day | Sufficient |
| GitHub spam flag | Potential | Cleared | 2 weeks |

## Related Documentation
- docs/spam-remediation-plan.md (main remediation plan)
- docs/spam-status-investigation.md (root cause analysis)
- CLAUDE.md section "Autonomous Agent Team" (workflow scheduling)

## Approval Required
- [ ] DevOps/SRE review
- [ ] Product owner approval (if dashboard freshness affected)
- [ ] Security review (backup frequency impact)
