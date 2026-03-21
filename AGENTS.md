# BBDevOpsAutopilot — Contexto Completo para Agentes

Este arquivo é lido automaticamente por Claude Code e outros agentes ao abrir este repo.

## O que é este projeto

Produto pessoal de automação DevOps (lucassfreiree).
Orquestra releases de aplicações da empresa bbvinet via GitHub Actions.
Zero dependência de máquina local. Zero arquivo nos repos da empresa.

## Tenant ativo: bbvinet (PSC SRE Automação)

### Repositórios da empresa
- Controller (fonte): github.com/bbvinet/psc-sre-automacao-controller
- Agent (fonte):      github.com/bbvinet/psc-sre-automacao-agent
- CAP releases agent: github.com/bbvinet/psc_releases_cap_sre-aut-agent
- Deploy controller:  fontes.intranet.bb.com.br (GitLab interno — acesso manual por ora)

### CI da empresa
- Nome exato do workflow: "Esteira de Build NPM"
- Branch: main

### Arquivo que o autopilot atualiza no CAP
- Repo: bbvinet/psc_releases_cap_sre-aut-agent
- Branch: main
- Arquivo: releases/openshift/hml/deploy/values.yaml
- Campo: image: docker.binarios.intranet.bb.com.br/bb/psc/psc-sre-automacao-agent:VERSAO
- Padrão sed: s|^\(\s*image: docker\.binarios\.intranet\.bb\.com\.br/bb/psc/psc-sre-automacao-agent:\).*|\1NOVA_TAG|

## Arquitetura implementada

### Autenticação: GitHub Device Flow
- Zero secrets armazenados
- Zero token da empresa em qualquer arquivo
- O workflow pede um código, mostra no Job Summary
- Operador abre github.com/login/device, digita o código, aprova com MFA
- Token gerado em memória, usado e descartado

### Estado persistido
- Branch: autopilot-state (neste repo)
- state/agent-state.json — último release do agent
- state/controller-state.json — último release do controller (manual por ora)

### Workflows a criar neste repo

#### 1. .github/workflows/init-state-branch.yml
- Cria o branch autopilot-state com os JSONs de estado
- Disparo: manual (workflow_dispatch)
- Trigger: digitar CONFIRMAR
- Usa GITHUB_TOKEN nativo (sem secrets)
- STATUS: PENDENTE — ainda não criado

#### 2. .github/workflows/agent-release.yml
- Fluxo completo de release do agent
- Device Flow para autenticação
- Busca último CI bem-sucedido da "Esteira de Build NPM"
- Extrai versão do package.json
- Faz checkout do CAP repo
- Atualiza releases/openshift/hml/deploy/values.yaml
- Persiste estado no branch autopilot-state
- STATUS: PENDENTE — ainda não criado

## O que falta para o setup estar completo

1. Criar .github/workflows/init-state-branch.yml
2. Criar .github/workflows/agent-release.yml
3. Disparar init-state-branch (digitar CONFIRMAR)
4. Disparar agent-release manualmente para teste
5. Aprovar o Device Flow quando aparecer o código no Job Summary

## Conteúdo dos workflows

Ver arquivos gerados nas sessões anteriores ou pedir ao agente para gerar
com base nas especificações acima.

## Controller

Deploy do controller está no GitLab interno (fontes.intranet.bb.com.br).
GitHub Actions não acessa a rede interna.
Solução futura: mirror GitLab -> GitHub.
Por ora: promoção manual.

## Segurança

- Token da empresa NUNCA deve ser salvo em secrets deste repo
- Autenticação sempre via Device Flow (aprovação humana a cada execução)
- Este repo é produto pessoal — não armazena dados proprietários da empresa
- Logs e estado contêm apenas metadados (tags, SHAs) — sem dados internos

## Para retomar em nova sessão

Diga ao agente: "Leia o AGENTS.md e continue o setup do autopilot bbvinet"
