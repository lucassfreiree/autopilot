---
description: Guide for creating new Claude Code skills. Use when agents need to create a new skill or improve existing ones.
---

# Create Skill — Skill Creation Guide

Reference for creating well-structured Claude Code skills for this project.

## Skill File Structure

```
.claude/skills/<skill-name>.md
```

### Required Format
```markdown
---
description: One-line description of what this skill does and WHEN to activate it.
---

# Skill Title

Brief explanation of the skill's purpose.

## Section 1: Core Capability
[Main knowledge/commands/patterns]

## Section 2: Decision Matrix
[When to do X vs Y]

## Section 3: Quick Commands
[Copy-paste ready commands]
```

## Rules for Good Skills

### DO
- **Specific triggers**: "Use when CI fails" not "Use for problems"
- **Actionable content**: Commands, checklists, decision matrices
- **Context-aware**: Reference our actual files (AGENT_BRAIN.md, contracts/, etc.)
- **Cost-conscious**: Note free tier limits, token costs
- **Workspace-aware**: Respect ws-default/ws-cit isolation

### DON'T
- Don't duplicate agent definitions (agents act, skills provide knowledge)
- Don't include secrets or corporate data
- Don't make skills too broad (1 skill = 1 focused domain)
- Don't add skills for hypothetical future needs
- Don't skip the `description:` frontmatter (it's how Claude finds the skill)

## Cost-Benefit Check (Before Creating)
```
1. Is there already a skill for this? → Extend it instead
2. Will it be used weekly? → If not, maybe it's just a doc
3. Is the knowledge actionable? → If just reference, put in ops/docs/
4. Does it fit in < 200 lines? → If much longer, split into sub-skills
```

## Existing Skills (Don't Duplicate)
| Skill | Domain |
|-------|--------|
| devops-sre-cloud | K8s, Terraform, CI/CD, Cloud |
| observability | Metrics, logs, traces, alerting |
| security-expert | OWASP, containers, supply chain |
| security-hardening | Auth, secrets, deps, web security |
| cost-reducer | Cloud costs, token costs, FinOps |
| ci-fix | CI failure diagnosis and repair |
| deploy-monitor | Deploy pipeline monitoring |
| daily-digest | Operational status report |
| incident-response | SRE incident management |
| capacity-planning | Resource usage optimization |
| workspace-onboarding | New workspace setup checklist |
| changelog-generator | Auto-generate CHANGELOG entries |

## Naming Convention
```
<domain>.md           — e.g., observability.md
<domain>-<focus>.md   — e.g., security-hardening.md
```

Avoid: generic names like "helper.md", "utils.md", "misc.md"
