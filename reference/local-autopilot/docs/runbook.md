# Recovery And Validation Runbook

## Validate
Run:
`<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\validate-autopilot.cmd`
`<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\test-controller-release-tooling.cmd`
`<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\preflight-controller-ci.cmd`

## Repair discovery layer
Run:
`<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\repair-autopilot.cmd`

## Recovery backup
- Backup zip: `<LOCAL_USER_HOME>\Downloads\BBDevOpsAutopilot-recovery-kit.zip`
- Restore launcher: `<LOCAL_USER_HOME>\Downloads\BBDevOpsAutopilot-restore-from-backup.cmd`
- The backup excludes the encrypted token by design. After restore, run `set-workspace-github-token.cmd` and save a fresh token.

## Typical recovery sequence
1. Restore from the recovery zip if the persistent directory was deleted.
2. Save a GitHub token again.
3. Validate the setup.
4. Inspect `state\controller-release-state.json` if the failure happened during an existing cycle.
5. Inspect the audit trace in `reports\audit` first, then inspect the subsystem reports in `reports\github-actions`.
6. Prepare `main` again.
7. Resume the release cycle with the same version if the cycle is recovering from CI failure.

## CI diagnostics drill
Run:
`<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\run-controller-ci-failure-probes.cmd`

Review:
- `reports\ci-failure-probes`
- `docs\ci-failure-probes.md`

If local preflight bootstrap fails before lint/test:
- review `reports\audit` for the latest `preflight-controller-ci` session
- confirm registry/DNS reachability for the corporate npm endpoint before retrying `-InstallDependencies`
- if `node_modules` was partial, trust the preflight cleanup and inspect the saved npm logs before retrying again by hand

Treat `run-controller-ci-failure-probes.cmd` as the standard regression check whenever the workflow YAML, reusable workflow, or CI build chain changes.

## If `AUTOMACAO` is deleted
Nothing operational should depend on that directory. Use the persistent autopilot home and the global `AGENTS.md` file.

## Audit evidence
- Primary trace root: `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\reports\audit`
- Audit model: `docs\auditability.md`
- Review checklist: `docs\audit-checklist.md`
- Handoff template: `docs\handoff-template.md`
