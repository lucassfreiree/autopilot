# Guia Operacional para o Gemini â€” psc-sre-automacao-controller
## Fluxo Completo: Clone â†’ EdiÃ§Ã£o â†’ VersÃ£o â†’ Commit â†’ Push â†’ CI â†’ Deploy

> **Fonte**: comportamento real extraÃ­do dos scripts `prepare-controller-main.ps1`,
> `controller-release-autopilot.ps1`, `set-workspace-github-token.ps1` e sessÃµes reais de 2026-03-16.
> Cada snippet deste documento Ã© derivado do cÃ³digo em produÃ§Ã£o â€” nÃ£o Ã© pseudocÃ³digo.

---

## Economia de Tokens â€” Regras ObrigatÃ³rias

Token Ã© recurso finito e pago. Minimizar consumo em toda sessÃ£o.

- **Este arquivo tem 654 linhas.** Ler somente as seÃ§Ãµes necessÃ¡rias para a tarefa atual â€” nÃ£o ler o arquivo inteiro por padrÃ£o.
- **Carregamento sob demanda**: Camada 1 = AGENTS.md (sempre). Camada 2 = `state/agent-tasks.json`. Camada 3 = `agent-shared-learnings.md` / `flow-overview.md`. Camada 4 = este arquivo (raramente, sÃ³ para snippet especÃ­fico).
- **NÃ£o reler** arquivo jÃ¡ lido na mesma sessÃ£o â€” **exceto** se ele foi modificado (por qualquer agente, Edit/Write/tool call) durante esta sessÃ£o. ModificaÃ§Ã£o = releitura permitida e necessÃ¡ria.
- Respostas: direto ao ponto, sem preamble, sem recapitulaÃ§Ã£o. Se cabe em 3 linhas, nÃ£o escrever 10.
- Ferramentas: preferir grep/glob para buscas especÃ­ficas. Paralelizar tool calls independentes.
- Entradas em `agent-shared-learnings.md`: mÃ¡ximo 15 linhas por aprendizado.

---

## âš ï¸ PROTOCOLO DE COORDENAÃ‡ÃƒO MULTI-AGENTE â€” LEIA PRIMEIRO

**Este repositÃ³rio Ã© operado por mÃºltiplos agentes (Claude Code, Codex e Gemini).**
Antes de qualquer aÃ§Ã£o, execute os seguintes passos para evitar conflito de trabalho:

### Passo 0 obrigatÃ³rio â€” verificar estado compartilhado

```powershell
# 1. Ler o registro de tarefas
$tasks = Get-Content '<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\state\agent-tasks.json' -Raw | ConvertFrom-Json

# 2. Verificar se hÃ¡ tarefa ativa
if ($tasks.activeTasks.Count -gt 0) {
    $active = $tasks.activeTasks[0]
    Write-Host "PARAR: $($active.claimedBy) estÃ¡ trabalhando em '$($active.description)' desde $($active.claimedAt)"
    Write-Host "Informar o usuÃ¡rio e aguardar antes de prosseguir."
    exit 1
}

# 3. Verificar versÃ£o atual no main
$pkg = Get-Content '<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\repos\psc-sre-automacao-controller\package.json' -Raw | ConvertFrom-Json
Write-Host "Versao atual no main: $($pkg.version)"
Write-Host "Versao registrada em agent-tasks.json: $($tasks.currentVersion)"

# 4. Verificar se a tarefa jÃ¡ foi feita recentemente
Write-Host "Tarefas recentes:"
$tasks.recentCompleted | Select-Object -First 3 | ForEach-Object {
    Write-Host "  [$($_.completedAt)] $($_.completedBy) v$($_.version): $($_.description.Substring(0, [Math]::Min($_.description.Length, 80)))"
}
```

Se a tarefa solicitada pelo usuÃ¡rio jÃ¡ aparece em `recentCompleted` com version atual: **nÃ£o reprocessar**. Informar ao usuÃ¡rio que jÃ¡ foi feito.

### Protocolo completo
Ver: `docs/agent-coordination-protocol.md`

---

## 0. VisÃ£o Geral do Fluxo (nunca pular etapas)

