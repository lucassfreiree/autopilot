# Portability Guide

## Purpose
Make the autopilot easy to understand and rehydrate on another machine, another VS Code installation, or another AI session.

## Portable kit contents
- `portable-kit\manifest\autopilot-manifest.json`
- `portable-kit\docs\`
- `portable-kit\prompts\`
- `portable-kit\skill\`
- `portable-kit\scripts\`

## Portable install flow
1. Copy the full `portable-kit\` directory to the target machine.
2. Run `install-from-portable.ps1` from `portable-kit\scripts\` as the target user.
3. Save a valid GitHub token using `set-workspace-github-token.cmd` after the install.
4. Run `refresh-managed-repos.cmd` on the target machine.
5. Confirm the setup with `validate-autopilot.cmd`.

## Important limitations
- The token is intentionally not exported in the portable kit. It must be created again on the target machine.
- The portable kit only covers the managed controller release flow through the deploy `values.yaml` tag update. Cluster credentials and remote execution tooling are intentionally outside the exported runtime.
