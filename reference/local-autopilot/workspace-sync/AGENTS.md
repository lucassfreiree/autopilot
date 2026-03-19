# Shared AI Operating Protocol

This workspace uses one shared memory layer for Codex, Claude Code, and Gemini.

Canonical workspace files:
- `ai-sync/STATE.json`
- `ai-sync/LATEST.md`
- `ai-sync/AUTO.md`
- `ai-sync/DECISIONS.md`
- `ai-sync/LEARNINGS.md`
- `ai-sync/HANDOFF.md`
- `ai-sync/EVENTS.jsonl`
- `scripts/ai-sync.ps1`

Persistent BBDevOpsAutopilot sources of truth for controller/agent/release work:
- `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\AGENTS.md`
- `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\docs\agent-coordination-protocol.md`
- `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\docs\agent-shared-learnings.md`

## Before any work

1. Read `ai-sync/STATE.json`.
2. Read `ai-sync/LATEST.md`.
3. Read `ai-sync/AUTO.md` for the generated cross-agent summary.
4. If the task touches BBDevOpsAutopilot, controller, agent, CI, release flow, or deploy automation, also read the persistent files above.
5. If `activeTasks` already contains the same work claimed by another agent, do not duplicate the work.
6. Claim the task before editing anything:
   `powershell -ExecutionPolicy Bypass -File scripts/ai-sync.ps1 claim -Agent <claude|gemini|codex> -Description "<task>"`

## While working

- Keep notes factual and short.
- Use `ai-sync/AUTO.md` as the quick summary and `ai-sync/EVENTS.jsonl` as the append-only operational trace.
- Record architecture or process changes in `ai-sync/DECISIONS.md`.
- Record reusable fixes, failures, and patterns in `ai-sync/LEARNINGS.md`.
- If you stop with partial work, append a handoff entry to `ai-sync/HANDOFF.md`.
- If any shared file changes during the same session, reread it before continuing.
- Do not store secrets, tokens, passwords, cookies, or private credentials in any shared file.

## After meaningful work

1. Complete the task:
   `powershell -ExecutionPolicy Bypass -File scripts/ai-sync.ps1 complete -Agent <agent> -Notes "<result>"`
2. Add a decision entry if the workflow, architecture, path, or standard changed.
3. Add a learning entry if another agent should reuse the discovery later.
4. Add a handoff entry if follow-up is still needed.

## Collaboration model

- Claude, Gemini, and Codex are peers. No hierarchy.
- Natural strengths are useful, but not exclusive:
  - Claude: deeper analysis, long context, review, debugging.
  - Gemini: docs, monitoring, repetitive operational flows, follow-through.
  - Codex: focused implementation, refactors, utility scripts, bounded code changes.
- Any agent can start a task.
- Any agent can review or extend another agent's work.
- Shared knowledge must move into the files above, not stay only in one chat session.

## Scope rule

This workspace-local protocol exists to keep the three agents aligned inside `AUTOMACAO`.
It must not replace the persistent BBDevOpsAutopilot memory. If there is any conflict, the persistent files under `.bbdevops-autopilot-safe` win for operational controller/agent work.

## Automatic Efficiency Routine

- The persistent autopilot now maintains an efficiency routine through `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\autopilot-efficiency.ps1`.
- Latest audit report: `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\reports\efficiency\latest.md`
- Latest state snapshot: `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\state\efficiency-state.json`
- `scripts/ai-sync.ps1` triggers the routine opportunistically after meaningful shared-state updates, but cleanup remains conservative and skips active work by default.
- Agents must prefer the smallest useful context first and avoid eager reads of large docs unless the task clearly requires them.

## Suggested commands

- Status:
  `powershell -ExecutionPolicy Bypass -File scripts/ai-sync.ps1 status`
- Claim:
  `powershell -ExecutionPolicy Bypass -File scripts/ai-sync.ps1 claim -Agent codex -Description "Implement X"`
- Complete:
  `powershell -ExecutionPolicy Bypass -File scripts/ai-sync.ps1 complete -Agent codex -Notes "Done and validated"`
- Event:
  `powershell -ExecutionPolicy Bypass -File scripts/ai-sync.ps1 event -Agent gemini -Category runtime -Description "Spooler executed command" -EventStatus success`
- Decision:
  `powershell -ExecutionPolicy Bypass -File scripts/ai-sync.ps1 decision -Agent codex -Title "Use workspace sync layer" -Decision "Local files mirror the persistent protocol" -Rationale "Gemini local memory was empty"`
- Learning:
  `powershell -ExecutionPolicy Bypass -File scripts/ai-sync.ps1 learning -Agent codex -Title "Gemini home memory is not enough" -Context "Workspace sync" -Problem "Project state was not shared" -Solution "Use ai-sync files" -ReusablePattern "Keep project state in workspace, not only in ~/.gemini/GEMINI.md"`
- Handoff:
  `powershell -ExecutionPolicy Bypass -File scripts/ai-sync.ps1 handoff -Agent codex -Description "Partial implementation" -Files AGENTS.md,ai-sync/STATE.json -Notes "Tests pending" -NextStep "Run validation"`
- Efficiency:
  `<LOCAL_USER_HOME>\START.cmd efficiency`
