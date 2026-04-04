---
description: Analyze and reduce costs across cloud infrastructure, code efficiency, services, and FinOps. Use when evaluating costs, optimizing workflows, or planning infrastructure.
---

# Cost Reducer Skill

> Inspired by `daianepepes-lab/claude-skills/cost-reducer`, adapted for autopilot context.

Autonomous cost reduction specialist. Activates when discussing costs, optimization, billing,
resource usage, or efficiency improvements.

## Core Principle
**Zero waste, maximum output.** Every resource must justify its existence.

## 1. Cloud & Infrastructure Cost Reduction

### GitHub Actions (Our Primary Compute)
| Optimization | Saving | How |
|-------------|--------|-----|
| Cancel stale runs | ~30% minutes | `concurrency: cancel-in-progress: true` |
| Skip unnecessary CI | ~20% minutes | `[skip ci]` on docs/memory commits |
| Cache dependencies | ~15% minutes | `actions/cache@v4` for pip/npm |
| Conditional steps | ~10% minutes | `if: steps.changes.outputs.workflows == 'true'` |
| Matrix strategy | Parallel vs sequential | Only matrix when testing multiple versions |

### When ws-cit Adds Cloud (AWS/Azure/GCP)
```
ALWAYS check before provisioning:
1. Right-size instances (don't use m5.xlarge when t3.small works)
2. Use spot/preemptible for non-critical (CI runners, batch jobs)
3. Reserved instances for steady-state workloads
4. Auto-scaling with proper min/max (don't leave instances idle)
5. Delete unused resources weekly (EBS volumes, old snapshots, unused EIPs)
6. Use S3 lifecycle policies (move to Glacier after 90 days)
7. NAT Gateway alternatives ($32/month/AZ — consider VPC endpoints)
8. CloudWatch log retention (don't keep forever — set 30/90 day retention)
```

### Container Optimization
```
- Multi-stage builds (reduce image size 60-80%)
- Alpine/distroless base images (50MB vs 900MB)
- Layer caching in CI (don't rebuild unchanged layers)
- Image cleanup policy (keep last 5 tags, delete old ones)
```

### Cloud Cost Quick Wins (from daianepepes-lab/claude-skills)
| Area | Optimization | Saving |
|------|-------------|--------|
| Compute | Spot/preemptible for CI runners and batch | Up to 90% |
| Compute | Right-size: compare actual CPU/RAM vs provisioned | 20-40% |
| Compute | ARM instances (Graviton/Ampere) | 20% cheaper |
| Storage | Cold data to S3 Glacier / Archive tier | 70-90% |
| Storage | Delete orphaned EBS volumes and old snapshots | Immediate |
| Network | Colocate services (avoid cross-region transfer) | Variable |
| Network | Audit NAT Gateway usage (hidden cost ~$32/mo/AZ) | $32+/mo |
| Database | Reserved instances for steady workloads | Up to 60% |
| Database | Auto-pause dev/staging databases when idle | 50-80% |
| K8s | Set resource requests/limits properly | Prevent overprovisioning |
| K8s | Cluster autoscaler + image cleanup policy | Variable |
| K8s | Fargate Spot for batch workloads | Up to 70% |

## 2. Code-Level Savings

### Token Cost (Claude Code — Our Biggest Cost)
| Model | Cost/1M tokens | Use For |
|-------|---------------|---------|
| Haiku | $0.80 | File search, exploration, simple lookups |
| Sonnet | $3.00 | Code review, moderate implementations |
| Opus | $15.00 | Complex architecture, multi-step deploys |

**Rules (from cost-reduction-mandate.md):**
- Use `model: "haiku"` for Explore agents
- Use `model: "sonnet"` for simple research
- Opus only for complex multi-step tasks
- Read files with `offset+limit`, never full large files
- Batch parallel tool calls (1 message with 5 calls > 5 messages)

### Workflow Efficiency
```
- Combine related changes in 1 commit (not multiple PRs)
- Hash comparison before pushing state (skip if unchanged)
- Don't trigger workflows unnecessarily (check if action needed first)
- Use `paths` and `paths-ignore` filters on triggers
```

## 3. Services & FinOps

### Free Tier Tracking
Before adding ANY external service, verify:
```
1. Is it free? (check contracts/external-tools-registry.json)
2. What are the free tier limits?
3. Are we approaching limits?
4. What's the fallback when limits are hit?
5. Is there a free alternative?
```

### Cost Monitoring Checklist (Weekly)
```
- [ ] GitHub Actions minutes used this week vs budget
- [ ] Any workflow running excessively? (check workflow-cost-tracker.yml)
- [ ] Any new paid service introduced? (should be $0)
- [ ] Token usage trending up or down?
- [ ] Any idle/unused resources to clean up?
```

### Cost-Benefit Gate (from AGENT_BRAIN.md)
Every new tool/feature must pass:
```
Complexity: Low/Medium/High
Cost: $0 (only acceptable answer)
Value: Daily/Weekly/Rare
Alternative: Can existing tools do this?
Verdict: Only if value > complexity AND cost = $0
```

## Quick Commands
```bash
# Check GitHub Actions usage
gh api /repos/lucassfreiree/autopilot/actions/workflows --jq '.workflows[] | .name + ": " + .state'

# Find expensive workflows (most runs)
gh run list --limit 20 --json name,conclusion,createdAt --jq '.[] | .name'

# Check for stale resources
find state/ -name "*.json" -mtime +30 -ls  # Files not updated in 30 days
```
