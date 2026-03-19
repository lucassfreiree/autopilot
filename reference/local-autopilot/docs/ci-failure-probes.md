# Controller CI Failure Probes

## Objective
Run controlled CI failures on temporary controller branches, monitor the GitHub Actions jobs and steps, and preserve evidence without touching `main`.

## Safety model
- Do not run probes on `main`.
- Use only temporary branches under `fix/autopilot-ci-probe-*`.
- Keep each probe isolated in its own git worktree under `cache\ci-failure-probes\worktrees`.
- Delete the remote branch after the workflow completes unless branch retention is explicitly required.
- The default probe set intentionally fails before any deploy continuation.

## Commands
- Probe runner:
  - `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\run-controller-ci-failure-probes.cmd`
- Local preflight:
  - `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\preflight-controller-ci.cmd`

## Local preflight prerequisites
- `preflight-controller-ci.cmd -InstallDependencies` requires the corporate npm registry to be reachable from the current machine.
- If `node_modules` exists but local tools such as `tsc`, `eslint`, or `jest` are missing, treat the dependency bootstrap as incomplete. The preflight now removes the partial bootstrap and retries with `npm ci`.
- If the corporate registry host is not resolvable, the preflight records the DNS failure, runs `npm cache verify`, and attempts `npm ci --offline --no-audit` once. If the local cache is insufficient, the preflight fails with the npm log paths in the error message and audit trail.

## Default probe set
1. `invalid-package-json`
2. `type-error`
3. `missing-module`
4. `failing-unit-test`

The runner also captures the latest successful `main` run as the control baseline for stage comparison.

## Evidence
- Audit trace:
  - `reports\audit\<trace>\`
- Probe reports:
  - `reports\ci-failure-probes\<timestamp-trace>\`
- Per probe:
  - `diff.patch`
  - `run.json`
  - `jobs.json`
  - `job-summary.json`
  - `summary.md`
  - `error-excerpts.txt`
  - `probe-result.json`

## Improvement loop
Use the probe report to decide which failures should be prevented locally before push. The default improvement path is:
1. Run `preflight-controller-ci.cmd`.
2. If `node_modules` is missing, bootstrap once with `preflight-controller-ci.cmd -InstallDependencies`.
3. Treat `run-controller-ci-failure-probes.cmd` as the regression suite whenever the GitHub Actions workflow, reusable workflow, build chain, or CI stage mapping changes materially.
