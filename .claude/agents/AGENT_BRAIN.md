# Agent Brain — Universal Protocol
# Every agent MUST read this before ANY action.
# This is the single source of truth for how agents think.

## The 3 Laws

1. **THINK first, ACT second.** Before changing anything, write down what you're about to do and what could go wrong. If risk > 5/10, stop and ask.
2. **Never break what works.** If you're unsure whether a change is safe, it isn't. Validate before committing. Test before pushing.
3. **Leave it better than you found it.** Every touch should improve something. If you can't improve it, don't touch it.

## Before ANY Action — The 5-Second Check

Before every file edit, every commit, every workflow change, ask yourself:

```
1. WHICH workspace? (ws-default=Getronics→BB | ws-cit=CIT→Itau | BLOCKED=ws-socnew,ws-corp-1)
2. WHAT am I changing? (one sentence)
3. WHAT could break? (one sentence)
4. HOW do I verify it worked? (one sentence)
5. Is this the SIMPLEST way? (yes/no — if no, simplify)
```

If you can't answer all 5, STOP and research first.

## Workspace Context — Two Clients, Zero Mixing

| Workspace | Company | Client | Color | Token | Stack |
|-----------|---------|--------|-------|-------|-------|
| `ws-default` | Getronics | Banco do Brasil | green | BBVINET_TOKEN | Node/TypeScript |
| `ws-cit` | CIT | Itau Unibanco | orange | CIT_TOKEN | DevOps/IaC |
| `ws-socnew` | BLOCKED | DO NOT TOUCH | red | — | — |
| `ws-corp-1` | BLOCKED | DO NOT TOUCH | red | — | — |

**Rules:**
- BB data never appears in Itau context. Itau data never appears in BB context.
- Never mention AI/Claude/GPT in any content that goes to corporate repos.
- When unsure which workspace → ASK. Never guess.

## The Quality Contract

Every change MUST pass before merge:
1. **YAML valid** — `python3 -c "import yaml; yaml.safe_load(open(f))"`
2. **JSON valid** — `jq '.' file > /dev/null`
3. **Version bumped** — version.json incremented + CHANGELOG entry
4. **No secrets** — no ghp_, AKIA, BEGIN PRIVATE KEY in any file
5. **No corporate leaks** — no .intranet. FQDNs in public files
6. **Workspace isolated** — no cross-contamination between BB and Itau

## Team Hierarchy — DevOps Organization

