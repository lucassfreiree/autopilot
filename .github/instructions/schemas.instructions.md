---
applyTo: "schemas/**"
---

# Schema Files Instructions

Files in `schemas/` are JSON schemas that validate all Autopilot state objects.

## Schema List
| File | Validates |
|---|---|
| `approval.schema.json` | Release approvals |
| `audit.schema.json` | Audit trail entries |
| `handoff.schema.json` | Agent handoff queue items |
| `health-state.schema.json` | Health check results |
| `improvement.schema.json` | Improvement records |
| `improvement-report.schema.json` | Improvement scan reports |
| `lock.schema.json` | Session and operation locks |
| `metrics.schema.json` | Daily metrics snapshots |
| `release-freeze.schema.json` | Release freeze state |
| `release-state.schema.json` | Release state (agent/controller) |
| `workspace.schema.json` | Workspace configuration |

## Rules for Creating or Modifying Schemas

1. **`schemaVersion` is mandatory** — every schema must have and maintain a `schemaVersion` field
2. **Backward compatibility** — existing required fields must not be removed or renamed without a version bump
3. **Optional fields** — new fields should be optional (`not in required[]`) to preserve backward compatibility
4. **`workspace_id`** — any schema that is workspace-scoped must include `workspace_id` as a required field
5. **No hardcoded workspace IDs** — schemas validate structure, not specific values

## Workspace Isolation in Schemas
- Schemas must NEVER reference specific workspace IDs (`ws-socnew`, `ws-corp-1`, etc.)
- The `workspace_id` field must accept any string — isolation is enforced at the workflow level

## Testing Schema Changes
- After modifying a schema, validate all existing state files against it
- Use `ajv` or similar JSON Schema validator
- If existing state files fail validation after a change, the change is breaking — reconsider

## Do Not
- NEVER remove `schemaVersion` from any schema
- NEVER make previously-optional fields required (breaking change)
- NEVER reference `.intranet.` URLs or corporate-specific values in schemas
