# Paridade de interface WhatsApp Web ↔ Chatwoot

**Data da pesquisa:** 2026-09-08
**Escopo:** requisitos de comportamento e UI para conversas WhatsApp no Chatwoot, com foco em tempo real, status, presença, respostas, horários, mídia, áudio, arquivos, responsividade e interação.
**Regra de fontes:** somente documentação oficial da Meta/WhatsApp e documentação/código oficial do Chatwoot foram usados como base factual. O código foi inspecionado localmente no repositório em `422d5e2e0d9dffa5c59d69f9760f177ceb3774e3`.

## Conclusão executiva

O Chatwoot já possui os blocos estruturais necessários: eventos via Action Cable, reconciliação após reconexão, status `sent`/`delivered`/`read`/`failed`, agrupamento de balões, respostas citadas, galeria para imagens/vídeos, download de arquivos, gravador de áudio e player com waveform. A documentação oficial do Chatwoot confirma que WebSocket é o mecanismo destinado a atualizar mensagens sem recarregar a página e lista eventos de mensagem, atualização, digitação e presença.

Uma cópia literalmente idêntica do WhatsApp Web não é verificável nem apropriada: a implementação do WhatsApp Web, seus assets, tokens, métricas exatas, animações e regras internas são proprietários. O alvo implementável é **paridade comportamental observável**, com identidade visual própria do Chatwoot e adaptação às capacidades do provedor WhatsApp/Uazapi.

O ponto mais importante para não perder mensagens é tratar o realtime como um pipeline: evento instantâneo por WebSocket/webhook, atualização monotônica por ID externo e reconciliação após reconexão. O polling de segurança não deve substituir o WebSocket.

## O que a Meta documenta

### Status de envio, entrega, leitura e falha

