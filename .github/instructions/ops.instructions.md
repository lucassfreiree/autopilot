---
applyTo: "ops/**"
---

# Ops Environment Instructions

Files in `ops/` provide the operational environment for DevOps, SRE, Cloud, and Automation tasks.

## Directory Structure

```
ops/
  scripts/         # Executable operational scripts by domain
    troubleshooting/diagnose.sh    # Universal diagnostics
    ci/analyze-pipeline.sh         # Pipeline analyzer
    ci/validate-patches-local.sh   # Pre-deploy patch validation
    k8s/cluster-health.sh          # K8s cluster health
    terraform/tf-ops.sh            # Terraform operations
    cloud/cloud-check.sh           # Cloud auth check
    monitoring/alert-check.sh      # Alert check
    utils/ops-logger.sh            # Operational logger
  runbooks/        # Operational SOPs
    incidents/incident-response.json
    pipelines/pipeline-troubleshooting.json
    k8s/k8s-common-issues.json
    terraform/terraform-operations.json
    cloud/cloud-operations.json
    monitoring/monitoring-setup.json
  templates/       # Reusable templates (CI, K8s, Terraform, monitoring)
  checklists/      # Operational checklists (deploy, new-environment, troubleshooting)
  docs/            # Operational documentation
    deploy-process/   # 12-phase deploy process guide
  config/          # Per-tool and per-workspace configuration
  logs/            # Auto-generated operational logs (gitignored)
```

## Script Usage

```bash
# Universal diagnostics
./ops/scripts/troubleshooting/diagnose.sh endpoint|pod|service|dns|node|system

# Pipeline analysis
./ops/scripts/ci/analyze-pipeline.sh github|gitlab|jenkins <args>

# Pre-deploy patch validation (fast, no npm required)
./ops/scripts/ci/validate-patches-local.sh

# K8s cluster health
./ops/scripts/k8s/cluster-health.sh [namespace|--all-namespaces]

# Terraform operations
./ops/scripts/terraform/tf-ops.sh plan|apply|validate|drift|fmt <path>

# Cloud auth check
./ops/scripts/cloud/cloud-check.sh aws|azure|gcp|all [resources]

# Alert check
./ops/scripts/monitoring/alert-check.sh datadog|grafana|prometheus|alertmanager
```

## Workspace Scope

Scripts in `ops/` are shared across all workspaces EXCEPT where a specific token is required:
- `ws-default` operations require `BBVINET_TOKEN` (Getronics corporate CI)
- `ws-cit` operations use `CIT_TOKEN` (when available)
- `ws-socnew` and `ws-corp-1` are **THIRD-PARTY** — scripts must not be run against these workspaces without explicit authorization

## Operational Logging

```bash
source ops/scripts/utils/ops-logger.sh
ops_log "action" "description" "result" "details"
ops_log_search "keyword"
ops_log_tail 20
```

Log file: `ops/logs/ops-log.jsonl` (gitignored — local only)

## Deploy Process Guide (12 phases)

For any corporate deployment, follow the 12-phase guide in `ops/docs/deploy-process/`:
| Phase | File |
|---|---|
| 01 | `01-overview-and-prerequisites.md` |
| 02 | `02-clone-and-setup.md` |
| 03 | `03-fetch-corporate-files.md` |
| 04 | `04-code-changes-and-patches.md` |
| 05 | `05-version-bump.md` |
| 06 | `06-configure-trigger.md` |
| 07 | `07-commit-push-pr-merge.md` |
| 08 | `08-monitor-autopilot-workflow.md` |
| 09 | `09-monitor-corporate-ci.md` |
| 10 | `10-cap-tag-promotion.md` |
| 11 | `11-diagnostics-and-troubleshooting.md` |
| 12 | `12-quick-reference.md` |

## Adding New Scripts

1. Place in the appropriate domain directory under `ops/scripts/`
2. Make executable: `chmod +x ops/scripts/<domain>/<script>.sh`
3. Source `ops-logger.sh` for structured logging
4. Use `set -euo pipefail` at the top of every bash script
5. Document in `ops/docs/automation-ops.md`
