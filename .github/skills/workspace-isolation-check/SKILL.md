---
name: workspace-isolation-check
description: Verify workspace isolation before any operation. Use BEFORE any state-changing operation to ensure you are not operating on a third-party workspace.
---

# Workspace Isolation Check Skill

## When to use
- BEFORE any state-changing operation (deploy, trigger, seed, backup, etc.)
- When the user mentions a workspace you are not sure about
- When trigger files reference an unknown `workspace_id`
- MANDATORY before any operation that involves `ws-socnew` or `ws-corp-1`

## Step 1: Identify the workspace from context

| Context clue | Workspace |
|---|---|
| Getronics / controller / agent / NestJS / bbvinet / esteira / psc-sre | `ws-default` |
| CIT / DevOps / Terraform / K8s / cloud / monitoring / IaC / infra | `ws-cit` |
| SocNew / socnew | `ws-socnew` → **STOP — THIRD PARTY** |
| Corp-1 / corp1 | `ws-corp-1` → **STOP — THIRD PARTY** |
| Ambiguous | **ASK the user before proceeding** |

## Step 2: Check the LOCKED list

```
THIRD-PARTY WORKSPACES (LOCKED):
  ws-socnew  — belongs to a third party (account owner's brother)
  ws-corp-1  — belongs to a third party

IF target workspace is ws-socnew or ws-corp-1:
  → STOP immediately
  → Tell the user: "This workspace belongs to a third party. I need explicit authorization from lucassfreiree before operating on it."
  → Wait for explicit written authorization before proceeding
```

## Step 3: Verify session lock

```
get_file_contents(
  path: "state/workspaces/<ws_id>/locks/session-lock.json",
  ref: "autopilot-state"
)
```

If `agentId != "none"` AND `expiresAt > now`:
→ Another agent is active. Create a handoff instead of forcing.

## Step 4: Confirm token

| Workspace | Expected token |
|---|---|
| `ws-default` | `BBVINET_TOKEN` |
| `ws-cit` | `CIT_TOKEN` |

Verify the workflow or trigger uses the correct token for the identified workspace.

## Step 5: Proceed or stop

| Result | Action |
|---|---|
| Workspace is `ws-default` or `ws-cit`, lock free, correct token | ✅ Proceed |
| Workspace is `ws-socnew` or `ws-corp-1` | 🛑 STOP — request authorization |
| Workspace ambiguous | ❓ ASK user |
| Lock held by another agent | ⏳ Wait or create handoff |
| Wrong token | 🛑 STOP — do not cross-contaminate |

## Isolation Confirmation Message (show to user before proceeding)

```
## Workspace Isolation Check ✅
- Workspace: ws-default (Getronics)
- Owner: Account owner (authorized)
- Token: BBVINET_TOKEN
- Lock: Free
- Third party: No

Ready to proceed.
```
