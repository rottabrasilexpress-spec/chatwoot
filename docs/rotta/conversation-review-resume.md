# Retomar revisão de conversas

Guia de operação e manutenção — 06/10/2026. Implantação ainda pendente; este documento não confirma disponibilidade em produção.

## Operação

Ao abrir uma conversa pela lista, o sistema registra automaticamente um ponto individual por conta, agente e visualização. A visualização inclui aba/tipo, etiqueta, caixa de entrada, equipe, pasta, status, atribuição e filtros. Resultados de busca não sobrescrevem o ponto da aba.

Use **Próximo:** na lista ou **Retomar revisão** na navegação, em `/app/accounts/:accountId/review-resume`. A página mostra pontos por aba e os últimos cinco pontos. **Continuar revisão** abre a próxima conversa elegível pela rota nativa do contexto original, restaurando status, atribuição e filtros; pastas continuam usando sua consulta nativa.

A sequência original de próximos IDs (`nextIDs`, representada por `remaining` no código) é capturada somente entre as conversas já carregadas após a conversa aberta, com máximo de 200 entradas. Novas mensagens podem reordenar a lista ao vivo, mas não alteram nem acrescentam IDs nessa sequência. Retomar apenas consome seu início; abrir outra conversa manualmente cria um novo ponto. Exemplo: Francine → Eldon → Graziela continua nessa ordem mesmo se Francine ou Eldon receberem mensagem e subirem na lista.

Na retomada, candidatos sem acesso ou inexistentes (403/404), arquivados fora da aba Arquivados ou que deixaram de corresponder ao contexto são pulados. Menções e Participando têm confirmação adicional de pertencimento no servidor. Ao esgotar os candidatos, aparece o fim da sequência carregada; abra uma conversa da lista para iniciar outra. Isso não representa revisão de todas as conversas da conta.

## Persistência e recuperação

- Estado isolado por conta/agente; até 24 visualizações e histórico dos cinco pontos mais recentes. Retomar o mesmo ponto atualiza sua posição no histórico, sem duplicar seu ID.
- Fila compartilhada entre componentes da sessão, com gravação após 200 ms do último registro e lotes sequenciais de até cinco pontos. Não há polling. Leituras simultâneas compartilham a mesma requisição; **Atualizar pontos** força uma leitura após tentar esvaziar a fila.
- Falha de leitura: usar **Tentar novamente**. Falha de gravação: o ponto fica pendente em memória e a interface pede nova tentativa antes de sair. A fila em memória não garante recuperação após fechar ou recarregar a página antes da gravação.
- **Tentar novamente** tenta gravar pendências e depois reler os pontos. Falha de rede ao abrir o próximo candidato não avança a sequência; repetir **Continuar revisão**. Durante a abertura, o botão fica desabilitado para evitar navegação dupla.
- Respostas antigas de leitura não devem sobrescrever cliques pendentes. Trocar conta/agente durante uma operação não deve navegar nem gravar no contexto novo.

O recurso não altera n8n, etiquetas, follow-up nem envio de mensagens. Usa a conversa e as rotas nativas. A identidade visual permanece a de [DESIGN.md](../../DESIGN.md): tokens `n-*`, densidade operacional, estados explícitos e foco visível; nenhuma nova identidade é introduzida.

## Manutenção e implantação pendente

A migration `db/migrate/20261006120000_create_conversation_review_states.rb` cria a tabela própria `conversation_review_states`, com JSONB `data`, referências a conta/usuário e índice único `(account_id, user_id)`. Não armazena os pontos em `ui_settings` nem modifica registros de conversas. GET e PATCH autenticados usam `/api/v1/accounts/:accountId/review_points`; uma leitura inicial vazia não cria registro.

No ambiente de implantação, com Ruby/Bundler do projeto e configuração de banco já disponíveis, executar a preparação padrão antes de liberar a funcionalidade:

```sh
bundle exec rails db:chatwoot_prepare
```

Validar a migration e os testes de backend nesse ambiente. Status informado nesta entrega: 24 testes frontend passaram; oito exemplos RSpec foram adicionados em `spec/requests/api/v1/accounts/review_points_spec.rb`, mas não foram executados localmente por ausência de Ruby. Esta etapa de documentação não reexecutou testes, migrations ou implantação.

Os testes frontend estão em `app/javascript/dashboard/helper/specs/conversationReview.spec.js`, `app/javascript/dashboard/composables/spec/useConversationReview.spec.js` e `app/javascript/dashboard/components-next/Conversation/Review/ReviewResume.spec.js`. O fluxo está em `useConversationReview.js`, `conversationReview.js`, `ReviewResume.vue` e na integração de `ChatList.vue`.

## Checklist de regressão e verificação manual

Executar em ambiente com a migration aplicada; os itens abaixo são verificações pendentes, não resultados de produção.

- [ ] Sequência: carregar Francine, Eldon e Graziela; abrir Francine; gerar nova mensagem em Francine/Eldon; confirmar que **Próximo:** segue Eldon e depois Graziela, apesar da reordenação ao vivo.
- [ ] Rotas: repetir em Todos, Arquivados, etiqueta, caixa, equipe, pasta, Menções e Participando; confirmar a rota nativa e o contexto original ao continuar. Abrir resultado de busca e confirmar que o ponto anterior da aba permanece.
- [ ] Filtros: salvar pontos com status, atribuição e filtro avançado (incluindo ID numérico de caixa); mudar os filtros; retomar cada ponto e confirmar sua restauração. Retirar um candidato do contexto e verificar que é pulado; confirmar que Arquivados não reaparece em Todos.
- [ ] Conta/agente: salvar pontos em duas contas e dois agentes; confirmar isolamento. Trocar conta durante leitura de candidato, navegação e gravação atrasada; confirmar que nenhuma operação abre ou grava no novo contexto.
- [ ] Reload: aguardar a gravação, recarregar a página e confirmar pontos/histórico e próximo ID original; retomar e recarregar novamente para confirmar avanço persistido. Testar também uma leitura antiga chegando após um clique salvo.
- [ ] Mobile: em largura de 360 px, abrir lista e página de retomada; verificar nomes longos, botões acessíveis, ausência de rolagem horizontal, mensagens de erro e foco de teclado. Confirmar navegação para a conversa nativa e retorno à lista.
- [ ] Erros: simular falha de GET/PATCH; confirmar aviso e **Tentar novamente**, sem perda de pendências enquanto a sessão está aberta. Simular falha de rede no candidato: não deve avançar. Testar 403/404: deve pular. Clique duplo não deve abrir duas conversas.
- [ ] Limites/requisições: realizar cliques rápidos e inspecionar lotes de até cinco após 200 ms; confirmar ausência de polling em repouso. Verificar histórico de cinco, retenção de 24 visualizações e sequência de até 200 candidatos carregados; sequência vazia desabilita continuar.
- [ ] Atendimento existente: confirmar abertura, envio único por teclado/botão, etiquetas e follow-up nos fluxos nativos; verificar que registrar/retomar pontos não dispara mensagem nem muda etiquetas, follow-up ou integrações n8n.
- [ ] Antes de liberar: executar os oito exemplos RSpec em ambiente com Ruby, concluir a checklist e registrar o resultado da implantação separadamente.
