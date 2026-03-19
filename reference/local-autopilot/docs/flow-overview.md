# Flow Overview

## Objective
Automate the controller release cycle so the only manual input is the controller-change prompt.

## Managed repositories

### psc-sre-automacao-controller (GitHub Â· CI: GitHub Actions)
- Source: `https://github.com/<OWNER>/psc-sre-automacao-controller.git`
- Deploy: `https://github.com/<OWNER>/deploy-psc-sre-automacao-controller.git`
- Tasks: `state/agent-tasks.json` | Config: `controller-release-autopilot.json`
- Current: `3.4.0` | Next: `3.4.1`

### psc-sre-automacao-agent (GitHub Â· CI: GitHub Actions)
- Source: `https://github.com/<OWNER>/psc-sre-automacao-agent.git`
- CAP/Deploy: `https://github.com/<OWNER>/psc_releases_cap_sre-aut-agent.git`
  - Branch: `main` | File: `releases/openshift/hml/deploy/values.yaml`
  - Tag format: `image: <PRIVATE_REGISTRY>
  - CI: "Esteira PadrÃ£o" (`aic-chaplin-admin-workflows`) â€” dispara em push ao `main`
- Tasks: `state/agent-project-tasks.json` | Config: `agent-release-autopilot.json`
- Source version: `2.0.4` | Deployed hml: `2.0.4` (sincronizado) | Next: `2.0.5`
- Token: `secrets/github-token.secure.txt` (DPAPI)

When the user talks about â€œthe controllerâ€, assume the controller pair. â€œagentâ€ or â€œsre-agentâ€ â†’ agent pair. If ambiguous, ask.

**Versions are independent** â€” never synchronize version numbers between the two projects.

## Current fixed policy
- Controller repo branch: `main`
- Deploy repo branch: `cloud/homologacao`
- First commit of a cycle bumps release version
- Same-cycle fixes keep the same version
- Monitor the whole GitHub Actions run until `completed`
- The default completion point is the deploy promotion that updates `deployment.containers.tag` on `cloud/homologacao`

## End-to-end flow
1. Discover runtime settings from `autopilot-manifest.json`.
2. Refresh the managed repositories from their mapped clone URLs when needed.
3. Synchronize the canonical controller clone to `origin/main`.
4. Apply the requested controller change.
5. Bump release version on the first commit of the cycle.
6. Commit and push `main`.
7. Monitor the full GitHub Actions pipeline.
8. If CI fails, inspect logs, fix the problem, commit again on `main`, and push again without rebumping version.
9. When CI succeeds, update `deploy-psc-sre-automacao-controller` on `cloud/homologacao`, setting `deployment.containers.tag` to the same release version.
10. Persist state, reports, and diagnostics in the autopilot home.
11. End the release cycle at deploy promotion; cluster-side sync or pod orchestration is not part of the installed default flow.

## Configuration awareness
If a request changes any URL, branch, repo path, environment target, token location, deploy target, GitHub repo, or release-flow rule, update the full configuration surface consistently:
- `autopilot-manifest.json`
- `controller-release-autopilot.json`
- global `AGENTS.md`
- docs under `docs\`
- prompt library under `prompts\`
- local skill `bbdevops-controller-autopilot`
- portable kit under `portable-kit\`

## Output expectation
After a full cycle, report:
- what changed in the controller
- the release version used
- the pushed commit SHA
- the GitHub Actions result
- whether `cloud/homologacao` was updated
- whether the cycle completed at the deploy values promotion point
- whether any autopilot configuration or docs were updated

## Tooling verification
- Use `test-controller-release-tooling.cmd` to validate the installed runtime, manifest, validator, and portable export without performing a real controller release.
- Use `preflight-controller-ci.cmd` to run the local controller CI gate before pushing.
- Use `run-controller-ci-failure-probes.cmd` to study GitHub Actions behavior on temporary failing branches without touching `main`.

## Runtime directories
- Home: `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot`
- Controller clone: `repos\psc-sre-automacao-controller`
- Deploy clone cache: `cache\deploy-psc-sre-automacao-controller`
- Reports: `reports\github-actions`
- CI probe reports: `reports\ci-failure-probes`
- Audit reports for auxiliary maintenance tooling: `reports\audit`
- State: `state\controller-release-state.json`
- Prompt library: `prompts\`
- Persistent docs: `docs\`
- Portable export kit: `portable-kit\`
