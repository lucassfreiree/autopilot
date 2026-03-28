---
applyTo: ".github/workflows/**"
---

# Workflow Files Instructions

Files in `.github/workflows/` are GitHub Actions workflows that power the Autopilot control plane.

## Naming Conventions
- Core control plane operations: `[Core]` prefix in `name:`
- Corporate repo operations: `[Corp]` prefix — use `BBVINET_TOKEN`, scoped to `ws-default`
- Release management: `[Release]` prefix — workspace-aware
- Infrastructure/maintenance: `[Infra]` prefix
- Agent coordination: `[Agent]` prefix
- Operational tasks: `Ops:` prefix

## Trigger Patterns
- Most workflows are triggered by changes to `trigger/*.json` files (push to main)
- Workflow dispatch inputs always include `workspace_id`
- Scheduled workflows use UTC cron expressions

## Workspace Safety Rules
- **NEVER** hardcode `ws-socnew` or `ws-corp-1` in any workflow
- **ALWAYS** read `workspace_id` from inputs or trigger files — never hardcode
- `[Corp]` workflows currently require `BBVINET_TOKEN` (ws-default only)
- For multi-workspace support, read `workspace.json` from `autopilot-state` dynamically

## Security Rules
- NEVER print secrets or tokens in workflow steps (even with masking, avoid logging)
- NEVER use `permissions: write-all` without explicit justification in a comment
- Use `GITHUB_TOKEN` minimum permissions: specify only what is needed
- Secrets referenced must exist in the repository secrets (verify before adding)

## Error Handling
- Always use `set -euo pipefail` in bash steps
- Log warnings with `echo "::warning ::"` for non-fatal issues
- Log errors with `echo "::error ::"` for fatal issues
- NEVER use `|| true` without logging first: `command || { echo "::warning::..."; true; }`

## Session Guard Pattern
Any workflow that writes to `autopilot-state` or modifies corporate repos MUST call `session-guard.yml` first:
```yaml
uses: ./.github/workflows/session-guard.yml
with:
  workspace_id: ${{ inputs.workspace_id }}
  agent_id: 'my-workflow'
  operation: 'my-operation'
```

## Audit Trail
Every state-changing workflow MUST write an audit entry to `autopilot-state`:
```
state/workspaces/<workspace_id>/audit/<operation>-<timestamp>.json
```

## Run Trigger Mechanism
When a workflow is triggered by a `trigger/*.json` file change, the `run` field in that JSON MUST be incremented — without increment, the workflow does NOT re-trigger on identical content.
