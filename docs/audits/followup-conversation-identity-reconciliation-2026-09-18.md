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

## Bateria forense de trilhas e etiquetas — 18/09/2026

Escopo: teste real autorizado somente nos telefones `+5511991262866` (Caio)
e `11965927865`/`+5511965927865` (Kelvin), usando o Chrome, Chatwoot,
UAZAPI via workflow n8n e o painel autoritativo.

### Resultado por trilha

- Kelvin: `Contato instantâneo` → `Primeiro contato` → `Segundo contato` →
  `Terceiro contato` → `Quarto contato` → `Último contato`. O instantâneo
  gerou uma única mensagem; cada avanço controlado produziu uma única etapa,
  sem duplicidade de cartão ou `Conciliação pendente`.
- Caio: `Orçamento feito` → `Orçamento tentativa 2` → `Orçamento tentativa 3`
  → `Orçamento tentativa 4`; cada etapa foi vista no Chatwoot, no perfil e no
  quadro como `Na fila`, com a próxima etiqueta correta.
- Caio: `Orçamento 5 dias`, `Orçamento 10 dias` e `Orçamento 15 dias` foram
  testados isoladamente; os três criaram job `pending` autoritativo, com
  próxima etapa `Orçamento feito` e horários coerentes de 120/240/360 horas.
- A transição final dos testes removeu a etiqueta de prova. Não restou job
  operacional de teste em nenhum dos dois telefones.

### Sincronização visual e atalhos

- A etiqueta selecionada no menu do Chatwoot refletiu imediatamente no cabeçalho
  e no perfil da conversa.
- O Follow-up exibiu cada etapa somente uma vez, com cliente, etapa atual,
  próxima etapa, horário e status `Na fila`; a atualização ocorreu após o
  refresh/revalidação do painel, sem `Conciliação pendente`.
- `+1 dia` moveu o job de Caio de `19/09/2026 23:04` para `20/09/2026 23:04`;
  `−1 dia` restaurou exatamente `19/09/2026 23:04`.
- O perfil mostrou os mesmos estados e atalhos do quadro durante as etapas
  programadas.

### Correção do falso “Conciliação pendente”

O instantâneo de orçamento do Caio foi reivindicado pelo worker, mas a IA
  corretamente decidiu não enviar porque a conversa tinha intervenção humana
  recente. O finalizador antigo marcava o job como `cancelled`; como a etiqueta
  ainda permanecia visível, o proxy criava um fallback incorreto.

Correção publicada no workflow n8n `utaNsnFUZYBYDf5S`:

- jobs encerrados sem envio agora usam o status interno `no_send`;
- a listagem os projeta como `history_only`, sem incluí-los na fila operacional;
- a projeção histórica impede que a mesma etiqueta ativa gere um fallback
  `sync_failed`/`Conciliação pendente`;
- o workflow foi publicado na versão ativa
  `441a7254-f5be-4c71-a2cc-d745ae893ab5`.

Evidência: execução `638194` finalizou com `no_send_without_send`; a API
  autoritativa retornou o registro do Caio como `history_only`, e o quadro
  ficou com `4` itens ativos, `1` histórico e nenhum texto `Conciliação
  pendente` ou `Conciliação não confirmada`. A consulta final dos dois números
  retornou zero jobs ativos de teste e zero jobs `sync_failed`.

### Limpeza e conclusão

- Todas as etiquetas usadas no teste foram removidas ao final; o menu do
  Chatwoot confirmou estado desmarcado no Caio.
- O quadro final não exibiu Caio nem Kelvin como cartão operacional de teste.
- Nenhuma mensagem foi enviada nos testes das etapas programadas; o único
  envio instantâneo foi o teste autorizado de Kelvin, que gerou uma mensagem
  única. O instantâneo de orçamento do Caio foi deliberadamente bloqueado pela
  proteção de intervenção humana, e ficou auditado como histórico sem envio.

## Correção e reteste — instantâneos após intervenção humana (18/09/2026)

### Reprodução

- A execução `638194` reproduziu o defeito em `orcamento-instantaneo` para `5511991262866`: a LLM retornou `should_send=false` com motivo de intervenção humana recente, e o job terminou como `no_send_without_send`.
- O caso mínimo ficou red-capable: antes da correção, o teste retornou `RED: instantâneo foi bloqueado após resposta humana recente` com exit code 1.

### Correção publicada

- `Preparar Resumo Contextual` passou a marcar as etapas instantâneas e instruir a LLM a não bloquear por mensagem de agente/dono.
- `Interpretar Resumo e Mensagem` passou a forçar `should_send=true` para instantâneos quando há mensagem válida, mantendo o bloqueio apenas para pedido explícito do cliente e preservando o comportamento das etapas programadas.
- Atualização atômica de 2 nós sem warnings; publicação confirmada no n8n na versão ativa `d22b09b0-1989-4168-9e98-b39c0ce786bc`.

### Reteste real

- Kelvin, `5511965927865`: execução `639279`; `contato-instantaneo` enviou exatamente uma mensagem, confirmou UAZAPI e migrou para `Primeiro contato`.
- Caio, `5511991262866`: execução `639325`; `orcamento-instantaneo` enviou exatamente uma mensagem mesmo com intervenção humana recente e migrou para `Orçamento feito`.
- Chrome confirmou atualização dinâmica no histórico, na etiqueta, no Perfil e no quadro; não houve duplicidade nem `Conciliação pendente`.
- `+1 dia` e `−1 dia` foram testados nos dois cartões. Os botões ficaram desabilitados durante a chamada, e a reversão retornou o horário original.
- As etiquetas de teste foram removidas ao final; os dois telefones não permaneceram no quadro operacional.
