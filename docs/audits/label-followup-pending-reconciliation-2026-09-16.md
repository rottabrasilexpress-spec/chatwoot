# Auditoria de pendências — etiquetas, contadores e Follow-up

Data: 16/09/2026
Escopo: reconciliar pendências registradas no contexto do Chatwoot Rotta, verificar o código publicado e corrigir somente defeitos comprovados.

## Resultado executivo

As pendências históricas de sincronização de etiquetas e atualização do Follow-up foram reavaliadas. Duas falhas reais foram encontradas no workflow ativo do n8n e corrigidas:

1. O índice parcial por telefone e etapa era declarado, mas não era incluído no lote final de SQL. Isso permitia duplicidade quando o mesmo cliente aparecia em conversas diferentes.
2. O estado da conversa podia ignorar um segundo evento diferente recebido no mesmo `source_updated_at` (mesmo segundo). Isso explicava a corrida de adicionar/remover ou trocar etiquetas rapidamente.

Também foi confirmado no frontend que uma mutação de etiqueta só publica o refresh do Follow-up após a confirmação da API; em falha, o estado é reconciliado pela leitura de etiquetas e a UI sinaliza erro.

## Correções aplicadas

- Workflow `Rotta Chatwoot — Follow-up Contextual v1`, ID `utaNsnFUZYBYDf5S`:
  - índice único parcial ativo por `(phone, source_label)` incluído no SQL executado;
  - deduplicação por conversa/etapa preservada;
  - `ON CONFLICT (job_id) DO NOTHING` preservado para reentrega do mesmo evento;
  - coluna `last_received_at` adicionada de forma idempotente;
  - eventos com o mesmo timestamp de origem passam a ser ordenados pelo horário efetivo de recebimento (`clock_timestamp()`), evitando que o segundo evento seja descartado;
  - workflow ativo e draft conferidos iguais na versão publicada `b9821cb7-2908-4c32-81bc-2092596ed1a6`.
- Frontend:
  - menu reorganizado para `Follow-up → Etiquetas → Pergunte para IA` quando a IA global estiver habilitada;
  - nenhum outro comportamento funcional foi alterado nesta rodada.

## Evidências e testes

- Vitest focalizado: 6 arquivos, `45/45` testes aprovados.
- ESLint focalizado: `0` erros.
- `git diff --check`: aprovado.
- Build Vite: `5.100` módulos transformados, concluído; somente avisos já conhecidos de Browserslist e tamanho de chunks.
- Validação do nó n8n: `valid: true`, sem warnings novos.
- Regressão diferencial sintética do código real do nó:
  - antes da correção: índice por telefone ausente;
  - depois da correção: índice por telefone presente;
  - evento diferente no mesmo segundo: rejeitado pela regra antiga e aceito pela regra atual quando chega depois;
  - nenhum webhook de produção foi disparado e nenhum dado, etiqueta, mensagem ou contato foi alterado pelo teste.
- O frontend emite `ROTTA_FOLLOW_UP_REFRESH` após a resposta bem-sucedida de `mutateLabels` e `updateLabels`, e o Follow-up reage a esse evento com refresh agendado.

## Pendências que não são defeitos confirmados

- Endpoint Enterprise opcional `/enterprise/api/v1/accounts/1/limits` retornar `404`: comportamento conhecido do build comunitário; não impacta inbox, etiquetas ou Follow-up.
- Eventos `unknown` com `422/NoMethodError` registrados anteriormente: continuam sendo anomalia de telemetria sem identificadores confiáveis. Não é seguro aceitar ou transformar esses payloads por suposição; a investigação exige payload redigido e instrumentação própria.
- Ruby/Bundler e integração Rails não estão disponíveis neste host; os testes Rails locais não foram declarados como executados.
- Um stress test destrutivo com alterações reais rápidas em vários clientes não foi executado para não modificar produção. A proteção foi verificada por testes focalizados e pela geração do SQL real do workflow. O próximo teste operacional deve usar fixture isolado ou ambiente de homologação.

## Veredito

Não permanece uma falha conhecida no mecanismo de deduplicação por telefone/etapa ou na ordenação de eventos de etiqueta recebidos no mesmo segundo. A atualização visual depende da entrega normal do webhook/Action Cable; quando um evento externo não chega, a reconciliação periódica e a montagem da Sidebar continuam sendo os fallbacks documentados.

Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/dashboard) ↔ workflow n8n `utaNsnFUZYBYDf5S`.

## Verificação complementar — 16/09/2026

