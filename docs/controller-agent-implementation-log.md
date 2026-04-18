# Log de Implementação — Controller & Agent (PSC SRE)

> **Escopo**: Este documento cobre **exclusivamente** mudanças no `psc-sre-automacao-controller` e `psc-sre-automacao-agent` dentro do fluxo de release da Esteira Corporativa (BBVINET). Qualquer alteração fora desse escopo é proibida neste repositório.

> **Workspace**: `ws-default` | Contexto: `GETRONICS → Banco do Brasil (BB)`

---

## Sessão 1 — 2026-04-02: Padronização de Rotas + Fix TS5107

### Problema identificado: inconsistência de rotas no Controller

Ao auditar o `patches/agentsRouter.ts` e o `patches/cronjob-result.controller.ts`, foi detectado que os endpoints de callback do cronjob do Agent estavam registrados com prefixo diferente do padrão da API:

| Endpoint | Prefixo usado | Padrão esperado |
|----------|--------------|------------------|
| `POST /api/cronjob/result` | `/api/cronjob/*` | `/agent/*` |
| `GET /api/cronjob/status/:execId` | `/api/cronjob/*` | `/agent/*` |

Todos os outros endpoints do controller seguiam o padrão `/agent/*` (ex: `/agent/execute`, `/agent/execute/logs`). Os endpoints do cronjob eram a exceção, quebrando a consistência.

### Solução implementada: padronização para `/agent/cronjob/*`

**Arquivos alterados:**

| Arquivo | Caminho corporativo | O que mudou |
|---------|-------------------|-------------|
| `patches/agentsRouter.ts` | `src/routes/agentsRouter.ts` | Rotas do cronjob movidas de `/api/cronjob/*` para `/agent/cronjob/*` |
| `patches/cronjob-result.controller.ts` | `src/controllers/cronjob-result.controller.ts` | Handler e referências internas atualizadas |
| `patches/controller-swagger.json` | `src/swagger/swagger.json` | Paths `/api/cronjob/*` substituídos por `/agent/cronjob/*` |
| `patches/cronjob-result.controller.test.ts` | `src/__tests__/unit/cronjob-result.controller.test.ts` | Testes atualizados com as novas rotas |

**Rotas finais após padronização:**

```
POST  /agent/cronjob/result       → receiveCronjobResult
GET   /agent/cronjob/status/:execId → getCronjobStatus
```

O router é montado em `app.use("/", agentsRouter)` — sem prefixo adicional — portanto as URLs completas são exatamente as acima.

### Como o deploy foi disparado

O mecanismo de deploy usa o arquivo `trigger/source-change.json` na branch `main`. Para disparar, Claude:

1. Lê o SHA atual do arquivo (`Github:get_file_contents` com `ref: refs/heads/main`)
2. Monta o payload com `component: "controller"`, `change_type: "multi-file"`, lista de `changes` e incrementa `run`
3. Faz `Github:create_or_update_file` com o SHA lido no passo 1 (obrigatório para evitar conflito)
4. O workflow `apply-source-change.yml` é triggerado automaticamente pelo push

**Trigger do run 87 — v3.7.9 (primeira tentativa):**

```json
{
  "component": "controller",
  "change_type": "multi-file",
  "version": "3.7.9",
  "changes": [
    { "action": "replace-file", "target_path": "src/routes/agentsRouter.ts", "content_ref": "patches/agentsRouter.ts" },
    { "action": "replace-file", "target_path": "src/controllers/cronjob-result.controller.ts", "content_ref": "patches/cronjob-result.controller.ts" },
    { "action": "replace-file", "target_path": "src/__tests__/unit/cronjob-result.controller.test.ts", "content_ref": "patches/cronjob-result.controller.test.ts" },
    { "action": "replace-file", "target_path": "src/swagger/swagger.json", "content_ref": "patches/controller-swagger.json" }
  ],
  "run": 87
}
```

### Falha detectada: TS5107 — erro de TypeScript no repo corporativo

O run 87 falhou na Esteira com `error TS5107`:

```
error TS5107: Option 'moduleResolution' value 'node10' is deprecated and
will stop functioning in TypeScript 6.0.
Use '--ignoreDeprecations 6.0' to silence this error.
```

**Root cause**: O TypeScript no repo corporativo foi atualizado para uma versão (5.6+) que passa a tratar `"moduleResolution": "node10"` como erro bloqueante. Esse erro **não foi causado pelos nossos patches** — existia previamente no `tsconfig.json` do corporativo.

**Fix aplicado no run 88:**

Adicionado `search-replace` no `tsconfig.json`:

```json
{
  "action": "search-replace",
  "target_path": "tsconfig.json",
  "search": "\"compilerOptions\": {",
  "replace": "\"compilerOptions\": { \"ignoreDeprecations\": \"6.0\","
}
```

Resultado no `tsconfig.json` corporativo:
```json
{
  "compilerOptions": { "ignoreDeprecations": "6.0", "moduleResolution": "node10", ... }
}
```

### Resultado do run 88

Monitorado via `state/workspaces/ws-default/controller-release-state.json` na branch `autopilot-state`:

```json
{
  "lastTag": "3.7.9",
  "ciResult": "failure",
  "preExistingFailure": true,
  "gateDecision": "pass-preexisting",
  "promoted": true,
  "status": "promoted-preexisting-ci-fail"
}
```

- `preExistingFailure: true` → o autopilot detectou que a falha CI existia **antes** do nosso commit
- `gateDecision: "pass-preexisting"` → promoção liberada mesmo com CI failing
- `promoted: true` → tag `3.7.9` chegou ao CAP (repo `bbvinet/psc_releases_cap_sre-aut-agent`)

### Run 89 — tentativa de fix `types: ["node"]`

O diagnóstico CI mostrou erros adicionais após o run 88:

```
TS2591: Cannot find name 'process' / 'Buffer'
TS2307: Cannot find module '@aws-sdk/client-s3'
```

A mensagem do TypeScript sugeria `"add 'node' to the types field in your tsconfig"`. O run 89 tentou aplicar isso.

**⚠️ Análise posterior identificou esse fix como potencialmente prejudicial:**

Ao verificar o `package.json` corporativo fetched (`state/workspaces/ws-default/fetched-controller-package.json`), confirmou-se que `@types/node: 22.1.0` já estava em `devDependencies`. Os erros `TS2591` no diagnóstico eram **falsos positivos** — causados pelo ambiente de diagnóstico que executa `tsc` sem `npm ci`, portanto sem os `node_modules` instalados.

Adicionar `"types": ["node"]` explicitamente no tsconfig restringiria a inclusão automática de tipos — poderia **quebrar** outros tipos que dependem do comportamento padrão (sem o campo `types` explícito, TypeScript inclui todos os `@types/*` automaticamente).

**Conclusão do run 89**: os erros `TS2591`/`TS2307` no ambiente de diagnóstico são falsos positivos e **não devem ser corrigidos via tsconfig**. O `@types/node` já está no `devDependencies` e funciona corretamente no build real da Esteira.

---

## Regras permanentes estabelecidas nessa sessão

As seguintes regras foram definidas e devem ser seguidas em **todas** as alterações futuras no controller e no agent:

### Regra 1 — Swagger sempre junto com mudanças de rota

> Sempre que uma rota for criada, renomeada ou removida no controller ou no agent, o arquivo `swagger.json` correspondente **deve ser atualizado no mesmo commit/trigger**.

- Controller: `patches/controller-swagger.json` → aplica em `src/swagger/swagger.json`
- Agent: `patches/agent-swagger.json` → aplica no swagger do agent

### Regra 2 — Testes unitários sempre junto com mudanças de controller

> Sempre que um controller for criado ou alterado, os testes unitários correspondentes **devem ser criados ou atualizados no mesmo commit/trigger**.

- Testes ficam em `patches/[nome-do-controller].test.ts`
- São aplicados em `src/__tests__/unit/[nome-do-controller].test.ts`

---

## Sessão 2 — 2026-04-16 (quinta-feira): Esclarecimento de Arquitetura — Dispatch vs Túnel

### Questão levantada

