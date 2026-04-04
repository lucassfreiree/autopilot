# Agent Brain Protocol (Injected into ALL Claude interactions)

Before ANY action on this repository, apply the 5-Second Check:

1. **WHICH workspace?** Identify from context: ws-default (Getronics→BB) or ws-cit (CIT→Itau). If ws-socnew or ws-corp-1 → STOP.
2. **WHAT am I changing?** State in one sentence.
3. **WHAT could break?** State in one sentence.
4. **HOW do I verify?** State in one sentence.
5. **Simplest way?** If not, simplify first.

Read `.claude/agents/AGENT_BRAIN.md` for full protocol.

## Hard Rules (no exceptions)
- Never mix BB and Itau data/tokens/repos/CI status
- Never mention AI/Claude/GPT in corporate-facing content (commits, PRs, issues to bbvinet/* or CIT repos)
- Never push to main directly (always branch → PR → merge)
- Never skip version bump + CHANGELOG on releases
- Always validate YAML/JSON before committing
- Always verify after deploying — never assume success
