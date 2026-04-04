---
description: Self-healing patterns for autonomous error recovery, memory management, and pattern recognition. Use when diagnosing failures, building auto-recovery, or improving system resilience.
---

# Self-Healing Skill

Autonomous self-healing framework. The system detects failures, matches known patterns,
applies fixes, and learns new patterns — progressively reducing AI dependency.

## 1. Pattern Recognition

### How the System Learns
```
Failure occurs
  ↓
Match against contracts/resilience-patterns.json (13+ patterns)
  ↓ match found
Apply known workaround → verify fix → record success
  ↓ no match
Match against session memory errorRecovery patterns
  ↓ match found
Apply learned fix → verify → record success
  ↓ no match
NEW PATTERN DISCOVERED:
  1. Diagnose root cause
  2. Implement fix
  3. Add pattern to resilience-patterns.json
  4. Create GitHub Issue documenting the pattern
  5. Next occurrence → auto-fixed (zero intervention)
```

### Pattern Categories
| Category | Examples | Auto-fixable? |
|----------|---------|---------------|
| **CI Failure** | Test fail, lint error, type error, duplicate tag | Yes — ci-self-heal.yml |
| **Workflow Failure** | Syntax error, missing secret, timeout | Yes — workflow-auto-repair.yml |
| **Deploy Failure** | Push rejected, image build fail, promote fail | Partial — retry + escalate |
| **Network** | API timeout, rate limit, DNS failure | Yes — exponential backoff |
| **State** | Stale lock, corrupt JSON, missing file | Yes — cleanup + recreate |
| **Auth** | Token expired, permission denied, 403 | No — escalate (token rotation) |
| **Billing** | Minutes exceeded, API quota hit | No — escalate (needs human) |

### Pattern Definition Format
```json
{
  "id": "unique-pattern-id",
  "category": "ci|workflow|deploy|network|state|auth|billing",
  "trigger": "regex or keyword that identifies this failure",
  "severity": "critical|high|medium|low",
  "workaround": {
    "steps": ["step1", "step2"],
    "automated": true,
    "workflow": "workflow-that-fixes.yml"
  },
  "fallbackChain": ["try1", "try2", "escalate"],
  "learned": "2026-04-04",
  "successCount": 0
}
```

## 2. Memory Management

### What Gets Remembered
| Memory Type | Where Stored | Retention |
|-------------|-------------|-----------|
| Error patterns | `contracts/resilience-patterns.json` | Permanent (grows over time) |
| Session decisions | `contracts/claude-session-memory.json` | Compacted weekly |
| Workflow outcomes | `state/status-ledger/YYYY-MM-DD.json` | 30 days |
| Autonomy metrics | `state/autonomy-tracker.json` | Permanent (append) |
| Audit trail | `state/audit/` | Permanent |

### Memory Lifecycle
```
1. CAPTURE: Every failure/fix is recorded immediately
2. DEDUPLICATE: Same pattern → increment counter, don't add duplicate
3. PROMOTE: Pattern seen 3+ times → add to resilience-patterns.json
4. COMPACT: Weekly — archive old sessions, trim steps (token-auto-optimize.yml)
5. ARCHIVE: Static reference docs moved to contracts/archive/
```

### Memory Hygiene Rules
- Never delete learned patterns (they prevent future failures)
- Compact session history but keep error patterns forever
- Deduplicate before adding (same root cause = same pattern)
- Record success count per pattern (proves value)
- Archive sessions older than 30 days (keep summary, remove steps)

## 3. Self-Healing Workflows (Already Active)

| Layer | Workflow | What It Does | Schedule |
|-------|---------|-------------|----------|
| 1 | `builds-validation-gate.yml` | **Prevention** — blocks broken workflows | On PR |
| 2 | `workflow-health-monitor.yml` | **Detection** — finds consecutive failures | Every 30min |
| 3 | `workflow-auto-repair.yml` | **Repair** — fixes disabled/stuck workflows | On demand |
| 4 | `intelligent-orchestrator.yml` | **Brain** — OBSERVE→DECIDE→ACT→LEARN | Every 15-60min |
| 5 | `workflow-sentinel.yml` | **Meta** — watches the monitoring stack itself | Every 4h |
| 6 | `ci-self-heal.yml` | **CI Recovery** — pattern match + auto-fix | On failure |
| 7 | `autonomy-improver.yml` | **Learning** — analyzes interventions, generates fixes | Daily |
| 8 | `emergency-watchdog.yml` | **Emergency** — critical failure escalation | Continuous |
| 9 | `feature-validation-sweep.yml` | **Post-merge** — catches bugs in new features | On push |

### Fallback Chains (Ordered Recovery)
```
CI Failure:
  ci-self-heal → fix-corporate-ci → ci-diagnose → @claude Issue

Deploy Failure:
  retry (2s backoff) → version bump → ci-monitor → @claude Issue

Workflow Stuck:
  workflow-auto-repair → disable+re-enable → @claude Issue

API Call:
  retry 2s → 4s → 8s → 16s → escalate

State Corruption:
  backup-state restore → seed-workspace → @claude Issue
```

## 4. Building New Self-Healing Patterns

When you discover a new failure type:

```bash
# 1. Document the pattern
# Add to contracts/resilience-patterns.json:
jq '.patterns += [{"id":"new-pattern","category":"...","trigger":"...","workaround":{"steps":["..."],"automated":true}}]' \
  contracts/resilience-patterns.json > tmp.json && mv tmp.json contracts/resilience-patterns.json

# 2. Create GitHub Issue for traceability
# Use template: agent-finding.yml
# Labels: finding, pattern, auto-fixable

# 3. If automatable, add to relevant workflow
# ci-self-heal.yml for CI patterns
# workflow-auto-repair.yml for workflow patterns
# Add pattern matching in the "diagnose" step

# 4. Verify the auto-fix works
# Simulate the failure, confirm the workflow catches and fixes it

# 5. Update session memory
# Record in commonPatterns.errorRecovery
```

## 5. Measuring Self-Healing Effectiveness

### Key Metrics
| Metric | Target | Tracked By |
|--------|--------|-----------|
| Autonomy rate | >95% | autonomy-improver.yml |
| Mean time to auto-fix | <5 min | status-ledger |
| Pattern coverage | >90% of known failures | resilience-patterns.json |
| Human interventions/week | <2 | autonomy-tracker.json |
| False positive rate | <5% | manual review |

### The Ultimate Test
> If AI stops working for 24 hours, how many failures would self-heal?
> Current estimate: ~60% (Level 2). Target: >90% (Level 3-4).
