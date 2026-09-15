# Auditoria real do Follow-up e do carregamento — 2026-09-15

## Escopo

- Número autorizado para envio real: 5511965927865, conversa Chatwoot #2143.
- Trilhas executadas: contato instantâneo, primeiro, segundo, terceiro e último contato; orçamento instantâneo e orçamento feito; janelas de 5, 10 e 15 dias.
- Observação: não foi feito disparo real para outro cliente, porque a autorização de envio ficou restrita a esse número.

## Correção aplicada no workflow

Workflow n8n Rotta Chatwoot — Follow-up Contextual v1, ID utaNsnFUZYBYDf5S:

- Versão ativa: 1e1e93fd-15fe-4b15-a3f2-860a60139b9c.
- Modelo preservado: deepseek/deepseek-v4-flash-0731.
- reasoning desabilitado para a tarefa curta e estruturada de decidir/enviar; max_tokens=450; timeout HTTP=30 s.
- O parser agora registra finish_reason, ausência de JSON e falha de interpretação como llm_error.
- Falha de interpretação não cancela silenciosamente o job: agenda nova tentativa em cinco minutos até o limite de tentativas; depois registra failed_llm_response.
- Claim atômico permanece protegido por UPDATE ... RETURNING, SKIP LOCKED e advisory lock.

## Bug reproduzido e retestado

Antes da correção final, os workers 607245, 607321 e 607416 chegaram ao limite de raciocínio/token e retornaram finish_reason=length sem JSON. O comportamento anterior transformava essa falha em cancelamento silencioso.

Após reasoning.enabled=false:

- O worker 607459 processou Segundo contato com finish_reason=stop, reasoning_tokens=0, should_send=true, enviou pela UAZAPI e registrou Chatwoot message44233.
- O worker 607482 processou Terceiro contato com finish_reason=stop, reasoning_tokens=0, should_send=true, enviou e registrou message44240.
- Os testes seguintes também terminaram sem finish_reason=length.

## Trilha de contato — envio real

| Etapa | Worker | Resultado |
|---|---:|---|
| Contato instantâneo | 607355 | UAZAPI aceita; message44221; etiqueta avançou para Primeiro contato |
| Primeiro contato | 607385 | UAZAPI aceita; message44226; etiqueta avançou para Segundo contato |
| Segundo contato | 607459 | UAZAPI aceita; message44233; etiqueta avançou para Terceiro contato |
| Terceiro contato | 607482 | UAZAPI aceita; message44240; etiqueta avançou para Último contato |

O painel Follow-up atualizou sem F5 a cada transição. Depois da remoção da etiqueta final, ficou com Na fila 0, Prontos agora 0, Etapas ativas 0 e visão vazia.

## Trilha de orçamento

- Orçamento instantâneo: worker 607529 enviou pela UAZAPI e registrou message44248; a etiqueta avançou para Orçamento feito.
- Orçamento feito: o modelo retornou should_send=false porque o histórico mostrava que o cliente havia pedido encaminhamento ao setor responsável e não queria continuar respondendo perguntas. O job foi finalizado como cancelled_without_send, sem nova mensagem ou avanço indevido. Isso é uma trava de segurança contextual, não uma falha.

## Janelas de 5, 10 e 15 dias

As três etiquetas foram aplicadas e removidas pela UI, com atualização realtime:

- Orçamento 5 dias: painel mostrou disparo em 20/09 e próxima etapa Orçamento 10 dias.
- Orçamento 10 dias: painel mostrou disparo em 25/09 e próxima etapa Orçamento 15 dias.
- Orçamento 15 dias: painel mostrou disparo em 30/09 e próxima etapa Orçamento feito.

Após cada remoção, o painel voltou a zero. Nenhuma mensagem real extra foi enviada nessas janelas.

## Concorrência

Os workers 607599 e 607600 foram iniciados simultaneamente para o mesmo job. Apenas 607599 reivindicou e enviou; 607600 recebeu item vazio e não enviou. Não houve duplicidade.

## Estado final

- Consulta final do painel, execução 607623: nenhum job ativo para 5511965927865; total retornado na visão operacional: 1 registro não relacionado ao número autorizado.
- Chatwoot respondeu /health com HTTP 200 e {"status":"woot"}.
- /api respondeu HTTP 200 com queue_services=ok e data_services=ok.
- WebSocket wss://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/cable abriu corretamente.

## Diagnóstico do relato de carregamento

Não há indisponibilidade ativa no backend. Login, dashboard e assets responderam HTTP 200, e o endpoint /api confirmou serviços de fila e dados saudáveis. O ponto de atenção é o frontend: o bundle DashboardIcon entregue no primeiro carregamento tem 14.851.795 bytes e o CSS principal 1.546.004 bytes; ambos são enviados sem content-encoding observado. Isso pode deixar a tela em carregamento em conexões móveis ou após cache frio, embora não seja uma queda do Chatwoot.

Nenhuma alteração foi feita no container para esse diagnóstico. A correção recomendada, em mudança separada e com deploy controlado, é habilitar Brotli/gzip no proxy e dividir o bundle de ícones por rota antes de alterar qualquer comportamento funcional.

## Referências

- [Workflow n8n](https://saas.via-cargo.com/workflow/utaNsnFUZYBYDf5S)
- [Chatwoot #2143](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/conversations/2143)
- [Follow-up no Chatwoot](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/settings/labels/follow-up)
- [EasyPanel — deployments](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments)
- [Documentação do modelo DeepSeek V4 Flash 0731](https://openrouter.ai/deepseek/deepseek-v4-flash-0731)
