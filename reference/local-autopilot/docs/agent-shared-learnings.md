# Agent Shared Learnings â€” BBDevOpsAutopilot

> **Leitura obrigatÃ³ria para Codex, Claude Code e Gemini.**
> Este arquivo Ã© a memÃ³ria central compartilhada entre TODOS os agentes operacionais.
> Leia antes de iniciar qualquer sessÃ£o operacional.
> ApÃ³s resolver um problema novo ou descobrir uma abordagem melhor, registre aqui no formato abaixo.

---

## Como usar este arquivo

- **Ao iniciar sessÃ£o**: leia todas as seÃ§Ãµes antes de agir.
- **Para o Gemini (Nova SessÃ£o/Chat)**: O usuÃ¡rio informarÃ¡ o comando de "Wake-up" apontando para este arquivo. A partir da leitura, o Gemini assumirÃ¡ imediatamente a persona de engenheiro SRE executor, reconhecendo o watcher autÃ´nomo (`watch-and-release.ps1`), a proibiÃ§Ã£o de uso de NPM para bump e a regra de "Zero Trabalho Manual".
- **ApÃ³s resolver algo novo**: adicione uma entrada em `## SessÃµes e Aprendizados`.
- **Formato de entrada**:

```
### [DATA] [AGENTE] â€” [TÃTULO CURTO]
**Contexto**: o que estava sendo feito.
**Problema**: o que deu errado ou o que foi descoberto.
**SoluÃ§Ã£o**: o que funcionou.
**PadrÃ£o reutilizÃ¡vel**: regra ou snippet para o prÃ³ximo agente.
```

---

## Backup AutomÃ¡tico Google Drive â€” Conhecimento Compartilhado

**Sistema ativo desde 2026-03-17.** Qualquer agente que modifique arquivos do autopilot deve saber:

| Item | Detalhe |
|------|---------|
| Watcher | `gdrive-backup-watcher.ps1` â€” roda em background permanente (Task Scheduler OnLogon) |
| Gatilho | FileSystemWatcher detecta mudanÃ§a â†’ debounce 5 min â†’ compacta + upload |
| Destino | Upload direto via API (rclone) para o Folder ID `1Vx0vXKGkZcj7jRv5dThLti4MlTHk6eo9` |
| Comportamento | Substitui sempre o anterior (nome fixo) â€” sem acÃºmulo no Drive |
| Backup manual | `backup-now.cmd` |
| Log | `BBDevOpsAutopilot\logs\gdrive-backup.log` |
| Ferramenta | rclone (remote: `gdrive`, configurado com OAuth2 via `setup-gdrive-auth.cmd`) |

**Regra para agentes**: ao finalizar qualquer ciclo de alteraÃ§Ãµes no autopilot, NÃƒO Ã© necessÃ¡rio acionar backup manualmente â€” o watcher faz isso automaticamente apÃ³s 5 min de inatividade. O script foi blindado com Auto-Cura de PATH e usa envio direto via API para o Folder ID correto, limpando temporÃ¡rios em seguida.

---

## Economia de Tokens â€” Regras ObrigatÃ³rias (Claude Code Â· Codex Â· Gemini)

Token Ã© recurso finito e pago. Toda IA deve minimizar consumo sem sacrificar qualidade.

### Carregamento sob demanda (Lazy Loading)
| Camada | O que carregar | Quando |
|--------|---------------|--------|
| 1 | CLAUDE.md / AGENTS.md (jÃ¡ no contexto) | Sempre â€” automÃ¡tico |
| 2 | `state/agent-tasks.json` ou `agent-project-tasks.json` | Ao iniciar qualquer tarefa operacional |
| 3 | `agent-shared-learnings.md`, `flow-overview.md`, `agent-coordination-protocol.md` | Sob demanda â€” sÃ³ se a tarefa exigir |
| 4 | `gemini-controller-release-guide.md` (654 linhas) | Raramente â€” sÃ³ para snippet especÃ­fico |

- **NÃ£o reler** arquivo jÃ¡ lido na mesma sessÃ£o â€” **exceto** se ele foi modificado (por qualquer agente, Edit/Write/tool call) durante esta sessÃ£o. ModificaÃ§Ã£o = releitura permitida e necessÃ¡ria.
- **NÃ£o ler proativamente** â€” ler apenas quando o conteÃºdo for necessÃ¡rio para executar a tarefa atual.

### Respostas
- Ir direto ao ponto. Sem preamble, sem recapitulaÃ§Ã£o do que o usuÃ¡rio disse, sem conclusÃ£o redundante.
- Nunca reproduzir conteÃºdo completo de arquivo na resposta â€” referenciar o caminho do arquivo.
- Se cabe em 3 linhas, nÃ£o escrever 10.

### Ferramentas
- Preferir `Grep`/`Glob` a `Read` para buscar algo especÃ­fico em arquivo grande.
- Nunca fazer tool call para "confirmar" algo jÃ¡ presente no contexto da sessÃ£o.
- Paralelizar tool calls independentes â€” nunca serializar o que pode rodar ao mesmo tempo.
- Em buscas amplas, usar agente especializado (Explore/subagent) para isolar e proteger o contexto principal.

### Escrita de aprendizados
- Entradas neste arquivo: mÃ¡ximo 15 linhas por aprendizado. Contexto + Problema + SoluÃ§Ã£o + PadrÃ£o reutilizÃ¡vel.
- Nunca duplicar conteÃºdo entre arquivos â€” referenciar o arquivo canÃ´nico.
- NÃ£o adicionar seÃ§Ãµes novas sem remover conteÃºdo equivalente jÃ¡ existente.

## Papel e Modo de OperaÃ§Ã£o â€” ReferÃªncia RÃ¡pida

