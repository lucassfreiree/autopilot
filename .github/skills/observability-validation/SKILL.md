---
name: observability-validation
description: Validação de observabilidade para deploys e mudanças de infraestrutura. Use após deploys para confirmar que o sistema está saudável e monitorável.
---

# Observability Validation Skill

## Quando usar
- Após deploy via `apply-source-change.yml`
- Após promoção de CAP (values.yaml)
- Após mudanças de configuração em infraestrutura
- Durante investigação de incidentes (coletar sinais)
- Ao configurar novo workspace ou ambiente

## Fontes de Observabilidade

### Autopilot (control plane)
```bash
# Health do workspace
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/health.json?ref=autopilot-state" \
  --jq '.content' | base64 -d

# Estado de release
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/controller-release-state.json?ref=autopilot-state" \
  --jq '.content' | base64 -d

# Últimas entradas de audit (últimas 5 operações)
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/audit?ref=autopilot-state" \
  --jq '.[].name' | sort -r | head -5

# Resultado do CI monitor
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/ws-default/ci-monitor-controller.json?ref=autopilot-state" \
  --jq '.content' | base64 -d | jq '{ciOutcome: .ciOutcome, lastCheck: .lastCheck}'
```

### CI/CD (Getronics — ws-default)
```
state/workspaces/ws-default/ci-logs-controller-<job_id>.txt  ← logs do CI do controller
state/workspaces/ws-default/ci-logs-agent-<job_id>.txt       ← logs do CI do agent
state/workspaces/ws-default/ci-status-controller.json        ← status atual
```

### Workflows do GitHub Actions
```bash
# Últimas execuções de apply-source-change
gh run list --workflow=apply-source-change.yml --limit=5

# Últimas execuções de ci-monitor-loop
gh run list --workflow=ci-monitor-loop.yml --limit=5

# Status de um run específico
gh run view <run_id>
```

## Checklist Pós-Deploy

### Imediatamente após merge do PR de deploy
- [ ] `apply-source-change.yml` disparou (aguardar ~30s)
- [ ] Workflow aparece como `in_progress` ou `completed`
- [ ] Se `completed failure`: iniciar diagnóstico imediato

### Após `apply-source-change.yml` completar com sucesso
- [ ] Commit foi feito no repo corporativo (verificar SHA)
- [ ] `ci-monitor-loop.yml` foi disparado automaticamente
- [ ] Lock foi liberado (agentId = "none")

### Após CI Corporativo (Esteira de Build NPM)
- [ ] `ci-monitor-controller.json` → `ciOutcome: "success"`
- [ ] Docker image foi gerada no registry
- [ ] CAP foi promovido (values.yaml atualizado com nova tag)
- [ ] `controller-release-state.json` reflete nova versão

### Health Check Final
- [ ] `health.json` → status verde para workspace
- [ ] Audit trail tem entrada do deploy concluído
- [ ] Versão deployada refletida em `claude-session-memory.json`

## Workflows de Observabilidade
```bash
# Health check de workspace
gh workflow run health-check.yml -f workspace_id=<WS_ID>

# CI status check
# Editar trigger/ci-status.json com commit_sha e bumpar run

# Diagnose CI failure
# Editar trigger/ci-diagnose.json com commit_sha e bumpar run

# Alertas de monitoramento
gh workflow run ops-monitor-alerts.yml -f platform=datadog -f workspace_id=<WS_ID>
```

## Templates de Dashboard/Alertas
```
ops/templates/monitoring/prometheus-alerts-template.yml
ops/templates/monitoring/grafana-dashboard-template.json
```

## Sinais Verdes vs Vermelhos

| Sinal | Verde ✅ | Vermelho 🔴 |
|-------|---------|------------|
| `health.json` status | `healthy` | `degraded` / `unhealthy` |
| CI outcome | `success` | `failure` |
| Lock | `agentId: "none"` | agentId ativo + não expirado |
| Release state | versão atualizada | versão desatualizada |
| Audit trail | entrada recente | sem entradas recentes |
| CAP values.yaml | tag da nova versão | tag da versão antiga |
