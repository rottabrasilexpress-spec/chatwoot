# Auditoria real — contato instantâneo e limpeza operacional — 2026-09-15

## Escopo

Teste real autorizado exclusivamente para `5511965927865` (conversa Chatwoot `#2143`), cobrindo aplicação da etiqueta, criação de job, atualização do painel sem recarga, worker, envio pela UAZAPI, troca de etapa e limpeza sem deixar job ativo.

## Evidências reproduzíveis

- Ao aplicar `Contato instantâneo 🫶` pela UI do Chatwoot, o Follow-up atualizou sem F5 para `Na fila 1`, `Prontos agora 1`, `Etapas ativas 1`, com o card do Kelvin em `Na fila` e próxima etapa `Primeiro contato`.
- A listagem administrativa `606139` encontrou o job `cw:2143:contato-instantaneo:df3d46fc-6024-440b-bb20-f230b1371f88`.
- O job foi disparado imediatamente em `606142` e processado pelo worker `606144`. As etapas de reivindicação, resumo DeepSeek `deepseek/deepseek-v4-flash-0731`, envio UAZAPI, validação, troca de etiqueta e finalização terminaram com sucesso.
- O Chatwoot registrou a mensagem real `message44169` às `08:32` (horário de Brasília), e a etiqueta avançou para `Primeiro contato`.
- Sem recarga, o Follow-up passou para `Na fila 1`, `Prontos agora 0`, `Etapas ativas 1`, com a próxima janela futura. Isso comprova atualização dinâmica e separação entre histórico e fila ativa.
- A próxima etapa foi cancelada de forma explícita em `606188` após a verificação. A etiqueta temporária foi removida pela UI e a conversa foi resolvida.
- Após a limpeza, o painel ao vivo mostrou `Na fila 0`, `Prontos agora 0`, `Etapas ativas 0` e `Nenhum follow-up nesta visão`. A listagem final não deixou job operacional pendente para o telefone/conversa testados; registros antigos permaneceram somente como histórico.

## Saúde do serviço

- `GET /health`: HTTP `200`, `{"status":"woot"}`.
- Dashboard: HTTP `200`.
- Workflow n8n `utaNsnFUZYBYDf5S`: ativo, versão publicada `4a00ffca-ff9a-4a87-9e5c-6f5a1f04c58b`.
- O claim atômico com `FOR UPDATE SKIP LOCKED` e advisory lock já havia sido validado com dois workers: um reivindicou e o outro terminou sem item.

## Resultado

PASS no cenário real executado. Não ficou envio futuro ativo para o contato de teste. O histórico continua visível para auditoria, mas o painel operacional final ficou zerado e sincronizado ao vivo.

## Limite conhecido

O resumo do modelo ainda pode levar cerca de 100–130 s em históricos grandes. O lock evita duplicidade; a otimização seguinte, fora deste ciclo, é compactar o contexto antes do modelo e medir throughput sob carga.

## Linhas conectadas

[[Chatwoot Rotta — contexto e estado]] ↔ [workflow n8n](https://saas.via-cargo.com/workflow/utaNsnFUZYBYDf5S) ↔ [GitHub `rotta-custom-v1`](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [Chatwoot #2143](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/conversations/2143) ↔ [Follow-up](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/settings/labels/follow-up).
