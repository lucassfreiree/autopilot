# Changelog

All notable changes to the Autopilot project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.8.1] - 2026-04-04

### Improved
- **Skills enriched with original source content** from `daianepepes-lab/claude-skills` repo:
  - self-healing: Added 5 runtime failure patterns (memory leak, connection pool, cascading,
    disk exhaustion, CPU starvation) with symptoms, causes, detection, and fix for each
  - security-hardening: Added JWT best practices (RS256, short expiry, httpOnly cookies),
    password hardening (bcrypt cost 12+, argon2id), API key management
  - cost-reducer: Added 12 cloud cost quick wins table (spot instances up to 90% savings,
    storage tiering, NAT Gateway audit, K8s optimization, reserved instances)
- All enriched skills include attribution to original source

## [1.8.0] - 2026-04-04

### Added
- **Security Scorecard** (`security-scorecard.yml`): OpenSSF Scorecard (`ossf/scorecard-action@v2`,
  2k+ stars) runs 18 automated security checks — branch protection, pinned actions, token permissions.
  Results uploaded to GitHub Security tab as SARIF. Weekly + on push to main.
- **CI Hardening** (`harden-ci.yml`): Step Security Harden Runner (`step-security/harden-runner@v2`,
  18M+ weekly runs) monitors runner network egress and process activity. Audits workflows using
  BBVINET_TOKEN and RELEASE_TOKEN. Checks for unpinned 3rd-party actions, pull_request_target
  injection risks, and curl|sh patterns. Weekly audit.
- **Smart Path Filtering**: Integrated `dorny/paths-filter@v3` (3k+ stars) into Quality Gate.
  Jobs now skip when irrelevant files changed — saves Actions minutes on every PR.

### Changed
- Quality Gate (`agent-quality-gate.yml`): Added `detect-changes` job with paths-filter.
  YAML validation skips if no workflow changes, JSON skips if no schema/contract changes,
  dashboard check skips if no panel changes, etc. Report shows "skipped" with reason.
  Gate decision now checks for `failure` (not `!= success`) to allow skipped jobs.
- Total workflows: 81 (was 79)

## [1.7.0] - 2026-04-04

### Added
- **Issue Templates**: 3 structured templates for agent work (Finding, Improvement, Decision)
  with severity, workspace, agent dropdown, cost-benefit analysis fields
- **Skills** (7 new, inspired by `anthropics/skills` official patterns):
  - `workspace-onboarding`: 6-phase checklist for new workspace setup
  - `changelog-generator`: Auto-generate CHANGELOG from conventional commits
  - `cost-reducer`: Cloud/infra costs, token costs, FinOps, free tier tracking
  - `security-hardening`: Auth/secrets, dependency security, web security, supply chain
  - `create-skill`: Guide for agents to create well-structured new skills
  - `know-me`: Owner preference tracking across sessions (language, style, decisions)
  - `self-healing`: Pattern recognition, memory management, auto-recovery framework
- **PR Auto-Label** (`pr-auto-label.yml`): Uses `actions/labeler@v5` (official, 10k+ stars)
  to auto-label PRs by changed file paths (agent, workflow, dashboard, patch, security, etc.)
- **Lint Workflows** (`lint-workflows.yml`): Uses `rhysd/actionlint` (8k+ stars) to validate
  all workflow YAML for syntax errors, type issues, deprecated features, shell script problems
- **Stale PR Cleanup** (`stale-pr-cleanup.yml`): Uses `actions/stale@v9` (official, 1.2k+ stars)
  to auto-warn (7d) and close (10d) abandoned PRs
- **Auto-Fix on Push** (`auto-fix-on-push.yml`): Self-healing layer using
  `stefanzweifel/git-auto-commit-action@v5` (3k+ stars) — auto-formats JSON,
  removes trailing whitespace, ensures newlines at EOF
- **Labeler config** (`.github/labeler.yml`): 12 label rules for file path patterns

### Changed
- Total workflows: 79 (was 75)
- Total skills: 15 (was 8)
- Issue templates: 10 (was 7)

## [1.6.0] - 2026-04-04

### Added
- **External Tools Registry** (`contracts/external-tools-registry.json`): Catalog of ALL free tools
  agents should consider (Claude Web, ChatGPT Free, Gemini, GitHub CodeQL, Dependabot, Snyk Free,
  UptimeRobot, Grafana Cloud Free, community intelligence sources). Zero-cost mandate enforced.
- **Cost-Benefit Gate**: Mandatory analysis before ANY new tool/integration — complexity, cost ($0 only),
  value, alternatives check. If existing tools can do it → use existing. Director has veto power.
