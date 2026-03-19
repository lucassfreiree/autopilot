# BBDevOpsAutopilot

This directory is the persistent source of truth for the local controller release automation.

## What is stored here
- Installed scripts and wrappers
- Canonical controller clone on `main`
- Cached deploy clone on `cloud/homologacao`
- Encrypted GitHub token
- Release state
- GitHub Actions diagnostics
- Prompt library for controller-change and autopilot-maintenance requests
- Machine-readable manifest for future chat discovery
- Persistent docs with flow map, repository map, configuration map, portability guide, runbook, auditability guide, audit checklist, and handoff template
- Portable kit with copied docs, prompts, skill, runtime scripts, and bootstrap assets

## Safe deletion model
- `ai-devops-workspace` can be deleted.
- `<LOCAL_USER_HOME>\<CORPORATE_ONEDRIVE>\AUTOMACAO` can be emptied without breaking the installed autopilot.
- Deleting this directory breaks the installed autopilot and removes its state.

## Root launcher
- Use `<LOCAL_USER_HOME>\START.cmd` as the stable entry point in future chats or VS Code sessions.
- `START.cmd` sets the safe-root environment variables, runs validation by default, and exposes the main operational commands:
  - `START.cmd validate`
  - `START.cmd bootstrap`
  - `START.cmd release`
  - `START.cmd smoke`
  - `START.cmd preflight`
  - `START.cmd probes`
  - `START.cmd bundle`
  - `START.cmd docs`
  - `START.cmd efficiency`

## Managed repositories
- Controller source and release-version files:
  - web: `https://github.com/<OWNER>/psc-sre-automacao-controller`
  - clone: `https://github.com/<OWNER>/psc-sre-automacao-controller.git`
- Deploy promotion and `values.yaml` tag:
  - web: `https://github.com/<OWNER>/deploy-psc-sre-automacao-controller`
  - clone: `https://github.com/<OWNER>/deploy-psc-sre-automacao-controller.git`

If those links change, update the manifest, runtime config, docs, prompts, skill, and portable kit together.

## Standard release flow
1. Run `refresh-managed-repos.cmd` if you need both managed repos refreshed.
2. Run `prepare-controller-main.cmd`.
3. Edit code in `repos\psc-sre-automacao-controller`.
4. Run `controller-release-autopilot.cmd`.
5. The autopilot stops after promoting `cloud/homologacao` by updating `deployment.containers.tag` in `values.yaml`.
6. No cluster-side sync, pod restart, or remote execution is part of the default release flow.

## Autonomous bootstrap flow
- Run `bootstrap-controller-release-flow.cmd` when you want the autopilot to ensure the managed repositories are cloned/synchronized first and then continue into the normal controller release flow.
- This command operates from the persistent autopilot home and does not depend on the `AUTOMACAO` workspace contents.
- Optional flags:
  - `-RunPreflight`
  - `-InstallDependencies`
  - `-SkipMonitor`
  - `-SkipDeployUpdate`

## Controlled smoke test flow
- Run `run-controller-release-smoke-test.cmd` to generate a controlled change in `CHANGELOG.md` on the canonical controller clone and capture the diff in the audit trail.
- By default this command is a dry-run: it reverts the smoke patch after generating the evidence.
- Use `-ExecuteRelease` only when you intentionally want that controlled patch to enter the real release flow and reach the CI pipeline.

## Tooling test
- Run `test-controller-release-tooling.cmd` to validate the installed release tooling, manifest, portable kit export, and removal of unsupported subsystems without triggering a real release.

## Docs bundle
- Run `export-docs-bundle.cmd` to generate a transportable zip with docs, manifest, prompts, scripts, skill files, and discovery `AGENTS.md` references for configuring the flow in another AI or VS Code environment.
- The docs bundle intentionally excludes secrets, managed repository clones, and audit history.

## Complete handoff bundle
- Run `export-complete-handoff-bundle.cmd` to generate a fuller handoff zip with runtime scripts, config, docs, prompts, skill files, audit traces, CI probe reports, GitHub Actions reports, state snapshot, discovery files, and the portable kit.
- The complete handoff bundle still excludes secrets and managed repository clones by design.

## CI probe tooling
- Run `preflight-controller-ci.cmd` to catch package manifest, lint/typecheck, and Jest failures locally before pushing a fix or release cycle.
- Run `run-controller-ci-failure-probes.cmd` to launch controlled failures on temporary controller branches, capture GitHub Actions evidence, and map CI-stage behavior without touching `main`.
- Treat `run-controller-ci-failure-probes.cmd` as the regression suite whenever the pipeline YAML, reusable workflow, or CI build chain changes.

## Current policy
- Controller branch: `main`
- Deploy branch: `cloud/homologacao`
- First commit in a cycle bumps release version
- Corrective commits in the same failed cycle do not bump version again
- Monitor the full GitHub Actions run until completion
- The default completion point is the `values.yaml` tag update on `cloud/homologacao`

## Configuration awareness
If the user wants to change any URL, branch, repo, target environment, token location, or release-flow rule, update the manifest, runtime config, global discovery file, docs, prompt library, skill, and portable kit together.

## Audit trail
- Shared audit traces are written to `reports\audit` by the installed operational scripts, including `prepare-controller-main.ps1`, `refresh-managed-repos.ps1`, `controller-release-autopilot.ps1`, and `test-controller-release-tooling.ps1`.
- Managed Git history, `state\controller-release-state.json`, and GitHub Actions reports under `reports\github-actions` remain the primary evidence of what was actually released.
- Controlled CI probe evidence is written to `reports\ci-failure-probes`.

## Automatic efficiency routine
- Run `START.cmd efficiency` to audit token economy, disk usage, report retention, log rotation, and low-risk cleanup.
- Policy: `efficiency-policy.json`
- Latest report: `reports\efficiency\latest.md`
- State: `state\efficiency-state.json`
- The routine is conservative by default: it rotates oversized logs, trims shared event history, prunes empty directories, archives stale report directories after retention, and runs `git gc --auto` on managed repositories.
- It must not delete managed repository clones, secrets, active task state, or current release artifacts.

## Output expectation
A completed cycle should tell the operator what changed in the controller, which release version was used, which commit was pushed, what GitHub Actions concluded, whether `cloud/homologacao` was updated, and whether any autopilot configuration or docs changed.

## Recovery backup
- Recovery zip: `<LOCAL_USER_HOME>\Downloads\BBDevOpsAutopilot-recovery-kit.zip`
- Restore launcher: `<LOCAL_USER_HOME>\Downloads\BBDevOpsAutopilot-restore-from-backup.cmd`
- The recovery kit intentionally excludes the GitHub token. After restore, save a fresh token again.

## Discovery layers
- Global instructions: `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\AGENTS.md`
- Manifest: `autopilot-manifest.json`
- Prompt library: `prompts\`
- Persistent docs: `docs\`
- Portable kit: `portable-kit\`
- Local Codex skill: `bbdevops-controller-autopilot`

