---
applyTo: "schemas/**"
---

# Schemas Instructions

## Convenções de Schema JSON

### Estrutura obrigatória
Todo schema deve ter:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "NomeDoSchema",
  "description": "Descrição clara do propósito",
  "type": "object",
  "required": ["schemaVersion", ...],
  "properties": {
    "schemaVersion": {
      "type": "integer",
      "description": "Versão do schema para compatibilidade",
      "minimum": 1
    }
  }
}
```

### Campo `schemaVersion`
- OBRIGATÓRIO em todos os objetos de estado
- Tipo: inteiro (não string)
- Incrementar quando houver mudança breaking
- Manter para trás compatível quando possível

## Schemas Existentes

| Schema | Valida | SchemaVersion atual |
|--------|--------|---------------------|
| `release-state.schema.json` | Estado de release por workspace | 1 |
| `health-state.schema.json` | Resultado de health check | 1 |
| `lock.schema.json` | Locks de sessão e operação | 1 |
| `audit.schema.json` | Entradas de audit trail | 1 |
| `handoff.schema.json` | Items de handoff entre agentes | 1 |
| `workspace.schema.json` | Configuração de workspace | 1 |
| `metrics.schema.json` | Snapshots de métricas diários | 1 |
| `improvement.schema.json` | Registros de melhorias | 1 |
| `improvement-report.schema.json` | Relatórios de scans de melhoria | 1 |
| `release-freeze.schema.json` | Estado de freeze de releases | 1 |
| `approval.schema.json` | Aprovações de releases | 1 |

## Regras de Evolução de Schema

### Mudanças compatíveis (não incrementar schemaVersion)
- Adicionar campo opcional com `default`
- Adicionar novo valor a enum (se backward compatible)
- Relaxar validação de formato

### Mudanças breaking (incrementar schemaVersion + migrar objetos existentes)
- Remover campo obrigatório
- Renomear campo
- Mudar tipo de campo
- Tornar campo obrigatório

### Deprecação (preferir a remoção)
```json
"oldField": {
  "type": "string",
  "description": "DEPRECATED: use newField instead",
  "deprecated": true
}
```

## Validação
- Validar instâncias de estado contra schema antes de escrever
- Workflows devem usar `ajv` ou `jsonschema` para validação
- Instâncias inválidas devem ser rejeitadas com erro claro

## Localização de Estado
- Branch `autopilot-state` é a fonte da verdade
- Schemas ficam em `schemas/` no branch `main`
- Instâncias de estado ficam em `state/workspaces/<ws_id>/`