- **5th Law** in AGENT_BRAIN.md: "Use Every Free Tool Available" — agents must check free alternatives
  before coding custom solutions. Priority: GitHub-native > CLI tools > Free SaaS > AI research > Self-hosted.

### Changed
- AGENT_BRAIN.md: Added 5th Law + cost-benefit gate flowchart
- Director agent: Added Cost-Benefit Gate as veto power (Section 5), rejects any cost > $0
- Team Lead agent: Improvement planning now starts with free tools check (Step 2)
- All agents operate under principle: don't reinvent what free tools already provide

## [1.5.0] - 2026-04-04

### Added
- **Feature Validation Sweep** (`feature-validation-sweep.yml`): Automatic post-merge validation
  that catches bugs, gaps, and inconsistencies in every new feature merged to main.
  8 checks: JSON validity, YAML validity, Agent Brain consistency, version/CHANGELOG match,
  cross-reference integrity, security scan, workflow consistency, documentation mapping.
  Auto-fixes what it can (e.g., missing permissions blocks), creates GitHub Issue for what it can't.
  Runs on every push to main + manual dispatch with full scan option.

### Changed
- Post-merge validation now covers: content validation (new), health monitoring (existing),
  audit trail (existing), backup signal (existing). No gap between pre-merge gates and runtime.

## [1.4.0] - 2026-04-04

### Added
- **GitHub-First Governance** (`contracts/github-first-governance.json`): Central contract mandating
  that ALL agent work is registered on GitHub as durable artifacts (Issues, PRs, workflows, docs).
  Defines 4 maturity levels: AI-Dependent → AI-Assisted → AI-Supervised → AI-Optional.
- **4th Law** in AGENT_BRAIN.md: "If it's only in an AI conversation, it doesn't exist.
  If it's on GitHub, it's permanent." — every finding, fix, decision, and pattern MUST be on GitHub.
- **Registration rules**: Findings → Issues, Fixes → PRs linked to Issues, Patterns → resilience-patterns.json,
  Monitoring → GitHub Actions workflows (not AI prompts), Decisions → Issues with rationale.
- **Autonomy maturity tracking**: Target 95% autonomous operations by end Q2 2026.

### Changed
- Director agent: Added GitHub-First Mandate as primary directive, autonomy maturity tracking,
  "The Test" (if AI stopped tomorrow, would this process still run?)
- Team Lead agent: Added GitHub-First Operations checklist, AI-Dependent→Autonomous conversion guide,
  durable output verification for all agent work
- AGENT_BRAIN.md: Added 4th Law (GitHub-First), maturity path visualization, registration rules table
- All agents now operate under principle: build processes that work without AI

## [1.3.0] - 2026-04-04

### Added
- **Director Agent** (`director-agent.md`): Strategic oversight VP — deep audits, system-wide guarantee,
  escalation handling, defines priorities. The 5 Guarantees: nothing fails silently, no data crosses
  boundaries, no security regression, continuous improvement, full accountability.
- **Team Lead Agent** (`team-lead-agent.md`): DevOps Coordinator — creates improvement plans, distributes
  tasks to 11 specialist agents, ensures quality & delivery, monitoring oversight.
- **Agent hierarchy**: Director → Team Lead → 11 Specialists (mirrors real DevOps org structure)
- **Escalation chain**: Specialist → Team Lead → Director → Human Owner
- **Task distribution matrix**: Every issue type mapped to primary agent + backup + escalation path

### Changed
- AGENT_BRAIN.md updated with full team hierarchy diagram and role table
- Agent team now 13 members (was 11): added director-agent and team-lead-agent
- Coordination rule updated: specialists report to Team Lead, Team Lead to Director

## [1.2.0] - 2026-04-04

### Added
- **Agent Brain** (`AGENT_BRAIN.md`): Universal protocol that ALL agents read before any action.
  Forces 5-Second Check (which workspace, what changing, what breaks, how verify, simplest way?)
- **Brain Protocol rule** (`agent-brain-protocol.md`): Auto-injected into every Claude interaction
- **infra-ops-agent**: New agent covering Terraform, Kubernetes, Cloud, and Monitoring gaps
  (critical for ws-cit/Itau onboarding April 6)

### Changed
- All 11 agents now reference AGENT_BRAIN.md as first instruction
- Agents operate with 3 Laws: think first, never break what works, leave it better
- Unified workspace context in Brain (BB=green, Itau=orange, locked=red)
- Unified error recovery protocol: read error → check patterns → fix root cause → record lesson → verify

