# Chatwoot — áudio, UAZAPI, identidade, busca e ações de status

Data: 2026-09-15
Branch: `rotta-custom-v1`
Escopo: os cinco ajustes descritos nos vídeos de 15/09/2026.

## Resultado da análise dos vídeos

Foram revisados integralmente os três vídeos. O primeiro registra o envio de áudio, uma mensagem marcada como falha no Chatwoot apesar de aparecer no WhatsApp, e a identidade visual/nome do remetente. O tooltip do Chatwoot mostra `Net::ReadTimeout with #<TCPSocket:(closed)>`. O segundo demonstra a busca de conversas. O terceiro mostra as ações nativas de status.

### Transcrição consolidada

**Vídeo `20260915-2024-05.1819630.mp4`**

> Então, o primeiro ajuste que eu quero que você faça será na parte de envio de áudio. Quando a gente faz o envio do áudio aqui, começa a gravar, note que está gravando, e na hora de enviar é necessário clicar aqui em pausar áudio e depois clicar em enviar, pois o botão de enviar fica desabilitado. Porém, eu quero que esse botão de enviar fique habilitado para qualquer momento que você estiver gravando este áudio, você conseguir clicar em enviar e enviar do ponto que está, ok? Senão ele fica em loop infinito. Então esta será o primeiro ajuste que nós iremos fazer, ok?
>
> O segundo ajuste: note que está dando falha ao enviar. Por algum motivo está dando falha. Olha aqui o motivo, leia; falou alguma coisa sobre o timeout. Porém, esta mensagem foi enviada normalmente, eu conferi no WhatsApp normal. Então eu preciso que você verifique o motivo deste erro e veja se ele já foi ajustado.
>
> O terceiro ponto: note que aqui está escrito “enviado por Kelvin” e aqui está escrito “enviado por Caio Mazini”, porém a empresa em questão continua sendo a Rotta. É igual no WhatsApp, que é exatamente esta empresa, cuja foto é da Rotta. Então veja como chega para os clientes: chega como se fosse a Rotta enviando, tá vendo? Diante disso, eu preciso que você ajuste esse ponto. Precisamos deixar mais aprimorada toda esta parte. Eu quero que seja mostrada sempre a foto da Rotta, a foto padrão. Mas eu também preciso… cliquei em atualizar… mas eu também preciso que não apareça o meu nome, pois ali você viu que está o meu nome Kelvin. Eu não quero que o cliente veja o meu nome, ok? E o mesmo se equivale para o Caio. Quero que o cliente não veja o meu nome e quero também que fique aparecendo como da Rotta, enviado normalmente. Precisamos fazer esse ajuste. Eu vou procurar um cliente no qual foi enviado para você ter noção de como fica, pois fica escrito Caio Mazini em cima e Kelvin nos envios no chat, e é isso que eu não queria. Olha aqui, tá vendo? Escrito Caio Mazini. Foi enviado por lá. Essa é a mesma mensagem que deu falha, mas note que aqui funcionou corretamente. Aqui é WhatsApp Web. Agora, outro ponto de ajuste será nessas pesquisas de conversas. Eu quero que seja bem otimizada pra gente: sempre que escrever, seja o nome do cliente ou o número, já apareça tudo aqui. Por fim, o último ajuste será a remoção desta parte: a conversa que tem “resolver”, “adiar”, “deixar pendente”. Eu quero que você elimine isso. Essa função não vai existir no Chatbot. Elimine tudo que tem a resolver, adiar e deixar pendente. Pode tirar tudo isso.

**Vídeo `20260915-2028-21.4998547.mp4`**

> Outro ponto de ajuste que eu quero que você faça será nessas pesquisas de conversas, tá? Eu quero que seja bem otimizada pra gente sempre que escrever seja o nome do cliente ou o número já apareça tudo aqui de forma perfeita, tá bom?

**Vídeo `20260915-2029-04.7568869.mp4`**

> A remoção desta parte aqui, tá vendo? Tá vendo essa conversa dessa cliente que tem como resolver, clicar em resolver, adiar, deixar pendente? Eu quero que você elimine isso aqui, essa função não vai existir no Chatbot. Elimine tudo que tem a resolver, adiar e deixar pendente. Pode tirar tudo isso.

## Correções implementadas

