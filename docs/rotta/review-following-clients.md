# Revisão individual e acompanhamento compartilhado

Registro da extensão aprovada em 06/10/2026: acompanhamento entre agentes da mesma conta e revisão individual. Implantação pendente; este documento descreve o código local e não confirma disponibilidade em produção.

## Compatibilidade com o sistema existente

O contexto de `PRODUCT.md`, o sistema de `DESIGN.md` e o contrato de `.codex/review-following-brief.md` orientam esta extensão. A referência Impeccable `reference/document.md` foi aplicada para documentar decisões observáveis, sem substituir a identidade existente. Este documento é a única escrita desta tarefa; o `DESIGN.md` incumbente permanece preservado.

Achado de compatibilidade: a extensão mantém os tokens `n-*`, tipografia compacta, superfícies nativas, divisórias de um pixel, foco visível e navegação para a conversa nativa. A separação azul/teal organiza duas funções dentro da linguagem operacional existente. A compatibilidade descrita é sustentada pela leitura do código; não representa verificação visual ou regressão em produção.

## Layout e leitura

Em `ReviewResumeView.vue`, duas colunas equilibradas aparecem a partir do breakpoint `xl`; abaixo dele, inclusive no celular, as áreas ficam empilhadas. O contêiner usa largura máxima `max-w-7xl`, espaçamento `gap-6`, superfícies `n-solid-1`, bordas discretas e cantos `rounded-xl`.

| Área | Linguagem visual | Informação principal |
| --- | --- | --- |
| Revisão individual, à esquerda | Cabeçalho azul de marca, fundo `n-brand/10` e borda `n-brand/20` | Onde o agente parou, próximo contato, pontos por aba e últimos cinco pontos |
| Acompanhamento da equipe, à direita | Cabeçalho teal, fundo `n-teal-2`, texto `n-teal-11` e borda `n-teal-4` | Nome, avatar, horário, autoria e última mensagem pública de cada conversa acompanhada |

Os cards distinguem autoria como “Cliente” ou “Nossa resposta”; não identificam nominalmente o agente remetente. A prévia remove marcação HTML e ocupa até três linhas. Sem texto, usa descrição de áudio, imagem, vídeo, arquivo ou ligação; sem mensagem pública, informa essa ausência. Carregamento, vazio, erro, tentativa novamente e abertura em andamento têm estados explícitos. Botões de ação usam foco visível e ficam desabilitados durante operações relevantes.

## Revisão individual e próximo automático

Abrir uma conversa pela lista registra automaticamente um ponto por conta, agente e visualização. O próximo contato é calculado a partir da sequência original já carregada, sem exigir marcação manual. “Próximo:” e “Continuar revisão” permitem abrir esse contato; o registro automático não navega sozinho.

`createReviewPoint`, em `conversationReview.js`, captura até 200 candidatos posteriores à conversa aberta em `remaining`. Mensagens novas podem reordenar a lista ao vivo, mas não reordenam nem acrescentam candidatos nessa sequência. Francine → Eldon → Graziela continua nessa ordem mesmo quando chegam novas mensagens. Abrir outra conversa manualmente inicia um novo ponto; retomar consome a sequência existente e preserva seu ID.

`useConversationReview.js` consulta cada candidato e verifica elegibilidade no contexto salvo. Candidatos inexistentes ou sem acesso (404/403) e candidatos que deixaram de corresponder ao contexto são pulados; Menções e Participando têm confirmação adicional no servidor. Falhas de rede exibem erro sem consumir o candidato. Ao terminar, a interface informa o fim da sequência carregada, não a revisão de toda a conta.

Depois de abrir o candidato, a extensão salva o ponto na categoria operacional de destino, com status e atribuição `all`, sem filtros de caixa, equipe ou pasta. A ordem dos candidatos restantes continua sendo a original. Essa navegação substitui, nesta extensão, a descrição de restauração integral da rota/contexto original em `conversation-review-resume.md`; aquele documento não foi alterado nesta tarefa.

Os pontos continuam individuais em `conversation_review_states`, com índice por conta/usuário. O acompanhamento compartilhado não transforma esses pontos em estado da equipe.

## Navegação operacional

Tanto a retomada quanto a abertura de um card usam `reviewWorkspacePath` e `reviewWorkspaceDestination`, em `reviewWorkspace.js`. O card consulta a conversa novamente antes de navegar, para usar sua categoria atual.

O destino padrão é **Todos**. Quando houver mais de uma categoria aplicável, prevalece esta ordem:

| Prioridade | Condição | Destino |
| --- | --- | --- |
| 1 | `rotta_archived`, `arquivado` ou `arquivados` | Arquivados (`archived`) |
| 2 | `finalizados` | Finalizados |
| 3 | `clientes-fechados` | Clientes Fechados |
| 4 | `emitir-contrato` | Emitir Contrato |
| 5 | `caio-atencao` | Caio Atenção |
| Padrão | Nenhuma das condições anteriores | Todos |