## [1.1.2] - 2026-04-04

### Fixed
- Post-Merge Monitor step 4: shell interpolation of multiline MISSING_ITEMS broke gh api call. Now uses jq to build safe JSON payload via env var.

## [1.1.1] - 2026-04-04

### Fixed
- Intelligent Orchestrator Phase 4: subshell variable bug (pipe + while-read loses UPDATED), save to state branch
- Post-Merge Monitor: `set -e` killed script on `grep -c` exit 1, jq memory update now non-fatal
- Autonomous Direct Merge: stale queue detection (>3min = skip), timeout grace if completed checks passed

## [1.1.0] - 2026-04-04

### Added
- **Consultancy context model**: Each workspace now maps company → end-client
  - `ws-default`: Getronics → Banco do Brasil (BB)
  - `ws-cit`: CIT → Itau Unibanco (onboarding starts 2026-04-06)
- **Workspace context contract** (`contracts/workspace-context-rules.json`):
  - Keyword-based identification protocol for agents
  - Cross-contamination prevention rules (BB ↔ Itau)
  - Dashboard color coding and display rules
- **Dashboard workspace indicators**:
  - Sidebar shows active engagements with company→client labels and color coding
  - Workspace detail view shows client name, service type, start date
  - Work Center header shows company→client label
  - Color theme: green=Getronics/BB, orange=CIT/Itau, red=locked
- **Agent workspace awareness**: All 8 agent definitions updated with:
  - Consultancy model context (company→client mapping)
  - Cross-contamination prevention rules
  - Reference to workspace-context-rules.json
- **Enriched workspace configs** (schemaVersion 2):
  - Added client, clientShortName, serviceType, startDate, colorTheme, keywords
  - Updated ws-default with current versions (ctrl 3.8.2, agent 2.3.3)
  - Updated ws-cit with onboarding status and tasks
- **Workspace schema** updated: Added client, clientShortName, serviceType, startDate, colorTheme fields

### Security
- **Corporate environment rule**: NEVER mention AI/Claude/GPT/LLM in corporate-facing content (commits, PRs, issues, branch names, code comments). All work in corporate repos must appear as regular developer work. Rule enforced in workspace-context-rules.json and shared-agent-context.md

### Changed
- Shared agent context updated with consultancy model and current state
- Dashboard WS_CTX enriched with company, client, serviceType, icon, color per workspace

## [1.0.3] - 2026-04-04

### Improved
- All 5 agent definitions rewritten with detailed autonomous workflows, decision matrices, and escalation rules
- Agent orchestrator: precise deprecated action detection (uses: lines only), auto-version-bump, auto-CHANGELOG
- Autonomous improve: parallel agent analysis, false-positive-free scanning, auto-PR with version bump
- Quality gate: added trigger file validation, duplicate tag check, patch overflow check (never X.Y.10)
- Release pipeline: added patch overflow validation, streamlined state persistence
- Version-bump script: added overflow protection, input validation, semver enforcement
- Security scan: private key detection, precise FQDN matching (no false positives on doc patterns)

## [1.0.2] - 2026-04-04

### Fixed
- Added minimal `permissions:` blocks to 6 workflows (least privilege principle)
  - check-repo-access, release-agent, release-controller, security-vuln-scanner, session-guard, sync-community-resources
- Applied by: DevOps Agent (autonomous cycle)

## [1.0.1] - 2026-04-04

### Fixed
- Refined agent analysis to reduce false positives in deprecated action detection
- Agent orchestrator now skips sed pattern strings when scanning for deprecated actions

## [1.0.0] - 2026-04-04

### Added
- Product versioning system with `version.json` and git tags
- Autonomous agent team: architect, devops, quality, dashboard, security specialists
- Agent orchestration workflow (`agent-team-orchestrator.yml`) - daily autonomous improvements
- Release pipeline (`release-autopilot-product.yml`) - automated versioning and tagging
- Autonomous improvement workflow (`agent-autonomous-improve.yml`) - agents propose and implement fixes
- Quality validation gates for all agent changes
- CHANGELOG tracking for all releases

### Changed
- Autopilot now treated as a versioned product (v1.0.0+)
- Agents operate autonomously with high autonomy level
- Dashboard improvements automated via dashboard-agent

### Architecture
- 5 new specialized agents: architect, devops, quality, dashboard, security
- Agent team orchestrator coordinates daily improvement cycles
- Release pipeline validates, tags, and publishes releases
- Quality gates ensure no breaking changes from autonomous agents
