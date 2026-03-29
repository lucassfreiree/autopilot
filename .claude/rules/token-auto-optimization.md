# Token Auto-Optimization Rules (Enforced Every Session)

## 1. Subagent Model Routing
- Use `model: "haiku"` for Explore agents (file search, codebase exploration)
- Use `model: "sonnet"` for simple research agents (single question, straightforward lookup)
- Use default (Opus) only for complex multi-step agents requiring deep reasoning
- NEVER use Opus for agents that only read files or search patterns

## 2. Memory Efficiency
- Session memory is injected in COMPACT form at startup (essential sections only)
- If you need full execution history: `Read contracts/claude-session-memory.json` on demand
- If you need static reference docs: `Read contracts/archive/static-reference.json` on demand
- If you need CIT onboarding: `Read contracts/archive/cit-onboarding.json` on demand
- NEVER re-read the full memory file if you already have the compact version from hook

## 3. File Reading Strategy
- ALWAYS use `offset` + `limit` for files > 200 lines
- For JSON: use `jq` via Bash to extract specific fields instead of reading entire file
- For session memory updates: use Python script via Bash to modify specific fields

## 4. Parallel Operations
- Batch independent tool calls in parallel (max efficiency)
- When making N edits to different files, do them all in one message
- When creating multiple files, use parallel Write calls

## 5. Auto-Optimization Workflow
- `token-auto-optimize.yml` runs daily at 06:00 UTC
- Compacts session memory (archive old sessions, trim steps, externalize static docs)
- Rules defined in `contracts/token-optimization-rules.json`
- Audit trail written to autopilot-state branch
- Dashboard shows optimization status in Token Intelligence page
