# Protocolo de CoordenaÃ§Ã£o Multi-Agente

> **Aplica-se a: Claude Code Â· Codex Â· Gemini**
> Qualquer agente que atue no `psc-sre-automacao-controller` DEVE seguir este protocolo.
> **Objetivo**: evitar que dois agentes trabalhem na mesma tarefa, causando conflitos de git, versÃµes duplicadas ou trabalho redundante.

---

## 1. ANTES de qualquer aÃ§Ã£o no controller â€” checklist obrigatÃ³rio

```
[ ] 1. Ler state/agent-tasks.json
[ ] 2. Verificar se hÃ¡ tarefa ativa (activeTasks nÃ£o vazio)
[ ] 3. Verificar se a tarefa pedida pelo usuÃ¡rio jÃ¡ estÃ¡ em recentCompleted
[ ] 4. Confirmar versÃ£o atual (currentVersion) vs o que vocÃª vai fazer
[ ] 5. Sincronizar clone: git pull origin main + verificar HEAD
[ ] 6. Somente entÃ£o: reivindicar a tarefa e comeÃ§ar
```

---

## 2. Protocolo de verificaÃ§Ã£o de tarefa ativa

### 2a. Se `activeTasks` nÃ£o estiver vazio

**Regra principal â€” com exceÃ§Ã£o embutida:**

- Se `claimedAt` < 4 horas: informar o usuÃ¡rio `"Agente X ativo desde [timestamp]. Aguarde conclusÃ£o ou solicite cancelamento."` e parar.
- Se `claimedAt` â‰¥ 4 horas **E** nenhum commit recente nos Ãºltimos 30 min: assumir agente travado.
  1. Verificar no GitHub/GitLab se hÃ¡ commit recente do agente anterior.
  2. Se **nÃ£o houver commit**: sobrescrever `activeTasks` e prosseguir autonomamente.
  3. Se **houver commit**: aguardar CI terminar â€” timeout de **30 minutos**. Se nÃ£o concluir em 30 min: ler logs, informar usuÃ¡rio com diagnÃ³stico e oferecer retry ou abort.

### 2b. Verificar se a tarefa jÃ¡ foi feita (anti-duplicaÃ§Ã£o)

Antes de qualquer trabalho, comparar a descriÃ§Ã£o do pedido do usuÃ¡rio com `recentCompleted`:
- Se a tarefa foi completada nos **Ãºltimos 7 dias** E a versÃ£o estÃ¡ no main E nenhuma nota de "bloqueio", "parcial" ou erro: informar o usuÃ¡rio e NÃƒO reprocessar.
- Se a tarefa foi completada com `note` indicando falha, conflito ou estado parcial: **pode refazer**.
- Se a tarefa foi completada hÃ¡ **mais de 7 dias**: **pode refazer** (contexto diferente, nova sessÃ£o).

**Exemplo concreto (Gemini x Claude Code â€” 2026-03-17):**
```
UsuÃ¡rio pediu ao Gemini: "fixar Swagger UI com fundo escuro"
Gemini deve ler agent-tasks.json e ver:
  task-20260317-003: completedBy=claude-code, version=3.3.0, commit=504ec04
  description: "Fix Swagger UI contrast: opblock-summary..."
Gemini deve responder: "Esta tarefa foi concluÃ­da por Claude Code na versÃ£o 3.3.0
(commit 504ec04, deploy promovido). NÃ£o hÃ¡ nada a fazer."
```

---

## 3. Como reivindicar uma tarefa (claim)

Antes de comeÃ§ar qualquer trabalho, escrever em `state/agent-tasks.json`:

```json
{
  "activeTasks": [
    {
      "id": "task-YYYYMMDD-NNN",
      "claimedAt": "ISO-8601-timestamp",
      "claimedBy": "claude-code | codex | gemini",
      "status": "in_progress",
      "description": "O que serÃ¡ feito â€” suficientemente especÃ­fico para outro agente entender",
      "expectedVersion": "X.Y.Z",
      "estimatedFiles": ["lista de arquivos que serÃ£o alterados"]
    }
  ]
}
```

**Regra**: claim antes de qualquer edit, commit ou push. Nunca trabalhar sem claim.

---

## 4. Como liberar uma tarefa (release)

Ao concluir (CI green + values.yaml promovido), atualizar `agent-tasks.json`:

```json
{
  "activeTasks": [],
  "currentVersion": "X.Y.Z",
  "currentCommit": "SHA-curto",
  "deployedTag": "X.Y.Z",

  "recentCompleted": [
    {
      "id": "task-YYYYMMDD-NNN",
      "completedAt": "ISO-8601-timestamp",
      "completedBy": "nome-do-agente",
      "version": "X.Y.Z",
      "commitSha": "SHA-7-chars",
      "description": "O que foi feito",
      "filesChanged": ["lista"],
      "ciRunId": 12345,
      "ciConclusion": "success",
      "valuesYamlPromoted": true
    }
    /* manter somente os 5 mais recentes */
  ]
}
```

---

## 5. Como lidar com conflito de git

Se o push for rejeitado (non-fast-forward), significa que outro agente publicou enquanto vocÃª trabalhava:

```
1. git fetch origin main
2. Inspecionar os commits chegados: git log HEAD..origin/main --oneline
3. Verificar se os commits cobrem a mesma tarefa que vocÃª executou:
   - Se sim: sua versÃ£o Ã© redundante. Fazer git reset --hard origin/main, NÃƒO pushar.
             Atualizar agent-tasks.json informando que a tarefa jÃ¡ foi coberta.
   - Se nÃ£o (outro assunto): git rebase origin/main, resolver conflitos, pushar.
4. Nunca usar --force em main.
```

---

## 6. Regras de versionamento entre agentes

- **Nunca dois agentes fazem bump no mesmo ciclo sem coordenaÃ§Ã£o**
- Antes de bumpar: verificar `currentVersion` em `agent-tasks.json` e `package.json` no main
- A versÃ£o base para o prÃ³ximo agente Ã© sempre `currentVersion` + 1 patch
- Se `currentVersion` jÃ¡ foi aumentada por outro agente desde que vocÃª comeÃ§ou: rebase e use a versÃ£o atual + 1

---

## 7. Regras especÃ­ficas por arquivo sensÃ­vel

### `static/swagger-helmfire.css` e `static/swagger-helmfire.js`
- **ATENÃ‡ÃƒO: estes arquivos foram DELETADOS do repositÃ³rio** (a partir da versÃ£o 3.3.x).
- NÃ£o recriar, nÃ£o referenciar e nÃ£o tentar injetar temas via `customCss`/`customJs` no `server.ts`.
- O tema visual do Swagger UI Ã© controlado inteiramente pelo `src/swagger/swagger.json` e pelo CSS inline mÃ­nimo definido em `server.ts` (apenas oculta filtro de tag).
- Se encontrar referÃªncia a esses arquivos em cÃ³digo: remover como parte da tarefa em andamento.

### `src/swagger/swagger.json`
- DescriÃ§Ãµes devem estar em UTF-8 puro, sem U+FFFD (char 0xFFFD) e sem dupla-codificaÃ§Ã£o (ÃƒÂ§â†’Ã§)
- Antes de qualquer ediÃ§Ã£o de descriÃ§Ãµes: verificar encoding (ver agent-shared-learnings.md seÃ§Ã£o swagger.json)
- Bump de versÃ£o usa campo `"version":  "X.Y.Z"` com DOIS espaÃ§os antes do valor

### `package-lock.json`
- Usar **JSON estruturado** (Node.js `JSON.parse` / `jq`) â€” nunca regex global.
- Atualizar somente os campos `version` na raiz e em `packages[""]` (os dois primeiros `"version"` do arquivo).
- Nunca substituir a versÃ£o string globalmente â€” outras dependÃªncias podem ter o mesmo valor e seriam corrompidas.

---

## 8. Compatibilidade com o state file legado

O arquivo `state/controller-release-state.json` Ã© o state file do autopilot (usado pelo script `controller-release-autopilot.ps1`). O novo `state/agent-tasks.json` complementa â€” nÃ£o substitui â€” esse arquivo.

- `controller-release-state.json`: usado pelo script de automaÃ§Ã£o (stateful CI loop)
- `agent-tasks.json`: usado pelos agentes para coordenaÃ§Ã£o (anti-duplicaÃ§Ã£o, claim/release)

Ambos devem estar atualizados ao final de cada ciclo.

---

## 9. ResoluÃ§Ã£o autÃ´noma de conflitos

Aplicar nesta ordem **antes** de escalar ao usuÃ¡rio:

1. Aplicar Â§ 5 (git rebase â€” se non-fast-forward).
2. Se ambas as mudanÃ§as sÃ£o vÃ¡lidas e nÃ£o conflitam: fazer rebase + merge e prosseguir.
3. Se conflitam nos mesmos arquivos com intenÃ§Ãµes diferentes: aplicar **regra do mais seguro** â€” no-op > read-only > write. A mudanÃ§a menos destrutiva prevalece.
4. Se ainda ambÃ­guo apÃ³s as 3 etapas: documentar ambas as opÃ§Ãµes em `agent-shared-learnings.md` com contexto completo e **prosseguir com a opÃ§Ã£o mais segura**. Informar o usuÃ¡rio no final da sessÃ£o, nÃ£o bloquear o release.

**Escalar ao usuÃ¡rio apenas se**: nenhuma das 4 etapas resolve E a decisÃ£o envolve trade-off de negÃ³cio que sÃ³ o usuÃ¡rio pode fazer.

---

## 10. LocalizaÃ§Ã£o dos arquivos de coordenaÃ§Ã£o

### Projeto: psc-sre-automacao-controller

| Arquivo | PropÃ³sito |
|---------|-----------|
| `state/agent-tasks.json` | Registro ativo de tarefas (claim/release/completed) |
| `state/controller-release-state.json` | State do CI loop (script) |
| `controller-release-autopilot.json` | Config do release autopilot |
| `autopilot-manifest.json` | Fonte da verdade de caminhos e URLs |

### Projeto: psc-sre-automacao-agent

**RepositÃ³rio fonte**: `https://github.com/<OWNER>/psc-sre-automacao-agent.git` (GitHub)
**CI**: GitHub Actions â€” token em `secrets/github-token.secure.txt`
**CAP/Deploy repo**: GitHub (`psc_releases_cap_sre-aut-agent`, branch `cloud/homologacao`)
**Clone local CAP**: `cache/deploy-psc-sre-automacao-agent`

| Arquivo | PropÃ³sito |
|---------|-----------|
| `state/agent-project-tasks.json` | Registro ativo de tarefas do agent project |
| `state/agent-release-state.json` | State do CI loop do agent |
| `agent-release-autopilot.json` | Config do release autopilot do agent (ciProvider: github) |
| `autopilot-manifest-agent.json` | Fonte da verdade do agent project |

### Compartilhados por ambos os projetos

| Arquivo | PropÃ³sito |
|---------|-----------|
| `docs/agent-coordination-protocol.md` | Este documento |
| `docs/agent-shared-learnings.md` | Aprendizados tÃ©cnicos compartilhados |
| `secrets/github-token.secure.txt` | Token GitHub (DPAPI) â€” compartilhado |
| `docs/gemini-controller-release-guide.md` | Guia operacional para Gemini |

---

## 11. Como determinar qual projeto estÃ¡ sendo pedido

Antes de qualquer aÃ§Ã£o, identificar qual projeto o usuÃ¡rio quer trabalhar:

- Mencionou **controller**, **sre-controller**, **API controller** â†’ `psc-sre-automacao-controller`
  - Config: `controller-release-autopilot.json`
  - Tasks: `state/agent-tasks.json`
  - Clone: `repos/psc-sre-automacao-controller`

- Mencionou **agent**, **sre-agent**, **agente de execuÃ§Ã£o** â†’ `psc-sre-automacao-agent`
  - Config: `agent-release-autopilot.json`
  - Tasks: `state/agent-project-tasks.json`
  - Source clone: `repos/psc-sre-automacao-agent` (GitHub: `bbvinet/psc-sre-automacao-agent`)
  - CAP clone: `cache/deploy-psc-sre-automacao-agent` (GitHub: `bbvinet/psc_releases_cap_sre-aut-agent`)
  - CI: GitHub Actions (ciProvider: github)

**Quando ambiguidade**: perguntar ao usuÃ¡rio antes de agir.

### Regra de versionamento por projeto

Os dois projetos tÃªm versÃµes **independentes**:
- Controller: atualmente `3.4.0` (patch â†’ `3.4.1`, minor â†’ `3.5.0`)
- Agent: atualmente `2.0.4` (patch â†’ `2.0.5`, minor â†’ `2.1.0`)

Nunca sincronizar versÃµes entre projetos â€” cada um bump no prÃ³prio ciclo.
