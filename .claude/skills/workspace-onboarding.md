---
description: Onboard a new workspace (company/client). Use when setting up ws-cit or any new workspace engagement.
---

# Workspace Onboarding Skill

Structured checklist for onboarding a new workspace (company → client engagement).

## Usage
Invoke when a new workspace needs setup or when checking onboarding status.

## Onboarding Checklist

### Phase 1: Identity & Isolation
- [ ] Workspace ID defined (e.g., `ws-cit`)
- [ ] Company → Client mapping documented
- [ ] Keywords for context identification defined
- [ ] Entry added to `contracts/workspace-context-rules.json`
- [ ] Color theme assigned (not conflicting with existing)
- [ ] Token secret name defined (e.g., `CIT_TOKEN`)
- [ ] Workspace config created: `ops/config/workspaces/<ws_id>.json`
- [ ] Cross-contamination rules documented

### Phase 2: State & Infrastructure
- [ ] State directory seeded: `state/workspaces/<ws_id>/`
  - [ ] `workspace.json` with repos, branches, credentials
  - [ ] `health.json` initial state
  - [ ] `locks/` directory
  - [ ] `audit/` directory
- [ ] Workspace schema validates (`schemas/workspace.schema.json`)
- [ ] Seed workflow run: `seed-workspace.yml`

### Phase 3: Dashboard Integration
- [ ] Workspace added to `panel/dashboard/index.html` WS_CTX
- [ ] Sidebar indicator shows company → client
- [ ] Color theme applied correctly
- [ ] Workspace detail view works

### Phase 4: Agent Awareness
- [ ] All agents updated with new workspace context
- [ ] `contracts/shared-agent-context.md` updated
- [ ] AGENT_BRAIN.md workspace table updated
- [ ] CLAUDE.md workspace tables updated

### Phase 5: Operational Readiness
- [ ] Token configured as repository secret
- [ ] Token access verified (`check-repo-access.yml` if repos exist)
- [ ] Corporate repos configured (if available)
- [ ] CI/CD pipeline identified (GitHub Actions / GitLab CI / Jenkins)
- [ ] Trigger files configured for workspace

### Phase 6: Verification
- [ ] Health check passes for new workspace
- [ ] Dashboard shows correct data
- [ ] No cross-contamination with existing workspaces
- [ ] Session memory updated with new workspace info

## Quick Status Check
```bash
# Check workspace config exists
cat state/workspaces/<ws_id>/workspace.json | jq '.status'

# Check health
cat state/workspaces/<ws_id>/health.json | jq '.overall'

# Check dashboard
grep '<ws_id>' panel/dashboard/index.html
```

## ws-cit Specific (Itau Unibanco — Starting April 6, 2026)
- Company: CIT
- Client: Itau Unibanco
- Stack: DevOps (K8s, Docker, Terraform, IaC, CI/CD)
- Token: CIT_TOKEN
- Color: orange
- Status: Onboarding
- Phase 1-4: Complete
- Phase 5-6: Pending (awaiting token and repo access)