1. **Gravação de áudio:** o botão pode enviar durante a gravação. Ao clicar, a captura é finalizada, o arquivo é convertido e o envio espera o upload/anexo terminar. Falhas de upload mantêm o envio bloqueado; gravações em finalização/upload não podem ser descartadas/iniciadas novamente nem enviadas em duplicidade.
2. **Falso erro UAZAPI:** o vídeo mostra `Net::ReadTimeout`. Timeout de leitura é resultado ambíguo — o provedor pode ter aceitado a mensagem sem devolver a resposta a tempo. Em vez de classificá-la imediatamente como falha, o Chatwoot registra estado enviado aguardando confirmação; eco/status UAZAPI correlacionado por `track_id` grava o ID externo e limpa erro/estado pendente. Rejeições explícitas continuam como falha.
3. **Nome/identidade:** o adaptador envia apenas o conteúdo da mensagem, ignorando inclusive a configuração legada que acrescentava o nome do agente. A autoria interna continua registrada em `sender` no Chatwoot. A foto e o nome públicos são os do perfil da instância WhatsApp/UAZAPI; o envio de mensagem não troca esses dados. Mensagens antigas não são reescritas.
4. **Busca:** a busca remota continua com debounce, agora invalida respostas antigas quando a consulta muda; a busca local normaliza acentos/caixa e telefones; o servidor também procura dígitos no telefone e no identificador WhatsApp do contato. A consulta pede até 100 resultados.
5. **Status da conversa:** removidos os controles de resolver/reabrir/adiar/pendente da conversa, os atalhos associados, o menu de ações em lote e o submenu de status na command bar. “Adiar notificação” permanece, pois altera notificações e não o status da conversa. O modelo/status histórico e integrações internas de macros/automações permanecem intactos para não alterar fluxos já configurados.

## Validação

- Vitest focalizado: **126 testes passaram** (ReplyBox, busca, atalhos em lote e command bar), incluindo regressões de busca com acentos, fusão de resultados locais/remotos e deduplicação. O teste específico do hook de conversa que proíbe “adiar conversa” também passou.
- ESLint nos arquivos JavaScript/Vue alterados: **0 erros**, 6 avisos de tradução dinâmica já usados pelo projeto.
- Há 2 falhas preexistentes em outros casos de `useConversationHotKeys.spec.js`, que esperam ações de atribuição de agente/time ausentes na implementação-base; não foram alteradas por este escopo.
- Os RSpecs de busca, serviço UAZAPI e webhook foram adicionados/atualizados, mas não puderam ser executados localmente: esta estação não tem Ruby/Bundler e o Docker Desktop está sem daemon Linux ativo. A execução desses specs e a confirmação do deploy ficam pendentes no pipeline/ambiente.
- Não foi enviada mensagem real nem alterada conversa de cliente. O perfil público do WhatsApp deve ser validado por leitura da instância após deploy; não se deve enviar mensagem de teste sem autorização específica para esse teste.

## Limites e próximos passos

- Primeiro deploy do commit `a8529b1b` concluído pelo EasyPanel com log `Success` às 21:39:39 GMT; Rails, Sidekiq e Sidekiq UAZAPI foram iniciados. Smoke `/health` e `/app/login`: HTTP 200. O aviso de containers órfãos foi observado, mas nenhum foi removido.
- No smoke read-only pós-deploy, a busca por “Tati Leal” retornou a conversa; “Heloísa Brizolari” não encontrou “Heloisa Brizolari”. A correção que combina e deduplica resultados remotos e locais foi commitada em `beddad06`; o segundo deploy terminou `Success` às 21:50:13 GMT, mas o teste ainda carregou o bundle antigo. A causa foi o pacote de deploy: `docker/Dockerfile.overlay` copia `public/vite` para a imagem, enquanto os novos bundles gerados estavam ignorados/não commitados. Portanto, o sucesso do segundo deploy não significou que a interface nova estava publicada.
- Não usar botão de envio para simular mensagem a clientes.
- A correção remove o prefixo inserido pelo Chatwoot. Se o nome do agente ainda aparecer no WhatsApp depois disso, revisar o comportamento da instância/configuração UAZAPI sem fazer envio real.

### Publicação dos bundles Vite