O payload oficial de status da WhatsApp Business Platform identifica a mensagem por `id`, informa `status`, `recipient_id` e um `timestamp`. A Meta documenta notificações de envio, entrega e leitura e alerta que a ordem de chegada das notificações pode não refletir a ordem real; portanto, o integrador deve usar o timestamp e não regredir um status já avançado. Consulte [Message Status Update Notifications — Meta WhatsApp Business Platform](https://www.postman.com/meta/whatsapp-business-platform/request/rgtfq23/message-status-update-notifications) e o [Statuses Object — Meta WhatsApp Business Platform](https://www.postman.com/meta/whatsapp-business-platform/folder/fuaee8l/statuses-object).

Requisito de produto:

| Estado | Representação esperada | Regra de dados |
| --- | --- | --- |
| `progress` | relógio/indicador de envio | estado local antes do aceite do provedor |
| `sent` | uma marca cinza | provedor aceitou a mensagem; não significa que chegou ao aparelho |
| `delivered` | duas marcas cinza | provedor confirmou entrega |
| `read` | duas marcas azuis | provedor recebeu confirmação de leitura |
| `failed` | erro claramente visível e ação de retry | preservar o erro externo e permitir nova tentativa explícita |

Os estados devem avançar de forma monotônica (`progress → sent → delivered → read`) e `failed` deve ser associado ao erro da tentativa. Eventos duplicados e fora de ordem precisam ser idempotentes. Nunca exibir `read` apenas porque o agente abriu a conversa: esse estado depende de confirmação do contato/provedor.

O Chatwoot documenta os mesmos quatro estados e explica que `sent` significa handoff aceito pelo provedor, enquanto `delivered` e `read` dependem de confirmações externas. Também documenta que leitura pode não ser reportada quando o contato desabilita confirmações. Consulte [Message Statuses — Chatwoot Developer Docs](https://developers.chatwoot.com/self-hosted/message-statuses).

### Mensagens, IDs e respostas citadas

Na coleção oficial da Meta, o endpoint de mensagens aceita texto, áudio, documentos, imagens, vídeos, templates e outros tipos; cada mensagem tem um ID que pode ser usado para acompanhar o status. O campo `context` referencia a mensagem à qual a resposta se vincula. Também é possível marcar uma mensagem recebida como lida pelo endpoint de mensagens. Consulte [Messages — Meta WhatsApp Business Platform](https://www.postman.com/meta/whatsapp-business-platform/folder/o48mro7/messages) e [WhatsApp Cloud API — documentação da coleção Meta](https://www.postman.com/meta/whatsapp-business-platform/documentation/wlk6lh4/whatsapp-cloud-api?entity=request-13382743-198b362a-c39e-48fc-a446-20fe430401e4).

Requisitos:

- persistir o ID externo da mensagem e mapear `context.id` para a mensagem original;
- renderizar uma prévia citada com tipo, trecho/legenda e clique para navegar até a mensagem;
- manter a resposta citada mesmo quando a mensagem original estiver em uma página anterior;
- mostrar fallback legível quando a mensagem citada tiver sido apagada ou não estiver disponível;
- manter a operação de marcar como lida separada do status de entrega.

### Tipos e limites de mídia

A referência oficial de mídia da Meta descreve upload, recuperação de URL e download, além dos tipos aceitos pela Cloud API. Para Cloud API, a tabela publicada lista áudio até 16 MB, imagem JPEG/PNG até 5 MB, vídeo 3GP/MP4 até 16 MB e documentos suportados até 100 MB; a referência também exige codecs específicos para determinados formatos. Consulte [Media — Meta WhatsApp Business Platform](https://www.postman.com/meta/whatsapp-business-platform/folder/13382743-ecb27be5-4d27-4763-bbee-6a8002c04bf3) e [Media Object — Meta WhatsApp Business Platform](https://www.postman.com/meta/whatsapp-business-platform/folder/t8iajsk/media-object).

O nome do arquivo, MIME type, checksum, ID e legenda devem ser preservados quando fornecidos. A UI deve validar o limite do canal antes do upload, mostrar progresso, permitir cancelar/repetir e exibir erro acionável. Não assumir que os limites da Cloud API sejam os limites do Uazapi; o adaptador do provedor precisa expor suas capacidades reais.

### Áudio e mensagem de voz no WhatsApp Web

O Help Center oficial documenta, para Web/Desktop, os seguintes comportamentos observáveis:

- gravação por microfone, pausa, continuação, pré-visualização, exclusão/cancelamento e envio;
- reprodução de mensagens enviadas ou recebidas;
- seek clicando/arrastando no waveform;
- velocidades `1x`, `1.5x` e `2x`;
- reprodução sequencial de mensagens de voz consecutivas;
- mini-player quando o usuário navega para outra conversa;
- diferenciação visual de voz ainda não reproduzida e voz já reproduzida.

Fontes: [How to send voice messages — WhatsApp Help Center](https://faq.whatsapp.com/657157755756612/?cms_platform=mac-desktop&helpref=platform_switcher), [How to play voice messages — WhatsApp Help Center](https://faq.whatsapp.com/1165411581043811/?cms_platform=windows-desktop&helpref=search&locale=kn_IN&query=Voice+Messages&search_session_id=71ad21097fe92384c537c8b83da967d1&sr=2) e [How to preview a voice message — WhatsApp Help Center](https://faq.whatsapp.com/1044960269529733/?cms_platform=web&locale=et_EE).

Requisitos de paridade:

1. O gravador deve ter estados claros `recording`, `paused`, `preview` e `discarded`, com timer estável e tratamento de permissão negada.
2. O áudio enviado deve preservar o MIME type/codec real dos bytes, não apenas a extensão escolhida.
3. O player deve possuir play/pause, waveform navegável, tempo atual, duração, velocidade `1x/1.5x/2x`, teclado e acessibilidade.
4. A reprodução deve pausar um player concorrente; mensagens consecutivas podem ser enfileiradas explicitamente.
5. O estado “reproduzido” deve ser separado do status de entrega/leitura.
6. Falhas de download, codec, autoplay e saída de áudio devem ter feedback sem quebrar o restante da conversa.

### Imagens, vídeos, documentos e arrastar-e-soltar

O Help Center oficial do WhatsApp Web documenta anexar fotos/vídeos, documentos e PDFs pelo botão de anexo, além de arrastar e soltar fotos, vídeos e documentos no campo de texto. Também documenta pré-visualização de PDFs e limite de documentos de 2 GB no produto WhatsApp, que não deve ser confundido automaticamente com o limite da Cloud API ou do Chatwoot. Consulte [How to send media, contacts, or location — WhatsApp Help Center](https://faq.whatsapp.com/453914586839706/?cms_platform=web&locale=sq_AL).

Requisitos de UI:

- imagem: miniatura responsiva, preservação de proporção, legenda, zoom/galeria, download e estado de carregamento/erro;
- vídeo: miniatura ou player inline com controles, poster, proporção preservada, tela ampliada e fallback;
- documento: ícone por tipo, nome truncado sem perder tooltip, tamanho, download e preview quando o formato for suportado;
- anexos múltiplos: ordenação estável, mosaico sem overflow, legenda associada ao conjunto correto;
- composer: seleção de arquivos, drag-and-drop, preview antes do envio, progresso individual, cancelamento e retry;
- limites: mensagens de validação devem mencionar limite do canal, não um limite genérico incorreto.

### Horários, datas, presença e “visto por último”

O payload oficial de mensagem e de status contém timestamps Unix. O produto deve conservar o timestamp externo e o timestamp de persistência do Chatwoot separadamente quando forem diferentes. A UI deve exibir hora local da instalação/usuário, datas separadoras por dia, e uma indicação consistente para mensagens antigas; o formato exato do WhatsApp Web não é uma especificação pública.

O WhatsApp Help Center define “last seen” como o último momento em que a pessoa usou o WhatsApp e “online” como WhatsApp aberto e conectado à Internet, mas deixa claro que estar online não significa ter lido uma mensagem. Privacidade pode ocultar esses dados e, se o usuário não compartilha os próprios dados, também não vê os de outros. Consulte [About last seen and online — WhatsApp Help Center](https://faq.whatsapp.com/general/chats/about-last-seen-and-online?lang=ta) e [How to change your privacy settings — WhatsApp Help Center](https://faq.whatsapp.com/3307102709559968/?cms_platform=web).

Requisitos:

- distinguir `online`, `last seen`, `typing` e `read` como sinais independentes;
- nunca inferir “visto por último” a partir do horário da última mensagem;
- ocultar ou indicar indisponibilidade quando o provedor/política de privacidade não fornecer o dado;
- não mostrar “online” baseado apenas no navegador do agente;
- renderizar typing com expiração para não deixar o indicador preso;
- usar relógio monotônico/servidor para ordenar eventos e tolerar diferenças de fuso.

## O que a documentação e o código do Chatwoot mostram hoje

### Tempo real e recuperação

O guia oficial do Chatwoot descreve Action Cable/WebSocket como conexão bidirecional contínua para atualizar dados sem reload. Para o canal de sala, a documentação lista `message.created`, `message.updated`, `conversation_typing_on`, `conversation_typing_off` e `presence.update`, entre outros eventos; também recomenda usar o token PubSub mais recente e classifica a interface como experimental, sujeita a mudanças. Consulte [How to setup a WebSocket connection? — Chatwoot Help Center](https://chatwoot.help/hc/user-guide/articles/1677691027-how-to-setup-a-web_socket-connection).

Na inspeção local:

- `app/javascript/dashboard/helper/actionCable.js` encaminha `message.created` diretamente para `addMessage`, `message.updated` para `updateMessage`, presença para contatos/agentes e eventos de digitação para a UI;
- `app/javascript/dashboard/helper/ReconnectService.js` executa sincronização da conversa ativa em intervalos de 5 segundos apenas quando a aba está visível, evita requests concorrentes e faz sincronização adicional em foco/reconexão;
- `MessagesView.vue` preserva scroll durante paginação, marca mensagens como lidas, mostra separador/contador de não lidas e evita autoscroll destrutivo quando o operador está lendo histórico;
- o código tem a arquitetura correta de “evento rápido + reconciliação”, mas o comportamento final depende da entrega confiável do webhook do provedor, do worker, Redis, Action Cable e do adaptador que transforma o evento externo em mensagem Chatwoot.

### Balões, agrupamento e metadados

Na implementação local, `components-next/message/Message.vue` seleciona bubbles por tipo e carrega status, anexos, remetente e `inReplyTo`. `bubbles/Base.vue` usa variantes para agente/usuário/privado/erro, cantos assimétricos para o “rabicho”, largura máxima responsiva, agrupamento de mensagens consecutivas e metadados no fim do balão. A fonte oficial equivalente está no [diretório de componentes de mensagem do Chatwoot](https://github.com/chatwoot/chatwoot/tree/develop/app/javascript/dashboard/components-next/message).

`MessageMeta.vue` usa o helper de timestamp do Chatwoot e o componente `MessageStatus.vue`; na revisão local, uma marca representa `sent`, duas `delivered`, duas azuis `read`, e mensagens falhas não mostram a marca porque exibem erro separado. Isso é compatível com o modelo de estados documentado pelo Chatwoot, mas a cor, espessura, ícone, distância e animação exatas não são uma especificação oficial do WhatsApp Web.

### Respostas e tipos de conteúdo

O bubble base já renderiza uma prévia citada clicável e emite navegação para a mensagem original. O [ReplyToMessage.vue](https://github.com/chatwoot/chatwoot/blob/develop/app/javascript/dashboard/components/widgets/conversation/ReplyToMessage.vue) implementa a faixa de composição “respondendo a” com descarte. Os bubbles oficiais do Chatwoot cobrem texto, imagem, vídeo, áudio, arquivo, localização, contato, fallback e outros tipos no [diretório de bubbles](https://github.com/chatwoot/chatwoot/tree/develop/app/javascript/dashboard/components-next/message/bubbles).

O Chatwoot publica uma matriz de capacidades por canal. Para WhatsApp Cloud, ela documenta resposta a mensagens de entrada e saída, áudio/imagem/vídeo/documento com limites próprios, e suporte a anexos; a mesma página alerta que recursos variam por canal. Consulte [Supported Features on Channels — Chatwoot Developer Docs](https://developers.chatwoot.com/self-hosted/supported-features).

### Áudio local

O `chips/Audio.vue` local já implementa player HTML5 oculto, waveform visual, seek por clique, duração, play/pause, pausa de outros players e transcrição opcional. O `AudioRecorder.vue` usa WaveSurfer/RecordPlugin, emite progresso, pausa/play, término e erro, e converte o Blob antes de criar o arquivo. Para paridade com o comportamento oficial documentado ainda faltam, ou precisam ser explicitamente validados:

- seletor de velocidade `1x/1.5x/2x`;
- mini-player persistente ao trocar de conversa;
- estado visual de voz não reproduzida/reproduzida;
- fila sequencial opcional;
- confirmação de que o backend/provider preserva codec, duração, MIME e bytes em todos os navegadores;
- testes de teclado, autoplay bloqueado, dispositivo sem microfone e rede lenta.

## Requisitos concretos para a próxima implementação

### Camada de dados e realtime

- normalizar cada evento externo para `{ external_id, conversation_id, direction, type, timestamp, status, media, reply_context }`;
- deduplicar por `external_id` e atualizar a mesma mensagem, nunca criar uma bolha duplicada;
- aceitar eventos fora de ordem sem regredir status;
- registrar o timestamp do provedor e o timestamp de ingestão;
- usar WebSocket como caminho primário, reconectar com backoff e executar backfill delimitado por último ID/horário após reconexão;
- manter a reconciliação de segurança para corrigir perda de evento, com proteção contra sobreposição e sem autoscroll indevido;
- expor estado de conexão ao operador: conectado, reconectando, offline e sincronizando;
- instrumentar latências: provedor → webhook, webhook → banco, banco → Action Cable, Action Cable → renderização.

### Experiência de conversa

- balões alinhados por remetente, agrupamento consistente e largura fluida em desktop, tablet e mobile;
- metadata de hora/data sempre estável, com timezone explícito na preferência do usuário;
- status visual com tooltip/texto acessível e erro acionável;
- separador de não lidas, “novas mensagens” e scroll suave somente quando o operador estiver no fim da conversa;
- menu de ações por hover e teclado, com foco visível e suporte a touch;
- resposta citada navegável, inclusive para mensagens fora da página atual;
- reações, encaminhamento, cópia, download, abertura em galeria e retry conforme o suporte real do canal;
- redução/remoção de animações quando `prefers-reduced-motion` estiver ativo;
- estados skeleton/loading/erro vazios sem bloquear o composer ou a navegação.

### Mídia e composer

- drag-and-drop e seletor de arquivos;
- preview antes do envio e caption associado;
- upload multipart/resumível ou fila com retry quando suportado pela infraestrutura;
- validação de MIME, tamanho e codec no cliente e no servidor;
- imagem com `object-fit` e proporção segura, sem estourar o balão;
- vídeo com poster, controles nativos e fallback;
- documento com nome, tipo, tamanho, download e preview seguro;
- áudio com gravar/pausar/continuar/pré-visualizar/apagar/enviar, waveform, seek, velocidade, duração e estado reproduzido;
- não confiar em extensão para decidir o tipo real.

## Matriz de limitações

| Tema | O que é comprovável | Limitação |
| --- | --- | --- |
| Status | Estados e payloads da Cloud API são documentados pela Meta; Chatwoot documenta o mapeamento | Uazapi pode ter semântica/atraso diferente; validar o contrato do adaptador |
| WebSocket | Chatwoot documenta Action Cable e eventos | O próprio guia chama a integração de experimental; proxy, Redis e workers podem interromper o fluxo |
| Last seen/online | WhatsApp documenta significado e controles de privacidade | Não há garantia de disponibilidade via provedor; não inferir o dado |
| Áudio | WhatsApp documenta controles e fluxo Web/Desktop | Codec, waveform exato, mini-player e assets internos do WhatsApp Web não são públicos |
| Layout | É possível reproduzir princípios observáveis e responsivos | Tamanhos exatos, tokens, transições e código do WhatsApp Web são proprietários |
| Limites | Meta e Chatwoot publicam tabelas próprias | Cloud API, WhatsApp Web e Uazapi não são necessariamente o mesmo produto/limite |
| Pixel parity | Não há fonte oficial que especifique o CSS interno | Deve ser substituída por critérios visuais e comportamentais testáveis, sem copiar código/assets proprietários |

## Plano de verificação antes de subir qualquer alteração

1. **Unidade:** fixtures de texto, imagem, vídeo, áudio, documento, resposta citada, `progress`, `sent`, `delivered`, `read` e `failed`; testes de status fora de ordem e duplicado.
2. **Componente:** snapshots/visual regression em larguras desktop, tablet e mobile; teclado, touch, `prefers-reduced-motion`, erro de mídia e limites.
3. **Realtime:** abrir a conversa, enviar/receber sem recarregar, interromper e restaurar WebSocket, verificar backfill, foco, aba em background e scroll no meio do histórico.
4. **WhatsApp/provedor:** texto, imagem com legenda, vídeo, PDF, documento, áudio gravado, reply/context e status; verificar IDs externos, timestamps e ausência de duplicidade.
5. **Carga:** medir p95 de webhook→render, fila do worker, Action Cable, Redis e browser main thread; testar bursts de mensagens e anexos grandes.
6. **Produção:** canário, logs sem segredos, rollback conhecido, health check, reconexão e teste real controlado para o número autorizado.

## Fontes primárias

- [WhatsApp Cloud API — Messages, Meta Postman workspace](https://www.postman.com/meta/whatsapp-business-platform/folder/o48mro7/messages)
- [WhatsApp Cloud API — Message Status Update Notifications, Meta Postman workspace](https://www.postman.com/meta/whatsapp-business-platform/request/rgtfq23/message-status-update-notifications)
- [WhatsApp Cloud API — Statuses Object, Meta Postman workspace](https://www.postman.com/meta/whatsapp-business-platform/folder/fuaee8l/statuses-object)
- [WhatsApp Cloud API — Context Object, Meta Postman workspace](https://www.postman.com/meta/whatsapp-business-platform/folder/hysdhqs/context-object)
- [WhatsApp Cloud API — Media, Meta Postman workspace](https://www.postman.com/meta/whatsapp-business-platform/folder/13382743-ecb27be5-4d27-4763-bbee-6a8002c04bf3)
- [WhatsApp Cloud API — Media Object, Meta Postman workspace](https://www.postman.com/meta/whatsapp-business-platform/folder/t8iajsk/media-object)
- [How to send voice messages, WhatsApp Help Center](https://faq.whatsapp.com/657157755756612/?cms_platform=mac-desktop&helpref=platform_switcher)
- [How to play voice messages, WhatsApp Help Center](https://faq.whatsapp.com/1165411581043811/?cms_platform=windows-desktop&helpref=search&locale=kn_IN&query=Voice+Messages&search_session_id=71ad21097fe92384c537c8b83da967d1&sr=2)
- [How to preview a voice message, WhatsApp Help Center](https://faq.whatsapp.com/1044960269529733/?cms_platform=web&locale=et_EE)
- [How to send media, contacts, or location, WhatsApp Help Center](https://faq.whatsapp.com/453914586839706/?cms_platform=web&locale=sq_AL)
- [About last seen and online, WhatsApp Help Center](https://faq.whatsapp.com/general/chats/about-last-seen-and-online?lang=ta)
- [How to change your privacy settings, WhatsApp Help Center](https://faq.whatsapp.com/3307102709559968/?cms_platform=web)
- [How to setup a WebSocket connection, Chatwoot Help Center](https://chatwoot.help/hc/user-guide/articles/1677691027-how-to-setup-a-web_socket-connection)
- [Message Statuses, Chatwoot Developer Docs](https://developers.chatwoot.com/self-hosted/message-statuses)
- [Supported Features on Channels, Chatwoot Developer Docs](https://developers.chatwoot.com/self-hosted/supported-features)
- [Chatwoot message components, official source](https://github.com/chatwoot/chatwoot/tree/develop/app/javascript/dashboard/components-next/message)
- [Chatwoot Action Cable helper, official source](https://github.com/chatwoot/chatwoot/blob/develop/app/javascript/dashboard/helper/actionCable.js)
- [Chatwoot reconnect service, official source](https://github.com/chatwoot/chatwoot/blob/develop/app/javascript/dashboard/helper/ReconnectService.js)
- [Chatwoot message model, official source](https://github.com/chatwoot/chatwoot/blob/develop/app/models/message.rb)

> **Nota de interpretação:** quando este documento transforma uma capacidade documentada em requisito de UX ou em estratégia de implementação, isso é uma recomendação de engenharia derivada das fontes, não uma afirmação de que o WhatsApp Web publica seu código ou seu CSS interno.
