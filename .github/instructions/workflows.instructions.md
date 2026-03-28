---
applyTo: ".github/workflows/**"
---

# Workflows Instructions

## Convenções Gerais

### Nomenclatura
- Arquivos: `kebab-case.yml`
- Nome do workflow: `[Categoria] Descrição: Detalhe`
- Categorias: `[Corp]`, `[Core]`, `[Release]`, `[Infra]`, `[Agent]`, `Ops:`

### Triggers
- Trigger files (preferred): editar `trigger/*.json` + bumpar campo `run`
- `workflow_dispatch`: para operações manuais
- `push`: apenas quando necessário e com path filters
- Schedule: formato cron UTC

## Estrutura Padrão
```yaml
name: "[Categoria] Nome do Workflow"

on:
  workflow_dispatch:
    inputs:
      workspace_id:
        description: "Workspace ID"
        required: true

jobs:
  main:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup
        run: |
          set -euo pipefail
          # ...
```

## Regras Críticas

### Workspace
- SEMPRE aceitar `workspace_id` como input em workflows que operam por workspace
- NUNCA hardcodar `ws-default` como padrão
- NUNCA operar `ws-socnew` ou `ws-corp-1` sem verificação explícita
- Identificar workspace pelo campo `_context` nos trigger files

### Secrets
- Usar apenas secrets definidos em repository secrets
- `BBVINET_TOKEN` → ws-default apenas
- `CIT_TOKEN` → ws-cit apenas
- `RELEASE_TOKEN` → operações de release e autopilot checkout
- Nunca logar valores de secrets

### Error Handling
```yaml
# SEMPRE usar set -euo pipefail
run: |
  set -euo pipefail
  
# SEMPRE usar fallback em jq
VALUE=$(echo "$JSON" | jq -r '.field // "default"' 2>/dev/null || echo "fallback")

# SEMPRE logar antes de continuar em erro não-fatal
echo "::warning ::Campo X ausente, usando default"

# SEMPRE usar ::error:: para falhas fatais
echo "::error ::Workspace ID não encontrado"
exit 1
```

### Idempotência
- Operações devem ser seguras para re-executar
- Verificar estado antes de mudar (ex: check lock antes de acquire)
- Usar `|| true` apenas com log anterior — nunca silenciosamente

### Estado e Locks
- Sempre adquirir lock via `session-guard.yml` antes de operações de estado
- Sempre liberar lock no final (mesmo em falha — usar `if: always()`)
- Audit entry obrigatório para toda mutação de estado
- Branch `autopilot-state` é a fonte da verdade

## Trigger Files
Cada trigger file em `trigger/` corresponde a um workflow:
```json
{
  "_context": "GETRONICS | ws-default | BBVINET_TOKEN",
  "workspace_id": "ws-default",
  "run": 67  // DEVE ser incrementado a cada disparo
}
```
- `run` sem incremento = workflow NÃO dispara
- `_context` identifica visualmente o workspace
- `commit_message` em source-change.json: sem prefixo de agente

## Workflows Auto-Gerados (NÃO editar diretamente)
- `.github/copilot-instructions.md` → editado por `sync-copilot-prompt.yml`
- `AGENTS.md` → editado por `sync-codex-prompt.yml`

## Monitoramento Automático
Após qualquer deploy via `apply-source-change.yml`:
1. `ci-monitor-loop.yml` dispara automaticamente
2. Poll a cada 2 min por 30 min
3. Se CI passou: `promote-cap.yml`
4. Se CI falhou: `ci-diagnose.yml` + `fix-corporate-ci.yml`
5. ZERO intervenção manual necessária