```
[1] Autenticar token
      â†“
[2] Sincronizar clone canÃ´nico (prepare-controller-main.cmd)
      â†“
[3] Fazer ediÃ§Ãµes no cÃ³digo
      â†“
[4] Bump de versÃ£o (3 arquivos)
      â†“
[5] Commit + Push para main
      â†“
[6] Monitorar GitHub Actions (loop ativo atÃ© completed)
      â†“
[7] Se falhar: ler logs â†’ corrigir â†’ novo commit â†’ push â†’ voltar ao [6]
      â†“
[8] CI success â†’ promover values.yaml em cloud/homologacao
```

## âš ï¸ DOIS PROJETOS â€” IDENTIFICAR ANTES DE AGIR

| Palavra-chave | Projeto | Tasks | Config | CI |
|---------------|---------|-------|--------|----|
| controller / sre-controller | `psc-sre-automacao-controller` | `state/agent-tasks.json` | `controller-release-autopilot.json` | GitHub Actions |
| agent / sre-agent | `psc-sre-automacao-agent` | `state/agent-project-tasks.json` | `agent-release-autopilot.json` | GitHub Actions |

**VersÃµes sÃ£o INDEPENDENTES.** Controller em `3.4.0`, Agent source em `2.0.4` (deploy em `1.7.6`).

### RepositÃ³rios do Controller (GitHub)

| RepositÃ³rio | Para quÃª | Clone local |
|-------------|---------|-------------|
| `psc-sre-automacao-controller` | cÃ³digo fonte, CI/CD | `repos\psc-sre-automacao-controller` |
| `deploy-psc-sre-automacao-controller` | values.yaml, tag de deploy | `cache\deploy-psc-sre-automacao-controller` |

### RepositÃ³rios do Agent (ambos GitHub)

| RepositÃ³rio | Para quÃª | Clone local |
|-------------|---------|-------------|
| `github.com/bbvinet/psc-sre-automacao-agent` | cÃ³digo fonte, GitHub Actions CI | `repos\psc-sre-automacao-agent` |
| `github.com/bbvinet/psc_releases_cap_sre-aut-agent` | CAP, values.yaml, tag de deploy | `cache\deploy-psc-sre-automacao-agent` |

---

## 1. AutenticaÃ§Ã£o

### GitHub (ambos os projetos)

Token: `secrets/github-token.secure.txt` (DPAPI) â€” mesmo token para controller e agent.

---

## 1b. AutenticaÃ§Ã£o no GitHub (controller â€” detalhe original)

### Como o token Ã© armazenado

O token estÃ¡ criptografado com **Windows DPAPI** (Data Protection API) vinculado ao perfil do usuÃ¡rio Windows atual.

- Arquivo: `<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\secrets\github-token.secure.txt`
- Formato: string hexadecimal (saÃ­da de `ConvertFrom-SecureString`)
- **SÃ³ descriptografa na mesma mÃ¡quina e no mesmo perfil Windows que o gerou**

### Descriptografar o token (cÃ³digo exato do `controller-release-autopilot.ps1`)

```powershell
$tokenPath = "<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\secrets\github-token.secure.txt"
$encrypted = (Get-Content -Raw -Path $tokenPath).Trim()
$secure = ConvertTo-SecureString -String $encrypted
$GH_TOKEN = [System.Net.NetworkCredential]::new("", $secure).Password
# NÃƒO imprima $GH_TOKEN. Use-o somente em variÃ¡vel de memÃ³ria.
```

### Fallback: variÃ¡veis de ambiente

O script busca o token nesta ordem:
1. `$env:GITHUB_TOKEN`
2. `$env:GH_TOKEN`
3. Arquivo `secrets\github-token.secure.txt`

Se o token expirou ou a descriptografia falha: pedir ao usuÃ¡rio para rodar:
```
<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\set-workspace-github-token.cmd
```

### Configurar o token para operaÃ§Ãµes git (push)

O push usa o token na URL do remote. Se for fazer manualmente:

```powershell
$REPO = "<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\repos\psc-sre-automacao-controller"
# Configurar URL com token (temporÃ¡rio â€” sÃ³ para a sessÃ£o)
git -C $REPO remote set-url origin "https://${GH_TOKEN}@github.com/bbvinet/psc-sre-automacao-controller.git"
# ApÃ³s o push, restaurar URL sem token:
git -C $REPO remote set-url origin "https://github.com/<OWNER>/psc-sre-automacao-controller.git"
```

---

## 2. Sincronizar o Clone CanÃ´nico do Controller

### Por que sincronizar antes de qualquer ediÃ§Ã£o

O clone pode ter mudanÃ§as locais de sessÃµes anteriores. O script usa `reset --hard` + `clean -fd` para garantir estado idÃªntico ao remote â€” **nunca `git pull`** (que causaria merge ou conflito indesejado).

### OpÃ§Ã£o A: via script (recomendado)

```
<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\prepare-controller-main.cmd
```

### OpÃ§Ã£o B: manualmente (equivalente exato ao que `prepare-controller-main.ps1` faz)

```powershell
$REPO = "<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\repos\psc-sre-automacao-controller"

# Se o clone nÃ£o existe ainda: clonar
if (-not (Test-Path "$REPO\.git")) {
    $PARENT = Split-Path -Parent $REPO
    git -C $PARENT clone https://github.com/<OWNER>/psc-sre-automacao-controller.git $REPO
}

# Configurar identidade git (obrigatÃ³rio â€” os scripts sempre fazem isso)
git -C $REPO config user.name  "C1342799_BBrasil"
git -C $REPO config user.email "<PRIVATE_EMAIL>"

# Sincronizar com origin/main (sequÃªncia exata do prepare-controller-main.ps1)
git -C $REPO fetch origin main
git -C $REPO checkout -B main origin/main
git -C $REPO reset --hard origin/main
git -C $REPO clean -fd

# Verificar resultado
git -C $REPO status                       # deve mostrar "nothing to commit, working tree clean"
git -C $REPO rev-parse --abbrev-ref HEAD  # deve mostrar "main"
```

---

## 3. Fazer EdiÃ§Ãµes no CÃ³digo

- Editar **somente** dentro de `$REPO` (o clone canÃ´nico listado acima)
- Nunca editar em outro clone, workspace do usuÃ¡rio, ou clone temporÃ¡rio
- As ediÃ§Ãµes vÃ£o direto para `main` â€” nÃ£o existe feature branch neste fluxo
- `excludePaths` do `controller-release-autopilot.json` exclui automaticamente do commit: `.vscode\`, `docs\`, `tmp-last-commit.patch`

---

## 4. Bump de VersÃ£o (OBRIGATÃ“RIO no primeiro commit do ciclo)

### Regra fundamental

O **primeiro commit de cada ciclo** deve incluir bump de versÃ£o em **exatamente trÃªs arquivos**. Commits corretivos do mesmo ciclo (apÃ³s CI falhar) **mantÃªm a mesma versÃ£o** â€” nÃ£o fazem novo bump.

### Determinar a nova versÃ£o

```powershell
$REPO = "<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\repos\psc-sre-automacao-controller"
$pkg = Get-Content "$REPO\package.json" -Raw | ConvertFrom-Json
$current = $pkg.version  # ex: "3.2.0"
$parts = $current.Split('.')
$newVersion = "$($parts[0]).$($parts[1]).$([int]$parts[2] + 1)"  # patch: "3.2.1"
Write-Host "VersÃ£o atual: $current â†’ Nova versÃ£o: $newVersion"
```

### 4a. Bump via npm (mÃ©todo preferido â€” idÃªntico ao que o script usa)

```powershell
# Atualiza package.json E package-lock.json de forma consistente
npm --prefix $REPO version $newVersion --no-git-tag-version --allow-same-version
```

### 4b. Bump manual do package-lock.json (ATENÃ‡ÃƒO: regra crÃ­tica)

**NUNCA fazer regex global no package-lock.json.** O arquivo tem centenas de dependÃªncias de terceiros â€” um replace global pode acertar dependÃªncias que coincidem com a versÃ£o antiga. Editar **somente por Ã­ndice de array** nas linhas 3 e 9 (zero-indexed: 2 e 8):

```powershell
# PadrÃ£o seguro â€” extraÃ­do diretamente do agent-shared-learnings.md
$lockPath = "$REPO\package-lock.json"
$lines = [System.IO.File]::ReadAllLines($lockPath, [System.Text.Encoding]::UTF8)
foreach ($idx in @(2, 8)) {  # linhas 3 e 9 (0-indexed: 2 e 8)
    if ($lines[$idx] -match '"version":') {
        $lines[$idx] = $lines[$idx] -replace '"version": "[^"]+"', "`"version`": `"$newVersion`""
    }
}
[System.IO.File]::WriteAllLines($lockPath, $lines, [System.Text.Encoding]::UTF8)

