#!/bin/bash
# Auto-save session memory on session end
# Called by .claude/settings.json Stop hook
# Commits and pushes any uncommitted changes to session memory

set -euo pipefail

MEMORY_FILE="contracts/claude-session-memory.json"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '/home/user/autopilot')"
cd "$REPO_ROOT"

# Check if memory file has uncommitted changes
if git diff --quiet "$MEMORY_FILE" 2>/dev/null && git diff --staged --quiet "$MEMORY_FILE" 2>/dev/null; then
  # No changes to memory — nothing to do
  exit 0
fi

# Update lastUpdated timestamp
python3 -c "
import json, datetime
with open('$MEMORY_FILE') as f:
    mem = json.load(f)
mem['lastUpdated'] = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
with open('$MEMORY_FILE', 'w') as f:
    json.dump(mem, f, indent=2, ensure_ascii=False)
" 2>/dev/null || true

# Get current branch
BRANCH=$(git branch --show-current 2>/dev/null || echo "")

# If on main, create a temp branch
if [ "$BRANCH" = "main" ] || [ -z "$BRANCH" ]; then
  BRANCH="claude/auto-memory-$(date +%Y%m%d-%H%M%S)"
  git checkout -B "$BRANCH" 2>/dev/null || exit 0
fi

# Stage and commit
git add "$MEMORY_FILE" 2>/dev/null || exit 0
git commit -m "[claude] chore: auto-save session memory [skip ci]" 2>/dev/null || exit 0

# Push (with retry)
for i in 1 2 3; do
  git push -u origin "$BRANCH" 2>/dev/null && break
  sleep $((i * 2))
done

echo '{"systemMessage":"Session memory auto-saved and pushed to '"$BRANCH"'"}'
