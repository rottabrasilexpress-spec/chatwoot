# Gauntlet — Follow-up E2E Chatwoot/UAZAPI

Data: 2026-09-10  
Contato autorizado: Kelvin Martins CEO — conversa Chatwoot `2143`  
Workflow n8n: `utaNsnFUZYBYDf5S` — Rotta Chatwoot — Follow-up Contextual v1  
Escopo: Chatwoot real + UAZAPI via n8n; nenhum WhatsApp Web foi usado.

## Contrato

Validar o motor de follow-up ao vivo, sem tocar em outros contatos: entrada e remoção por etiqueta, fila, contadores, ações administrativas, disparo UAZAPI, troca de etapa, arquivamento e ausência de jobs fantasmas.

## Defeitos encontrados e corrigidos

1. `Ler Etiquetas Atuais Chatwoot` usava `ROTTA CHATWOOT — HML API` e retornava HTTP 401. A credencial foi substituída pela mesma credencial Chatwoot que já retornava 200 no POST de etiquetas (`Header Auth account 4`).
2. `Arquivar Conversa no Chatwoot` usava a mesma credencial HML e retornava HTTP 401. Também foi corrigido para `Header Auth account 4`.
3. Como os requests estavam com `neverError`, um 401 podia seguir silenciosamente. O nó `Trocar Etiqueta da Trilha` agora interrompe quando a leitura não for 2xx; o job não aplica etiquetas nem é finalizado em falha de autenticação.

Publicações n8n:

- versão ativa após leitura: `684568d9-eff5-46d8-8d17-0084f81024d5`;
- versão ativa após correção de arquivamento: `924cfab3-88b9-480f-ba35-8fc76fd55320`;
- versão ativa final com trava fail-closed: `731fe7df-0169-4ef8-91ad-1fc1ccb5bf73`.

## Matriz live

| Cenário | Evidência | Resultado |
|---|---|---|
| Primeiro contato entra na fila | etiqueta aplicada na conversa 2143 | `Na fila 1` |
| Adiantar 2h | cartão live alterou o horário em -2h | aprovado |
| Atrasar 2h | cartão live retornou ao horário original | aprovado |
| Primeiro disparo | n8n execution `574449` | UAZAPI 200; leitura antiga 401; causa reproduzida |
| Troca para segundo contato | mesma execução + Chatwoot | etiqueta `Segundo contato`, job seguinte criado |
| Remover etiqueta pelo Chatwoot | conversa 2143 | `Na fila 0`, sem fantasma |
| Segundo disparo pós-correção | execution `574544` | UAZAPI 200, leitura 200, aplicação 200, `Terceiro contato` |
| Cancelar job | webhook `574603` | status `cancelled` |
| Terceiro disparo e preservação de etiqueta paralela | execution `574628` | leitura 200; `next_labels=[kelvin, ultimo-contato]`; aplicação 200 |
| Quarto/último contato antes da correção de arquivamento | execution `574639` | envio/troca 200; arquivamento reproduziu 401 |
| Orçamento 5 dias | entrada/remover no Chatwoot real | contador `1` e depois `0` |
| Orçamento 10 dias | entrada/remover no Chatwoot real | contador `1` e depois substituído |
| Orçamento 15 dias | entrada/remover no Chatwoot real | contador `1` e depois `0` |
| Contato instantâneo | entrada real | `Prontos agora 1`; remoção pelo painel retornou para `0` |
| Orçamento instantâneo | entrada real | `Orçamento feito 1`, `Prontos agora 1`; remoção retornou para `0` |
| Arquivamento pós-correção | execution `574829` | UAZAPI 200, leitura 200, aplicação 200, arquivamento 200 |
| Estado final | Follow-up live | `Na fila 0`, `Prontos agora 0`, sem job ativo |

## Evidência final do worker

Execution `574829` concluiu com sucesso:

- `Enviar Follow-up pela Uazapi`: HTTP 200;
- `Ler Etiquetas Atuais Chatwoot`: HTTP 200;
- `Aplicar Próxima Etiqueta`: HTTP 200;
- `Arquivar Conversa no Chatwoot`: HTTP 200;
- `Finalizar Job Arquivado`: `sent`.

A conversa autorizada terminou arquivada, com a fila sem jobs ativos. As mensagens adicionais foram enviadas somente para o número autorizado para o teste real.

## Segurança e limites

- Não houve uso do WhatsApp Web do navegador.
- Não foram alteradas mensagens históricas nem outros contatos.
- A única mudança funcional desta rodada no n8n foi corrigir credenciais e impedir continuação silenciosa em resposta não-2xx.
- A preservação de etiqueta não pertencente ao follow-up foi comprovada na transição para `ultimo-contato`; a etapa final usa `arquivado` como estado terminal.
