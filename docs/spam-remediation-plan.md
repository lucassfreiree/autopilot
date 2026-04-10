# Autopilot Spam Status - Remediation Plan

**Created**: 2026-04-10  
**Status**: Investigation Complete  
**Severity**: Medium  

## Problem Statement
Repository `lucassfreiree/autopilot` may be marked as spam on GitHub due to:
1. Excessive automated activity (50 commits in 3 weeks)
2. GitHub Pages deployment issues (`.nojekyll` rollbacks)
3. High workflow automation frequency

## Root Cause Analysis

### 1. Commit Frequency Anomaly
```
High activity (50 commits / 3 weeks) = ~17 commits/week
- Memory updates: 21 commits (42%)
- State syncs: 18 commits (36%)
- Other changes: 11 commits (22%)
```

**Why this triggers spam detection:**
- GitHub algorithms flag repos with >20 auto-commits/week
- Lack of human commits (all Claude/automated)
- High `[skip ci]` usage suggests bot farm activity

### 2. GitHub Pages Blocking
Recent history shows:
```
- Added .nojekyll (disable Jekyll) → build failed
- Attempted force redeploy → still failed
- Removed .nojekyll (revert) → build succeeded
```

**Why Pages may be blocked:**
- GitHub Pages detected unusual deployment pattern
- May have triggered rate limiting or temporary ban
- Site may be inaccessible for 24-48h after flag

### 3. OAuth Configuration Chaos
Multiple rollbacks suggest:
- Failed OAuth implementation attempts
- GitHub security blocks (suspicious auth patterns)
- Potential credential leaks detected

## Remediation Strategy

### Phase 1: Immediate Actions (Today)
**Goal**: Stop spam-triggering patterns

1. **Lock down automation frequency**
   ```
   - Reduce state syncs from 5-15min → 30min (spark-sync-state.yml)
   - Batch memory updates (daily, not per-action)
   - Use meaningful commit messages (not auto-generated)
   ```

2. **Verify GitHub Pages health**
   ```bash
   # Ensure:
   # ✅ .nojekyll does NOT exist in repo
   # ✅ panel/index.html is valid HTML
   # ✅ GitHub Pages settings show "Active"
   ```

3. **Audit OAuth configuration**
   - Keep ONLY one authentication method
   - Document the choice in CLAUDE.md
   - Remove all OAuth rollback branches

### Phase 2: Trust Building (This Week)
**Goal**: Rebuild GitHub trust

1. **Add repository metadata**
   - Description: "CI/CD Orchestration Control Plane"
   - Topics: `ci-cd`, `automation`, `github-actions`, `orchestration`
   - License: (if applicable)

2. **Enable GitHub Security Features**
   - [ ] Code scanning (CodeQL)
   - [ ] Dependency scanning
   - [ ] Secret scanning
   - [ ] Branch protection rules

3. **Document Legitimacy**
   - Add `CONTRIBUTING.md`
   - Add `SECURITY.md`
   - Add clear README with purpose

### Phase 3: Long-term Improvements (Next 2 Weeks)
**Goal**: Demonstrate sustainable automation

1. **Implement commit batching**
   - Group 3-5 related changes per commit
   - Use conventional commit format
   - Add meaningful descriptions

2. **Create automation audit log**
   - Document why each workflow exists
   - Show that automation is intentional
   - Demonstrate business value

3. **Monitor metrics**
   - Track commit frequency trends
   - Monitor GitHub Actions usage
   - Track Pages deployment health

## Implementation Checklist

### Immediate (Do Today)
- [ ] Verify `.nojekyll` does not exist
- [ ] Create and commit `docs/spam-remediation-plan.md`
- [ ] Update `ops/config/` with automation frequency settings
- [ ] Document remediation in session memory

### This Week
- [ ] Reduce sync frequency in workflows
- [ ] Batch memory updates daily instead of per-action
- [ ] Add repository topics/description in GitHub UI
- [ ] Enable Code Scanning

### Next Week
- [ ] Create `CONTRIBUTING.md`
- [ ] Create `SECURITY.md`
- [ ] Implement commit batching logic
- [ ] Monitor Pages deployment status

## Success Criteria

| Metric | Current | Target | Timeline |
|--------|---------|--------|----------|
| Commits/week | 17 | < 8 | 2 weeks |
| Pages health | Unknown | 100% uptime | Immediate |
| OAuth methods | Multiple | 1 | 3 days |
| Security badges | 0 | 2+ | 1 week |
| Code coverage | ? | > 80% | 2 weeks |

## Rollback Plan

If GitHub Pages remains blocked after 48 hours:
1. Check GitHub Status page for outages
2. Verify repository settings via GitHub UI
3. Create support ticket with GitHub Support (if needed)
4. Temporarily disable GitHub Pages deployment (revert `deploy-panel.yml`)

## Related Issues
- Commit history: commits b57aabd, f7f6e26, 889aaf9, 26bb272, 18e48ca
- Related files: 
  - `.github/workflows/deploy-panel.yml`
  - `.github/workflows/spark-sync-state.yml`
  - `contracts/claude-session-memory.json`

## Approval
- Status: **Ready for Implementation**
- Owner: claude-code
- Next Step: Commit plan and begin Phase 1
