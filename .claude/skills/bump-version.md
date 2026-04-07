---
name: bump-version
description: Bump the autopilot product version (patch/minor/major). Updates version.json, CHANGELOG.md, and session memory. Use when releasing new features or fixes.
allowed-tools: Read, Bash, Edit, Write, Grep
---

# Bump Version — Autopilot Product Version Management

Safely bump the autopilot product version following semver rules.

## Usage
Invoke with argument: `/bump-version patch`, `/bump-version minor`, or `/bump-version major`
Default: `patch` if no argument provided.

## Versioning Rules (from CLAUDE.md)
```
patch: 0-9 (bug fixes, small improvements, agent auto-fixes)
  When patch reaches 9 → minor += 1, patch = 0

minor: 0-9 (new features, new agents, new workflows, dashboard enhancements)
  When minor reaches 9 → major += 1, minor = 0

major: Breaking changes to contracts, state schema, or workflow interfaces
```

**CRITICAL**: Version X.Y.10 is NEVER valid. Patch 9 → next is minor bump.

## Step 1: Read Current Version
```bash
jq -r '.version' version.json
```

## Step 2: Calculate New Version
Apply the bump type with rollover rules:
- `patch`: X.Y.Z → X.Y.(Z+1), but if Z=9 → X.(Y+1).0
- `minor`: X.Y.Z → X.(Y+1).0, but if Y=9 → (X+1).0.0
- `major`: X.Y.Z → (X+1).0.0

## Step 3: Update Files (4 locations)
1. `version.json` — update `version` field
2. `CHANGELOG.md` — add new version header with date and changes
3. `contracts/claude-session-memory.json` — update `versioningRules.currentVersion`
4. Session context — remember new version for deploy flow

## Step 4: Validate
- Confirm no X.Y.10+ versions
- Confirm CHANGELOG has entry for new version
- Confirm version.json is valid JSON
- Check git tags to ensure version doesn't already exist: `git tag -l "v{new_version}"`

## Step 5: Report
```
Version bumped: v{old} → v{new}
Type: {patch/minor/major}
Files updated:
  ✓ version.json
  ✓ CHANGELOG.md
  ✓ session-memory
Ready for: commit + PR + merge → auto-tags via release-autopilot-product.yml
```

## Rollover Examples
| Current | Bump | Result |
|---------|------|--------|
| 1.8.6 | patch | 1.8.7 |
| 1.8.9 | patch | 1.9.0 |
| 1.9.9 | patch | 2.0.0 |
| 1.8.6 | minor | 1.9.0 |
| 1.9.0 | minor | 2.0.0 |
