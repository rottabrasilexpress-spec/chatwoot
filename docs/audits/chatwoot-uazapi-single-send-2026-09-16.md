# Auditoria de entrega única Chatwoot → UAZAPI — 2026-09-16

## Escopo

Investigar o sintoma em que o Chatwoot exibe uma única mensagem, mas o WhatsApp recebe duas cópias — uma representação associada ao agente e outra sem nome interno.

## Diagnóstico

- A mensagem manual é criada uma vez no Chatwoot e agenda `SendReplyJob` no callback de criação.
- O serviço `Messages::SendOnApiService` envia para a UAZAPI e usa `track_id=message-<id>`.
- Não havia uma reivindicação transacional antes do POST. Dois jobs concorrentes podiam, portanto, aceitar a mesma mensagem para envio.
- Os dois ecos podiam carregar o mesmo `track_id`; nesse caso o webhook correlacionava ambos ao mesmo registro do Chatwoot. Isso explica “uma mensagem no Chatwoot” junto com “duas entregas no WhatsApp”.
- A trava do `ReplyBox` já evitava a segunda submissão normal do editor. A correção anterior do n8n para fragmentos também permanece publicada; ela trata outro caminho de envio.

## Correção aplicada

`Messages::SendOnApiService` agora:

1. adquire um advisory lock PostgreSQL por conta e ID da mensagem;
2. recarrega a mensagem dentro da transação;
3. verifica `source_id` e o marcador pendente da própria mensagem;
4. grava o marcador pendente antes do primeiro POST;
5. permite que somente o worker que obteve a reivindicação faça a chamada externa;
6. mantém a reivindicação em timeout, erro de transporte ambíguo ou falha de persistência após resposta aceita; libera somente em rejeição HTTP 4xx confirmada (exceto 408/425/429), falha confirmada antes do POST ou após a confirmação/eco do provedor.

O lock é liberado antes do HTTP; assim, o webhook não fica bloqueado durante a chamada externa. Jobs concorrentes registram `skipped duplicate send claim` e não enviam novamente.

Erros que podem ocorrer depois de o provedor aceitar a requisição (`Net::OpenTimeout`, `Net::ReadTimeout`, `SocketError`, reset/fechamento de conexão e equivalentes) são tratados como confirmação pendente. Se a resposta foi aceita e falhar a persistência do `source_id`, o claim também permanece pendente; isso evita um retry que poderia duplicar a entrega.

Respostas 5xx, 408, 425 e 429 também são tratadas como ambíguas. A validação local anterior ao POST continua podendo falhar normalmente, sem criar um claim de rede.

## Regressões cobertas

- dois jobs sobrepostos para a mesma mensagem devem produzir exatamente um POST;
- um timeout ambíguo seguido de outra tentativa não deve produzir um segundo POST;
- uma falha de transporte ambígua além de timeout não deve liberar o claim;
- uma rejeição HTTP confirmada (422) deve liberar retry legítimo;
- dois jobs sobrepostos para uma mensagem de áudio devem produzir exatamente um POST;
- uma falha ao persistir o ID depois de resposta aceita não deve liberar o claim;
- um claim com `track_id` inconsistente deve bloquear de forma conservadora, sem sobrescrever o marcador;
- os testes existentes de texto, nome do agente, falha confirmada, timeout e áudio foram preservados.

## Verificação realizada

- `git diff --check`: aprovado.
- Auditoria n8n somente leitura: workflow ativo `ViaCargo - UAZAPI WhatsApp - ATENDIMENTO`, versão `5ea4cc6c-871b-4740-9a5b-bbcd013a34ad`; a execução histórica de duplicação foi anterior à correção do nó principal.
- Execuções recentes inspecionadas após a publicação anterior: nenhuma duplicação do nó principal foi observada no recorte analisado.
- RSpec não foi executado localmente porque esta estação não possui Ruby/Bundler.
- Vitest não coletou os testes porque o `node_modules` local resolve para outro worktree e não contém `fake-indexeddb`; não é falha de teste funcional.
- Para detectar claims órfãos, está disponível `rake rotta_uazapi:report_stale_pending_sends STALE_AFTER_MINUTES=30`. A rotina lista somente IDs de mensagem/conversa, `track_id` e horário; ela não libera nem reenvia automaticamente.
- Depois de confirmar manualmente na UAZAPI que não houve entrega, um operador pode liberar somente a mensagem escolhida com `rake rotta_uazapi:release_pending_send MESSAGE_ID=<id> CONFIRM=I_UNDERSTAND`; sem os dois parâmetros a tarefa aborta. A tarefa exige claim antigo, sem `source_id`, com `track_id` canônico e usa o mesmo advisory lock do sender; remove o marcador de confirmação, mas não enfileira reenvio automático enquanto uma chamada antiga possa estar em voo.

## Limite conhecido

A proteção impede reenvios concorrentes e redeliveries do Chatwoot. Se a própria UAZAPI repetir internamente uma requisição já aceita, a confirmação precisa ser investigada no provedor; o `track_id` determinístico continua sendo enviado para permitir essa correlação. Claims órfãos não são liberados automaticamente justamente para evitar transformar uma queda de processo em duplicação. A reconciliação manual só libera claims antigos e canônicos, sob lock idêntico ao envio.

- A validação de integridade do diff permanece sem erros de whitespace após este registro.
