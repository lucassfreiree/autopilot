# Backup System Reference (Plan B)

## O que e

Sistema de backup completo do autopilot que opera **sem GitHub Actions**.
Replica as funcionalidades criticas do autopilot usando scripts shell + GitHub API/MCP tools diretamente.

## Onde esta

- **Repo**: `lucassfreiree/spark-dashboard`
- **Path**: `autopilot-backup/`
- **Branch**: `main`
- **Clone**: `git clone https://github.com/lucassfreiree/spark-dashboard.git`

## Quando usar

1. GitHub Actions indisponivel (minutos esgotados, conta com restricao, etc.)
2. Operacoes urgentes de release que nao podem esperar
3. Monitoramento de estado sem workflows
4. Diagnostico e recovery de falhas

## Capabilities

| Funcionalidade | Script | Status |
|---------------|--------|--------|
| Release Agent | `operations/release-agent.sh` | Validado E2E |
| Release Controller | `operations/release-controller.sh` | Validado E2E |
| Version Bump (0-9 rule) | `core/version-bump.sh` | Validado |
| CAP Promotion | `operations/promote-cap.sh` | Validado E2E |
| CI Monitoring | `operations/ci-status-check.sh` | Validado |
| State Management | `core/state-manager.sh` | Validado |
| Session Locks | `core/session-guard.sh` | Validado |
| Audit Trail | `core/audit-writer.sh` | Validado |
| Schema Validation | `core/schema-validator.sh` | Validado |
| Trigger System | `core/trigger-engine.sh` | Validado |
| Health Check | `operations/health-check.sh` | Implementado |
| Rule #0 Enforcement | `core/safe-commit.sh` | Validado |
| Orchestrator | `orchestrator.sh` | Implementado |

## Estrutura

```
autopilot-backup/
  config.json              # Configuracao central
  orchestrator.sh          # Entry point unico
  core/                    # 8 scripts do engine
  operations/              # 24+ scripts de operacoes
  contracts/               # Contratos de agentes
  schemas/                 # Schemas JSON
  triggers/                # Sistema de triggers local
  compliance/              # Regras de seguranca
  auth/                    # Autenticacao (PAT + OAuth)
  runbooks/                # Guias de recovery
```

## Como usar

### Entry point rapido
```bash
cd spark-dashboard/autopilot-backup
./orchestrator.sh health                          # Health check
./orchestrator.sh status ws-default               # Status atual
./orchestrator.sh release agent ws-default        # Release completo
./orchestrator.sh ci-check agent ws-default       # Verificar CI
./orchestrator.sh safe-msg validate "mensagem"    # Validar commit msg
```

### Pre-requisito: Token
```bash
export BBVINET_TOKEN="ghp_..."
# ou
bash auth/github-auth.sh setup-pat
```

## Historico de validacao

| Data | Operacao | Resultado |
|------|----------|-----------|
| 2026-04-07 | Release Agent 2.3.5 → 2.3.6 | CI 8/8, CAP promoted |
| 2026-04-07 | Release Controller 3.8.2 → 3.8.3 | CI 7/7, CAP promoted |
| 2026-04-07 | Testes unitarios (version-bump, schema, trigger) | 100% pass |

## Regra #0 — SIGILO CORPORATIVO

NUNCA mencionar autopilot, AI, Claude, ou automacao em repos corporativos (bbvinet/*).
O script `core/safe-commit.sh` valida mensagens de commit automaticamente.

## Relacao com o Autopilot

Este backup system **nao substitui** o autopilot — e um **fallback**.
Quando GitHub Actions estiver funcionando, usar o autopilot normalmente.
O backup system le/escreve no mesmo state branch (`autopilot-state`).
