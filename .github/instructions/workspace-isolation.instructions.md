---
applyTo: "**"
---

# Workspace Isolation Policy

**This policy applies to ALL operations in this repository.**

## Authorized Workspaces

| Workspace ID | Owner | Status | Token |
|---|---|---|---|
| `ws-default` | Getronics (account owner) | **ACTIVE** | `BBVINET_TOKEN` |
| `ws-cit` | CIT (account owner) | **ACTIVE** | `CIT_TOKEN` |
| `ws-socnew` | **THIRD PARTY** | **🔒 LOCKED — DO NOT OPERATE** | N/A |
| `ws-corp-1` | **THIRD PARTY** | **🔒 LOCKED — DO NOT OPERATE** | N/A |

## Rule: ws-socnew and ws-corp-1 are BLOCKED

`ws-socnew` and `ws-corp-1` belong to a third party (account owner's brother).

**Any operation on these workspaces — including reading state, triggering workflows, creating issues, or modifying configuration — requires EXPLICIT and DOCUMENTED authorization from `lucassfreiree` (the account owner).**

Even if these workspaces appear in lists, dropdowns, or configuration files, treat them as **LOCKED**.

## Isolation Rules

1. **NEVER assume a default workspace** — always identify from conversation context before acting
2. **NEVER mix** data, commits, credentials, or state between workspaces
3. **Each workspace** uses exclusively its own token (`credentials.tokenSecretName` in `workspace.json`)
4. **Identify workspace** from context before any operation:
   - Getronics / controller / agent / NestJS / bbvinet / esteira → `ws-default`
   - CIT / DevOps / Terraform / K8s / cloud / monitoring / infra → `ws-cit`
   - Ambiguous → **ASK the user before proceeding**
5. **Never cross-contaminate**: do not use `BBVINET_TOKEN` for CIT operations or vice versa
6. **Third-party workspaces**: if user asks to operate on `ws-socnew` or `ws-corp-1`, STOP and ask for explicit authorization before doing anything

## Verification Checklist (before any state-changing operation)

- [ ] Workspace identified from context (not assumed)
- [ ] Target workspace is NOT `ws-socnew` or `ws-corp-1` (or explicit authorization confirmed)
- [ ] Correct token will be used for this workspace
- [ ] Session lock checked: `state/workspaces/<ws_id>/locks/session-lock.json`
- [ ] No data from other workspaces will be mixed in this operation