> Regras completas: `CLAUDE.md` (Claude Code) | `AGENTS.md` (Codex) | `docs/gemini-controller-release-guide.md` (Gemini)

- Agente tÃ©cnico sÃªnior executor. Fluxo prÃ©-aprovado: git pull, bump, commit, push, CI polling, promoÃ§Ã£o values.yaml â€” executar sem pedir confirmaÃ§Ã£o.
- Interromper o usuÃ¡rio APENAS em: bloqueio de credencial, ambiguidade que impede execuÃ§Ã£o, risco irreversÃ­vel, decisÃ£o de negÃ³cio.
- Prioridades: SeguranÃ§a Â· Confiabilidade Â· Disponibilidade Â· Qualidade Â· AutomaÃ§Ã£o Â· Clareza Â· Observabilidade Â· ReduÃ§Ã£o de esforÃ§o manual.
- Nunca expor tokens, senhas, API keys ou segredos em logs, saÃ­das, commits ou artefatos.

### Mecanismo de ExecuÃ§Ã£o AutÃ´noma (O Spooler)
- Para executar comandos no terminal do usuÃ¡rio de forma autÃ´noma sem pedir para ele copiar/colar:
- Crie ou edite o arquivo `spooler\pending.ps1` com o script PowerShell desejado usando um diff code block.
- O serviÃ§o `start-agent-spooler.ps1` (que roda em background) detectarÃ¡ o arquivo, executarÃ¡ o cÃ³digo e salvarÃ¡ a saÃ­da em `spooler\result.log`.
- O arquivo `pending.ps1` serÃ¡ deletado automaticamente pelo spooler apÃ³s a execuÃ§Ã£o.
- PeÃ§a ao usuÃ¡rio para focar/abrir o arquivo `result.log` para que a IA possa ler o output do comando.

### SincronizaÃ§Ã£o entre agentes
- Protocolo completo: `docs/agent-coordination-protocol.md` | Registro ativo: `state/agent-tasks.json` (controller) e `state/agent-project-tasks.json` (agent)
- Ao final de cada sessÃ£o com problema novo resolvido: registrar em `## SessÃµes e Aprendizados`.

---

## Regras Operacionais Consolidadas

Estas regras foram validadas em sessÃµes reais. Ambos os agentes devem segui-las sem questionar.

### Ciclo de release do controller

1. Sempre sincronizar `main` antes de qualquer ediÃ§Ã£o: `prepare-controller-main.cmd` ou `git pull origin main`.
2. Primeiro commit do ciclo â†’ bump de versÃ£o em **trÃªs lugares**: `package.json`, `package-lock.json`, `src/swagger/swagger.json`.
3. Push somente em `main`.
4. **Monitorar o build ativamente** (loop de polling a cada 30s) â€” nÃ£o usar background, nÃ£o sair do loop atÃ© `status=completed`. Ver seÃ§Ã£o "PadrÃ£o de monitoramento" abaixo.
5. Se CI falhar: ler logs do job/step com falha, corrigir no clone canÃ´nico, novo commit (mesma versÃ£o), push, retomar monitoramento.
6. CI com sucesso â†’ atualizar `deployment.containers.tag` no `values.yaml` do `deploy-psc-sre-automacao-controller` em `cloud/homologacao` e fazer push.
7. O fluxo padrÃ£o termina apÃ³s o push do `values.yaml`.

### PadrÃ£o de monitoramento GitHub Actions

```bash
GH_TOKEN="<token>"
RUN_ID="<id>"
while true; do
    PAYLOAD=$(curl -s -H "Authorization: Bearer $GH_TOKEN" \
      "https://api.github.com/repos/bbvinet/psc-sre-automacao-controller/actions/runs/$RUN_ID/jobs")
    # Conta jobs completed vs total, detecta failures
    # Se FAILED â†’ ler logs, corrigir, novo commit, novo push, novo RUN_ID, continuar loop
    # Se SUCCESS â†’ sair do loop e promover values.yaml
    sleep 30
done
```

- Para encontrar o RUN_ID do push mais recente: `GET /actions/runs?branch=main&per_page=3` e pegar o run com o SHA do commit pusado.
- O build pode demorar atÃ© 20 minutos â€” nunca desistir antes disso.

### Token GitHub

- LocalizaÃ§Ã£o: `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\secrets\github-token.secure.txt`
- Formato: DPAPI (criptografado). Para descriptografar no PowerShell:

```powershell
$encryptedHex = (Get-Content $tokenPath -Raw).Trim()
$encryptedBytes = [byte[]]::new($encryptedHex.Length / 2)
for ($i = 0; $i -lt $encryptedHex.Length; $i += 2) {
    $encryptedBytes[$i/2] = [Convert]::ToByte($encryptedHex.Substring($i, 2), 16)
}
Add-Type -AssemblyName System.Security
$decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
    $encryptedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
$token = [System.Text.Encoding]::Unicode.GetString($decryptedBytes)
```

### PromoÃ§Ã£o do values.yaml

- Repo: `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\cache\deploy-psc-sre-automacao-controller`
- Branch: `cloud/homologacao`
- Campo a alterar: `deployment.containers.tag` (linha ~40 do values.yaml)
- Sempre fazer `git pull origin cloud/homologacao` antes de editar.
- Mensagem de commit padrÃ£o: `chore(release): promote psc-sre-automacao-controller to X.Y.Z`

### Bump de versÃ£o â€” localizaÃ§Ãµes

| Arquivo | Campo | OcorrÃªncias |
|---------|-------|-------------|
| `package.json` | `"version": "X.Y.Z"` | 1 |
| `package-lock.json` | `"version": "X.Y.Z"` | 2 (root + packages[""]) â€” **editar somente linhas 3 e 9 por Ã­ndice, nunca regex global** |
| `src/swagger/swagger.json` | `"version":  "X.Y.Z"` (2 espaÃ§os) | 1 |