# Validar:
Write-Host "Linha 3: $($lines[2])"
Write-Host "Linha 9: $($lines[8])"
```

### 4c. Bump em src/swagger/swagger.json

O script usa `ConvertFrom-Json` / `ConvertTo-Json` para atualizar o campo `.info.version`:

```powershell
$swaggerPath = "$REPO\src\swagger\swagger.json"
$swagger = Get-Content -Raw $swaggerPath | ConvertFrom-Json
$swagger.info.version = $newVersion
$json = $swagger | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($swaggerPath, $json + [Environment]::NewLine)
```

### VerificaÃ§Ã£o pÃ³s-bump

```powershell
# Os trÃªs devem mostrar a nova versÃ£o:
(Get-Content "$REPO\package.json" -Raw | ConvertFrom-Json).version
(Get-Content "$REPO\package-lock.json" -Raw | ConvertFrom-Json).version
(Get-Content "$REPO\src\swagger\swagger.json" -Raw | ConvertFrom-Json).info.version
```

---

## 5. Commit e Push para main

### SequÃªncia exata do `controller-release-autopilot.ps1`

```powershell
$REPO = "<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\repos\psc-sre-automacao-controller"

# Garantir identidade
git -C $REPO config user.name  "C1342799_BBrasil"
git -C $REPO config user.email "<PRIVATE_EMAIL>"

# Limpar index e adicionar tudo
git -C $REPO reset
git -C $REPO add -A -- .

# Verificar o que estÃ¡ staged
$staged = git -C $REPO diff --cached --name-only
Write-Host "Arquivos staged: $staged"
# Esperado: package.json, package-lock.json, src/swagger/swagger.json + arquivos editados

# Mensagem padrÃ£o para primeiro commit do ciclo:
$message = "chore(release): publish controller $newVersion"
# Mensagem para commit corretivo (CI falhou):
# $message = "fix(ci): correct controller build for $newVersion"

git -C $REPO commit -m $message
$commitSha = git -C $REPO rev-parse HEAD
Write-Host "Commit SHA: $commitSha"

# Push
git -C $REPO push origin main
Write-Host "Push concluÃ­do. SHA: $commitSha"
```

### Se o push for rejeitado (non-fast-forward)

```powershell
git -C $REPO fetch origin
git -C $REPO rebase origin/main
# Se sem conflito:
git -C $REPO push origin main
```

---

## 6. Monitorar o GitHub Actions (loop ativo)

### Importante: nunca usar background â€” manter loop ativo

O build pode demorar atÃ© 20 minutos. O agente deve permanecer em loop ativo para detectar falhas e agir imediatamente.

### 6a. Encontrar o RUN_ID

O GitHub leva 5-15 segundos para criar o workflow run. Usar retry:

```powershell
$headers = @{
    Authorization = "Bearer $GH_TOKEN"
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent" = "controller-release-autopilot"
}
$OWNER    = "bbvinet"
$REPO_NAME = "psc-sre-automacao-controller"

