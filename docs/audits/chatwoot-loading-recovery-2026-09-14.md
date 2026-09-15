# Auditoria de carregamento do Chatwoot — 2026-09-14

## Sintoma

O Chatwoot podia permanecer em `Carregando conversas` mesmo quando a requisição inicial da lista falhava de forma transitória. A tela não limpava o estado de carregamento e o usuário precisava recarregar ou trocar de página.

## Causa confirmada

Em `app/javascript/dashboard/store/modules/conversations/actions.js`, `fetchAllConversations` ativava `SET_LIST_LOADING_STATUS`, mas o bloco `catch` não executava `CLEAR_LIST_LOADING_STATUS`. O estado visual ficava preso no spinner após um erro de rede/API.

Também foi confirmado que `docker/Dockerfile.overlay` copia `public/vite` pronto para a imagem. Portanto, publicar apenas o código-fonte sem recompilar o bundle não altera o JavaScript entregue ao navegador.

## Correção

- O caminho de erro agora sempre executa `CLEAR_LIST_LOADING_STATUS`.
- Foi adicionada regressão em `app/javascript/dashboard/store/modules/specs/conversations/actions.spec.js`.
- O bundle Vite foi recompilado e os 240 arquivos referenciados pelo manifesto foram verificados.
- `docker-compose.yml` recebeu uma tag de imagem imutável baseada no bundle recompilado, evitando reutilização do cache antigo.

## Evidências de teste

- Teste isolado da suíte de conversas: `51/51` testes passaram.
- Verificação do manifesto Vite: `240` assets referenciados e presentes.
- `git diff --check`: passou.
- `GET /health`: `200` com `{"status":"woot"}` após a implantação.
- HTML de produção entrega `dashboard-BT7zfAKK.js` e não entrega o bundle antigo `dashboard-DFrwo4Du.js`.
- Validação visual no Chatwoot após reload: a lista de conversas deixou `Carregando conversas` e exibiu os atendimentos/histórico automaticamente, sem trocar de página.

## Entrega

- Código da correção: [`c05a1587`](https://github.com/rottabrasilexpress-spec/chatwoot/commit/c05a1587).
- Bundle publicado: [`a67a0712`](https://github.com/rottabrasilexpress-spec/chatwoot/commit/a67a0712).
- Deploy usando o bundle novo: [`ecde3e8a`](https://github.com/rottabrasilexpress-spec/chatwoot/commit/ecde3e8a).
- Branch publicada: [`rotta-custom-v1`](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1).
- Deploy monitorado no [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments).

## Resultado e limite

O incidente de carregamento infinito foi corrigido e a versão publicada foi validada em produção. O serviço pode apresentar indisponibilidade transitória durante uma implantação enquanto os containers reiniciam; isso é diferente do bug corrigido, pois após a recuperação o health check e a lista voltam automaticamente.

Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/dashboard).