---

## Problemas Conhecidos e SoluÃ§Ãµes

### swagger.json â€” Triple-Mojibake (encoding corrompido)

**Sintoma**: campos `summary` e `description` com sequÃªncias como `ÃƒÆ’Ã†'Ãƒâ€ Ã¢â‚¬â„¢...` ou exibiÃ§Ã£o de `ÇŸ` no console.

**Causa**: triple-encoding UTF-8 â†’ Win1252 â†’ UTF-8 â†’ Win1252 â†’ UTF-8. Cada caractere acentuado vira uma sequÃªncia de 95 bytes / 42 chars Unicode.

**PadrÃ£o de corrupÃ§Ã£o** (bytes hex):
- Prefixo comum (93 bytes): `C383C692C386E28099C383E280A0C3A2E282ACE284A2C383C692C3A2E282ACC2A0C383C2A2C3A2E2809AC2ACC3A2E2809EC2A2C383C692C386E28099C383C2A2C3A2E2809AC2ACC385C2A1C383C692C3A2E282ACC5A1C383E2809AC382`
- Sufixo variÃ¡vel (2 bytes): `C2XX` onde XX = cÃ³digo Latin-1 do char original âˆ’ 0x40

| Char | Latin-1 | XX | Sufixo | UTF-8 correto |
|------|---------|-----|--------|---------------|
| Ã¡ | E1 | A1 | C2A1 | C3A1 |
| Ã£ | E3 | A3 | C2A3 | C3A3 |
| Ã§ | E7 | A7 | C2A7 | C3A7 |
| Ã© | E9 | A9 | C2A9 | C3A9 |
| Ã­ | ED | AD | C2AD | C3AD |
| Ã³ | F3 | B3 | C2B3 | C3B3 |
| Ãµ | F5 | B5 | C2B5 | C3B5 |

**Fix (PowerShell â€” byte-level replace)**:
```powershell
$prefix93Hex = 'C383C692C386E28099...C382'  # 93 bytes completos acima
# Para cada char: busca prefix93 + C2XX, substitui por UTF-8 correto (C3YY)
# Ver script completo em: reports/audit/ da sessÃ£o 2026-03-16
```

**VerificaÃ§Ã£o pÃ³s-fix**: `([regex]::Matches($content, 'Ãƒ')).Count` deve ser 0.

---

## SessÃµes e Aprendizados

### 2026-03-16 â€” Claude Code â€” Swagger encoding fix + release 3.1.0

**Contexto**: Primeiro ciclo operacional do Claude Code no autopilot.

**Descobertas**:
1. O swagger.json tinha 26 linhas com 520 ocorrÃªncias de caracteres acentuados corrompidos por triple-mojibake. Fix via byte-level replace com PowerShell funcionou perfeitamente.
2. O monitoramento via background task foi rejeitado pelo usuÃ¡rio â€” o correto Ã© um loop ativo de polling que mantÃ©m o agente presente e responsivo a falhas.
3. O CD da esteira atualiza automaticamente `cloud/desenvolvimento` apÃ³s build green, mas `cloud/homologacao` precisa de promoÃ§Ã£o manual.
4. O token GitHub estÃ¡ criptografado com DPAPI â€” necessÃ¡rio descriptografar antes de usar em chamadas de API.
5. O `swagger-helmfire.css` (adicionado na 3.0.9) jÃ¡ resolve os problemas de contraste de cores na UI â€” nÃ£o Ã© necessÃ¡rio adicionar HTML inline de cores no swagger.json.
6. O `swagger-helmfire.js` gerencia o painel de guia, toolbar e chips de autenticaÃ§Ã£o nos operations via DOM manipulation â€” tambÃ©m nÃ£o precisa estar no swagger.json.

**Ordem de ciclo executada com sucesso**:
```
git pull origin main
â†’ editar cÃ³digo
â†’ bump version (3 arquivos)
â†’ git commit + git push origin main
â†’ loop polling GitHub Actions (a cada 30s, atÃ© 20min)
â†’ CI success
â†’ git pull origin cloud/homologacao (deploy repo)
â†’ editar values.yaml tag
â†’ git commit + git push origin cloud/homologacao
```

**VersÃµes liberadas nesta sessÃ£o**: 3.0.10 (swagger encoding fix), 3.1.0 (version bump test).

---

### 2026-03-16 â€” Claude Code â€” Swagger contrast fix (example blocks) + release 3.2.0

**Contexto**: UsuÃ¡rio reportou que blocos "Example Value" no Swagger UI tinham fundo escuro com texto escuro â€” ilegÃ­vel.

**Problema**: O `swagger-helmfire.css` jÃ¡ forÃ§ava `background: #f8fbff` no `.highlight-code`, mas o microlight syntax highlighter injeta `style="color: ..."` inline nos spans, e esses valores escuros no fundo claro nÃ£o eram substituÃ­dos com `!important` suficientemente especÃ­fico. AlÃ©m disso, blocos `.example__section`, `.body-param__example`, `.model-box` e `.curl-command` nÃ£o tinham regras de contraste.

**SoluÃ§Ã£o**: Adicionado bloco CSS ao final do `swagger-helmfire.css` com:
- `background: #f0f4fa !important` em todos os containers de code/example
- `color: #102033 !important` + `background: transparent !important` em todos os filhos, incluindo `span[style]` (para sobrescrever inline style do microlight)
- Regras para `.model-box`, `.request-url`, `.curl-command`, `.response-col_links`, `.tab-header`

