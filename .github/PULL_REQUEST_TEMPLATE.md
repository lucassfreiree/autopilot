# Pull Request

## Summary

<!-- Briefly describe what this PR does and why -->

---

## Type of Change

- [ ] 🚀 Deploy — new version of controller or agent
- [ ] 🔧 Patch — code change to corporate repo (`patches/`)
- [ ] 📋 Trigger — workflow trigger file update (`trigger/`)
- [ ] 🏗️ Infrastructure — workflow, schema, or control plane change
- [ ] 📚 Documentation — CLAUDE.md, AGENTS.md, HANDOFF.md, ops/docs
- [ ] 🔒 Security — security fix or compliance update
- [ ] 🤖 Agent — new or updated agent, skill, or instruction
- [ ] ♻️ Memory — session memory update

---

## Workspace Isolation Check

**Target workspace:** `ws-___`

- [ ] Workspace identified from context (NOT assumed)
- [ ] Target workspace is **NOT** `ws-socnew` or `ws-corp-1` — OR explicit authorization from `lucassfreiree` is documented below
- [ ] Correct token will be used for this workspace
- [ ] No data from other workspaces mixed in this PR

> **Third-party workspace authorization** (if applicable):
> Workspace: ___ | Authorization: ___ | Date: ___

---

## Security Checklist

- [ ] No secrets, tokens, or credentials in committed files
- [ ] No `.intranet.` URLs in tracked files
- [ ] No corporate source code stored in this repo
- [ ] Workflow permissions are scoped to minimum needed (not `write-all`)
- [ ] Input validation uses `parseSafeIdentifier()` (NOT inside `fetch`/`postJson`)
- [ ] Error messages use `sanitizeForOutput()`

---

## Deploy Checklist (if applicable)

- [ ] `trigger/source-change.json` `run` field incremented
- [ ] Version bumped in all 5 required files (see `version-bump` skill)
- [ ] `validate-patches.yml` will run (or has been run) for patch changes
- [ ] `references/controller-cap/values.yaml` updated with new image tag
- [ ] `contracts/copilot-session-memory.json` updated with new version

---

## Documentation Checklist (if applicable)

- [ ] New workflows added to CLAUDE.md workflow table
- [ ] New trigger files added to CLAUDE.md trigger table
- [ ] New agents/skills/instructions documented
- [ ] Session memory updated (or will be updated at session end)
- [ ] `ws-socnew` and `ws-corp-1` documented as BLOCKED where relevant

---

## Testing

- [ ] `validate-patches.yml` passed (for patch changes)
- [ ] Existing tests not broken
- [ ] For infrastructure changes: tested in non-production environment first

---

## Notes for Reviewers

<!-- Any additional context, known limitations, or follow-up items -->
