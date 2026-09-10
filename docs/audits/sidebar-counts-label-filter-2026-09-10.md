# Auditoria — contadores do sidebar e filtro por etiquetas

Data: 2026-09-10  
Branch: `rotta-custom-v1`  
Commits de implementação: `b03b787`, `80db589`, `93bb13a`, `37bcc47`

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
- Na data do C15, o vídeo correto ainda estava pendente; essa pendência foi encerrada no C16 com a análise do arquivo correto e a correção visual correspondente.

## Revalidação C16 — apresentação visual do filtro por etiquetas — 10/09/2026

- O vídeo correto foi analisado em `C:\Users\User\AppData\Local\Packages\Microsoft.ScreenSketch_8wekyb3d8bbwe\TempState\Recordings\20260910-1638-49.5863089.mp4`: duração `79,3 s`, inspeção visual em intervalos de 5 s e transcrição integral do áudio em português. A filtragem funcionava, mas o seletor superior exibia slugs (`segundo-contato`, `kelvin`) enquanto o painel da conversa exibia nomes amigáveis e cores.
- Causa confirmada: `ChatList.vue` montava as opções com o título técnico e descartava a cor; `FilterSelect.vue` não renderizava cor; `RottaLabelsShortcut.vue` mantinha uma apresentação local separada.
- Correção: `rottaLabelPresentation.js` centraliza nome/cor; o filtro e o painel usam a mesma apresentação; `FilterSelect` exibe ponto colorido no gatilho e em cada opção. O `value` técnico continua sendo o slug para preservar as rotas `/label/:label` e o contrato do backend.
- Regressão: o teste focalizado foi primeiro executado em estado RED pela ausência do helper e depois passou GREEN (`1/1`) com `segundo-contato` → `Segundo contato` e `kelvin` → `Kelvin`, mantendo os valores técnicos.
- Build/lint: Vite transformou `5.078` módulos; lint semântico dos seis arquivos alterados ficou com `0` erros e somente os dois avisos dinâmicos i18n já conhecidos. O lint completo continua limitado pelos erros de CRLF globais do checkout Windows.
- Publicação: `93bb13a fix(rotta): match label filter presentation` foi seguido por `37bcc47 build(rotta): include generated vite assets`, que adicionou somente os 14 artefatos Vite referenciados pelo manifesto e ignorados pelo padrão `public/vite*`. Ambos foram enviados para `origin/rotta-custom-v1`.
- Deploy: o primeiro deploy revelou `404` dos novos assets após um reload limpo; a correção de empacotamento foi publicada e o segundo deploy concluiu com sucesso. O serviço passou por uma breve janela de inicialização e voltou saudável.
- Chatwoot real: após reload limpo, o menu exibiu `Segundo contato`, `Kelvin`, `Orçamento 10 dias` e demais nomes amigáveis, sem slugs visíveis; o DOM confirmou pontos coloridos nas opções. `Segundo contato` abriu `/app/accounts/1/label/segundo-contato` com ponto laranja no gatilho; `Kelvin` abriu `/app/accounts/1/label/kelvin` com ponto roxo; a visão foi restaurada para `/app/accounts/1/dashboard`.
- Segurança: nenhum WhatsApp Web foi utilizado, nenhuma mensagem foi enviada e nenhuma etiqueta, conversa, contato, fluxo n8n ou integração UAZAPI foi alterada durante a validação.