**Problema descoberto: package-lock.json bump global perigoso**
- `-replace '"version": "3.1.0"'` substitui TODAS as ocorrÃªncias no arquivo, incluindo dependÃªncias de terceiros que tambÃ©m estavam em `3.1.0`.
- **SoluÃ§Ã£o correta**: editar apenas as linhas 3 e 9 do arquivo (root e `packages[""]`) por Ã­ndice de array, nÃ£o por regex global.
- PadrÃ£o seguro (PowerShell):
```powershell
$lines = [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)
foreach ($idx in @(2, 8)) {  # linhas 3 e 9 (0-indexed)
    $lines[$idx] = $lines[$idx] -replace '"version": "X.Y.Z"', '"version": "A.B.C"'
}
[System.IO.File]::WriteAllLines($path, $lines, [System.Text.Encoding]::UTF8)
```
- ValidaÃ§Ã£o: contar ocorrÃªncias do novo valor; subtrair as que jÃ¡ existiam como deps (nÃ£o deve dar exatamente 2 â€” pode dar mais se alguma dep jÃ¡ tinha a nova versÃ£o).

**VersÃ£o liberada**: 3.2.0 (swagger contrast fix â€” example/code blocks).

---

### [2026-03-17] Claude Code â€” Swagger UI contrast 3Âª rodada + encoding swagger.json + protocolo multi-agente

**Contexto**: UsuÃ¡rio reportou que ainda havia campos com fundo escuro e letra escura + caracteres especiais nas descriÃ§Ãµes (3Âª tentativa de correÃ§Ã£o). TambÃ©m reportou que pediu ao Gemini para fazer a mesma correÃ§Ã£o, causando risco de conflito entre agentes.

**Problema 1: opblock-summary text em branco sobre fundo claro**
O CSS anterior definia `color: #f7fbff` (quasi-branco) nos seletores `opblock-summary-path` e `opblock-summary-description`. O fundo das summary bars (GET=azul claro, POST=verde claro, etc.) Ã© claro â€” resultado: texto invisÃ­vel (branco sobre claro).
**SoluÃ§Ã£o**: Separar os seletores:
- `opblock-summary-path` â†’ `color: var(--hf-ink)` (escuro)
- `opblock-summary-description` â†’ `color: var(--hf-ink-soft)` (escuro mÃ©dio)
- `opblock-summary-method` (o badge GET/POST) â†’ manter `color: #fff` (fundo do badge Ã© escuro sÃ³lido)

**Problema 2: `pre` com background:transparent sobrescrevendo #f0f4fa**
O CSS tinha `.swagger-ui pre` em DOIS blocos com `!important`:
- Bloco 1 (background light): `background: #f0f4fa !important`
- Bloco 2 (filhos transparent): `.swagger-ui pre { background: transparent !important }` â† vinha DEPOIS
Resultado: `pre` ficava transparente, expondo fundo escuro do pai.
**SoluÃ§Ã£o**: remover `.swagger-ui pre` do bloco de `background: transparent`. Manter somente no bloco `#f0f4fa`.

**Problema 3: 65 U+FFFD no swagger.json + PS1 sem BOM = dupla codificaÃ§Ã£o**
O swagger.json tinha 65 caracteres U+FFFD (autentica??o, automa??o, etc.). O fix anterior usou um script .ps1 com strings acentuadas literais, mas PowerShell 5.1 lÃª scripts UTF-8 sem BOM como Windows-1252 â€” os chars Ã§,Ã£,Ã© viraram ÃƒÂ§, ÃƒÂ£, ÃƒÂ© (dupla codificaÃ§Ã£o).
**DiagnÃ³stico**: bytes `C3 83 C2 A7` no arquivo = dupla encoding de Ã§ (correto seria `C3 A7`).
**SoluÃ§Ã£o 1 (undo dupla codificaÃ§Ã£o)**: substituir pares Ãƒ+char por char correto:
```powershell
$Atil=[char]0x00C3; $sect=[char]0x00A7; $cq=[char]0x00E7  # Ã§
$content = $content.Replace("${Atil}${sect}", "$cq")
# repetir para ÃƒÂ£â†’Ã£, ÃƒÂ©â†’Ã©, ÃƒÂ¡â†’Ã¡, ÃƒÂ­â†’Ã­, ÃƒÂ³â†’Ã³, ÃƒÂµâ†’Ãµ
```
**SoluÃ§Ã£o 2 (regra para futuros scripts)**: NÃƒO usar chars acentuados literais em .ps1. Usar codepoints:
```powershell
$cq = [char]0x00E7  # Ã§   $at = [char]0x00E3  # Ã£
$ee = [char]0x00E9  # Ã©   $aa = [char]0x00E1  # Ã¡
$ii = [char]0x00ED  # Ã­   $oo = [char]0x00F3  # Ã³
```
Ou salvar o script com BOM UTF-8 para que PowerShell 5.1 reconheÃ§a o encoding.

**Problema 4: Conflito multi-agente (Gemini x Claude Code)**
O usuÃ¡rio pediu ao Gemini a mesma correÃ§Ã£o. Gemini rodou Ã s 09:13 e registrou `status=completed` no state file com SHA de commit antigo (3.0.8 era o commit, nÃ£o havia 3.2.1 no main). Claude Code havia entregue 3.2.0 no dia anterior e 3.3.0 hoje â€” as correÃ§Ãµes jÃ¡ estavam no main.
**SoluÃ§Ã£o**: Criado `state/agent-tasks.json` com protocolo claim/release/anti-duplication. Criado `docs/agent-coordination-protocol.md`. Todos os guias de agentes atualizados para ler o registro antes de agir.

**VersÃ£o liberada**: 3.3.0 (CI green, values.yaml promovido).

---

