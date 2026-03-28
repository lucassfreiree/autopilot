---
name: Workspace Isolation Violation
about: Report a violation of workspace isolation policy (unauthorized operation on ws-socnew or ws-corp-1, token cross-contamination, or workspace data leakage)
title: '[SECURITY] Workspace Isolation Violation: <brief description>'
labels: security, incident, workspace-isolation
assignees: lucassfreiree
---

## Violation Summary

**Workspace affected:** (e.g., `ws-socnew`, `ws-corp-1`, `ws-default`, `ws-cit`)

**Type of violation:**
- [ ] Unauthorized operation on third-party workspace (`ws-socnew` or `ws-corp-1`)
- [ ] Token cross-contamination (wrong token used for workspace)
- [ ] Workspace state exposed in public logs or outputs
- [ ] Corporate data from one workspace visible in another
- [ ] Other: ___

**Severity:**
- [ ] P1 — Data exposed / operation executed on third-party workspace without authorization
- [ ] P2 — Attempted unauthorized operation (blocked before execution)
- [ ] P3 — Policy gap identified (no actual operation executed)

---

## Details

**When did it happen?** (timestamp or "discovered now")

**Which agent or workflow was involved?**

**What operation was attempted or executed?**

**Was any data accessed or modified?**

---

## Evidence

```
(paste relevant log lines, workflow output, or commit SHA)
```

---

## Impact Assessment

**Were any third-party workspace operations actually executed?**
- [ ] Yes — describe below
- [ ] No — violation was blocked or is theoretical

**If yes, what was done and what needs to be reversed?**

---

## Required Actions

- [ ] Confirm authorization status with `lucassfreiree` (account owner)
- [ ] If unauthorized: reverse any changes made to third-party workspaces
- [ ] Identify root cause (agent instruction gap, missing guard, etc.)
- [ ] Update workspace isolation policy if gap found
- [ ] Add lesson to session memory (`contracts/claude-session-memory.json`)

---

## Third-Party Workspace Policy Reminder

`ws-socnew` and `ws-corp-1` belong to a third party (account owner's brother).
**Any operation on these workspaces requires explicit documented authorization from `lucassfreiree`.**
Reference: `.github/instructions/workspace-isolation.instructions.md`
