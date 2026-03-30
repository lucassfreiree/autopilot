# Auto Memory Registration (MANDATORY — Owner Directive)

> New information must NEVER be lost between sessions.
> Registration is CONTINUOUS, not end-of-session.

## Rule: Register As You Go

Every time you complete an action that produces new knowledge, you MUST update
`contracts/claude-session-memory.json` **immediately** — not at the end of the session.

### What triggers a memory update:
1. **New errorRecovery pattern discovered** — add to `commonPatterns.errorRecovery`
2. **New workflow created/modified** — add to `executionHistory.sessions[]`
3. **New decision made** (version bump, architecture change, tool choice) — record it
4. **CI failure diagnosed and fixed** — add pattern + fix to `errorRecovery`
5. **New lesson learned** (something that broke, a workaround found) — record it
6. **PR merged** — add to current session entry in `executionHistory.sessions[]`

### When to commit memory updates:
- **After every PR merge**: include memory update in the next commit
- **After every significant discovery**: batch with next code change
- **Before context compaction**: auto-save hook runs, but verify it captured everything
- **At session end**: auto-save hook runs via `scripts/claude/auto-save-memory.sh`

### What NOT to do:
- Do NOT wait until session end to record patterns — context may be lost
- Do NOT skip memory updates to save tokens — the cost of re-learning is 10x higher
- Do NOT record trivial information (e.g., "read a file") — only actionable patterns

### Auto-save hooks:
- `PreCompact` hook: runs `auto-save-memory.sh` before context compaction
- `Stop` hook: runs `auto-save-memory.sh` at session end
- Both hooks commit and push uncommitted memory changes automatically

### Memory file structure quick reference:
```
contracts/claude-session-memory.json
  .lastUpdated           — ISO timestamp
  .commonPatterns.errorRecovery.<key>  — error pattern + fix
  .executionHistory.sessions[]         — session records with PRs and actions
  .communityIntelligence               — sync sources and skills
  .centralizedAgentModel               — disabled workflows
  .versioningRules                     — version management
  .deployFlow                          — deploy pipeline state
```
