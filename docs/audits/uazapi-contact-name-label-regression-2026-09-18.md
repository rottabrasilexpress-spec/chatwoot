# Auditoria UAZAPI — nome inbound e etiquetas First contact/KELVIN (2026-09-18)

## Escopo

Correção mínima no workflow n8n `ATENDIMENTO RT - UAZAP - EM USO` (`7ngn9zsHXZbjv1qG`): salvar automaticamente o nome de contatos inbound via UAZAPI e preservar o contexto necessário para os guards de `[1] Primeiro contato` e `KELVIN`.

Nenhuma alteração foi feita no frontend do Chatwoot, no follow-up, em credenciais, no prompt da IA ou em outros workflows.

## Diagnóstico reproduzido

As execuções reais anteriores mostraram:

- `Preparar contato UAZAPI — inbound` e `Registrar intenção de contato UAZAPI` encontravam o telefone e o nome.
- `Salvar nome do contato na UAZAPI` retornava `401 Missing token`.
- O Postgres entregava apenas o registro de controle ao nó HTTP; esse item não continha o token do contexto normalizado.
- Depois da falha, `Preparar inbound Primeiro contato` recebia apenas o resultado do ramo anterior e reconstruía `number`, `waChatId` e `event` vazios. Isso impedia a avaliação correta do subfluxo de etiqueta.

## Correção aplicada

Alteração atômica de dois nós:

1. `Salvar nome do contato na UAZAPI`
   - URL e cabeçalho `token` passaram a ler o contexto original de `Preparar contato UAZAPI — inbound`.
   - O payload continua usando somente o telefone e o nome retornados pelo controle idempotente.
2. `Preparar inbound Primeiro contato`
   - Mantém o contexto normalizado original e mescla os metadados do ramo de salvamento.
   - O caminho de sucesso e o de falha continuam chegando ao subfluxo com número, JID, evento, timestamp e flags inbound preservados.

## Publicação

- Update n8n aplicado com `2` operações atômicas.
- Workflow publicado e ativo: versão `2e08d7d0-6c79-46fc-b2c7-33b424749257`.
- O validador reportou apenas avisos preexistentes fora dos nós alterados.

## Testes e evidências

- Execução manual controlada `644139` usando um número de teste autorizado:
  - `/contact/add`: HTTP `200` (`Contact added`).
  - Contexto preservado até `Preparar inbound Primeiro contato`.
  - Subfluxo de Primeiro contato executado sem campos vazios; o contato foi corretamente reconhecido como histórico existente, portanto não recebeu uma segunda etiqueta.
- Execução inbound real posterior à publicação `644183`:
  - Nome já sincronizado: `should_save=false`.
  - Contexto completo chegou ao subfluxo de Primeiro contato.
  - Estado persistido desse contato estava `applied`; nenhuma duplicação foi criada.
- Execução de restauração do nome real do contato de teste `644192`:
  - `/contact/add`: HTTP `200`.
  - Registro de controle confirmado com o nome original.
- Auditoria de 120 execuções do subfluxo KELVIN:
  - Foram encontradas execuções recentes com detector, adição e confirmação da etiqueta concluídos com sucesso, incluindo execuções após a publicação.

## Limite da validação

Ainda não apareceu, durante a janela desta auditoria, uma conversa completamente nova com `history_count=0`. Portanto, o caminho de primeira aplicação física da etiqueta em um cliente sem histórico deve ser confirmado na próxima mensagem real de um novo contato; o caminho de contexto e o salvamento do nome já foram comprovados.

A janela adicional recebeu somente o evento `chat_labels` `644265`, não uma mensagem de cliente; não foi encontrado inbound novo com `fromMe=false` nesse período.

## Cobertura adicional do nome

- O nó `Dados` mantém `senderName`/`pushName` como fonte prioritária e agora usa `body.chat.wa_name`, `body.chat.wa_contactName` ou `body.chat.name` como fallback.
- Publicação adicional: versão ativa `890e2dd5-e1b6-4dd1-8df4-ba1041893e75`.
- Teste controlado `644302`, sem `senderName` na mensagem: o nome foi recuperado de `chat.name` e o controle idempotente retornou `should_save=false`, sem chamada HTTP redundante.
- Inbound real `644314` após essa publicação terminou com `success`; nome, telefone, JID e contexto chegaram ao guard de Primeiro contato sem duplicação. O contato já possuía histórico e estado de etapa, portanto a proteção de histórico foi aplicada corretamente.
- Inbound real `644365` também chegou com nome e contexto completos; o controle retornou `history_count=14`, `first_contact_status=closed` e `first_contact_eligible=false`, sem reaplicar ou retroceder etiqueta.

