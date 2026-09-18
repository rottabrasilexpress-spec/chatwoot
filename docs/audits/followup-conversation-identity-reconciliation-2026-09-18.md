# Follow-up — reconciliação de identidade de conversa

Data: 18/09/2026

## Problema reproduzido

O Chatwoot mostrava `Primeiro contato` na conversa pública `#2143`, enquanto a
fila de Follow-up mostrava Kelvin em `Segundo contato`. A origem era o uso do
ID interno/do contato (`206`) no caminho da API de conversas. A API do
Chatwoot usa o ID público da conversa.

## Correção aplicada no workflow n8n

- resolve o contato pelo telefone antes de ler ou trocar etiquetas;
- lista as conversas do contato e escolhe a aberta mais recente;
- usa o campo `id` retornado pelo endpoint como o identificador público da
  conversa;
- relê as etiquetas após a troca e só finaliza quando a próxima existe e a
  anterior não existe;
- agenda a próxima etapa correta, sem saltar uma fase;
- mantém o conflito de jobs ativo protegido pela chave de telefone e etapa.

## Reconciliação de Kelvin

A conversa `#2143` foi atualizada para `segundo-contato` sem enviar nova
mensagem. O único job ativo foi migrado do ID legado `206` para `2143` e
permanece agendado para a etapa seguinte. A rota temporária usada somente para
esse reparo foi removida antes da publicação final.

## Evidência

Consulta autoritativa do painel após a reconciliação retornou exatamente um job
ativo para `5511965927865`: conversa `2143`, etapa `segundo-contato`, próximo
passo `terceiro-contato`, status `pending`. A API de etiquetas da conversa
retornou apenas `segundo-contato`.

Workflow n8n ativo: `6d7742a2-fbb7-4340-a140-5d1fc9e22861`.

## Teste real posterior à correção

O job de teste de Kelvin foi disparado uma vez, de `segundo-contato` para
`terceiro-contato`. A execução `635586` concluiu com `sent`: a UAZAPI aceitou
uma mensagem, a etiqueta pública da conversa `#2143` mudou para
`terceiro-contato`, a releitura autoritativa confirmou esse valor e foi criado
somente um job pendente de Terceiro para Último contato, com 72 horas de atraso.

No Chrome, a conversa mostrou exclusivamente `Terceiro contato`, uma única
mensagem nova e o card lateral sincronizado com a próxima etapa e seus atalhos.

## Regressão de conciliação visual — 18/09/2026

O cenário real de `contato-instantaneo` para Kelvin confirmou que o motor
autoritativo criou somente o job de `primeiro-contato` para a conversa `#2143`.
O cartão extra de `segundo-contato` era um placeholder local do navegador:
após uma transição rápida de etiquetas, ele permanecia mesmo depois de a API
confirmar outra etapa da mesma conversa e era mostrado como `Conciliação
pendente`.

A projeção do painel passou a descartar todos os placeholders locais daquela
conversa assim que a fila retorna uma etapa ativa confirmada. O motor n8n, as
etiquetas do Chatwoot, os horários e as mensagens não são modificados por essa
correção. Foi incluído um teste de regressão para o caso com marcadores de
Primeiro e Segundo contato e confirmação remota de Primeiro contato.

## Regressão encontrada após o primeiro deploy — fallback do proxy — 18/09/2026

O bundle novo foi publicado e o serviço voltou com `/health` em HTTP 200, mas a
validação visual ainda mostrava Kelvin em Primeiro e Segundo contato. A causa
residual estava no proxy Rails do próprio Chatwoot: ao receber um job remoto
ativo para a conversa, ele também criava um fallback de conciliação para cada
outra etiqueta de follow-up que ainda estivesse temporariamente presente no
Chatwoot.

Correção aplicada no proxy:

- uma conversa com qualquer job remoto operacional não recebe fallback para
  nenhuma etiqueta adicional;
- quando não existe job remoto, múltiplas etiquetas antigas geram somente uma
  linha explícita de conciliação, evitando multiplicação de cartões;
- jobs históricos continuam fora da decisão operacional.

Foram adicionados testes de request para os dois cenários. A mudança é isolada
no controller do Follow-up e não altera envio, etiquetas, horários ou o worker.

Na validação real, o job atual estava na conversa `2143` e a etiqueta antiga
aparecia na conversa legada `206`, ambas do mesmo telefone. A conciliação agora
também usa a chave numérica do telefone; assim, uma etiqueta de uma conversa
legada não gera um segundo cartão enquanto houver job operacional do mesmo
cliente.

## Reparação de Bárbara — 18/09/2026

O telefone `5531998975727` apresentava `Conciliação pendente` porque a conversa
`2284` ainda possuía somente `contato-instantaneo`, embora o disparo inicial já
tivesse ocorrido. A consulta autoritativa não tinha job remoto para Bárbara.

Reparação aplicada, sem novo envio de WhatsApp:

- adicionada a etiqueta `primeiro-contato`;
- removida a etiqueta já processada `contato-instantaneo`;
- webhook de etiquetas criou o job autoritativo da conversa `2284`;
- o Follow-up passou a exibir `Primeiro contato → Segundo contato`, com status
  `Na fila` e data `2026-09-20T01:32:37.905Z` UTC;
- a consulta posterior retornou exatamente um job ativo para o telefone, sem
  fallback `pending` e sem `Conciliação pendente`.

Validação visual no Chrome: cartão de Bárbara presente uma única vez, com
horário, atalhos `Agora`, `−1 dia` e `+1 dia`, e atualização dinâmica após a
troca de etiquetas.