- Obsidian: o MCP específico do Obsidian não está exposto nesta sessão; a nota local foi conferida diretamente e permanece a fonte de contexto operacional.
- GitHub: o commit funcional `1bb6f05f934971a1b7683e0b43cec18b0c33938c` e as atualizações documentais desta auditoria estão publicados em `origin/rotta-custom-v1`; a conferência final confirmou `HEAD` local igual ao branch remoto, com pushes fast-forward e sem force push.
- n8n: o workflow `utaNsnFUZYBYDf5S` está ativo, com draft e versão publicada iguais em `b9821cb7-2908-4c32-81bc-2092596ed1a6`, 28 nós.
- EasyPanel: `/health` respondeu HTTP 200, mas o histórico visual do painel não pôde ser lido nesta sessão (timeout nas sessões Chrome e Edge). Portanto, o deploy/redeploy do commit `1bb6f05f` continua não confirmado no painel; não deve ser tratado como implantado só por o commit estar no GitHub.
- Reclassificação de histórico: as pendências antigas de calculadora/Google/IA/preço dos checkpoints C86, C87, C90 e C96 foram superadas pelos C97, C98 e C100, que registram Google Routes/Places, IA e preço testados live. O envio real pelo WhatsApp não foi exercitado nesta auditoria e permanece sem prova de transmissão, sem ser tratado como falha por inferência.
- Reclassificação de histórico: os bloqueios temporários de chave/adaptador/publicação dos C107–C111 foram superados pelo Estado final C113; a IA global respondeu `OK` live e o adaptador de Follow-up está registrado. Os registros antigos permanecem apenas como histórico.
- Reclassificação de histórico: as provas visuais inicialmente pendentes para Caio nos C78/C139/C140 foram superadas pela prova independente do C79, com popup/card e filtro por destinatário confirmados.
- Nenhuma alteração de código, workflow, produção, conversa, etiqueta, follow-up, credencial ou mensagem foi feita nesta verificação.

## Verificação direta das abas — 16/09/2026

- EasyPanel, serviço `n8nsaas / chatwoot-rotta`, página de Implantações: histórico visual carregado. As entradas visíveis estavam verdes, com sucesso, incluindo `fix(search): show fallback identity for nameless contacts`, `build(frontend): publish current conversation fixes`, `fix(search): retain local matches for normalized conversation queries` e `fix(rotta): harden audio sends and remove conversation status actions`.
- A tela do painel não expôs o hash do commit nessas linhas; portanto, a confirmação é de sucesso das implantações exibidas, sem vincular visualmente a entrada mais recente ao commit `1bb6f05f` por inferência.
- HTTP somente leitura: `GET /health` retornou `200` com `{"status":"woot"}`; a rota exata do Chatwoot `/app/accounts/1/conversations/2463` retornou `200` e HTML do Chatwoot.
- A aba exata mencionada do Chatwoot no Edge (`1026731986`) não pôde ser capturada pelo controle visual após duas tentativas de recuperação; o timeout do navegador não foi tratado como falha da aplicação, especialmente porque a rota respondeu `200` por HTTP.
- Nenhum botão de deploy, reinício, exclusão, mutação de conversa, mensagem, etiqueta, follow-up, credencial ou dado de produção foi acionado.

## Ajuste do atalho de envio — 16/09/2026

- Escopo: tornar o envio por `Enter` o comportamento padrão para todos os agentes, preservando `Shift + Enter` para quebra de linha e sem substituir uma preferência explícita de `Ctrl/Cmd + Enter`.
- Implementação: `useUISettings.isEditorHotKeyEnabled` agora usa `Enter` como fallback quando `editor_message_key` não está definido. O composable é compartilhado pelo ReplyBox da conversa e pelo fluxo de nova conversa; portanto, os dois pontos passam a seguir o mesmo padrão.
- Compatibilidade: uma preferência já gravada como `cmd_enter` continua sendo respeitada. Não houve migração, alteração de agente, mensagem, conversa, etiqueta, Follow-up ou credencial.
- Testes: `useUISettings.spec.js` e `FullEditor.spec.js` passaram juntos, `121/121`; ESLint focalizado passou; `git diff --check` passou; build Vite passou com `5.100` módulos transformados; `verify:manifest-assets` confirmou `240` assets.
- Publicação: commit funcional `e8725e50` (`fix(composer): default message send to enter`) publicado em `origin/rotta-custom-v1`, sem force push.
- Deploy: EasyPanel concluiu `Success` em `16/09/2026 14:33:47 UTC`; Rails, Sidekiq e Sidekiq UAZAPI foram iniciados. A primeira leitura durante o restart retornou `502` transitório; a checagem seguinte confirmou `/health` HTTP `200` com `{"status":"woot"}` e `/app/login` HTTP `200`.
- Teste live: a interface Chatwoot carregou, exibiu `Enviar (↵)` no compositor da conversa e passou de `Reconectando...` para `Reconectado`. Nenhuma mensagem real foi enviada.
- Veredito: ajuste implantado e validado no serviço live. O padrão novo é Enter; agentes com preferência explícita por Ctrl/Cmd+Enter permanecem inalterados por segurança.

Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [commit `e8725e50`](https://github.com/rottabrasilexpress-spec/chatwoot/commit/e8725e50) ↔ [branch `rotta-custom-v1`](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [deploy EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/conversations/48).
