# Auditoria — duplicação de mensagem no atendimento UAZAPI

Data: 16/09/2026  
Escopo: remover a duplicação causada pelo envio de um mesmo fragmento duas vezes, sem alterar o conteúdo da empresa nem as credenciais.

## Sintoma

Foi reportado que uma mensagem digitada no Chatwoot aparecia duas vezes: uma bolha sem o nome do agente e outra com a identificação interna de Kelvin. A evidência visual foi tratada como sintoma, não como instrução técnica.

## Evidência reproduzível

- Workflow ativo: `ViaCargo - UAZAPI WhatsApp - ATENDIMENTO` (`t7TqOMDFXbf66MPa`).
- Execução histórica analisada: `800056`, iniciada em `2026-09-16T22:04:44Z` (`19:04:44` no horário de São Paulo), compatível com o horário mostrado no relato.
- O nó `VC - Claim Envio Idempotente` produziu dois fragmentos distintos, ambos marcados como novos.
- O nó HTTP `Enviar mensagem` foi executado duas vezes, mas usava `$('VC - Envio Novo?').first()` para `number`, `text` e `delay`. As duas chamadas resultantes carregaram o mesmo primeiro fragmento.
- O payload desse nó não tinha campo de nome de agente e o texto enviado não concatenava Kelvin/Caio. Portanto, a correção desta auditoria não adiciona nem transmite nome de agente; a identificação interna que o Chatwoot eventualmente mostra ao operador é separada do texto entregue ao cliente.

## Correção aplicada

Foi atualizada atomicamente apenas a lista de parâmetros do nó `Enviar mensagem`:

- `number`: item corrente (`$json.chatid`, com fallbacks existentes).
- `text`: item corrente (`$json.message`, `output` ou `text`).
- `delay`: item corrente (`$json.delayTime`, com zero como fallback).
- URL, credencial, `readchat`, `linkPreview` e os demais parâmetros permaneceram inalterados.

O workflow foi publicado pelo MCP do n8n. A versão ativa passou de `fe49b4b2…` para `5ea4cc6c…`, com o workflow permanecendo ativo.

## Testes

- Regressão antes da correção: **vermelha** — os três campos do nó continham `.first()`.
- Regressão depois da correção: **verde** — os três campos usam `$json` e dois itens sintéticos produziram `fragment-A` e `fragment-B` separadamente, com seus respectivos atrasos e o mesmo destinatário.
- Verificação de escopo: os demais workflows ativos que usam UAZAPI foram inspecionados; o caminho normal do atendimento está corrigido. Nós de fallback/fora-de-horário que usam `.first()` não foram alterados porque são ramos distintos e a solicitação era remover a duplicação do atendimento normal.
- Verificação live sem comunicação externa: a conversa Chatwoot `48` carregou e mostrou uma única mensagem `Oi` às `19:04` no estado atual. Nenhuma mensagem nova foi enviada durante a auditoria.
- Após a publicação houve uma execução automática `800156` com sucesso, mas ela percorreu somente o ramo de retomada/horário e não executou `Enviar mensagem`; por isso ela não é apresentada como teste de envio real.

## Limitações e acompanhamento

- A execução histórica comprovou uma duplicação real no fluxo n8n, mas não permite afirmar que toda ocorrência do rótulo interno “Kelvin” venha exclusivamente desse nó. O transporte HTTP não envia nome de agente no payload.
- Para confirmar o ciclo completo UAZAPI → webhook → persistência no Chatwoot seria necessário aguardar uma nova mensagem real ou realizar um envio autorizado. Nenhum envio foi disparado nesta correção para evitar nova mensagem duplicada a cliente.
- O validador n8n continua reportando três avisos pré-existentes em outros nós (subnós sem conexão e header sensível hardcoded); eles não foram introduzidos por esta alteração e ficaram fora do escopo.

## Rastreamento

- Workflow publicado: `t7TqOMDFXbf66MPa`.
- Auditoria versionada: este arquivo.
- Obsidian: seção “Correção da duplicação no envio UAZAPI — 16/09/2026”.
- GitHub: a documentação desta auditoria será publicada na branch `rotta-custom-v1`.