Dúvida sobre se o mecanismo de `dispatch` do autopilot funcionaria como um túnel reverso para a máquina local.

### Clarificação

**Dispatch (`workflow_dispatch` / `repository_dispatch`)** é **assíncrono e unidirecional**:

```
Claude/Usuário → push em trigger/source-change.json
                         ↓
               GitHub Actions runner executa o workflow
                         ↓
               Resultado gravado em autopilot-state branch
                         ↓
               Claude monitora via polling (GET /actions/runs/...)
```

Não há canal persistente, não há conexão reversa, não há dependência de máquina local. Isso é **intencional e correto** na arquitetura do BBDevOpsAutopilot.

**Túnel** seria algo como ngrok/Cloudflare Tunnel — conexão persistente e bidirecional. Isso quebraria a premissa de zero-dependência local.

### Implicação prática para o controller e agent

O ciclo de vida de um deploy corporativo via autopilot é sempre:

```
1. Claude prepara patches/    →  arquivos em patches/ no repo autopilot
2. Claude monta trigger       →  escreve trigger/source-change.json (run N)
3. Workflow executa           →  apply-source-change.yml aplica no repo corporativo
4. CI corporativa roda        →  Esteira de Build NPM (bbvinet)
5. Autopilot monitora         →  ci-monitor-loop.yml → ci-diagnose.yml
6. Estado salvo               →  controller-release-state.json na autopilot-state
7. Claude lê o resultado      →  Github:get_file_contents ref: autopilot-state
```

Nunca há interação direta Claude ↔ Esteira. Sempre via state machine no GitHub.

---

## Estado atual do controller (referência)

| Campo | Valor |
|-------|-------|
| `lastTag` | `3.8.3` |
| `ciResult` | `success` |
| `gateDecision` | `pass` |
| `promoted` | `true` |
| `updatedAt` | `2026-04-07T20:05:00Z` |
| `lastRun` | `104` |

As rotas `/agent/cronjob/*` estão no CAP desde a `3.7.9`. As versões subsequentes (`3.8.x`) foram bumps de versão e não alteraram as rotas do cronjob.

---

## Como monitorar um deploy após disparar

```markdown
# Checklist de monitoramento pós-trigger

1. Aguardar ~3-5 min após o push em trigger/source-change.json
2. Ler controller-release-state.json:
   GET lucassfreiree/autopilot/state/workspaces/ws-default/controller-release-state.json
   ref: refs/heads/autopilot-state
3. Interpretar status:
   - "promoted" + ciResult:"success"     → deploy limpo ✅
   - "promoted-preexisting-ci-fail"      → deploy ok, CI falhou por causa pré-existente ⚠️
   - "failed"                            → deploy bloqueado, ver ci-diagnosis-controller.json ❌
4. Se status "failed": ler ci-diagnosis-controller.json (pode levar 10-30min extra)
   ATENÇÃO: erros TS2591/TS2307 em arquivos do s3logger são falsos positivos no ambiente de diagnóstico
5. ci-status-controller.json tende a ficar desatualizado — priorizar controller-release-state.json
```

---

## Arquivos de referência no repositório

| Arquivo | Descrição |
|---------|-----------|
| `patches/agentsRouter.ts` | Roteador principal do controller — com rotas `/agent/cronjob/*` |
| `patches/cronjob-result.controller.ts` | Controller de callback do cronjob |
| `patches/cronjob-result.controller.test.ts` | Testes unitários do controller de cronjob |
| `patches/controller-swagger.json` | Swagger do controller com endpoints padronizados |
| `patches/tsconfig.json` | tsconfig com `ignoreDeprecations: "6.0"` |
| `trigger/source-change.json` | Último trigger disparado (run mais recente) |
| `state/workspaces/ws-default/controller-release-state.json` | Estado atual do release (branch autopilot-state) |
| `state/workspaces/ws-default/ci-diagnosis-controller.json` | Diagnóstico detalhado da CI (branch autopilot-state) |

---

*Documento gerado em 2026-04-18 a partir dos históricos de sessão do Claude.*
*Última revisão: Claude Sonnet 4.6 | Joao (lucassfreiree)*
