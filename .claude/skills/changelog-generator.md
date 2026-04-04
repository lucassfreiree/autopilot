---
description: Auto-generate CHANGELOG entries from conventional commits. Use before version bump or release.
---

# Changelog Generator Skill

Generate CHANGELOG.md entries automatically from git commit history.

## Usage
Invoke before a version bump to auto-generate the CHANGELOG entry.

## How It Works

1. Read current version from `version.json`
2. Get commits since last version tag
3. Categorize by conventional commit prefix
4. Generate formatted CHANGELOG entry

## Commit Prefix → CHANGELOG Section Mapping

| Prefix | CHANGELOG Section | Example |
|--------|------------------|---------|
| `feat:` | **Added** | New feature, agent, workflow |
| `fix:` | **Fixed** | Bug fix, correction |
| `security:` | **Security** | Security improvement |
| `perf:` | **Improved** | Performance, optimization |
| `refactor:` | **Changed** | Code restructuring |
| `docs:` | **Documentation** | Doc updates |
| `ci:` | **CI/CD** | Workflow changes |
| `chore:` | (skip) | Maintenance, memory updates |

## Generation Steps

```bash
# 1. Get current version
VERSION=$(jq -r '.version' version.json)

# 2. Find last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# 3. Get commits since last tag
if [ -n "$LAST_TAG" ]; then
  COMMITS=$(git log ${LAST_TAG}..HEAD --oneline --no-merges)
else
  COMMITS=$(git log --oneline --no-merges -20)
fi

# 4. Categorize
ADDED=$(echo "$COMMITS" | grep -i "^[a-f0-9]* feat:" || true)
FIXED=$(echo "$COMMITS" | grep -i "^[a-f0-9]* fix:" || true)
SECURITY=$(echo "$COMMITS" | grep -i "^[a-f0-9]* security:" || true)
CHANGED=$(echo "$COMMITS" | grep -iE "^[a-f0-9]* (refactor|perf):" || true)

# 5. Format entry
echo "## [$VERSION] - $(date +%Y-%m-%d)"
[ -n "$ADDED" ] && echo -e "\n### Added" && echo "$ADDED" | sed 's/^[a-f0-9]* feat: /- /'
[ -n "$FIXED" ] && echo -e "\n### Fixed" && echo "$FIXED" | sed 's/^[a-f0-9]* fix: /- /'
[ -n "$SECURITY" ] && echo -e "\n### Security" && echo "$SECURITY" | sed 's/^[a-f0-9]* security: /- /'
[ -n "$CHANGED" ] && echo -e "\n### Changed" && echo "$CHANGED" | sed 's/^[a-f0-9]* \(refactor\|perf\): /- /'
```

## Rules
- Always review generated entry before committing (AI may need to improve wording)
- Combine related commits into single bullet points
- Skip `chore:` and `[skip ci]` commits
- Ensure entry matches the actual impact, not just commit messages
- Date format: YYYY-MM-DD
- Follow Keep a Changelog format
