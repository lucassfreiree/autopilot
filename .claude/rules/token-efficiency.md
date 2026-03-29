# Token Efficiency Rules

> These rules optimize token usage WITHOUT reducing capability.
> The goal is maximum output with minimum waste.

## 1. File Reading Strategy
- NEVER read an entire large file when you only need a specific section. Use `offset` + `limit`.
- NEVER re-read a file you already read in this session unless it changed.
- Use `Grep` to find the exact line before reading the surrounding context.
- For JSON files, use `jq` via Bash instead of reading the full file when you need 1-2 fields.

## 2. Search Strategy
- Use `Grep` with specific patterns before using `Agent` for exploration.
- Use `Glob` for file finding — never `find` via Bash.
- Set `head_limit` on Grep results to avoid flooding context with 100+ matches.

## 3. Multi-Step Efficiency
- Plan changes mentally BEFORE starting tool calls. Batch related edits.
- Use `Edit` with precise `old_string` — never read-then-write when a targeted edit works.
- When creating multiple files, use parallel tool calls when independent.
- When making N changes to different files, do them in parallel, not sequentially.

## 4. Git Operations
- Combine `git add + commit + push` in a single Bash call when possible.
- Use `git status --short` (not verbose) for status checks.
- Use `git diff --stat` before full diff to see if changes are worth reviewing.

## 5. API & Webhook Efficiency
- For GitHub API checks, fetch only the fields you need with `--jq`.
- Use `per_page=1` when you only need the latest item.
- Don't poll in tight loops — use background tasks with appropriate intervals.

## 6. Avoid Redundant Work
- Before creating a file, check if it already exists with Glob.
- Before creating a PR, check if one already exists for the same branch.
- Before searching for a pattern, check if you already have the answer in session memory.
- Don't re-validate YAML files you just wrote — validate once at the end.

## 7. Output Conciseness
- Don't repeat back to the user what they just said.
- Don't explain what you're about to do in detail — just do it.
- Show results, not process. Summarize at the end.
- Use tables for structured data — more info in fewer tokens.

## 8. Agent Delegation
- Use subagents for genuinely parallel independent research.
- Don't spawn agents for simple grep/glob operations.
- When delegating, give complete context so the agent doesn't re-discover.

## 9. Context Window Management
- Prioritize keeping recent, actionable information in context.
- Summarize large tool outputs mentally — don't ask tools to re-fetch.
- When approaching context limits, compress by summarizing findings so far.

## 10. Session Start Optimization
- Session memory is auto-injected via hook — don't re-read it manually.
- Read CLAUDE.md only when you need specific sections, not the full 800+ lines.
- Workspace config: only fetch when doing workspace-specific operations.