## Estado atual

- A implementação está publicada e operacional para mensagens inbound com nome em `message.senderName` e para o fallback em `chat.name/wa_name`.
- A auditoria ainda não capturou um cliente totalmente novo com `history_count=0`; essa é a única validação operacional restante para confirmar a primeira aplicação da etiqueta em uma conversa sem histórico.
- A janela seguinte de oito verificações não recebeu outro inbound de cliente.
- A verificação posterior encontrou 13 webhooks: 12 eventos `chat_labels` e 1 mensagem `fromMe=true`; nenhum foi uma mensagem inbound de cliente e, portanto, nenhum poderia validar `history_count=0`.

## Segurança

Nenhum token, senha ou credencial foi registrado neste documento.

## Correção final — nome independente da etapa

O caso real `644498` mostrou uma cobertura que ainda faltava: a mensagem inbound chegou com `senderName`, `chat.name`, `wa_name` e `wa_contactName` vazios. A rota anterior encerrava antes de salvar o nome e antes de avaliar as etiquetas.

Foi implementado no workflow principal, antes dos subfluxos de Primeiro contato e KELVIN:

- `Nome inbound disponível?` mantém o caminho rápido quando já existe nome.
- Quando o nome não vem no evento, `UAZAPI — Detalhes para nome inbound` consulta `POST /chat/details`.
- `Consolidar nome inbound` recupera `name`, `wa_name` ou `wa_contactName`, preserva o contexto original e monta o SQL idempotente.
- O Postgres decide `should_save`; somente quando necessário o `/contact/add` é chamado.
- Mesmo sem nome retornado, o fluxo segue para as etiquetas sem bloquear o atendimento.

## Publicação e testes finais

- Correção intermediária publicada: versão `eadd72d7-07a6-45c9-a1d1-ea506d1db09a`.
- Um teste real controlado `644569` expôs um erro de montagem do SQL (`\\n` literal); ele foi corrigido sem alterar outros nós.
- Versão final publicada e ativa: `3ccd26cb-19d0-48e4-bf18-50850493698e`.
- Teste `644600`, sem nome no evento: `/chat/details` retornou HTTP 200 com `Kelvin Martins`; SQL executou sem erro (`should_save=false`); Primeiro contato foi acionado e KELVIN foi avaliado.
- Teste `644669`, com escopo de auditoria novo e sem nome no evento: `/chat/details` retornou HTTP 200 com `Caio Mazine`; `should_save=true`; `/contact/add` retornou HTTP 200; confirmação e Primeiro contato terminaram com sucesso.
- O subfluxo Primeiro contato `644670` reconheceu histórico existente e não duplicou etiqueta.
- Execuções KELVIN `644254` e `644214` continuam comprovando o caminho completo: detector de pré-orçamento, aplicação confirmada de KELVIN e remoção confirmada de Primeiro contato. A execução `644634` ignorou corretamente um texto que não era pré-orçamento.

## Regra operacional consolidada

Toda mensagem inbound elegível passa primeiro pela sincronização de nome, independentemente de estar em Primeiro contato, KELVIN, orçamento ou outra etapa. A aplicação das etiquetas permanece separada e idempotente; nenhum frontend do Chatwoot, follow-up, prompt, credencial ou outro workflow foi alterado.

## Validação de cliente realmente novo

A pendência de observar um contato com histórico zero foi encerrada com a mensagem inbound real `644688`:

- Contato: Bianca Yoshikawa, JID `553387198394@s.whatsapp.net`.
- O nome veio no evento e o controle retornou `should_save=true`.
- `/contact/add` retornou HTTP `200` e a confirmação do salvamento concluiu sem erro.
- Subworkflow Primeiro contato `644689`: `history_count=0`, `first_contact_eligible=true`, reserva concluída, `/chat/labels` para Primeiro contato HTTP `200`, confirmação HTTP `200`, `confirmed=true`, `status=applied`.
- Mensagens posteriores de Barbeta (`644642`/`644644`, histórico 32) e Graziele (`644717`/`644718`, histórico 4) foram bloqueadas pelo guard de histórico, sem duplicação.
- Os subfluxos KELVIN recentes foram conferidos; as execuções `644254` e `644214` têm aplicação e remoção confirmadas. As execuções `644725` e `644682` ignoraram corretamente textos sem bloco de pré-orçamento.

Conclusão operacional: o salvamento do nome ocorre antes da etapa, Primeiro contato aplica somente em histórico zero e KELVIN só altera a conversa quando o detector de pré-orçamento é satisfeito.