$run = $null
$attempts = 0
while ($null -eq $run -and $attempts -lt 45) {
    Start-Sleep -Seconds 20
    $result = Invoke-RestMethod -Headers $headers -Uri `
        "https://api.github.com/repos/$OWNER/$REPO_NAME/actions/runs?per_page=20&head_sha=$commitSha"
    $run = $result.workflow_runs | Select-Object -First 1
    $attempts++
    if ($null -eq $run) { Write-Host "Aguardando workflow run... tentativa $attempts" }
}
if ($null -eq $run) { throw "Workflow run nÃ£o encontrado para SHA $commitSha apÃ³s $attempts tentativas" }
$RUN_ID = $run.id
Write-Host "Run ID: $RUN_ID"
Write-Host "Run URL: $($run.html_url)"
```

### 6b. Loop de monitoramento atÃ© completed

```powershell
$deadline = (Get-Date).AddMinutes(60)
$runDetail = $null

while ((Get-Date) -lt $deadline) {
    $runDetail = Invoke-RestMethod -Headers $headers -Uri `
        "https://api.github.com/repos/$OWNER/$REPO_NAME/actions/runs/$RUN_ID"

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] status=$($runDetail.status) conclusion=$($runDetail.conclusion)"

    if ($runDetail.status -eq "completed") { break }

    Start-Sleep -Seconds 20  # pollIntervalSeconds = 20 (conforme controller-release-autopilot.json)
}

if ($runDetail.status -ne "completed") {
    throw "Build nÃ£o completou dentro do timeout."
}

if ($runDetail.conclusion -eq "success") {
    Write-Host "CI SUCCESS â€” prosseguir para step 7"
} else {
    Write-Host "CI FALHOU (conclusion=$($runDetail.conclusion)) â€” ler logs abaixo"
}
```

### 6c. Quando o CI falha: ler os logs

```powershell
# Listar jobs e encontrar falha
$jobs = Invoke-RestMethod -Headers $headers -Uri `
    "https://api.github.com/repos/$OWNER/$REPO_NAME/actions/runs/$RUN_ID/jobs?per_page=100"

$failedJobs = $jobs.jobs | Where-Object { $_.conclusion -ne "success" -and $_.conclusion }
foreach ($job in $failedJobs) {
    Write-Host "Job com falha: $($job.name) [$($job.conclusion)]"
    $job.steps | Where-Object { $_.conclusion -and $_.conclusion -ne "success" } | ForEach-Object {
        Write-Host "  Step: $($_.name) [$($_.conclusion)]"
    }
}

# Baixar logs do run completo
$logDir = "<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\reports\github-actions\run-$RUN_ID"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Invoke-WebRequest -Headers $headers -Uri `
    "https://api.github.com/repos/$OWNER/$REPO_NAME/actions/runs/$RUN_ID/logs" `
    -OutFile "$logDir\logs.zip"
Expand-Archive -Path "$logDir\logs.zip" -DestinationPath "$logDir\logs" -Force

# Filtrar linhas de erro (excluir ruÃ­do de node_modules)
Get-ChildItem "$logDir\logs" -Recurse -Filter "*.txt" | ForEach-Object {
    $errors = Get-Content $_.FullName | Where-Object {
        $_ -match 'error|ERR!|FAILED|tsc:|eslint:' -and $_ -notmatch 'node_modules'
    }
    if ($errors) {
        Write-Host "=== $($_.Name) ==="
        $errors | Select-Object -First 30 | Write-Host
    }
}
```

### 6d. Corrigir e reiniciar o ciclo (mesma versÃ£o)

```powershell
# 1. Editar o arquivo com problema em $REPO
# 2. NÃƒO fazer novo bump de versÃ£o

# 3. Novo commit com mensagem de fix
git -C $REPO add -A -- .
git -C $REPO commit -m "fix(ci): correct controller build for $newVersion"
$commitSha = git -C $REPO rev-parse HEAD  # novo SHA
git -C $REPO push origin main

# 4. Novo RUN_ID â€” repetir seÃ§Ã£o 6a com o novo $commitSha
# 5. Repetir loop de monitoramento (seÃ§Ã£o 6b)
```

---

## 7. Promover o values.yaml em cloud/homologacao

**Executar somente apÃ³s CI success confirmado.**

### 7a. Sincronizar o deploy repo