- Build de produção executado novamente a partir do código incluindo `beddad06`: 5.100 módulos transformados, concluído em 1m13s; o bundle de Dashboard gerado é `dashboard-t7cB-ix7.js`. O build terminou com sucesso (avisos de tamanho de chunk e Browserslist, sem erro).
- O manifesto atual referencia 240 assets; todos estão presentes localmente e versionados/staged. Para a imagem overlay efetivamente servir esta versão, estão sendo publicados o manifesto e os 51 assets novos que faltavam no Git (52 arquivos ao todo; cerca de 31,8 MB). Assets Vite minificados preservam espaços de comentários/licenças de terceiros; por isso `git diff --check` aponta whitespace somente nos bundles gerados, não em alterações-fonte.
- A build incluída em `68c44b37` foi implantada com sucesso pelo EasyPanel às 22:04:05 GMT. O smoke imediato deu 502 durante a subida dos containers; após inicialização, `/health` e `/app/login` voltaram a HTTP 200 (`{"status":"woot"}`), e os logs Rails registraram as chamadas da caixa concluídas em 200.
- Smoke real read-only no Chatwoot após o deploy: a consulta `Heloísa Brizolari` retornou “Heloisa Brizolari”; a consulta pelo número de teste `11965927865` também retornou uma conversa sem abrir nem alterar a conversa. O card desse resultado apareceu com nome `undefined`, identificado como falha de apresentação quando falta o nome do contato.
- Ajuste adicional em `ConversationCard.vue`: exibir primeiro o nome; se ausente/“undefined”, tentar telefone do contato/remetente, identificador WhatsApp sem sufixo `@...` e, por último, o ID da conversa. Teste de regressão cobre nome e rótulo acessível do card.
- A nova build após esse ajuste compilou 5.100 módulos em 1m15s; Dashboard `dashboard-DcuOgjIW.js`. 13 testes direcionados (card, busca normalizada e cabeçalho da lista) passaram; ESLint e Prettier sem erros; manifesto verifica 240 assets. O commit `65f8e7ae` que contém esse bundle foi implantado no EasyPanel às 22:15:10 UTC e validado abaixo.
- Nenhuma mensagem WhatsApp foi enviada; nenhuma conversa foi aberta ou modificada durante estes testes.

### Fechamento e verificação final em produção — 15/09/2026

- O EasyPanel implantou o commit funcional `65f8e7ae` (`fix(search): show fallback identity for nameless contacts`) e registrou `Success` às 22:15:10 UTC. O build copiou `public/vite` para a imagem e recriou Rails, Sidekiq e Sidekiq UAZAPI; o aviso de containers órfãos permaneceu apenas como aviso e nenhum container foi removido.
- Smoke pós-deploy: `/health` HTTP 200 (`{"status":"woot"}`) e `/app/login` HTTP 200. A imagem implantada foi construída do commit funcional `65f8e7ae0c90a4276e8aa3ee5023883fc7eff9e3`; depois, o branch GitHub `rotta-custom-v1` recebeu commits posteriores somente documentais, sem alteração do código implantado ou novo deploy.
- Smoke real read-only no Chatwoot após carregar a versão `65f8e7ae`: buscas por `11965927865` e `+5511965927865` retornaram a conversa `#4`, cartão `~Kelvin Martins`, sem `undefined`. A primeira leitura imediata da busca local mostrou vazio; após a consulta estabilizar/repetir, o resultado apareceu. Isso foi registrado como comportamento de timing, não como prova de latência constante. Nenhuma conversa foi aberta.
- Regressão do caso sem nome validada em teste unitário; pacote direcionado: 13/13 testes passando. Build Vite com 5.100 módulos e verificação dos 240 assets concluídas; ESLint e Prettier sem erros.
- Limites do teste real: não enviei mensagem pelo WhatsApp nem gravei/enfileirei áudio real; não alterei cliente/conversa. O perfil público (nome/foto) da instância não foi alterado nem validado por mensagem enviada. RSpecs Rails continuam sem execução local por ausência de Ruby/Bundler e daemon Linux do Docker.
- Trilha funcional publicada: `a8529b1b` (áudio, timeout, identidade e status), `beddad06` (busca local/remota), `68c44b37` (bundles Vite exigidos pelo overlay Docker) e `65f8e7ae` (fallback visual para contato sem nome). A auditoria foi sincronizada no GitHub no commit documental `e32d6d21d47cfb4d36fc19d23366cdd3ca3708d2`; esse commit não alterou o artefato implantado nem exigiu novo deploy.
