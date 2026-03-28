# Pull Request

## Tipo de mudança
<!-- Marque com [x] o que se aplica -->
- [ ] 🚀 Deploy / Release (novo deploy para repos corporativos)
- [ ] 🔧 Fix de CI/CD (correção de pipeline ou workflow)
- [ ] 📝 Documentação (CLAUDE.md, AGENTS.md, runbooks, etc.)
- [ ] 🏗️ Infraestrutura (schemas, contratos, workflows core)
- [ ] 🔒 Segurança (correção de vulnerabilidade ou melhoria de segurança)
- [ ] ✨ Feature (nova funcionalidade no control plane)
- [ ] 🧹 Chore (limpeza, refatoração, atualização de dependências)

## Workspace afetado
<!-- Marque com [x] o workspace relevante -->
- [ ] `ws-default` (Getronics)
- [ ] `ws-cit` (CIT)
- [ ] Todos os workspaces
- [ ] Nenhum (mudança somente no control plane)

> ⚠️ **ws-socnew** e **ws-corp-1** são workspaces de terceiros e NÃO devem ser afetados por este PR sem autorização explícita do proprietário.

## Descrição
<!-- O que esta mudança faz? Por que é necessária? -->

## Mudanças realizadas
<!-- Liste os arquivos principais modificados e o que foi feito em cada um -->
- 
- 

## Validações executadas
<!-- Marque com [x] o que foi validado -->
- [ ] Lint: nenhum erro de ESLint
- [ ] TypeScript: `tsc --noEmit` sem erros
- [ ] Testes: `jest --ci` passou
- [ ] Swagger: apenas ASCII (sem acentos ou caracteres especiais)
- [ ] Trigger `run` incrementado (se aplicável)
- [ ] Versão correta em 5 arquivos (se deploy)
- [ ] Workspace isolamento verificado (workspace-isolation-check skill)
- [ ] Sem secrets hardcodados
- [ ] `ws-socnew` e `ws-corp-1` não foram afetados

## Checklist de segurança
- [ ] JWT claims usam `scope` (singular), não `scopes`
- [ ] `validateTrustedUrl` não está dentro de helpers de fetch/postJson
- [ ] `parseSafeIdentifier()` usado para inputs em rotas
- [ ] Nenhum secret exposto em logs ou outputs
- [ ] Permissões mínimas nos workflows modificados

## Deploy (preencher se for deploy)
| Campo | Valor |
|-------|-------|
| Componente | controller / agent |
| Versão anterior | |
| Nova versão | |
| Trigger run | |
| Promote CAP | sim / não |

## Riscos e rollback
<!-- Qual o risco desta mudança? Como reverter se necessário? -->
**Risco:** 
**Rollback:** 

## Referências
<!-- Links para issues, PRs relacionados, docs, runbooks -->
- 