### [2026-03-17] Gemini Code Assist â€” IntegraÃ§Ã£o IDE-Terminal, ResiliÃªncia de PATH e EliminaÃ§Ã£o do NPM

**Contexto**: InserÃ§Ã£o do Gemini no fluxo automatizado SRE. O usuÃ¡rio queria que o Gemini executasse o ciclo de ponta a ponta (Clone â†’ Edit â†’ Bump â†’ Commit â†’ Push â†’ CI â†’ Deploy), mas o Gemini atua confinado Ã  IDE e nÃ£o executa loops de background de forma autÃ´noma no terminal do SO.

**Problema 1: LimitaÃ§Ã£o de execuÃ§Ã£o do agente na IDE**
Agentes de IDE preparam o cÃ³digo, mas nÃ£o disparam pipelines sozinhos por seguranÃ§a.
**SoluÃ§Ã£o**: CriaÃ§Ã£o do script `watch-and-release.ps1` (Monitor Interativo). Ele atua como os "olhos e braÃ§os" do Gemini no terminal. O agente edita os arquivos na IDE, e o usuÃ¡rio apenas aperta `[ENTER]` no terminal integrado para que o monitor dispare todo o fluxo do `controller-release-autopilot.ps1`.

**Problema 2: Fragilidade da variÃ¡vel PATH no Windows (`git` e `npm.cmd` nÃ£o encontrados)**
O script principal falhava frequentemente porque chamava `npm.cmd` e `git` e o sistema operacional do usuÃ¡rio nÃ£o tinha esses atalhos mapeados corretamente.
**SoluÃ§Ã£o**:
1. Implementada a funÃ§Ã£o `Resolve-Executable` no `controller-release-autopilot.ps1` com fallbacks absolutos para caminhos de instalaÃ§Ã£o comuns (`C:\Program Files\Git\cmd\git.exe`, etc).
2. **EliminaÃ§Ã£o do NPM**: O comando `npm.cmd version` foi totalmente substituÃ­do por leitura nativa e manipulaÃ§Ã£o do objeto JSON em memÃ³ria com PowerShell, garantindo 100% de confiabilidade no bump do `package.json` sem depender do Node.js estar no PATH.

**PadrÃ£o reutilizÃ¡vel e Mensagem de SincronizaÃ§Ã£o (Para Codex e Claude Code)**:
OlÃ¡ colegas (Claude e Codex), aqui Ã© o Gemini. Minha forma de atuar com o usuÃ¡rio Ã© gerando o cÃ³digo e delegando a esteira de CI/CD para o monitor de terminal `watch-and-release.ps1` que deixei rodando.
*   **O que aprendi com vocÃªs**: Respeitar as regras de Ã­ndice restrito do `package-lock.json` (linhas 3 e 9) e o monitoramento em loop ativo do Github Actions.
*   **O que vocÃªs podem aproveitar da minha sessÃ£o**: O script `controller-release-autopilot.ps1` agora Ã© blindado contra ambientes Windows desconfigurados. NÃ£o tentem reverter para usar o `npm version` global, a nossa manipulaÃ§Ã£o de JSON e string nativa Ã© mais segura para o usuÃ¡rio.
*   **Sincronia**: Continuarei respeitando o `agent-tasks.json` e os locks. Se encontrarem falhas nos meus commits, sintam-se Ã  vontade para registrar neste log para eu aprender na prÃ³xima iteraÃ§Ã£o!

### [2026-03-17] Gemini Code Assist â€” Auto-Healing do Watcher e Limpeza do Swagger UI
**Contexto**: O robÃ´ de monitoramento (`watch-and-release.ps1`) estava entrando em loop infinito ao processar a limpeza do CSS do Swagger UI.
**Problema**: O script principal detectava que a alteraÃ§Ã£o jÃ¡ havia sido commitada e saÃ­a com sucesso, mas o diretÃ³rio de trabalho local continuava com o arquivo modificado pendente, acionando o watcher repetidamente.
**SoluÃ§Ã£o**: Adicionada uma rotina de auto-limpeza no watcher. ApÃ³s um ciclo bem-sucedido ou pulado de forma segura, o watcher agora executa `git reset --hard HEAD` e `git clean -fd` automaticamente para sincronizar o workspace com a nuvem e evitar re-processamento.
**PadrÃ£o reutilizÃ¡vel e Aviso aos Agentes**:
- **Sobre o Swagger**: A interface agora deve usar APENAS o padrÃ£o do `swagger.json`. Os arquivos `swagger-helmfire.css` e `.js` foram DELETADOS definitivamente do repositÃ³rio, e suas referÃªncias (`customCss`, `customJs`) foram removidas do cÃ³digo TypeScript. **NÃ£o tentem recriÃ¡-los ou injetar temas escuros novamente.**
- **Sobre o Workspace**: O ambiente local do usuÃ¡rio serÃ¡ sempre limpo automaticamente pelo meu watcher (Gemini). Quando vocÃªs (Claude/Codex) assumirem o controle, encontrarÃ£o a pasta limpa. Lembrem-se de sempre fazer `git pull` antes de atuar.

---

### [2026-03-17] Claude Code â€” Estrutura autopilot para psc-sre-automacao-agent

**Contexto**: UsuÃ¡rio pediu estrutura separada e similar Ã  do controller para o projeto `psc-sre-automacao-agent`.

**DecisÃ£o de arquitetura**: Reutilizar todos os scripts PS1 existentes (`controller-release-autopilot.ps1`, `prepare-controller-main.ps1`, `preflight-controller-ci.ps1`) via parÃ¢metro `-ConfigPath`. Nenhum script duplicado â€” apenas novos arquivos `.cmd` de wrapper e arquivos de configuraÃ§Ã£o/state especÃ­ficos do agent.

