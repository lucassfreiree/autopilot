---
applyTo: "**/*.ts,**/*.js,patches/**,contracts/**"
---

# Security Instructions

## Princípios Gerais
- Segurança por padrão (secure by default)
- Menor privilégio (principle of least privilege)
- Nunca expor secrets em logs, outputs ou commits
- Validar inputs antes de usar em qualquer operação

## Secrets e Credenciais

### Regras absolutas
- NUNCA hardcodar secrets, tokens ou senhas em código
- NUNCA logar valores de secrets (mesmo mascarados parcialmente)
- NUNCA commitar secrets (nem em histórico, nem em comentários)
- Tokens por workspace — nunca compartilhar entre ws-default, ws-cit e workspaces de terceiros

### Referência de secrets
```typescript
// CORRETO — referenciar por nome
const token = process.env.BBVINET_TOKEN;

// ERRADO — hardcoded
const token = "ghp_xxxxx";
```

## Autenticação JWT

### Regras de Claims
```typescript
// CORRETO — scope singular
const scope = payload.scope;

// ERRADO — scopes plural
const scopes = payload.scopes;  // NÃO existe no sistema
```

### Validação de input
```typescript
// CORRETO — validar input antes de usar
const id = parseSafeIdentifier(req.params.id);
const result = await fetch(`${baseUrl}/resource/${id}`);

// ERRADO — validateTrustedUrl dentro de helpers de fetch
async function postJson(url: string, data: unknown) {
  validateTrustedUrl(url);  // NÃO FAZER — quebra testes mock
  return fetch(url, { method: 'POST', body: JSON.stringify(data) });
}
```

## Sanitização de Output
```typescript
// SEMPRE sanitizar mensagens de erro expostas externamente
res.status(400).json({ error: sanitizeForOutput(err.message) });

// NUNCA expor stack traces ou detalhes internos
res.status(500).json({ error: err.stack });  // ERRADO
```

## Workflows do GitHub Actions

### Permissões mínimas
```yaml
permissions:
  contents: read  # mínimo necessário
  # adicionar apenas o que for estritamente necessário
```

### Secrets em workflows
```yaml
# CORRETO
env:
  TOKEN: ${{ secrets.BBVINET_TOKEN }}

# ERRADO — nunca expor valor
run: echo "Token is ${{ secrets.BBVINET_TOKEN }}"
```

### Actions de terceiros
- Sempre usar hash SHA para actions externas, não tags
- Auditar actions antes de usar

## Isolamento de Workspaces (Segurança)
- `ws-socnew` e `ws-corp-1` são de terceiros — NUNCA operar sem autorização explícita
- Cada workspace usa exclusivamente seu próprio token
- Dados corporativos NUNCA transitam entre workspaces
- Ver `workspace-isolation.instructions.md` para detalhes completos

## Swagger / OpenAPI
```json
// CORRETO — ASCII apenas
"description": "Callback de cronjob recebido pelo agente"

// ERRADO — acentos geram caracteres garbled
"description": "Callback de cronjob recebido pelo agente"
```

## IaC e Kubernetes
- Secrets do K8s nunca embutidos em manifests — usar `secretKeyRef`
- RBAC com permissões mínimas por serviceAccount
- Imagens em produção: digest fixo (`image@sha256:...`), não `:latest`
- Network policies: default deny, allowlist explícito
