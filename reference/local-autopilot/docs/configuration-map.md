# Configuration Map

Use this file when the request is about changing some URL, branch, repo path, deploy target, or other release-flow setting.

## Current default release boundary
- The default controller autopilot flow ends after promoting `deploy-psc-sre-automacao-controller` on `cloud/homologacao` by updating `deployment.containers.tag` in `values.yaml`.
- Cluster-side sync, pod restart, and OneDrive-based remote execution are intentionally outside the installed operational surface.
- CI diagnostics and controlled failure probes are allowed only on temporary controller branches and never on `main`.

## Primary configuration surfaces
- `autopilot-manifest.json`
  - machine-readable source of truth for paths, repo URLs, Argo target, bridge target, policy, prompts, and commands
- `controller-release-autopilot.json`
  - runtime script configuration used by the autopilot implementation
- `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\AGENTS.md`
  - global discovery layer for future chats
- local skill `bbdevops-controller-autopilot`
  - reusable skill guidance for Codex
- prompt library in `prompts\`
  - reusable wording for controller changes, hardening, recovery, and self-check
- `portable-kit\`
  - copied docs/assets meant to move to another machine or another AI setup

## Repository mapping
- `psc-sre-automacao-controller`
  - source code, release-version files, and GitHub Actions monitoring
  - web URL: `https://github.com/<OWNER>/psc-sre-automacao-controller`
  - clone URL: `https://github.com/<OWNER>/psc-sre-automacao-controller.git`
- `deploy-psc-sre-automacao-controller`
  - deploy promotion through `cloud/homologacao` and `values.yaml`
  - web URL: `https://github.com/<OWNER>/deploy-psc-sre-automacao-controller`
  - clone URL: `https://github.com/<OWNER>/deploy-psc-sre-automacao-controller.git`

If the URLs change, treat that as a configuration change. Do not ask the user to reclone the repos manually; update the mapped clone URL and refresh the managed cache.

## What to update for common changes
### Change controller repo URL or controller web link
- `autopilot-manifest.json`: `controller.repoUrl`, `controller.webUrl`
- `controller-release-autopilot.json`: matching controller fields
- `docs\repository-map.md`, `docs\flow-overview.md`, `docs\configuration-map.md`
- `prompts\controller-change-superprompt.md`
- `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\AGENTS.md`
- local skill if the description mentions the old repo
- portable kit copy

### Change deploy repo URL, branch, or web link
- `autopilot-manifest.json`: `deploy.repoUrl`, `deploy.webUrl`, `deploy.branch`
- `controller-release-autopilot.json`
- docs: this file, `docs\repository-map.md`, and `docs\flow-overview.md`
- prompt library if wording mentions the old environment
- portable kit copy

### Change token location or persistence home
- `autopilot-manifest.json`: relevant `paths.*`
- `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\AGENTS.md`
- env vars `BB_DEVOPS_AUTOPILOT_HOME` and `BB_DEVOPS_AUTOPILOT_MANIFEST`
- repair script if it rewrites these values
- portable kit copy

### Change branch policy or versioning rule
- `autopilot-manifest.json`: `policy.*`
- `controller-release-autopilot.json`
- docs and prompt library
- local skill instructions
- portable kit copy

### Change the CI probe branch prefix, probe count, or evidence paths
- `autopilot-manifest.json`: `policy.ciFailureProbesUseTemporaryBranches`, `policy.ciFailureProbeMaxTests`, `commands.preflightControllerCi`, `commands.runControllerCiFailureProbes`, `paths.ciFailureProbes`, `docs.ciFailureProbes`
- `controller-release-autopilot.json`: `ciFailureProbes.*`
- `docs\ci-failure-probes.md`, `docs\runbook.md`, `README.md`
- portable kit copy

### Change the default completion point of the release flow
- `autopilot-manifest.json`
- `controller-release-autopilot.json`
- `controller-release-autopilot.ps1`
- `README.md`
- `docs\flow-overview.md`
- `docs\configuration-map.md`
- `prompts\controller-change-superprompt.md`
- `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\AGENTS.md`
- local skill instructions
- portable kit copy