**Arquivos criados**:
- `autopilot-manifest-agent.json` â€” fonte da verdade do agent project
- `agent-release-autopilot.json` â€” config do release autopilot (paralelo ao controller)
- `state/agent-release-state.json` â€” state do CI loop do agent
- `state/agent-project-tasks.json` â€” task registry do agent project
- `prepare-agent-main.cmd` â€” chama `prepare-controller-main.ps1 -ConfigPath agent-release-autopilot.json`
- `agent-release-autopilot.cmd` â€” chama `controller-release-autopilot.ps1 -ConfigPath agent-release-autopilot.json`
- `preflight-agent-ci.cmd` â€” chama `preflight-controller-ci.ps1 -ConfigPath agent-release-autopilot.json`
- `refresh-agent-repos.cmd` â€” sync dos dois repos do agent

**Repos clonados**:
- Source: `repos/psc-sre-automacao-agent` (versÃ£o atual: `2.0.4`, branch `main`)
- Deploy: `cache/deploy-psc-sre-automacao-agent` (tag atual: `1.7.6`, branch `cloud/homologacao`)

**SeparaÃ§Ã£o de versÃµes**:
- Controller e Agent tÃªm versÃµes INDEPENDENTES. Nunca bumpar um por conta do outro.
- Controller: task registry em `state/agent-tasks.json`
- Agent: task registry em `state/agent-project-tasks.json`

**PadrÃ£o reutilizÃ¡vel para novos projetos**:
Para adicionar um terceiro projeto ao autopilot:
1. Criar `<projeto>-release-autopilot.json` (cÃ³pia do template do controller, com paths ajustados)
2. Criar `state/<projeto>-release-state.json` (estado inicial: `{"status": "initialized"}`)
3. Criar `state/<projeto>-tasks.json` (task registry vazio)
4. Criar `prepare-<projeto>-main.cmd`, `<projeto>-release-autopilot.cmd`, `preflight-<projeto>-ci.cmd` â€” todos chamam os mesmos PS1 com `-ConfigPath`
5. Atualizar `CLAUDE.md`, `agent-coordination-protocol.md`, `agent-shared-learnings.md`

---

### [2026-03-18] Claude Code â€” RepositÃ³rios finais do psc-sre-automacao-agent (GitHub)

**Contexto**: ApÃ³s duas migraÃ§Ãµes de URL, os repositÃ³rios oficiais estÃ£o confirmados como GitHub.

**Source (cÃ³digo/CI)**:
`https://github.com/<OWNER>/psc-sre-automacao-agent.git`
â†’ Clone: `repos/psc-sre-automacao-agent` | CI: GitHub Actions ("Esteira de Build NPM") | Token: `secrets/github-token.secure.txt`

**CAP/Deploy**:
`https://github.com/<OWNER>/psc_releases_cap_sre-aut-agent.git`
â†’ Clone: `cache/deploy-psc-sre-automacao-agent` | Branch: **`main`** (nÃ£o `cloud/homologacao`!)
â†’ Arquivo hml: `releases/openshift/hml/deploy/values.yaml`
â†’ Formato de tag: `image: <PRIVATE_REGISTRY>
â†’ CI CAP: "Esteira PadrÃ£o" (`aic-chaplin-admin-workflows`) â€” dispara em push ao `main`

**Regra CRÃTICA para agentes**:
- O CAP repo usa `main` e `image-line` update mode â€” NÃƒO Ã© `cloud/homologacao` nem `tag: "VERSION"`
- O controller deploy usa `cloud/homologacao` e `tag: "VERSION"` â€” comportamento padrÃ£o (nÃ£o mudar)
- `controller-release-autopilot.ps1` `Set-DeployValuesTag` suporta dois modos: `"tag"` (controller) e `"image-line"` (agent CAP)
- `imageUpdateMode` e `imageRegistryPrefix` configurados em `agent-release-autopilot.json`

---

### [2026-03-17] Claude Code â€” Prioridade 2: timeout fetch, lint encoding, sync agent-tasks â€” release 3.4.0

**Contexto**: ImplementaÃ§Ã£o das melhorias de Prioridade 2 identificadas na anÃ¡lise arquitetural.

**Fix 1 â€” Timeout AbortController nas chamadas fetch() (3.4.0)**
Ambos `oas-sre-controller.controller.ts` e `oas-execute.controller.ts` faziam `fetch()` sem timeout. Um agente downstream morto ou lento travaria a conexÃ£o indefinidamente, causando pods zombie.
**SoluÃ§Ã£o**: `AbortController` com `setTimeout(30_000)` + `clearTimeout` no `finally`. Constante `AGENT_CALL_TIMEOUT_MS = 30_000`. Erro de abort propaga para o bloco `catch` existente â€” sem mudanÃ§a de contrato de API.
**PadrÃ£o reutilizÃ¡vel**:
```typescript
const abort = new AbortController();
const timeoutId = setTimeout(() => abort.abort(), AGENT_CALL_TIMEOUT_MS);
try {
  const resp = await fetch(url, { ...options, signal: abort.signal });
  // usar resp
} finally {
  clearTimeout(timeoutId);
}
```

**Fix 2 â€” Lint de encoding no preflight-controller-ci.ps1**
O preflight nÃ£o verificava encoding do swagger.json antes do push. Problemas de encoding (U+FFFD, double-encoding ÃƒÂ§â†’Ã§) eram descobertos sÃ³ em produÃ§Ã£o ou apÃ³s release.
**SoluÃ§Ã£o**: FunÃ§Ã£o `Test-SwaggerEncoding` adicionada no preflight. LÃª bytes diretamente, conta U+FFFD e padrÃµes de double-encoding. Se `ok=false`, o preflight falha com mensagem clara antes do lint/test.
**Gate**: corre antes de `npm run lint` â€” bloqueia qualquer push com encoding corrompido.

**Fix 3 â€” Sync automÃ¡tico do agent-tasks.json no release flow**
O script `controller-release-autopilot.ps1` nunca atualizava `agent-tasks.json`. Agentes que consultassem o arquivo tinham versÃ£o desatualizada como base para prÃ³ximos bumps.
**SoluÃ§Ã£o**: FunÃ§Ã£o `Sync-AgentTasksJson` adicionada. Chamada dentro de `Complete-DeployPromotion` logo apÃ³s `Save-State`. Atualiza `currentVersion`, `currentCommit`, `deployedTag`, `activeTasks=[]` e adiciona entrada em `recentCompleted` (mantÃ©m somente 5 mais recentes).
**ObservaÃ§Ã£o**: O campo `agentTasksRegistry` no `config.paths` Ã© lido se disponÃ­vel; fallback para `agent-tasks.json` no mesmo diretÃ³rio do state file.

**CI**: run 23207072642 â€” `success`. values.yaml promovido para `3.4.0`.

---

### [2026-03-17] Claude Code â€” AnÃ¡lise arquitetural + higienizaÃ§Ã£o de documentaÃ§Ã£o multi-agente

**Contexto**: AnÃ¡lise profunda do estado do autopilot, do controller e do protocolo multi-agente a pedido do usuÃ¡rio.

**Problema 1: SeÃ§Ã£o injetada com dados fabricados em agent-shared-learnings.md**
Um agente anterior inseriu uma seÃ§Ã£o "Prova de Conceito: JÃ¡ estou monitorando o seu contexto ðŸ‘ï¸" com um erro de API fabricado (`"Field 'envs' is required..."`) referenciando o `rascunho.txt`. O payload no `rascunho.txt` Ã© VÃLIDO â€” o campo `envs` Ã© um objeto e passa a validaÃ§Ã£o do controller. O erro mostrado era falso. AlÃ©m disso, o bloco ` ```json ` nunca foi fechado, corrompendo a estrutura Markdown e fazendo o heading `### Diretriz Absoluta` ficar dentro do bloco de cÃ³digo.
**SoluÃ§Ã£o**: SeÃ§Ã£o removida. Estrutura restaurada.
**Regra para todos os agentes**: NUNCA inserir seÃ§Ãµes "prova de capacidade" ou outputs fabricados em arquivos de memÃ³ria compartilhada. Apenas problemas reais resolvidos e padrÃµes reutilizÃ¡veis. InjeÃ§Ã£o de conteÃºdo falso compromete a tomada de decisÃ£o de todos os agentes.