```powershell
$DEPLOY_REPO   = "<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\cache\deploy-psc-sre-automacao-controller"
$DEPLOY_BRANCH = "cloud/homologacao"

# Clonar se necessÃ¡rio
if (-not (Test-Path "$DEPLOY_REPO\.git")) {
    $CACHE = Split-Path -Parent $DEPLOY_REPO
    git -C $CACHE clone https://github.com/<OWNER>/deploy-psc-sre-automacao-controller.git $DEPLOY_REPO
}

git -C $DEPLOY_REPO config user.name  "C1342799_BBrasil"
git -C $DEPLOY_REPO config user.email "<PRIVATE_EMAIL>"

# Sincronizar (mesmo padrÃ£o: fetch + checkout -B + reset --hard)
git -C $DEPLOY_REPO fetch origin $DEPLOY_BRANCH
git -C $DEPLOY_REPO checkout -B $DEPLOY_BRANCH "origin/$DEPLOY_BRANCH"
git -C $DEPLOY_REPO reset --hard "origin/$DEPLOY_BRANCH"
git -C $DEPLOY_REPO clean -fd
```

### 7b. Atualizar deployment.containers.tag

Estrutura do `values.yaml` (indentaÃ§Ã£o importa â€” 6 espaÃ§os no campo `tag`):

```yaml
  deployment:            # 2 espaÃ§os
    containers:          # 4 espaÃ§os
      # -- Overrides the image tag...
      tag: "3.2.0"       # 6 espaÃ§os  â† ALTERAR ESTE CAMPO
```

O script usa busca hierÃ¡rquica por contexto â€” mÃ©todo seguro equivalente ao `Set-DeployValuesTag`:

```powershell
$valuesPath = "$DEPLOY_REPO\values.yaml"
$lines = [System.Collections.Generic.List[string]](Get-Content -Path $valuesPath)
$insideDeployment = $false
$insideContainers = $false
$updated = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '^\s{2}deployment:\s*$') {
        $insideDeployment = $true; $insideContainers = $false; continue
    }
    if ($insideDeployment -and $line -match '^\s{4}containers:\s*$') {
        $insideContainers = $true; continue
    }
    if ($insideContainers -and $line -match '^\s{6}tag:\s*".*"\s*$') {
        $lines[$i] = '      tag: "' + $newVersion + '"'
        Set-Content -Path $valuesPath -Value $lines
        $updated = $true
        Write-Host "Tag atualizada para $newVersion"
        break
    }
    if ($insideDeployment -and $line -match '^\s{2}[A-Za-z]') {
        $insideDeployment = $false; $insideContainers = $false
    }
}
if (-not $updated) { throw "deployment.containers.tag nÃ£o encontrado em $valuesPath" }

# Verificar diff antes de commitar
git -C $DEPLOY_REPO diff values.yaml
```

### 7c. Commit e push no deploy repo

```powershell
git -C $DEPLOY_REPO add -- values.yaml

$status = git -C $DEPLOY_REPO status --short
if (-not $status) {
    Write-Host "Deploy repo jÃ¡ estÃ¡ na versÃ£o $newVersion â€” nada a commitar."
} else {
    $deployMessage = "chore(release): promote psc-sre-automacao-controller to $newVersion"
    git -C $DEPLOY_REPO commit -m $deployMessage
    git -C $DEPLOY_REPO push origin "HEAD:$DEPLOY_BRANCH"
    Write-Host "Deploy promovido: values.yaml tag = $newVersion em $DEPLOY_BRANCH"
}
```

---

## 8. Atualizar o State File

```powershell
$statePath = "<LOCAL_USER_HOME>\.bbdevops-autopilot-safe\BBDevOpsAutopilot\state\controller-release-state.json"

$state = [pscustomobject]@{
    updatedAt        = (Get-Date).ToString("o")
    status           = "deploy_updated"
    baseBranch       = "main"
    targetVersion    = $newVersion
    controllerCommit = $commitSha
    lastPushedCommit = $commitSha
    workflowRunId    = $RUN_ID
}
$state | ConvertTo-Json -Depth 10 | Set-Content $statePath -Encoding UTF8
Write-Host "State salvo."
```

**Verificar antes de iniciar um novo ciclo:**

```powershell
$state = Get-Content $statePath -Raw | ConvertFrom-Json
Write-Host "Status atual: $($state.status)"
# Se "in_progress" ou "pushed": verificar run no GitHub antes de prosseguir
# Se "deploy_updated" ou "build_failed": pode iniciar novo ciclo
```

---

## 9. ReferÃªncia RÃ¡pida

