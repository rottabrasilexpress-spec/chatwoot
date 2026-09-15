# Auditoria realtime do Chatwoot e concorrência do Follow-up — 2026-09-15

## Escopo

Auditoria live do Chatwoot Rotta e do workflow `Rotta Chatwoot — Follow-up Contextual v1`, usando exclusivamente a UAZAPI para o teste real no contato autorizado `5511965927865` (conversa `#2143`). O objetivo foi confirmar carregamento, histórico, atualização realtime, envio, troca de etiquetas e comportamento com dois workers simultâneos.

## Carregamento do Chatwoot

- `GET /health` respondeu HTTP `200` com `{"status":"woot"}`.
- O dashboard respondeu HTTP `200`.
- Edge e Chrome renderizaram o shell do Chatwoot, a lista e a conversa `#2143`.
- Após um envio real, o navegador exibiu temporariamente `Desconectado`; a conexão realtime se recuperou sozinha, sem F5, e a interface voltou a refletir a nova mensagem.
- Uma recarga controlada posterior saiu de `Carregando conversas` e renderizou novamente a conversa, o histórico e a lista. Não houve banner persistente de desconexão.
- A lista exibiu `Todas as conversas carregadas 🎉` no cenário verificado e não ficou presa no spinner.

Conclusão: não há evidência de indisponibilidade atual do serviço. O sintoma foi uma combinação de estado transitório do ActionCable durante atividade/deploy e sessão/cache do navegador; o endpoint e o frontend publicados estavam saudáveis.

## Testes reais UAZAPI/Chatwoot

### Trilha de contato

- `contato-instantaneo` foi aplicado ao contato, criou job e o worker enviou uma mensagem real.
- A etiqueta foi trocada para `primeiro-contato` após confirmação HTTP 200 da UAZAPI.
- As etapas seguintes `segundo-contato`, `terceiro-contato` e `ultimo-contato` foram observadas no histórico do job durante a auditoria anterior; a sequência de troca foi monotônica.

### Trilha de orçamento

- `orcamento-instantaneo` foi aplicado, processado e enviado pela UAZAPI; a etiqueta mudou para `orcamento-feito`.
- O teste concorrente final colocou o job de `orcamento-feito` como devido e iniciou dois workers simultaneamente.
- Apenas o worker `605380` reivindicou o job e concluiu com `Finalizar Job Enviado`/`status=sent`; o worker `605381` terminou sem item disponível.
- A mensagem real apareceu no histórico do Chatwoot como `message44096`, às `02:29` locais. Não houve segunda mensagem correspondente ao segundo worker.
- O job posterior de `orcamento-tentativa-2` foi cancelado depois do teste; não ficou envio agendado pendente para o contato.

### Janelas de orçamento

- `orcamento-10-dias` foi executado com envio real e transição confirmada.
- `orcamento-5-dias` e `orcamento-15-dias` foram validados como agendamento/remoção sem envio adicional, conforme auditoria live anterior.
- A configuração persistida permanece: 5 dias = 7.200 minutos, 10 dias = 14.400 minutos, 15 dias = 21.600 minutos.

## Bug encontrado e correção publicada

O teste com dois workers reproduziu risco de concorrência: antes do endurecimento, duas execuções (`605369` e `605371`) haviam recebido o mesmo job. Mesmo que uma decisão da IA tenha evitado um segundo envio naquele caso, o desenho permitia duplicidade se as duas decisões fossem positivas.

Correção aplicada no n8n, workflow `utaNsnFUZYBYDf5S`:

- `Reivindicar Próximo Follow-up` agora usa `UPDATE ... RETURNING` atômico, condição `status='pending'`, `FOR UPDATE SKIP LOCKED` e `pg_try_advisory_xact_lock` transacional.
- A estrutura real da tabela foi preservada usando `error_message`; uma primeira versão de teste foi rejeitada pelo banco antes de reivindicar qualquer job porque usava `last_error`. O nome foi corrigido e republicado.
- A versão ativa publicada após a correção foi `4a00ffca-ff9a-4a87-9e5c-6f5a1f04c58b`.
- O teste final de dois workers comprovou uma única reivindicação e uma única mensagem.

## Estado final

- Conversa `#2143`: etiqueta visual `Arquivado`, estado resolvido, sem job pendente.
- Admin do Follow-up após limpeza: registros do contato somente em histórico (`sent_history`); nenhum job operacional pendente/processing.
- O Chatwoot foi recarregado e permaneceu visualmente funcional.

## Risco residual

O modelo DeepSeek `deepseek/deepseek-v4-flash-0731` ainda pode levar cerca de 100–130 s em históricos muito extensos. O lock impede duplicidade, mas a fila pode atrasar se muitos jobs vencerem simultaneamente; a próxima otimização deve reduzir o contexto enviado ao modelo e medir throughput antes de aumentar paralelismo.

## Linhas conectadas

[[Chatwoot Rotta — contexto e estado]] ↔ [workflow n8n](https://saas.via-cargo.com/workflow/utaNsnFUZYBYDf5S) ↔ [GitHub `rotta-custom-v1`](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot #2143](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/conversations/2143).
