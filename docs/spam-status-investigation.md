# Autopilot Repository Spam Status Investigation

## Investigation Date
April 10, 2026

## Executive Summary
This investigation checks whether the `lucassfreiree/autopilot` repository has been marked as spam by GitHub and identifies potential causes and remediation steps.

## Current Status Findings

### Symptom Analysis
Based on recent commit history, evidence suggests GitHub imposed restrictions:
1. **GitHub Pages Issues** (commits b57aabd, f7f6e26, 889aaf9)
   - Multiple attempts to add/remove `.nojekyll` file
   - Forced redeploy attempts
   - This typically indicates GitHub Pages was blocking the site

2. **OAuth Configuration Rollbacks** (commits 26bb272, 18e48ca)
   - Multiple OAuth implementations attempted and reverted
   - Suggests authentication issues or GitHub security restrictions

3. **High Workflow Activity** (50+ auto-commits from sync and memory updates)
   - Dashboard state syncs every 5-15 minutes
   - Memory updates after every action
   - Could trigger GitHub's abuse detection for automated activity

### Potential Root Causes of Spam Flagging

| Cause | Evidence | Impact |
|-------|----------|--------|
| **High automated commit frequency** | 50+ `[skip ci]` commits in 4 weeks | May trigger abuse detection |
| **GitHub Pages blocking** | `.nojekyll` file additions/reversions | Site may be inaccessible or flagged |
| **Suspicious OAuth flow** | Multiple OAuth implementations & rollbacks | GitHub security restrictions |
| **Repository reputation** | New product repo with minimal history | GitHub may flag new high-activity repos |
| **GitHub Actions concurrent runs** | Multiple agents + workflows | May trigger rate limiting |

## Verification Checklist

- [ ] Verify GitHub Pages is active and accessible
- [ ] Check if OAuth secrets are properly configured
- [ ] Verify no GitHub Actions rate limits are triggered
- [ ] Confirm dashboard deploys are succeeding
- [ ] Check if repository has any trust/verification badges

## Recommended Remediation

### 1. GitHub Pages Recovery
```bash
# Ensure .nojekyll is NOT present (Jekyll disabled for raw HTML)
rm -f .nojekyll

# Confirm index.html exists in panel/
ls -l panel/index.html

# Verify deploy-panel.yml workflow is healthy
```

### 2. Commit Frequency Optimization
- Batch state syncs (currently every 5 min → 30 min)
- Compress memory updates (daily instead of per-action)
- Use `[skip ci]` for non-critical commits

### 3. OAuth Cleanup
- Remove unused OAuth implementations
- Keep only single, tested authentication method
- Document the choice in CLAUDE.md

### 4. Repository Trust Building
- Add repository description/topics
- Add code security settings
- Enable GitHub Advanced Security if available

## Action Items

1. **Immediate**: Remove `.nojekyll` if it exists and commit
2. **This Week**: Optimize commit/workflow frequency
3. **This Week**: Audit GitHub Pages deployment status
4. **Next**: Document findings in session memory

## References
- GitHub Pages Spam Policy: https://docs.github.com/en/pages/getting-started-with-github-pages
- GitHub Abuse Detection: https://docs.github.com/en/github/site-policy/github-community-guidelines
- CLAUDE.md Deploy Flow: See section "Deploy Flow — Complete Guide"
- Recent problematic commits:
  - b57aabd: Add .nojekyll
  - 889aaf9: Revert .nojekyll
  - 26bb272: Remove OAuth
  - 18e48ca: Rollback OAuth changes