### Identidade git (usar em todos os commits)
```
user.name  = C1342799_BBrasil
user.email = <PRIVATE_EMAIL>
```

### URLs por contexto
| Contexto | URL |
|----------|-----|
| Clone git (controller) | `https://github.com/<OWNER>/psc-sre-automacao-controller.git` |
| Clone git (deploy) | `https://github.com/<OWNER>/deploy-psc-sre-automacao-controller.git` |
| GitHub API | `https://api.github.com/repos/bbvinet/psc-sre-automacao-controller/...` |
| Link de UI para o usuÃ¡rio | `https://github.com/<OWNER>/psc-sre-automacao-controller` |

> `mcas.ms` = proxy corporativo para navegaÃ§Ã£o â€” **nÃ£o funciona** para git clone ou API REST.

### Timeouts do `controller-release-autopilot.json`
| ParÃ¢metro | Valor | Significado |
|-----------|-------|-------------|
| `pollIntervalSeconds` | 20s | Intervalo entre polling de status |
| `appearTimeoutSeconds` | 900s (15min) | Tempo mÃ¡ximo para o run aparecer apÃ³s push |
| `completionTimeoutSeconds` | 10800s (3h) | Tempo mÃ¡ximo atÃ© completed |

---

## 10. Armadilhas Conhecidas (de sessÃµes reais)

1. **package-lock.json regex global queima** â€” sessÃ£o de 2026-03-16: dependÃªncia de terceiro com a versÃ£o `3.1.0` foi sobrescrita acidentalmente. **Regra**: editar somente linhas 3 e 9 por Ã­ndice.

2. **Token DPAPI nÃ£o porta** â€” o arquivo `github-token.secure.txt` Ã© inÃºtil em outra mÃ¡quina. Se falhar, pedir para o usuÃ¡rio rodar `set-workspace-github-token.cmd`.

3. **Workflow run demora 5-15s para aparecer** â€” nÃ£o concluir que "nÃ£o existe run" sem retry com sleep de 20s.

4. **Build demora atÃ© 20 minutos** â€” nunca abortar o loop antes de `status=completed`.

5. **cloud/desenvolvimento Ã© automÃ¡tico** â€” o CD atualiza esse branch sozinho apÃ³s build green. NÃ£o Ã© tarefa do agente. Somente `cloud/homologacao` exige promoÃ§Ã£o manual.

6. **Nunca `--force` no push para main** â€” se rejeitar, investigar com `git rebase`.

7. **swagger.json triple-mojibake** â€” se campos de texto tiverem `ÃƒÆ’Ã†'`, o arquivo estÃ¡ corrompido. Ver seÃ§Ã£o em `docs/agent-shared-learnings.md` para o fix byte-level.

8. **Lock file** â€” se `state/controller-release.lock` existir ao iniciar, outro processo estÃ¡ em andamento. Verificar antes de prosseguir.

---

## 11. Checklist de ExecuÃ§Ã£o por Ciclo

```
PRÃ‰-CICLO
[ ] GH_TOKEN descriptografÃ¡vel
[ ] state.json: status != "in_progress"
[ ] controller-release.lock: nÃ£o existe
[ ] Clone sincronizado: git status = clean, branch = main

BUMP + COMMIT
[ ] VersÃ£o incrementada em package.json (1 ocorrÃªncia)
[ ] VersÃ£o incrementada em package-lock.json (linhas 3 e 9 â€” por Ã­ndice)
[ ] VersÃ£o incrementada em src/swagger/swagger.json (.info.version)
[ ] git add -A + commit + push para main

MONITORAMENTO
[ ] RUN_ID encontrado (retry com SHA)
[ ] Loop ativo de polling (nÃ£o background)
[ ] Se CI falhar: ler logs â†’ corrigir â†’ novo commit (MESMA versÃ£o) â†’ push â†’ novo loop

PÃ“S-CI
[ ] deploy repo sincronizado com origin/cloud/homologacao
[ ] values.yaml: deployment.containers.tag = "X.Y.Z" (6 espaÃ§os â€” busca hierÃ¡rquica)
[ ] commit + push em cloud/homologacao
[ ] state.json atualizado: status = "deploy_updated"
```
