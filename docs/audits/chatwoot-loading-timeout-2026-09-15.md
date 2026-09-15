# Chatwoot — auditoria do carregamento com timeout — 2026-09-15

## Sintoma reproduzido

Após recarregar o Chatwoot, a lista podia permanecer em `Carregando conversas` quando uma requisição de pré-carregamento ficava pendente. O serviço não estava totalmente fora do ar: o HTML e `/health` respondiam, mas a tela dependia indefinidamente de uma chamada auxiliar.

## Diagnóstico

- Antes do novo deploy, o domínio respondia `HTTP 200` e `/health` retornava `{\"status\":\"woot\"}`, mas o HTML ainda servia `dashboard-BT7zfAKK.js`.
- O fluxo de `fetchAllConversations` aguardava o pré-carregamento sem limite. Um erro retornado já limpava o estado visual, porém uma chamada pendurada não chegava ao `catch`.
- O bundle pronto é copiado pelo `docker/Dockerfile.overlay`; portanto, publicar apenas a alteração-fonte não bastava.

## Correção publicada

- `app/javascript/dashboard/api/inbox/conversation.js`: timeout padrão de `20.000 ms` nas requisições da lista.
- `app/javascript/dashboard/store/modules/conversations/actions.js`: o pré-carregamento deixa de bloquear o carregamento principal após `2.500 ms`; ele é uma otimização e não um pré-requisito da tela.
- Regressões adicionadas para o timeout da API e para o pré-carregamento pendente.
- Bundle Vite recompilado e manifesto validado com `240` assets.

## Validações

- Build Vite: aprovado (`5.101` módulos transformados).
- `verify:manifest-assets`: aprovado, `240` assets presentes.
- ESLint lógico dos quatro arquivos alterados, com a regra de Prettier desativada por causa do baseline CRLF: aprovado.
- Vitest focalizado: bloqueado antes da coleta por resolução compartilhada de `fake-indexeddb/auto`; o caminho existe no checkout, mas o Vite/Vitest não o resolve nesta máquina. Não houve falha de asserção.
- GitHub: commit [`032dd4f9`](https://github.com/rottabrasilexpress-spec/chatwoot/commit/032dd4f9) publicado em `origin/rotta-custom-v1`.
- EasyPanel: deploy `fix(chatwoot): bound conversation loading requests` concluído; após a janela de reinicialização, a produção passou a servir `dashboard-Bqg3r3F9.js`.
- Saúde live: `/health` respondeu `200` com `{\"status\":\"woot\"}`.
- Smoke visual real no Chatwoot: três recarregamentos completos terminaram com a lista/histórico carregados em aproximadamente `0,96 s`, `1,93 s` e `2,57 s`; o spinner apareceu apenas durante a carga e não permaneceu preso.

## Escopo e limite

Nenhuma mensagem foi enviada e nenhuma conversa, etiqueta, Follow-up, contato ou dado de cliente foi alterado. A correção trata carregamento pendente da lista; uma indisponibilidade transitória durante reinício do EasyPanel pode continuar exibindo `502` até os containers subirem, como ocorreu por alguns segundos durante este deploy.

## Linhas conectadas

[[Chatwoot Rotta — contexto e estado]] ↔ [GitHub `rotta-custom-v1`](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel deployments](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/dashboard).
