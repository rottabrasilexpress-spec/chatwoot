# Auditoria — contadores do sidebar e filtro por etiquetas

Data: 2026-09-10  
Branch: `rotta-custom-v1`  
Commit de implementação: `b03b787`

## Escopo

- Remover números residuais de `ORÇAMENTOS`, `Caio Atenção` e `Clientes Fechados` quando a etiqueta deixa de existir ou fica sem contatos.
- Adicionar um filtro no topo da lista de conversas que exibe todas as etiquetas da conta e navega para a lista filtrada.
- Não alterar conversas, etiquetas, mensagens, n8n, UAZAPI ou WhatsApp.

## Diagnóstico e correção

O estado Vuex de contagens era atualizado apenas com as etiquetas encontradas e a mutação fazia merge com o mapa anterior. Assim, um valor antigo sobrevivia quando uma etiqueta era removida ou zerada.

`labels/getSidebarCounts` agora sempre publica as três chaves (`budget`, `caioAttention`, `closedClients`), normalizando ausências para zero. `SET_SIDEBAR_LABEL_COUNTS` substitui o mapa completo, eliminando valores stale.

O seletor de etiquetas foi adicionado a `ChatListHeader.vue`. A lista vem de `labels/getLabels`; a seleção usa a rota existente `/label/:label`, que já envia `labels` para `ConversationFinder`. A opção `Filtrar por etiqueta` retorna a `/dashboard`.

## Evidências

- Regressão antes do fix: com contagem anterior de `1`, a ação publicava somente `{ budget: 0 }`; `caioAttention` e `closedClients` ficavam sem atualização.
- Após o fix: teste focalizado `sidebarLabelCounts.spec.js` passou `4/4`.
- Build Vite: `5.077` módulos transformados, concluído.
- GitHub: `b03b787` enviado para `origin/rotta-custom-v1`.
- Easypanel: deploy `fix(rotta): clear sidebar counts and add label filter` concluiu com `Compose implantado`; o serviço voltou saudável.
- Chatwoot real: após reload, `ORÇAMENTOS` e `Caio Atenção` não exibiram badges fantasmas. O botão `Filtrar por etiqueta` abriu o catálogo completo; `kelvin` e `primeiro-contato` produziram as rotas esperadas; limpar retornou para `/app/accounts/1/dashboard`.

## Limitações e segurança

- O vídeo citado para o bug visual das etiquetas não está nos anexos acessíveis desta sessão; somente imagens foram localizadas. Nenhuma alteração visual/auditiva foi inferida.
- ESLint direcionado ficou limitado pelo CRLF global do checkout Windows e avisos i18n dinâmicos preexistentes; `git diff --check` passou e o build confirmou a compilação.
- Nenhuma mensagem foi enviada pela UAZAPI/WhatsApp e nenhuma aba WhatsApp foi utilizada.
