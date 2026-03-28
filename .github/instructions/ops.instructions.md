---
applyTo: "ops/**"
---

# Ops Instructions

## Ambiente Operacional

O diretório `ops/` contém o ambiente operacional completo para DevOps/SRE/Cloud/Automation.

## Scripts Operacionais (`ops/scripts/`)

### Uso direto
```bash
# Diagnóstico universal
./ops/scripts/troubleshooting/diagnose.sh endpoint|pod|service|dns|node|system

# Análise de pipeline
./ops/scripts/ci/analyze-pipeline.sh github|gitlab|jenkins <args>

# Health de cluster K8s
./ops/scripts/k8s/cluster-health.sh [namespace|--all-namespaces]

# Operações Terraform
./ops/scripts/terraform/tf-ops.sh plan|apply|validate|drift|fmt <path>

# Check de acesso cloud
./ops/scripts/cloud/cloud-check.sh aws|azure|gcp|all [resources]

# Check de alertas
./ops/scripts/monitoring/alert-check.sh datadog|grafana|prometheus|alertmanager
```

### Logging operacional
```bash
# Log local (gitignored)
source ops/scripts/utils/ops-logger.sh
ops_log "action" "description" "result" "details"
ops_log_search "keyword"
ops_log_tail 20
```

## Runbooks (`ops/runbooks/`)

| Runbook | Quando usar |
|---------|-------------|
| `incidents/incident-response.json` | Qualquer incidente P1-P4 |
| `pipelines/pipeline-troubleshooting.json` | Falhas de CI/CD |
| `k8s/k8s-common-issues.json` | Problemas de container/pod |
| `terraform/terraform-operations.json` | State lock, drift, import |
| `cloud/cloud-operations.json` | AWS/Azure/GCP issues |
| `monitoring/monitoring-setup.json` | Setup de alertas e dashboards |

## Templates (`ops/templates/`)

Reutilizar templates existentes antes de criar novos:
```
ops/templates/ci/             # GitLab CI, GitHub Actions, Jenkinsfile
ops/templates/terraform/      # Módulos base, backend S3
ops/templates/k8s/            # Deployment production-ready
ops/templates/monitoring/     # Prometheus alerts, Grafana dashboards
```

## Checklists (`ops/checklists/`)

| Checklist | Quando usar |
|-----------|-------------|
| `deploy-checklist.json` | Antes/durante/depois de deploys |
| `new-environment.json` | Setup de novo ambiente |
| `troubleshooting-checklist.json` | Troubleshooting estruturado |

## Workflows Operacionais

| Workflow | Trigger | Uso |
|----------|---------|-----|
| `ops-cloud-diagnose.yml` | manual | Auth e recursos cloud |
| `ops-tf-plan.yml` | manual | Terraform plan/validate/drift |
| `ops-k8s-health.yml` | manual | Health de cluster K8s |
| `ops-monitor-alerts.yml` | manual + 6h schedule | Alertas ativos |
| `ops-pipeline-diagnose.yml` | manual | Falhas de pipeline |

## Regras de Qualidade
- SEMPRE usar runbooks existentes antes de improvisar procedimentos
- SEMPRE registrar operações no ops log (`ops/logs/ops-log.jsonl`)
- NUNCA usar `rm -rf` em produção sem dry-run documentado
- SEMPRE Terraform plan antes de apply
- SEMPRE checar custos antes de provisionar recursos cloud
- Scripts devem ser idempotentes quando possível

## Contexto Multi-Workspace
- Scripts ops são compartilhados entre workspaces
- Cada workspace tem config em `ops/config/workspaces/<ws_id>.json`
- Credenciais cloud são per-workspace — NUNCA misturar
- `ws-socnew` e `ws-corp-1`: NÃO executar ops sem autorização explícita

## Terraform
```
ops/terraform/environments/
  dev/         # Ambiente de desenvolvimento
  staging/     # Ambiente de staging
  production/  # Ambiente de produção
```
- Sempre `tf-ops.sh validate` + `tf-ops.sh plan` antes de `tf-ops.sh apply`
- State locking obrigatório (DynamoDB backend)
- Módulos reutilizáveis em `ops/templates/terraform/module-template/`
