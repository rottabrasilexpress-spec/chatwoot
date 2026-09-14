# Auditoria — confirmação de entrega WhatsApp/UAZAPI — 14/09/2026

## Escopo

Corrigir os indicadores de mensagens no Chatwoot para preservar a semântica do WhatsApp: um check cinza quando a mensagem foi enviada, dois checks cinza quando foi entregue e dois checks azuis quando foi lida. O estado deve ser atualizado em tempo real sem recarregar a conversa.

## Evidência do vídeo

Arquivo analisado: `C:\Users\User\AppData\Local\Packages\Microsoft.ScreenSketch_8wekyb3d8bbwe\TempState\Recordings\20260914-1847-18.8882580.mp4`.

Transcrição revisada do áudio: “Precisamos fazer um ajuste bastante simples nesses risquinhos de enviado com sucesso. Está apenas um risco; como foi enviado, tem que ser dois. Deve ficar um risco apenas quando não chega para o cliente, ou seja, foi enviado, porém não chegou. O mesmo vale para o cliente. Precisa ficar exatamente igual ao WhatsApp oficial; quando for lido, fica azulzinho. Precisamos alinhar este ponto para os risquinhos serem responsivos.”

Inspeção visual: as mensagens de saída mostradas no Chatwoot apresentavam um único check cinza. O vídeo também mostra a referência do WhatsApp oficial com a transição para dois checks e para dois checks azuis.

## Reprodução técnica

- Conversa real do Chatwoot: a API retornava as mensagens de saída com `status=sent`, sem metadado de confirmação UAZAPI.
- O DOM renderizado confirmava um único ícone `i-lucide-check` cinza para esse estado.
- O componente visual já continha o mapeamento correto: `sent` → um check cinza; `delivered` → dois checks cinza; `read` → dois checks azuis.
- O Rails já publica `message.updated` pelo Action Cable quando uma mensagem é atualizada; o frontend já consome esse evento e atualiza a mensagem na store.

## Causa e correção

1. O parser do webhook não conseguia correlacionar alguns eventos `messages_update` quando o status vinha em `data.update.status` e o ID da mensagem vinha separado em `data.key.id`.
2. O eco de uma mensagem enviada pela UAZAPI era criado como `delivered`, embora o evento `messages` confirme apenas o envio/aceite; isso podia exibir dois checks antes da confirmação de entrega.
3. O parser passou a reconhecer eventos `messages_update`/`ack`, correlacionar IDs separados no mesmo subárvore do payload e promover o status de forma monotônica.
4. O eco de saída passou a iniciar como `sent`; somente o evento posterior de entrega/leitura pode promover para `delivered`/`read`.

## Regressão coberta

Foi adicionado spec de request para o formato separado `data.key.id` + `data.update.status=3`, esperando persistência de `delivered`, `uazapi_status` e `uazapi_message_id`. O teste existente do eco de saída foi ajustado para exigir `sent`.

## Critério de aceite

- `sent`: um check cinza.
- `delivered`: dois checks cinza.
- `read`: dois checks azuis.
- Evento fora de ordem nunca rebaixa o status.
- A alteração persistida dispara `message.updated` e chega ao agente via Action Cable.
- Nenhum texto deve ser enviado ao cliente para produzir a mudança visual.

## Validação e limites

- `git diff --check`: aprovado.
- Teste unitário existente do helper de status: 5/5 aprovado em checkout equivalente com as mesmas regras do helper.
- Ruby/Bundler/RSpec e Docker não estão instalados/disponíveis neste host; o spec Rails precisa ser confirmado no container de produção/EasyPanel após a publicação.
- A confirmação final de entrega depende de a instância UAZAPI estar inscrita no evento `messages_update`; o código do Chatwoot agora processa esse evento, mas a configuração do provedor deve permanecer habilitada.

## Rollback

Reverter o commit desta rodada restaura apenas o parser/estado do eco no arquivo `app/controllers/webhooks/uazapi_controller.rb` e o spec correspondente. Não altera mensagens, etiquetas, follow-up ou credenciais.
