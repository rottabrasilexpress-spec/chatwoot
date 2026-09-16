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
6. mantém a reivindicação em timeout ambíguo e libera somente em falha confirmada ou após a confirmação/eco do provedor.

O lock é liberado antes do HTTP; assim, o webhook não fica bloqueado durante a chamada externa. Jobs concorrentes registram `skipped duplicate send claim` e não enviam novamente.

## Regressões cobertas

- dois jobs sobrepostos para a mesma mensagem devem produzir exatamente um POST;
- um timeout ambíguo seguido de nova tentativa automática não deve produzir um segundo POST;
- os testes existentes de texto, nome do agente, falha confirmada, timeout e áudio foram preservados.

## Verificação realizada

- `git diff --check`: aprovado.
- Auditoria n8n somente leitura: workflow ativo `ViaCargo - UAZAPI WhatsApp - ATENDIMENTO`, versão `5ea4cc6c-871b-4740-9a5b-bbcd013a34ad`; a execução histórica de duplicação foi anterior à correção do nó principal.
- Execuções recentes inspecionadas após a publicação anterior: nenhuma duplicação do nó principal foi observada no recorte analisado.
- RSpec não foi executado localmente porque esta estação não possui Ruby/Bundler.
- Vitest não coletou os testes porque o `node_modules` local resolve para outro worktree e não contém `fake-indexeddb`; não é falha de teste funcional.

## Limite conhecido

A proteção impede reenvios concorrentes e redeliveries do Chatwoot. Se a própria UAZAPI repetir internamente uma requisição já aceita, a confirmação precisa ser investigada no provedor; o `track_id` determinístico continua sendo enviado para permitir essa correlação.

