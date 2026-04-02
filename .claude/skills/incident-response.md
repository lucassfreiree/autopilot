---
name: incident-response
description: Structured SRE incident response. Use when CI fails repeatedly, deploys break, or runtime errors detected.
allowed-tools: Read, Bash, Edit, Write, Grep, Glob, Agent
---

# Incident Response — SRE Auto-Triage

## Severity Classification
| Level | Criteria | Response Time |
|-------|----------|---------------|
| P0 | Production down, all users affected | Immediate |
| P1 | Degraded service, partial outage | < 15 min |
| P2 | CI/CD blocked, deploy stuck | < 1 hour |
| P3 | Non-blocking issue, cosmetic | Next session |

## Step 1: Detect & Classify
1. Read latest CI logs from autopilot-state branch
2. Check health.json status (healthy/degraded/critical)
3. Check release-state.json for stuck deploys
4. Correlate timing with recent deploys (last 24h)

## Step 2: Triage
| Signal | Classification | Action |
|--------|---------------|--------|
| CI failed < 5 min after deploy | Code error (lint/type/test) | Auto-fix via ci-fix skill |
| CI failed after 14 min | Build/Docker error | Check corporate runner logs |
| Agent 401/403 | Auth/JWT misconfiguration | Check JWT middleware + secrets |
| Agent 503 | Pod rolling update | Wait 5 min, verify recovery |
| Multiple consecutive failures | Systemic issue | Rollback to last known good version |
| Health DEGRADED + expired locks | Stale state | Dispatch workspace-lock-gc |

## Step 3: Respond
- **Auto-fixable**: Create patch, bump version, deploy (ci-fix flow)
- **Rollback needed**: Revert to previous version in trigger/source-change.json
- **Infrastructure**: Dispatch appropriate ops workflow (lock-gc, drift-correction, health-check)
- **External**: Document in session memory, notify user

## Step 4: Post-Incident
1. Record error pattern in session memory `commonPatterns.errorRecovery`
2. Add pattern to `.claude/skills/ci-fix.md` if new
3. Update `contracts/improvement-history.json`
4. Verify health returns to HEALTHY status

## Rollback Procedure
```
1. Read last successful version from session memory
2. Update trigger/source-change.json with rollback version
3. Increment run number
4. Commit + PR + merge (auto-triggers apply-source-change)
5. Monitor until CI Gate passes
```
