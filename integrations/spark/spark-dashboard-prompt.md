# Autopilot Dashboard — Mega Prompt para GitHub Spark

> Este e o prompt COMPLETO para criar o dashboard mais inteligente possivel.
> O dashboard e sincronizado automaticamente via `spark-sync-state.yml`.
> Codigo fonte: `references/spark-dashboard/public/index.html`

## CONTEXTO DO PROJETO

O Autopilot e um control plane web-only para orquestracao CI/CD multi-workspace e multi-agente.
Gerencia deploys para repositorios corporativos via GitHub Actions, com 3 agentes AI (Claude Code,
Copilot, Codex) operando de forma 100% autonoma.

### Arquitetura
- **Repo principal**: `lucassfreiree/autopilot` (control plane)
- **State branch**: `autopilot-state` (source of truth — release states, locks, audit)
- **Backups branch**: `autopilot-backups` (snapshots para rollback)
- **Dashboard**: `lucassfreiree/spark-dashboard` (este app)
- **Sync**: workflow `spark-sync-state.yml` envia `state.json` a cada 5 minutos

### Empresas (Workspaces Isolados)
| Workspace | Empresa | Status | Stack |
|-----------|---------|--------|-------|
| ws-default | Getronics | Active | Node/TypeScript (NestJS, Jest) |
| ws-cit | CIT | Setup | DevOps (K8s, Docker, Terraform) |
| ws-socnew | SocNew | LOCKED (terceiro) | — |
| ws-corp-1 | Corp-1 | LOCKED (terceiro) | — |

### Repos Corporativos (Getronics)
| Repo | Funcao |
|------|--------|
| bbvinet/psc-sre-automacao-controller | Codigo fonte Controller (Node 22, TS, Express, Jest) |
| bbvinet/psc-sre-automacao-agent | Codigo fonte Agent (Node 22, TS, Express, Jest, K8s) |
| bbvinet/psc_releases_cap_sre-aut-controller | Deploy K8s Controller (values.yaml) |
| bbvinet/psc_releases_cap_sre-aut-agent | Deploy K8s Agent (values.yaml) |

### Pipeline apply-source-change (7 Stages)
1. **Setup** — Le workspace config
1.5. **Session Guard** — Adquire lock multi-agente
2. **Apply & Push** — Clona repo, aplica patches, push
3. **CI Gate** — Espera esteira corporativa (Esteira de Build NPM)
4. **Promote** — Atualiza image tag no CAP values.yaml
5. **Save State** — Salva no autopilot-state
6. **Audit** — Trail + libera lock

### Pos-Deploy (100% automatico)
- ci-monitor-loop.yml poll a cada 2 min por 30 min
- Se CI passou: promote-cap.yml
- Se CI falhou: ci-diagnose.yml + fix-corporate-ci.yml (auto-fix)

