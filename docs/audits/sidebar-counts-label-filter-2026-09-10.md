# Auditoria — contadores do sidebar e filtro por etiquetas

Data: 2026-09-10  
Branch: `rotta-custom-v1`  
Commits de implementação: `b03b787`, `80db589`

## Escopo

- Remover números residuais de `ORÇAMENTOS`, `Caio Atenção` e `Clientes Fechados` quando a etiqueta deixa de existir ou fica sem contatos.
- Adicionar um filtro no topo da lista de conversas que exibe todas as etiquetas da conta e navega para a lista filtrada.
- Não alterar conversas, etiquetas, mensagens, n8n, UAZAPI ou WhatsApp.

## Diagnóstico e correção

O estado Vuex de contagens era atualizado apenas com as etiquetas encontradas e a mutação fazia merge com o mapa anterior. Assim, um valor antigo sobrevivia quando uma etiqueta era removida ou zerada.

`labels/getSidebarCounts` agora sempre publica as três chaves (`budget`, `caioAttention`, `closedClients`), normalizando ausências para zero. `SET_SIDEBAR_LABEL_COUNTS` substitui o mapa completo, eliminando valores stale. A Sidebar também dispara essa ação quando o catálogo chega vazio, inclusive na troca de conta.

O seletor de etiquetas foi adicionado a `ChatListHeader.vue`. A lista vem de `labels/getLabels`; a seleção usa a rota existente `/label/:label`, que já envia `labels` para `ConversationFinder`. A opção `Filtrar por etiqueta` retorna a `/dashboard`.

## Evidências

- Regressão antes do fix: com contagem anterior de `1`, a ação publicava somente `{ budget: 0 }`; `caioAttention` e `closedClients` ficavam sem atualização.
- Após o fix: teste focalizado `sidebarLabelCounts.spec.js` passou `5/5`, incluindo catálogo vazio.
- Build Vite: `5.077` módulos transformados, concluído.
- GitHub: `b03b787` e `80db589` enviados para `origin/rotta-custom-v1`.
- Easypanel: os deploys `fix(rotta): clear sidebar counts and add label filter` e `fix(rotta): reset sidebar counts for empty labels` concluíram com `Compose implantado`; o serviço voltou saudável.
- Chatwoot real: após reload, `ORÇAMENTOS` e `Caio Atenção` não exibiram badges fantasmas. O botão `Filtrar por etiqueta` abriu o catálogo completo; `kelvin` e `primeiro-contato` produziram as rotas esperadas; limpar retornou para `/app/accounts/1/dashboard`.
- Revalidação final no Chatwoot real: `orcamento-feito` foi selecionada pelo menu e abriu `/app/accounts/1/label/orcamento-feito`; o estado vazio foi exibido porque não havia conversas ativas nessa etiqueta no conjunto atual. A aba foi restaurada para `/app/accounts/1/dashboard`.

## Limitações e segurança

- O único MP4 localizado nos temporários não é o vídeo solicitado: tem 3 segundos, 368x368, mostra somente uma animação do logotipo do ChatGPT e sua trilha AAC está em silêncio (`-91 dB`), sem interface Chatwoot, etiquetas ou explicação audível. Nenhuma alteração visual/auditiva foi inferida.
- ESLint direcionado ficou limitado pelo CRLF global do checkout Windows e avisos i18n dinâmicos preexistentes; `git diff --check` passou e o build confirmou a compilação.
- Nenhuma mensagem foi enviada pela UAZAPI/WhatsApp e nenhuma aba WhatsApp foi utilizada.

## Revalidação C15 — 10/09/2026

- O catálogo do filtro continuou carregando as etiquetas disponíveis após o deploy final.
- A seleção de `orcamento-feito` confirmou a navegação pelo seletor e o filtro de etiqueta existente, sem alteração de dados.
- O vídeo/áudio correto do bug visual continua pendente: o único MP4 encontrado foi identificado como clipe não relacionado, sem Chatwoot e sem fala. A análise dessa parte exige o reenvio do arquivo correto ou seu caminho local.
