---
name: incident-response
description: Resposta estruturada a incidentes no Autopilot e repos corporativos. Use quando houver falha em produção, CI/CD failure, degradação de serviço ou alerta crítico.
---

# Incident Response Skill

## Quando usar
- Falha em produção (controller ou agent down)
- CI/CD pipeline failure (esteira de build NPM)
- Deploy failure no `apply-source-change.yml`
- Alertas críticos de infraestrutura
- Lock de sessão não liberado
- Workspace em estado inconsistente

## Severidade

| Nível | Critério | SLA de Resposta |
|-------|---------|-----------------|
| P1 | Serviço em produção fora do ar | Imediato |
| P2 | Deploy bloqueado / CI falhando repetidamente | < 30 min |
| P3 | Degradação de funcionalidade / warning CI | < 2h |
| P4 | Melhoria / não urgente | Best effort |

## Fluxo de Resposta

### Fase 1: Identificação (< 5 min)
1. Identificar workspace afetado
2. Verificar estado atual:
   ```bash
   # Health do workspace
   gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/health.json?ref=autopilot-state" --jq '.content' | base64 -d
   
   # Deploy ativo?
   cat contracts/claude-live-status.json | jq '.activeDeploy'
   
   # Lock ativo?
   gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/locks/session-lock.json?ref=autopilot-state" --jq '.content' | base64 -d
   ```
3. Coletar logs de CI se disponível:
   ```
   state/workspaces/<ws_id>/ci-logs-<component>-<job_id>.txt
   ```

### Fase 2: Diagnóstico (< 10 min)
1. Formular hipóteses (por probabilidade)
2. Correlacionar timeline: último deploy ↔ primeiro erro
3. Checar erros comuns:
   | Erro | Causa | Fix |
   |------|-------|-----|
   | 403 push | Branch errada | Renomear para `copilot/*` ou `claude/*` |
   | Trigger não dispara | `run` não incrementado | Bumpar +1 |
   | Tag duplicate | Versão existe | Incrementar versão |
   | Lock preso | Workflow falhou | Rodar `workspace-lock-gc.yml` |
   | CI Gate falso positivo | Detection quebrado | Ler logs reais em `ci-logs-*.txt` |

### Fase 3: Mitigação (< 15 min)
1. Aplicar fix via deploy flow padrão se possível
2. Se lock preso: `gh workflow run workspace-lock-gc.yml`
3. Se CI falhando: disparar `fix-corporate-ci.yml`
4. Se fix não disponível: criar handoff para agente adequado

### Fase 4: Validação
1. Confirmar resolução com evidência objetiva
2. `ci-monitor-loop.yml` confirma CI passou
3. Health check retorna verde
4. Registrar em `contracts/claude-session-memory.json` → `knownFailures`

## Runbooks por Tipo

| Tipo | Runbook |
|------|---------|
| Incident genérico | `ops/runbooks/incidents/incident-response.json` |
| Pipeline failure | `ops/runbooks/pipelines/pipeline-troubleshooting.json` |
| K8s issues | `ops/runbooks/k8s/k8s-common-issues.json` |
| Terraform | `ops/runbooks/terraform/terraform-operations.json` |

## Formato de Relatório
```markdown
## Incidente: <título>
- Workspace: <ws_id>
- Componente: controller | agent
- Severidade: P1 | P2 | P3 | P4
- Status: Resolvido | Em investigação

### Causa Raiz
<evidência objetiva>

### Fix Aplicado
<o que foi feito>

### Validação
<evidência de resolução>

### Prevenção
<o que registrar em session memory para evitar recorrência>
```