### 3 Agentes AI
| Agente | Papel | Branch | Memoria |
|--------|-------|--------|---------|
| Claude Code | Primario — arquitetura, releases | claude/* | claude-session-memory.json |
| Copilot | Backup + dispatch | copilot/* | copilot-session-memory.json |
| Codex | Implementacao | codex/* | codex-session-memory.json |

## SCHEMA DO state.json (dados disponiveis)

O dashboard le `state.json` que contem:

```json
{
  "lastSync": "ISO timestamp",
  "controller": { "version", "status", "ciResult", "promoted", "lastSha", "repo", "capRepo", "stack" },
  "agent": { "version", "status", "ciResult", "promoted", "lastSha", "repo", "capRepo", "stack" },
  "pipeline": { "status", "lastRun", "component", "version", "promote", "workspace", "changeType", "commitMessage", "changesCount" },
  "agents": {
    "claude": { "status", "task", "phase", "lastUpdated", "lastAction" },
    "copilot": { "sessionCount", "lastSession", "lessonsCount", "sessions[]" },
    "codex": { "sessionCount", "lastSession", "lessonsCount", "sessions[]" }
  },
  "sessionLock": { "agentId", "expiresAt", "acquiredAt", "operation" },
  "health": {},
  "ciMonitor": { "ciOutcome", "component", "commitSha" },
  "workspaces": [{ "id", "company", "status", "stack", "token", "controllerVersion", "agentVersion", "pipelineStatus", "repos[]" }],
  "recentWorkflows": [{ "name", "status", "conclusion", "created", "url", "head_branch", "event" }],
  "openPRs": [{ "number", "title", "author", "branch", "draft", "created", "labels[]" }],
  "deployHistory": ["audit/path..."],
  "lessonsLearned": { "total", "copilot", "codex", "copilotLessons[]", "codexLessons[]" },
  "versionRules": { "currentController", "currentAgent", "pattern", "lastTriggerRun", "lastSuccessfulRun" },
  "executionHistory": [{ "id", "date", "summary" }],
  "knownErrors": [{ "code", "desc", "fix" }],
  "pipelineStages": [{ "name", "desc" }],
  "metadata": { "autopilotRepo", "sparkRepo", "totalAgents", "totalWorkspaces", "syncInterval", "stateVersion" }
}
```

## PAGINAS DO DASHBOARD

### 1. Overview (pagina principal)
- Health score (0-100) calculado inteligentemente
- Cards: Controller version, Agent version, Pipeline run, Health
- Smart alerts: analise automatica do state para gerar avisos
- Active agent indicator (qual agente esta trabalhando)
- Session lock status (bloqueio multi-agente)

### 2. Smart Alerts
- Sync stale (>15 min sem update)
- Pipeline running/failed
- CI failed (controller ou agent)
- Not promoted to CAP
- Lock ativa ou expirada
- Agent PRs acumulando
- Version mismatch

### 3. Pipeline Monitor
- Visualizacao dos 7 stages com status
- Info do trigger atual (run, component, version, commit message)
- CI Monitor (resultado da esteira corporativa)
- Version rules (regras de versionamento)

### 4. Agent Activity
- Cards dos 3 agentes com status, sessoes, lessons
- Timeline de sessoes recentes (combinando copilot + codex)
- Detalhes de task/phase quando agente ativo

### 5. Workspaces
- Card por workspace com versoes, pipeline status
- Indicador de workspace LOCKED (terceiro)
- Stack, token, repos

### 6. Workflows
- Tabela de workflows recentes com status, resultado, branch, data
- Categorizado por prefixo: [Corp], [Core], [Release], [Agent], [Infra], Ops:

### 7. Open PRs
- Lista de PRs abertos com autor, branch, labels, draft status

### 8. Deploy History
- Historico de deploys do audit trail

### 9. Lessons Learned
- Stats totais (Copilot vs Codex)
- Lista detalhada de licoes com fix

### 10. Error Patterns
- Referencia rapida de erros conhecidos e fixes

### 11. Architecture
- Control plane structure
- Corporate repos (Getronics)
- Pipeline flow visualization
- Multi-agent system overview

## DESIGN
- Dark mode (#0d1117 background)
- Cores: verde=success, vermelho=failed, amarelo=running, azul=info, roxo=copilot, laranja=codex, cinza=idle
- Sidebar com navegacao
- Responsivo (desktop + mobile)
- Auto-refresh a cada 30 segundos
- Dados de state.json carregados via fetch

## INTELIGENCIA DO DASHBOARD
O dashboard NAO e apenas uma visualizacao. Ele CALCULA:
1. **Health Score**: Deduz pontos por CI failure (-20), pipeline failure (-15), not promoted (-10), sync stale (-10), expired lock (-5)
2. **Smart Alerts**: Analisa state e gera avisos contextuais automaticamente
3. **Stage Status**: Infere status de cada stage baseado no pipeline status geral
4. **Session Timeline**: Combina sessoes de todos os agentes em timeline unificada
