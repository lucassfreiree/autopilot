---
description: Track owner preferences, working patterns, and decisions across sessions. Use at session start to load context about how the owner works.
---

# Know Me — Owner Preference Tracking

Tracks preferences, patterns, and decisions of the repository owner (lucassfreiree)
to provide better, more aligned assistance across sessions.

## Owner Profile

### Communication
- **Language**: Portuguese (BR) primary, English for code/technical
- **Style**: Direct, wants results not explanations
- **Autonomy**: High — prefers agents that act without asking
- **Confirmation**: Only ask when risk > 7/10 or irreversible

### Technical Preferences
- **Commits**: Conventional commits (`feat:`, `fix:`, `chore:`)
- **PRs**: Squash merge to main, always from `claude/*` branches
- **Version**: Semver strict, patch 0-9 only, never X.Y.10
- **CHANGELOG**: Required for every version bump
- **CI**: Must monitor corporate CI after deploy (never assume success)

### Working Patterns
- **Sessions**: Typically long, multi-task sessions
- **Deploy flow**: Wants autonomous end-to-end (commit → PR → merge → monitor → fix)
- **Errors**: Fix automatically, don't ask — download logs, diagnose, fix, redeploy
- **Monitoring**: Live monitoring mandatory every session
- **Cost**: Zero additional cost mandate — everything must be free

### Strategic Vision
- **System autonomy**: Build processes that work WITHOUT AI (GitHub-First)
- **Maturity goal**: AI-Optional (Level 4) — system runs via GitHub Actions alone
- **Corporate rule**: NEVER mention AI/Claude/GPT in corporate content
- **Workspace isolation**: BB and Itau data NEVER mix — treat as state secrets
- **Team structure**: Director → Team Lead → 11 Specialists (real DevOps org)

### Known Decisions (Permanent)
| Decision | Rule | Date |
|----------|------|------|
| Centralized in Claude Code | Codex, Copilot, Gemini workflows disabled | 2026-03 |
| Zero cost mandate | Only free tools, no exceptions | 2026-04 |
| GitHub-First governance | Everything registered on GitHub as durable artifacts | 2026-04 |
| Corporate AI secrecy | Never mention AI in corporate-facing content | 2026-04 |
| Patch 0-9 rule | After X.Y.9 → X.(Y+1).0, never X.Y.10 | 2026-04 |
| Agent Brain protocol | All 13 agents read AGENT_BRAIN.md before any action | 2026-04 |
| Cost-benefit gate | Director veto on any tool with cost > $0 | 2026-04 |
| ws-socnew/ws-corp-1 blocked | Third-party workspaces, never operate | Permanent |

## What to Track (Update Each Session)

### Preferences Discovered
When the owner expresses a preference, record it here:
```
Format: [date] preference: details
```

### Patterns Observed
When a pattern repeats across sessions:
```
Format: [date] pattern: details
```

## Memory Integration
This skill complements `contracts/claude-session-memory.json`:
- Session memory = technical state (versions, deploys, errors)
- Know-me = personal preferences (how the owner works, what they value)

Both are read at session start. Both are updated during sessions.