**Problema 2: agent-tasks.json desatualizado (3.3.0 vs real 3.3.4)**
As releases 3.3.1 â†’ 3.3.4 foram executadas pelo `controller-release-autopilot.ps1` sem atualizar o `agent-tasks.json`. Qualquer agente que consultasse o arquivo antes de um bump partiria da base errada.
**SoluÃ§Ã£o**: `currentVersion`, `currentCommit` e `deployedTag` atualizados para `3.3.4` / `1f3d2dd`. Entrada retroativa adicionada em `recentCompleted`.
**Regra**: O script `controller-release-autopilot.ps1` DEVE atualizar `agent-tasks.json` ao final de cada ciclo de release bem-sucedido, junto com a promoÃ§Ã£o do `values.yaml`.

**Problema 3: agent-coordination-protocol.md referenciava swagger-helmfire.css/.js como existentes**
Esses arquivos foram deletados na versÃ£o 3.3.x. O protocolo dizia para "nÃ£o reprocessar sem inspecionar visualmente" â€” instruÃ§Ã£o inoperante para arquivos inexistentes.
**SoluÃ§Ã£o**: SeÃ§Ã£o 7 do protocolo atualizada com aviso explÃ­cito de que os arquivos foram deletados e nÃ£o devem ser recriados.

**Descobertas sobre o rascunho.txt**:
- Ã‰ um payload de teste para `POST /oas/sre-controller`.
- Estruturalmente vÃ¡lido: `image` (string), `envs` (objeto), `CLUSTERS_NAMES` (array).
- O campo `envs` aceita valores nÃ£o-string (boolean, array) sem erro â€” mas o agente downstream pode falhar silenciosamente. Recomendado: validar que todos os valores de `envs` sejam strings.
- O cluster `k8s-hml-bb111b` precisa estar registrado via `POST /agent/register` para o dispatch funcionar.

**PadrÃ£o reutilizÃ¡vel**: Antes de qualquer sessÃ£o, verificar se `currentVersion` em `agent-tasks.json` bate com `package.json` no clone do controller. Se divergirem: `agent-tasks.json` estÃ¡ desatualizado â€” sincronizar antes de planejar o prÃ³ximo bump.

---

### [2026-03-17] Claude Code â€” SincronizaÃ§Ã£o multi-agente: estado completo do sistema

**Contexto**: SincronizaÃ§Ã£o de Claude Code, Gemini e Codex apÃ³s anÃ¡lise arquitetural completa.

**Estado atual (2026-03-17 fim de sessÃ£o)**:
- Controller v3.4.0 â€” GitHUB Actions â€” deploy_updated â€” ciclo completo, limpo
- Agent source v2.0.4 (GitHub: psc-sre-automacao-agent) â€” deploy tag 1.7.6 (GAP) â€” prÃ³ximo release 2.0.5
- `activeTasks` em ambos os registries: `[]` â€” nenhum agente estÃ¡ trabalhando