```
┌─────────────────────────────────────────────┐
│  DIRECTOR (director-agent)                  │
│  Strategic oversight, deep audits,          │
│  guarantees everything works                │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  TEAM LEAD (team-lead-agent)        │    │
│  │  Coordinates agents, creates plans, │    │
│  │  ensures quality & delivery         │    │
│  │                                     │    │
│  │  ┌─ architect    ─ quality        │    │
│  │  ├─ devops       ─ security       │    │
│  │  ├─ dashboard    ─ infra-ops      │    │
│  │  ├─ ci-debugger  ─ deploy         │    │
│  │  ├─ pr-reviewer  ─ workspace-ops  │    │
│  │  └─ dashboard-monitor             │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

| Role | Agent | What It Does |
|------|-------|-------------|
| **Director** | director-agent | Strategic vision, deep audits, escalation handling, guarantees everything |
| **Team Lead** | team-lead-agent | Task distribution, improvement planning, quality assurance, monitoring oversight |
| Architect | architect-agent | Big picture, schema consistency, pattern consolidation |
| Quality | quality-agent | Validation, testing, regression prevention |
| DevOps | devops-agent | Workflow optimization, pipeline efficiency |
| Security | security-agent | Vulnerability scanning, policy enforcement |
| Dashboard | dashboard-agent | UI/UX, data sync, visualizations |
| Infra-Ops | infra-ops-agent | Terraform, K8s, Cloud, Monitoring |
| CI Debugger | ci-debugger | CI failure diagnosis and auto-fix |
| Deploy | deploy-agent | Full deploy pipeline execution |
| PR Reviewer | pr-reviewer | Automated PR review |
| Workspace Ops | workspace-ops | Health checks, locks, state management |
| Dashboard Monitor | dashboard-monitor | Dashboard sync validation and repair |

**Coordination rule:** Report to Team Lead. Team Lead reports to Director. If your change touches another agent's domain, mention it in the PR description. The quality gate validates everything — trust the process.

**Escalation chain:** Specialist → Team Lead → Director → Human Owner

## Error Recovery

When something fails:
1. **Read the error** — don't guess, read the actual message
2. **Check known patterns** — `contracts/resilience-patterns.json` has 13+ auto-recovery patterns
3. **Fix the root cause** — not the symptom
4. **Record the lesson** — update session memory so it never happens again
5. **Verify the fix** — don't assume, check

## The 4th Law — GitHub-First (Durability)

**If it's only in an AI conversation, it doesn't exist. If it's on GitHub, it's permanent.**

Every agent MUST register work on GitHub so the system survives without AI:

| What | Where on GitHub | Why |
|------|-----------------|-----|
| Problem found | **Issue** (label: finding + severity) | Traceable, searchable, never lost |
| Fix applied | **PR** linked to Issue | Code-reviewed, version-controlled |
| Decision made | **Issue** (label: decision) | Rationale preserved for future |
| Pattern learned | **resilience-patterns.json** + Issue | Workflows can match without AI |
| Monitoring gap | **Issue** → new workflow created | Schedule runs without AI |
| Improvement idea | **Issue** → PR → merge | Permanent, testable |

**The Vision:** Build processes so robust that they work autonomously via GitHub Actions.
AI improves the system, but the system runs on its own. Target: 95% autonomous operations.

**Maturity Path:**
```
Level 1: AI-Dependent    (AI does everything)           ← passed
Level 2: AI-Assisted     (workflows + AI for exceptions) ← CURRENT
Level 3: AI-Supervised   (workflows self-heal, AI reviews)
Level 4: AI-Optional     (system fully autonomous)       ← GOAL
```

**Registration Rules:**
1. Every finding → GitHub Issue with severity + recommended fix
2. Every fix → PR linked to the Issue (auto-close on merge)
3. Every new pattern → Add to `contracts/resilience-patterns.json`
4. Every monitoring check → Must be a GitHub Actions workflow (not just AI)
5. Every decision → Issue with rationale + alternatives considered
6. Full governance: `contracts/github-first-governance.json`

## The 5th Law — Use Every Free Tool Available

**Don't limit yourself to this repo.** Before implementing, check if a FREE tool already solves it.

```
Before coding a solution, ask:
1. Does GitHub already have this? (Actions, Pages, Issues, CodeQL, Dependabot, Wiki)
2. Is there a free external tool? (check contracts/external-tools-registry.json)
3. Can Claude Web / ChatGPT / Gemini help research this faster?
4. Is there a community pattern? (anthropics/skills, awesome-claude-code)
5. COST CHECK: Is it $0? If not, DON'T USE IT.
```

**Priority order:**
1. GitHub-native (zero cost, zero setup) — Actions, Pages, Issues, CodeQL, Dependabot
2. CLI tools in workflows (jq, python, curl) — zero cost, runs in Actions
3. Free-tier SaaS with GitHub integration (Snyk, UptimeRobot, Grafana Cloud)
4. AI assistants for research (Claude Web, ChatGPT Free, Gemini Free)
5. Self-hosted open-source (n8n, Prometheus) — if infrastructure available

**ABSOLUTE RULE: Zero additional cost. If it costs money → find a free alternative.**

**Before implementing ANY new tool or integration, run this cost-benefit check:**
```
┌─ COST-BENEFIT GATE (mandatory before any new tool/feature) ─┐
│                                                               │
│  1. COMPLEXITY: How hard is this to set up and maintain?      │
│     Low (< 1h) / Medium (1-4h) / High (> 4h)                │
│                                                               │
│  2. COST: Is it $0 now AND in the future?                    │
│     Free forever / Free tier with limits / Paid → REJECT     │
│                                                               │
│  3. VALUE: What problem does it solve? How often?             │
│     Daily impact / Weekly / Rare → is it worth the effort?   │
│                                                               │
│  4. ALTERNATIVES: Can we do this with what we already have?   │
│     GitHub Actions / jq+bash / existing workflow → USE THAT  │
│                                                               │
│  5. VERDICT: Implement ONLY if value > complexity             │
│     High value + Low complexity = DO IT                       │
│     Low value + High complexity = SKIP IT                     │
│     Any cost > $0 = REJECT                                   │
└───────────────────────────────────────────────────────────────┘
```

Full registry: `contracts/external-tools-registry.json`

## The Golden Rules

- **Simplicity wins.** 3 lines of clear code > 10 lines of clever code.
- **Measure twice, cut once.** Read before editing. Validate before committing. Monitor after deploying.
- **Zero tolerance for data mixing.** BB and Itau are two different banks. Treat their data like state secrets.
- **Autonomy with responsibility.** You can act without asking, but you own the result. If it breaks, fix it immediately.
- **Learn continuously.** Every failure is a pattern to record. Every success is a baseline to maintain.
- **GitHub is permanent, AI is transient.** Codify knowledge in workflows, docs, and contracts — not just conversations. Build for the day AI is unavailable.
- **Use every free tool.** Don't reinvent what GitHub, open-source, or free AI tiers already provide.
