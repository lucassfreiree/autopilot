---
applyTo: "state/**,trigger/**,contracts/**"
---

# Workspace Isolation Instructions

## REGRA ABSOLUTA: ISOLAMENTO TOTAL ENTRE WORKSPACES

Cada workspace representa uma empresa diferente. Dados, credenciais e operações NUNCA se misturam.

## Workspaces e Status

| Workspace | Empresa | Token | Status |
|-----------|---------|-------|--------|
| `ws-default` | Getronics | `BBVINET_TOKEN` | ✅ ATIVO |
| `ws-cit` | CIT | `CIT_TOKEN` | ✅ ATIVO |
| `ws-socnew` | **TERCEIRO (irmão do proprietário)** | N/A | 🔴 **BLOQUEADO** |
| `ws-corp-1` | **TERCEIRO** | N/A | 🔴 **BLOQUEADO** |

## `ws-socnew` e `ws-corp-1` — POLÍTICA DE BLOQUEIO

**Esses workspaces pertencem a terceiros (irmão do proprietário da conta).**

- NUNCA executar operações nesses workspaces sem **autorização EXPLÍCITA e ESCRITA** do proprietário da conta `lucassfreiree`
- NUNCA ler, escrever ou modificar `state/workspaces/ws-socnew/` ou `state/workspaces/ws-corp-1/`
- NUNCA usar os repos corporativos de `ws-socnew` ou `ws-corp-1`
- NUNCA executar workflows em nome desses workspaces
- Se um handoff ou trigger referenciar `ws-socnew` ou `ws-corp-1`: PARAR e alertar o proprietário

**Em caso de dúvida: não operar. Perguntar primeiro.**

## Identificação de Workspace (OBRIGATÓRIO antes de qualquer ação)

1. Checar `workspace_id` no trigger file ou contexto da conversa
2. Pistas linguísticas:
   - Getronics / controller / agent / NestJS / bbvinet / esteira / psc-sre → `ws-default`
   - CIT / DevOps / Terraform / K8s / cloud / monitoring / IaC → `ws-cit`
3. Ambíguo? → **PERGUNTAR ao usuário antes de prosseguir**

## Regras por Workspace

### ws-default (Getronics)
- Token: `BBVINET_TOKEN`
- Repos: `bbvinet/psc-sre-automacao-controller`, `bbvinet/psc-sre-automacao-agent`
- CAP: `bbvinet/psc_releases_cap_sre-aut-controller`, `bbvinet/psc_releases_cap_sre-aut-agent`
- Deploy: apenas via `apply-source-change.yml`
- CI: Esteira de Build NPM (runner corporativo)

### ws-cit (CIT)
- Token: `CIT_TOKEN`
- Stack: DevOps / K8s / Terraform / Cloud
- Operações iniciais: sem pipeline de deploy — foco em organização e tooling
- Scripts: `ops/scripts/`, runbooks: `ops/runbooks/`

## Proibições Absolutas
- NUNCA hardcodar `ws-default` como workspace "padrão" em código ou workflows
- NUNCA compartilhar secrets entre workspaces
- NUNCA fazer operação que afete dois workspaces simultaneamente
- NUNCA assumir que o contexto atual é de um workspace sem verificar
- NUNCA misturar logs, states ou audit trails de workspaces diferentes