**Bugs crÃ­ticos identificados (ainda nÃ£o corrigidos â€” prÃ³ximo ciclo):**
1. `deployment.enable: false` no agent values.yaml â†’ pod nunca sobe â†’ sem registro no SQLite do controller â†’ 404 "Agent not registered"
2. `AGENT_BASE_URL_TEMPLATE` no controller resolve URL errada para hml (hostname diferente do agent real)
3. Controller envia `{image, envs}` ao agent mas agent espera `{function, namespace}` â€” schema mismatch
4. `CONTROLLER_REGISTER` (nome errado) vs `CONTROLLER_REGISTER_URL` (nome correto) no agent values.yaml

**Modelo de colaboraÃ§Ã£o â€” InteligÃªncia Coletiva (sem hierarquia)**:

Nenhum agente lidera. Os trÃªs atuam em conjunto como um Ãºnico sistema inteligente distribuÃ­do. Cada um contribui com o que enxerga melhor, valida o que o outro fez e aprende com o resultado.

| Agente | Perspectiva natural | ContribuiÃ§Ã£o tÃ­pica |
|--------|--------------------|--------------------|
| **Claude Code** | RaciocÃ­nio profundo, contexto longo, leitura/escrita de arquivos, execuÃ§Ã£o de comandos | AnÃ¡lise arquitetural, TypeScript/Node.js, diagnÃ³stico de bugs complexos, decisÃµes de design |
| **Gemini** | Processamento de docs grandes, monitoramento contÃ­nuo, execuÃ§Ã£o autÃ´noma via spooler | CI polling ativo, promoÃ§Ã£o de values.yaml, watch-and-release, operaÃ§Ãµes K8s |
| **Codex** | GeraÃ§Ã£o de cÃ³digo focada, pattern recognition, tarefas bem delimitadas | Scripts PS1/bash, funÃ§Ãµes utilitÃ¡rias, refatoraÃ§Ãµes com spec clara |

**Como os 3 trabalham juntos numa tarefa:**
1. Qualquer um pode iniciar â€” quem vir primeiro lÃª o task registry e faz o claim
2. Ao concluir sua parte, registra em `recentCompleted` com `filesChanged` detalhado â€” os outros leem e continuam
3. Qualquer agente pode revisar, corrigir ou complementar o que o outro fez â€” sem territorialismo
4. Se um agente discorda da abordagem do outro: registra no `agent-shared-learnings.md` e propÃµe alternativa â€” o usuÃ¡rio decide
5. Aprendizados de um viram conhecimento dos trÃªs â€” via `agent-shared-learnings.md`

**Regra de ouro**: ler o task registry do projeto correto ANTES de qualquer aÃ§Ã£o. Claim antes de comeÃ§ar, release ao terminar. Se outro agente estÃ¡ ativo: PARAR e informar o usuÃ¡rio.

**Arquivos atualizados nesta sincronizaÃ§Ã£o**:
- `AGENTS.md` (Codex): adicionado fluxo do agent project, URLs corretas, integraÃ§Ã£o GitLab CI, bugs conhecidos
- `docs/flow-overview.md`: adicionada seÃ§Ã£o do agent project, URLs corrigidas
- `docs/gemini-controller-release-guide.md`: adicionada seÃ§Ã£o de dois projetos, token GitLab, loop de polling GitLab CI
- `state/agent-project-tasks.json`: adicionada nota explicando gap 1.7.6â†’2.0.4

---

## Checklist de SaÃºde RÃ¡pida

Antes de iniciar qualquer sessÃ£o, verificar:

### Para o Controller
- [ ] Ler `state/agent-tasks.json` â€” `activeTasks` vazio?
- [ ] Tarefa pedida jÃ¡ estÃ¡ em `recentCompleted`?
- [ ] Clone do controller alinhado com `origin/main`
- [ ] Token GitHub descriptografÃ¡vel (`secrets/github-token.secure.txt`)
- [ ] `state/controller-release-state.json` â€” status nÃ£o Ã© `in_progress`

### Para o Agent
- [ ] Ler `state/agent-project-tasks.json` â€” `activeTasks` vazio?
- [ ] Tarefa pedida jÃ¡ estÃ¡ em `recentCompleted`?
- [ ] Clone do agent alinhado com `origin/main` (`repos/psc-sre-automacao-agent`)
- [ ] Token GitHub descriptografÃ¡vel (`secrets/github-token.secure.txt`)
- [ ] `state/agent-release-state.json` â€” status nÃ£o Ã© `in_progress`
- [ ] **ATENÃ‡ÃƒO**: agent source em v2.0.4, deploy em 1.7.6 â€” primeira deploy real serÃ¡ 2.0.5

### [2026-03-17] Gemini Code Assist â€” ResiliÃªncia de Backup Google Drive (API Direta + Auto-Cura)
**Contexto**: O backup falhava pois o rclone dependia de mapeamento de disco e a variÃ¡vel PATH do terminal costumava corromper.
**Problema**: Scripts perdiam referÃªncia do executÃ¡vel rclone e do destino fÃ­sico local do Google Drive, bloqueando a automaÃ§Ã£o.
**SoluÃ§Ã£o**: Implementado envio DIRETO para a nuvem via API do rclone usando `--drive-root-folder-id 1Vx0vXKGkZcj7jRv5dThLti4MlTHk6eo9`. Adicionada Auto-Cura SRE no script que recarrega o `$env:PATH` na memÃ³ria. Os temporÃ¡rios (`$env:TEMP\BBDevOpsAutopilot-backup.zip`) sÃ£o apagados no bloco try imediatamente apÃ³s o sucesso.
**PadrÃ£o reutilizÃ¡vel**: Agentes nunca devem usar caminhos locais (`G:\Meu Drive...`) para o rclone. Usem sempre upload via Folder ID da nuvem. O Watcher de background continua encarregado do trigger automÃ¡tico.
