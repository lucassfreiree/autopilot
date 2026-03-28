---
applyTo: "state/**"
---

# State Management Instructions

## Fonte da Verdade

O branch `autopilot-state` contém o estado runtime do Autopilot. **Nunca editar diretamente** — workflows são responsáveis por todas as mutações.

## Estrutura de Estado por Workspace

```
state/workspaces/<workspace_id>/
  workspace.json              # Config do workspace (repos, branches, paths)
  controller-release-state.json
  agent-release-state.json
  health.json
  release-freeze.json         # Criado sob demanda
  locks/
    session-lock.json          # Lock de sessão multi-agente
    <operation>-lock.json      # Locks por operação (TTL)
  audit/
    <operation>-<timestamp>.json  # Entradas imutáveis de audit
  handoffs/                   # Fila de handoffs entre agentes
  improvements/               # Registros de melhoria
  metrics/
    YYYY-MM-DD.json            # Snapshots diários de métricas
```

## Workspaces Existentes

| Workspace | Empresa | Operável? |
|-----------|---------|-----------|
| `ws-default` | Getronics | ✅ Sim |
| `ws-cit` | CIT | ✅ Sim |
| `ws-socnew` | Terceiro | 🔴 **NÃO — bloqueado** |
| `ws-corp-1` | Terceiro | 🔴 **NÃO — bloqueado** |

**NUNCA ler, escrever ou modificar estado de `ws-socnew` ou `ws-corp-1` sem autorização explícita.**

## Locks (CRÍTICO)

### Antes de qualquer operação de estado:
```bash
# Verificar lock
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/locks/session-lock.json?ref=autopilot-state" \
  --jq '.content' | base64 -d | jq '{agentId: .agentId, expiresAt: .expiresAt}'

# Se agentId != "none" E expiresAt > now: PARAR → criar handoff
```

### Operações que requerem lock:
- Push para repos corporativos
- Modificar branch `autopilot-state`
- Promover CAP (values.yaml)
- Seed de workspace
- Backup/restore de estado
- Freeze/unfreeze de releases

### Operações sem lock:
- Ler workspace config
- Health check
- Ler audit/metrics

## Audit Trail

Toda mutação de estado deve ter audit entry:
```json
{
  "schemaVersion": 1,
  "timestamp": "2026-03-28T12:00:00Z",
  "agentId": "claude-code",
  "operation": "deploy",
  "workspace_id": "ws-default",
  "component": "controller",
  "version": "3.6.9",
  "result": "success",
  "details": {}
}
```

## Leitura de Estado
```bash
# Config do workspace
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/workspace.json?ref=autopilot-state" \
  --jq '.content' | base64 -d

# Estado de release
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/controller-release-state.json?ref=autopilot-state" \
  --jq '.content' | base64 -d

# Health
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/health.json?ref=autopilot-state" \
  --jq '.content' | base64 -d
```

## Regras Críticas
- NUNCA push direto para `autopilot-state` — apenas via workflows
- `workspace.json` deve ser atualizado tanto em `main` quanto em `autopilot-state`
- `schemaVersion` obrigatório em todos os objetos de estado
- Logs de CI ficam em `state/workspaces/<ws_id>/ci-logs-<component>-<job_id>.txt`
- `jq` sempre com fallback: `jq -r '.field // "default"' 2>/dev/null || echo ""`
