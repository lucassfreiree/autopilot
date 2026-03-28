---
name: workspace-isolation-check
description: Verifica o isolamento correto entre workspaces antes de executar qualquer operação. Use SEMPRE antes de operações que envolvam state, deploy ou repos corporativos. Crítico para evitar operações não autorizadas em ws-socnew e ws-corp-1.
---

# Workspace Isolation Check Skill

## Quando usar
- SEMPRE antes de qualquer operação que envolva:
  - Deploy para repos corporativos
  - Leitura/escrita em `state/workspaces/`
  - Trigger de workflows com `workspace_id`
  - Operações em repos `bbvinet/*`
- Quando o contexto da conversa não deixar claro qual workspace

## Passos do Check

### 1. Identificar workspace pelo contexto
```
Getronics / controller / agent / NestJS / bbvinet / esteira / psc-sre → ws-default
CIT / DevOps / Terraform / K8s / cloud / monitoring / IaC           → ws-cit
```

### 2. Verificar se workspace é operável
```
ws-default → ✅ ATIVO (BBVINET_TOKEN)
ws-cit     → ✅ ATIVO (CIT_TOKEN)
ws-socnew  → 🔴 BLOQUEADO — PARAR IMEDIATAMENTE
ws-corp-1  → 🔴 BLOQUEADO — PARAR IMEDIATAMENTE
```

**Se workspace for `ws-socnew` ou `ws-corp-1`:**
> ⛔ OPERAÇÃO BLOQUEADA
> Este workspace pertence a um terceiro (irmão do proprietário da conta).
> Não é possível executar operações neste workspace sem autorização explícita e escrita do proprietário da conta `lucassfreiree`.
> Por favor, confirme explicitamente se deseja prosseguir com este workspace.

### 3. Verificar lock (para operações de estado)
```bash
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/locks/session-lock.json?ref=autopilot-state" \
  --jq '.content' | base64 -d | jq -r 'if .agentId != "none" then "LOCKED by \(.agentId) until \(.expiresAt)" else "UNLOCKED" end' 2>/dev/null || echo "No lock"
```

### 4. Verificar token disponível
```
ws-default → secrets.BBVINET_TOKEN deve estar configurado
ws-cit     → secrets.CIT_TOKEN deve estar configurado
Ambos     → secrets.RELEASE_TOKEN para operações de release
```

### 5. Confirmar contexto correto
```bash
# Ler config do workspace para confirmar repos e paths
gh api "repos/lucassfreiree/autopilot/contents/state/workspaces/<WS_ID>/workspace.json?ref=autopilot-state" \
  --jq '.content' | base64 -d | jq '{company: .company, workspace_id: .workspace_id, status: .status}'
```

## Output Esperado

### Check passou ✅
```
Workspace: ws-default (Getronics)
Status: ATIVO
Lock: UNLOCKED
Token: BBVINET_TOKEN (disponível)
→ Seguro para prosseguir
```

### Check falhou — workspace bloqueado 🔴
```
Workspace: ws-socnew
Status: BLOQUEADO (pertence a terceiro)
→ OPERAÇÃO ABORTADA — solicitar autorização explícita ao proprietário
```

### Check falhou — lock ativo ⚠️
```
Workspace: ws-default
Lock: LOCKED by claude-code until 2026-03-28T20:00:00Z
→ Aguardar expiração ou criar handoff para o agente ativo
```