Etiquetas comuns, como `kelvin`, não desviam a abertura de Todos. Arquivados prevalece inclusive sobre etiquetas terminais. A classificação apenas escolhe a rota; não altera as etiquetas da conversa.

## Botão e confirmação

`FollowingButton.vue`, integrado ao cabeçalho nativo da conversa, alterna entre “Acompanhar cliente” e “Acompanhando”. O estado ativo usa teal e `aria-pressed`; durante a gravação aparece “Salvando…”. Enquanto o estado inicial não foi confirmado, o botão fica desabilitado e uma falha permite tentar novamente.

Após confirmação da API, o toast de inclusão informa: “Cliente adicionado ao acompanhamento da equipe. Veja em Retomar revisão.” A remoção informa: “Cliente retirado do acompanhamento da equipe.” O botão de remover no card usa a mesma operação e confirmação. Falhas exibem o erro e não anunciam sucesso.

## Persistência compartilhada e permissões

`ConversationFollowing` persiste o acompanhamento em tabela própria `conversation_followings`, criada por `20261006150000_create_conversation_followings.rb`. O índice único `(account_id, conversation_id)` representa uma seleção compartilhada por conta, sem proprietário individual. Remover encerra o acompanhamento da equipe nessa conta.

Esse estado é independente das etiquetas, dos pontos individuais, da IA e dos fluxos de follow-up. GET da lista e GET/PATCH/DELETE da conversa usam `/api/v1/accounts/:accountId/conversation_followings`. PATCH cria ou reutiliza o registro; DELETE remove apenas esse vínculo de acompanhamento.

Compartilhamento respeita acesso: o controller restringe a lista por conta, caixas/equipes e política de visualização. Operações individuais autorizam a conversa, e o broadcast de mudança vai aos usuários autorizados a vê-la. “Compartilhada com a equipe” não significa liberar conversas sem permissão.

## Mensagens públicas, paginação e atualização

O backend seleciona exclusivamente mensagens `private: false` dos tipos `incoming` e `outgoing`, escolhendo a mais recente por horário e ID. Notas privadas e mensagens de atividade não entram nas prévias. O conteúdo retornado é limitado a 1.000 caracteres. O composable aplica a mesma restrição a eventos recebidos.

A lista usa paginação por cursor `before_id`, ordenada pelo ID do vínculo de acompanhamento em ordem decrescente. O controller consulta 31 registros para detectar continuação, retorna até 30 cards e fornece `has_more` e `next_cursor`. A filtragem final por permissão pode resultar em menos de 30 cards. “Mostrar mais clientes” acrescenta a página seguinte sem duplicar cards.

`actionCable.js` encaminha `conversation.following_changed` para o estado compartilhado e eventos de mensagens para as prévias. `useConversationFollowing.js` atualiza a última mensagem pública dos cards carregados por push, impede que resposta antiga substitua prévia mais nova e trata inclusão/remoção com invalidação de leituras antigas.

A lista carrega na entrada e na mudança de sessão; foco da janela, retorno à visibilidade e `WEBSOCKET_RECONNECT` disparam atualização quando a página está visível. O botão do cabeçalho também reconfirma seu estado no foco, retorno à visibilidade e reconexão. Eventos de acompanhamento agrupam a releitura com debounce de 500 ms. Há atualização manual e tentativa novamente; não há polling periódico. Esse debounce é acionado por eventos, não um intervalo de consulta em repouso.

## Evidências e validação pendente

As evidências desta documentação são os componentes `ReviewResume.vue`, `FollowingClients.vue`, `FollowingButton.vue` e `ReviewResumeView.vue`; os helpers/composables citados; o controller, modelo e migration de acompanhamento; e a integração de Action Cable. A leitura foi feita no código local, sem navegador, comandos Docker, acesso a segredos ou implantação.

Status confirmado para a implementação: **51 testes JavaScript frontend passaram**, após **49 nas verificações anteriores**. O resultado foi confirmado pelo usuário; esta atualização de documentação não reexecutou a suíte. A configuração `.codex/review-vitest.config.mjs` inclui os specs de revisão, roteamento, acompanhamento e seus componentes.

Specs Ruby foram escritos em `spec/requests/api/v1/accounts/conversation_followings_spec.rb` e `spec/requests/api/v1/accounts/review_points_spec.rb`; não puderam ser executados localmente por ausência de Ruby. A aplicação das migrations, execução de backend e confirmação do fluxo integrado permanecem pendentes no ambiente de implantação.

Antes de liberar, confirmar a sequência original apesar de mensagens novas, a prioridade de destinos, inclusão/remoção visível entre agentes autorizados, isolamento entre contas, exclusão de notas privadas, cursor com mais de 30 vínculos e recuperação por foco/reconexão. Confirmar também os fluxos nativos de conversa, envio, etiquetas e follow-up. **Deployment pendente: não há confirmação de recurso live.**
