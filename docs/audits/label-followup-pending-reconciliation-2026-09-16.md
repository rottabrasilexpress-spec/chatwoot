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
- GitHub: `origin/rotta-custom-v1` aponta para `1bb6f05f934971a1b7683e0b43cec18b0c33938c` (`fix(rotta): reconcile label follow-up pending items`), sem divergência entre `HEAD` local e o branch remoto; o push foi fast-forward, sem force push.
- n8n: o workflow `utaNsnFUZYBYDf5S` está ativo, com draft e versão publicada iguais em `b9821cb7-2908-4c32-81bc-2092596ed1a6`, 28 nós.
- EasyPanel: `/health` respondeu HTTP 200, mas o histórico visual do painel não pôde ser lido nesta sessão (timeout nas sessões Chrome e Edge). Portanto, o deploy/redeploy do commit `1bb6f05f` continua não confirmado no painel; não deve ser tratado como implantado só por o commit estar no GitHub.
- Nenhuma alteração de código, workflow, produção, conversa, etiqueta, follow-up, credencial ou mensagem foi feita nesta verificação.
