# Repository Map

## Managed pair for controller work
When the user asks to change â€œthe controllerâ€, the autopilot must treat these two repositories as a fixed managed pair unless the user explicitly says otherwise.

### 1. Source controller repository
- Purpose: source code changes, release-version files, GitHub Actions monitoring
- Web URL: `https://github.com/<OWNER>/psc-sre-automacao-controller`
- Clone URL: `https://github.com/<OWNER>/psc-sre-automacao-controller.git`
- Canonical local clone: `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\repos\psc-sre-automacao-controller`
- Branch policy: always work on `main`
- Version files:
  - `package.json`
  - `package-lock.json`
  - `src\swagger\swagger.json`

### 2. Deploy repository
- Purpose: promote the same release version to homologaÃ§Ã£o by updating `deployment.containers.tag` in `values.yaml`
- Web URL: `https://github.com/<OWNER>/deploy-psc-sre-automacao-controller`
- Clone URL: `https://github.com/<OWNER>/deploy-psc-sre-automacao-controller.git`
- Cached local clone: `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\cache\deploy-psc-sre-automacao-controller`
- Branch policy: always update `cloud/homologacao`

## Important clarification
If a previous note or prompt swapped these meanings, the runtime mapping above is the correct one:
- the controller repo is the code/source-of-version repo
- the deploy repo is the `values.yaml` promotion repo

## Link changes
The MCAS/GitHub links may change over time. If the user asks to change them, update:
- `autopilot-manifest.json`
- `controller-release-autopilot.json`
- `docs\configuration-map.md`
- this file
- `docs\flow-overview.md`
- `prompts\controller-change-superprompt.md`
- `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\AGENTS.md`
- the local skill
- the portable kit

## Refresh command
Use `refresh-managed-repos.cmd` from the autopilot home to fetch, align, and reset both managed repositories without asking the user to clone anything into the workspace.
