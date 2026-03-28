---
name: security-review-pr
description: Revisão de segurança de pull requests. Use antes de mergear PRs que envolvam código de aplicação, workflows, secrets, IaC ou configurações de workspace.
---

# Security Review PR Skill

## Quando usar
- Antes de mergear PRs com código TypeScript/JavaScript
- PRs que alteram workflows do GitHub Actions
- PRs que alteram configurações de secrets ou permissões
- PRs com patches para repos corporativos (`patches/`)
- PRs que alteram schemas ou contratos de agentes

## Checklist de Revisão

### 🔴 Crítico (bloquear PR se encontrado)

#### Secrets e Credenciais
- [ ] Nenhum secret, token, senha ou chave hardcodada
- [ ] Nenhum valor de secret em logs ou outputs de workflow
- [ ] Nenhum secret em variáveis de ambiente desnecessárias

#### Isolamento de Workspace
- [ ] `ws-socnew` e `ws-corp-1` não são operados sem autorização
- [ ] Workspace_id é sempre explícito (nunca hardcoded como `ws-default`)
- [ ] Tokens corretos por workspace (`BBVINET_TOKEN` → ws-default, `CIT_TOKEN` → ws-cit)

#### Autenticação
- [ ] JWT claims: `payload.scope` (singular), nunca `payload.scopes`
- [ ] `validateTrustedUrl` não está dentro de helpers de fetch/postJson
- [ ] `parseSafeIdentifier()` usado para inputs em rotas

### 🟡 Alto (corrigir antes de mergear)

#### Código
- [ ] Sem `eval()` ou execução dinâmica de código
- [ ] Sem `console.log` de dados sensíveis
- [ ] Inputs validados antes de uso em queries ou comandos shell
- [ ] `sanitizeForOutput()` em mensagens de erro expostas

#### Workflows
- [ ] Permissões mínimas no GITHUB_TOKEN
- [ ] Actions externas pinadas por SHA
- [ ] `pull_request_target` sem exposição de secrets para forks
- [ ] `set -euo pipefail` em todos os scripts bash

#### Swagger/OpenAPI
- [ ] Apenas caracteres ASCII (sem acentos, ç, ã, etc.)

### 🟢 Médio (registrar como finding, pode mergear)

#### IaC
- [ ] Secrets K8s referenciados, não embutidos
- [ ] RBAC com permissões mínimas
- [ ] Imagens com tag específica (não `:latest`)

#### Qualidade de Segurança
- [ ] Sem dependências novas com vulnerabilidades conhecidas
- [ ] Error messages não expõem stack trace em produção
- [ ] Logs suficientes para auditoria sem expor dados sensíveis

## Como executar

### Revisão manual
1. Ler diff do PR: `gh pr diff <number>`
2. Aplicar checklist acima
3. Registrar findings por severidade
4. Bloquear se encontrar itens críticos

### Revisão de workflow
```bash
# Verificar permissões de um workflow
grep -A5 "permissions:" .github/workflows/<file>.yml

# Verificar uso de secrets
grep -n "secrets\." .github/workflows/<file>.yml

# Verificar actions externas (devem ter @sha256: ou @v fixo)
grep -n "uses:" .github/workflows/<file>.yml | grep -v "@sha"
```

### Revisão de patch TypeScript
```bash
# Verificar padrões problemáticos
grep -n "validateTrustedUrl" patches/*.ts
grep -n "payload\.scopes" patches/*.ts
grep -n "console\.log" patches/*.ts
grep -n "[àáâãäçèéêëìíîïòóôõöùúûü]" patches/*.json  # acentos no swagger
```

## Output de Revisão
```markdown
## Security Review: PR #<number>

**Resultado:** ✅ Aprovado | ⚠️ Aprovado com ressalvas | 🔴 Bloqueado

### Findings Críticos
(lista de itens críticos encontrados)

### Findings Altos
(lista de itens altos encontrados)

### Findings Médios
(lista de itens médios — informativos)

### Recomendação
MERGEAR | CORRIGIR ANTES DE MERGEAR | BLOQUEAR
```
