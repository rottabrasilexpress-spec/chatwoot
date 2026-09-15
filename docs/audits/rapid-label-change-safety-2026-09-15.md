# Auditoria — segurança para alterações rápidas de etiquetas — 2026-09-15

## Pergunta e escopo

Verificar se o Chatwoot/Follow-up suporta (a) etiquetar conversas diferentes com intervalo médio de 2 s e (b) remover uma etiqueta e aplicar outra na mesma conversa em menos de 1 s. A auditoria foi somente leitura: nenhuma conversa, etiqueta, job ou configuração de produção foi alterada e nenhuma mensagem foi enviada.

## Conclusão

**A proteção não é completa para a sequência rápida na mesma conversa.** Há defesas contra eventos idênticos repetidos, jobs ativos duplicados e dois workers reivindicarem o mesmo job, mas elas não garantem ordenação dos eventos de etiquetas nem impedem um worker já iniciado de enviar depois do cancelamento.

Para conversas diferentes a cada 2 s, a amostra operacional observada é compatível com esse ritmo em condições normais; não foi um teste de carga e não certifica o comportamento sob pico.

## Evidências no Chatwoot

- useConversationLabels.js monta cada alteração a partir do conjunto atualmente salvo e envia a lista completa. O estado só é confirmado na resposta da API.
- store/modules/conversationLabels.js dispara os POSTs sem fila/mutex por conversationId; cada resposta grava seu próprio payload no store. O sinal global isUpdating não bloqueia novas chamadas.
- RottaLabelsShortcut.vue permite novos cliques enquanto a chamada anterior está pendente; o handler não aguarda nem desabilita a opção. Assim, requisições de uma mesma conversa podem competir e terminar fora da ordem pretendida.
- Em conversas diferentes, o cache é indexado por ID, então uma alteração não substitui diretamente a lista local de outra conversa. O risco restante é capacidade/ordenação do webhook compartilhado, que não foi testada sob carga.

## Evidências no workflow n8n ativo

- O conector rotta_n8n_mcp confirmou o workflow utaNsnFUZYBYDf5S, ativo, versão publicada 1e1e93fd-15fe-4b15-a3f2-860a60139b9c, 28 nós; versão ativa e draft coincidem.
- Normalizar Evento de Etiquetas cria identificador idempotente e o SQL verifica evento repetido, cancela jobs ativos de outra etapa e cria índices únicos parciais para jobs ativos. Isso reduz duplicatas.
- Porém, a gravação de estado (active_labels, stage_label, last_event_id) usa ON CONFLICT ... DO UPDATE sem comparar sequência/updated_at do evento e sem reconciliar primeiro com as etiquetas atuais do Chatwoot. Se o evento antigo terminar depois do novo, ele pode sobrescrever o estado e a fila com o snapshot antigo.
- O caminho do worker é Reivindicar Próximo Follow-up → resumo/LLM → Enviar ou Encerrar → UAZAPI. Não há releitura de status do job nem validação da etiqueta imediatamente antes do envio. O webhook de remoção cancela também registros processing, mas um worker que já recebeu seu item continua com o payload local. Portanto, se a remoção coincidir com um job já reivindicado, o cancelamento no banco não é, por si só, uma trava de envio.
- A reivindicação do worker continua protegida por UPDATE ... RETURNING, FOR UPDATE SKIP LOCKED e advisory lock; essa trava trata workers duplicados, não a corrida de alterações da etiqueta.

## Latência observada e testes anteriores

- Nas 50 execuções mais recentes do workflow, 47 eram webhooks; 47/47 terminaram com sucesso. Latências: mínimo 79 ms, mediana 129 ms, p95 402 ms e máximo 455 ms. É uma amostra operacional, não benchmark de carga.
- A auditoria anterior registrou oito entregas duplicadas do mesmo payload e uma única entrada ativa resultante. Também registrou dois workers simultâneos com somente uma reivindicação/envio. Esses testes não cobrem evento antigo chegando depois do novo, sequência add→remove→add abaixo de 1 s, ou cancelamento após o worker entrar em processing.
- Os testes locais focalizados não puderam ser executados nesta estação: pnpm disponível é 11.19.0, mas o repositório exige pnpm 10; o runner Vitest direto iniciou, porém falhou antes de coletar os testes porque falta o fake-indexeddb no caminho compartilhado work/chatwoot-source/node_modules/.... Resultado: zero testes executados nesta auditoria.

## Proteção necessária antes de declarar aprovado

1. No frontend, manter uma fila de intenções por conversa (IDs diferentes continuam independentes), atualizar o estado otimista imediatamente e enviar estados em ordem; não permitir que respostas antigas substituam o estado mais recente.
2. No webhook, serializar por conversa em transação e rejeitar evento obsoleto por versão/ordem; reconciliar com o estado atual do Chatwoot antes de criar/cancelar jobs. Manter os índices/idempotência já existentes.
3. Imediatamente antes da UAZAPI, confirmar atomicamente que o job ainda está processing e que sua etiqueta continua ativa; caso contrário, encerrar sem envio.
4. Regressão de staging sem envio real: clientes distintos a cada 2 s; mesma conversa add→remove→add em <1 s; entregas duplicadas e deliberadamente reordenadas; resposta HTTP atrasada/falha; cancelamento durante processing. Asserções: estado final igual à última intenção, no máximo um job ativo correto e zero envio após cancelamento.

## Resultado desta rodada

Auditoria concluída com achados; nenhuma correção funcional ou deploy foi feito. **Não declarar “completamente protegido” até implementar as três travas e passar a matriz isolada acima.**

## Linhas conectadas

[[Meu Cofre/Chatwoot Rotta — contexto e estado]] ↔ [este registro](rapid-label-change-safety-2026-09-15.md) ↔ [workflow Follow-up ativo](https://saas.via-cargo.com/workflow/utaNsnFUZYBYDf5S) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [Chatwoot](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/dashboard).
