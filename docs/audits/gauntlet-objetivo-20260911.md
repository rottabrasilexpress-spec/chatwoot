# Gauntlet — Implementações operacionais Rotta/Chatwoot

Data de início: 2026-09-11  
Branch de trabalho: `codex/rotta-objective-20260911`  
Base: `rotta-custom-v1` (`0d22fada4`)  
Deploy alvo: Easypanel/Chatwoot Rotta

## Contrato

### Por quê

Entregar quatro melhorias solicitadas para o atendimento no Chatwoot sem quebrar o fluxo existente de conversas, Follow-up, etiquetas, WhatsApp ou IA.

### O quê

1. Menu de contexto: remover reabrir/pendente e adicionar `Solicitar Atenção`, restrito ao agente autorizado, com aviso interno direcionado ao Caio e dados do cliente.
2. Etiqueta `Caio Atenção`: alerta visual e sonoro para o agente Caio quando a etiqueta for aplicada.
3. Mensagens apagadas pelo cliente: retenção interna por dois dias e visualização somente para agentes autorizados.
4. Composer: permitir reduzir mais a área e diferenciar transcrição por áudio de gravação de áudio para envio.

### Fora do escopo

Alterar o motor de Follow-up, os workflows UAZAPI/n8n ou a aparência/fluxos já estabilizados sem necessidade técnica direta.

## Régua AAA fixada

| Critério | Peso |
|---|---:|
| Correção | 25 |
| Completude | 20 |
| Verificação | 20 |
| Coerência integrada | 15 |
| Utilidade | 10 |
| Acabamento | 10 |

Gate: nota total >= 95, nenhum critério < 90, zero falha crítica e todos os testes obrigatórios aprovados.

## Microtarefas

| ID | Objetivo | Dono | Arquivos próprios | Aceite local | Estado |
|---|---|---|---|---|---|
| M1 | Implementar ação `Solicitar Atenção` com autorização e aviso interno | especialista de conversas | menu/ações de conversa, endpoint/serviço próprio, specs correspondentes | agente não autorizado não executa; Caio recebe aviso sem mensagem pública | concluída localmente; backend + policy + endpoint + alerta privado |
| M2 | Implementar alerta de `Caio Atenção` | especialista de etiquetas/notificações | componentes de sidebar/notificação, canal/evento e specs correspondentes | aplicação da etiqueta gera alerta apenas no alvo e sem duplicação | concluída localmente; Action Cable + deduplicação + alerta visual/sonoro |
| M3 | Reter e exibir mensagem apagada por dois dias | especialista de mensagens | modelo/migration/serviço/bubble e specs correspondentes | cliente não vê conteúdo; agente autorizado vê até TTL; após TTL não vê | concluída localmente; criptografia condicionada e job TTL |
| M4 | Ajustar composer e separar transcrição de gravação | especialista de composer/áudio | composer, recorder/transcriber, i18n e specs correspondentes | controles distintos; gravação envia áudio; transcrição envia texto pt-BR | concluída localmente; idioma `pt-BR` e controles distintos |
| I1 | Integrar, publicar manifestos/assets e validar E2E | controlador | interfaces compartilhadas, testes integrados, ledger | testes automatizados e navegador aprovados | deploy final publicado; validação ao vivo em andamento |
| R1 | Revisão independente AAA do snapshot integrado | revisor independente | nenhum | relatório com nota e veto por critério | veto recebido (72/100); correções aplicadas; R2 solicitado |

## Hipóteses iniciais verificáveis

1. O fork já possui pontos de extensão para Follow-up, IA e etiquetas; cada implementação deve reutilizar os canais existentes antes de criar infraestrutura nova.
2. A autorização de `Solicitar Atenção` precisa ser aplicada no backend, não apenas ocultada no menu.
3. O evento de etiqueta já chega ao frontend por Action Cable, mas o alerta deve deduplicar por conversa/etiqueta/evento.
4. A exclusão atual de mensagem pode preservar metadados, mas não conteúdo; a retenção deve ser independente do texto público renderizado.
5. O composer já possui gravação ou transcrição parcial; a entrega deve separar ações sem duplicar upload ou envio público.

## Checkpoints

| Rodada | Snapshot | Estado | Evidência | Nota |
|---:|---|---|---|---:|
| 0 | `cfeb0630a` | base limpa inspecionada | branch `rotta-custom-v1` e working tree limpos | — |
| 1 | `0d22fada4` | primeiro snapshot integrado | Vitest focalizado 29/30; build Vite aprovado; deploy Rails concluído, mas manifesto ainda antigo | veto independente: menu removeu `Resolver`, cobertura Ruby insuficiente |
| 2 | working tree pós-revisão | correções de segurança e publicação | ação `Resolver` preservada; `pt-BR`; specs de retenção/detector/job/policy/endpoint; manifesto verifica 240 assets; IDs dos agentes e chaves de criptografia adicionados no Easypanel | aguarda commit, novo deploy e R2 |
| 3 | `217f5941a` / `origin/rotta-custom-v1` | snapshot publicado | push concluído; Easypanel concluiu build e recriação dos três containers; Rails runner confirmou boot, criptografia e IDs `Caio=2`/`requester=1`; `/app/login` 200; manifesto ao vivo aponta `dashboard-Cm3m31nO.js` e `Messages-Bj9ACAIM.js`; navegador mostrou 50-page size, labels e menu contextual sem reabrir/pendente/fechar | R2 pendente |

## Registro operacional

- O primeiro 502 observado imediatamente após a recriação foi transitório; após a inicialização, o health check retornou 200.
- A configuração de criptografia foi adicionada ao ambiente de produção para habilitar a retenção interna sem expor os valores no repositório ou neste registro.
- O menu contextual foi verificado no navegador autenticado como Kelvin: apresentou `Solicitar Atenção`, `Marcar como resolvida`, `Adiar`, `Arquivar conversa`, etiquetas, link e fixação; não apresentou `Reabrir`, `Deixar pendente` ou `Fechar conversa`.
- Os testes Ruby continuam dependentes do runtime do container; localmente não há Ruby/Bundler disponíveis. O boot Rails remoto foi executado sem alteração de dados.

## Checkpoint 4 — overlay backend e migração recuperável — 12/09/2026

- O deploy `e0b997114` confirmou que o `Dockerfile.overlay` passou a copiar os arquivos backend de atenção, retenção, ditado, políticas, listener e controller para Rails/Sidekiq/Sidekiq UAZAPI.
- Esse deploy revelou um erro real de migração: `t.references :message` criava o índice automaticamente e a migração tentava criá-lo novamente. O serviço chegou a responder 502 durante a inicialização.
- A correção foi publicada no commit `1bc4c0096`: tabela e índices passaram a ser criados de forma recuperável, com reparo do índice parcialmente criado sem apagar dados de retenção.

## Checkpoint 5 — deploy recuperado e teste live — 12/09/2026

- Easypanel concluiu em verde o deploy `1bc4c0096` às `03:22:01 UTC`, recriando Rails, Sidekiq e Sidekiq UAZAPI; os logs terminaram com `Success`.
- Health check live voltou a HTTP 200 em `/app/login`; o manifesto continua servindo `dashboard-Cm3m31nO.js` e `Messages-Bj9ACAIM.js`.
- Após recarregar o Chatwoot autenticado como Kelvin, a lista carregou sem scroll inicial e terminou em “Todas as conversas carregadas”. O menu contextual manteve `Solicitar Atenção`, resolver, adiar, arquivar, etiquetas, link e fixação, sem reabrir/pendente/fechar.
- O teste real de `Solicitar Atenção` retornou o aviso `Solicitação enviada para o agente Caio.`. Não houve mensagem pública nem envio ao WhatsApp.
- O filtro `Caio Atenção` abriu uma conversa real e mostrou os chips `caio-atencao` e `clientes-fechados`, confirmando que a rota e a etiqueta existem.
- Pendência separada de contadores: a rota `ORÇAMENTOS/Kelvin` mostrou `#kelvin` com meta 1 ao mesmo tempo em que a lista informou “Não há conversas ativas neste grupo”. A implementação do filtro exclui resolvidas, enquanto a meta ainda conserva esse valor; isso deve ser corrigido em rodada própria, sem atribuí-lo ao deploy de retenção.
- A rota de Follow-up abriu em aproximadamente 4,5 s e estava vazia; não foi possível repetir o duplo clique em um cartão sem criar dados artificiais.

## Checkpoint 6 — prova runtime e diagnóstico oficial do aplicativo móvel — 12/09/2026

- No container Rails live `/n8nsaas_chatwoot-rotta-rails-1`, usando o shell POSIX disponível, o `rails runner` confirmou `DeletedMessageContent` carregado (`defined? => constant`), tabela `deleted_message_contents` existente (`true`), atributo criptografado `[:content]` e `RETENTION_PERIOD => 172800` segundos (48 horas). Nenhuma linha ou mensagem foi criada/alterada nessa verificação.
- O boot do runner registrou dois avisos não bloqueantes que ficam pendentes para limpeza técnica: a API legada do RubyLLM está depreciada e `Events::Types::CONVERSATION_CAIO_ATTENTION_ADDED` aparece como constante inicializada duas vezes. Isso não foi mascarado como aprovação completa.
- A documentação oficial do Chatwoot para o aplicativo móvel informa que uma instalação auto-hospedada deve receber a URL do servidor no formato de domínio/base (`domain.com`), e a página oficial de mobile exemplifica uma URL de instalação sem `/app/...`. A pesquisa também registrou a orientação oficial de `FRONTEND_URL` como URL pública raiz.
- Para esta instalação, o valor correto no aplicativo é `https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host` (sem `/app/login`, sem `/app/accounts/1/dashboard` e sem qualquer outra rota). Se o domínio customizado estiver apontando para o mesmo serviço, pode ser usado `https://atendimento.via-cargo.com`.
- Procedimento recomendado: apagar a instalação salva no aplicativo, atualizar o Chatwoot pela loja, fechar/reabrir o app, informar somente a URL-base com HTTPS e entrar com o mesmo usuário. `app.chatwoot.com` é apenas para Chatwoot Cloud; não é a URL desta instalação. Se a URL-base conectar mas a conta vier vazia, a próxima verificação é cache/sessão/WebSocket do app, pois a web já comprovou que os dados existem.

## Checkpoint 7 — causa raiz do contador fantasma e correção preparada — 12/09/2026

- A reprodução live da rota `ORÇAMENTOS/Kelvin` confirmou o defeito: o cabeçalho exibiu `#kelvin, Value: 1` enquanto a lista estava vazia e informava “Não há conversas ativas neste grupo”.
- A consulta read-only no Rails live, com `Current.account=Account.find(1)`, `Current.user=User.find(1)` e o mesmo filtro `status=all`, `assignee_type=all`, `labels=kelvin`, retornou `{ mine_count: 0, assigned_count: 0, unassigned_count: 0, all_count: 0 }`. A contagem global da etiqueta também retornou `0`; portanto o valor visual era estado/catalogo de etiqueta stale, não uma conversa ativa.
- Correção preparada somente no frontend: rota de etiqueta usa a meta filtrada `conversationStats.allCount`, solicita essa meta imediatamente ao montar/trocar a rota e após adicionar/remover etiquetas; também corrige a leitura existente `all_count` para o estado camelCase `allCount`. A constante duplicada de `CONVERSATION_CAIO_ATTENTION_ADDED` foi removida para eliminar o warning de boot.
- Teste focalizado: `conversationStats/actions.spec.js` e `labels/sidebarLabelCounts.spec.js` passaram, 9/9. ESLint focado passou sem erros quando isolada a diferença de CRLF preexistente, mantendo apenas 2 warnings de chaves i18n dinâmicas já existentes.
- A suíte frontend completa terminou com `4315 passed / 33 failed` em 443 arquivos; as falhas restantes são de ambiente/locale/fuso/estado global (por exemplo, timezone UTC, traduções pt-BR e dados de macros), sem falha apontada nos arquivos da correção. O script `pnpm test` nativo não funciona no Windows porque usa `TZ=UTC`; a execução equivalente via `corepack pnpm exec vitest` foi usada.
- Estado: código ainda não implantado neste checkpoint; próximo passo obrigatório é commit, push para `origin/rotta-custom-v1`, deploy verde no Easypanel e revalidação live da rota Kelvin e da atualização após add/remove.

## Checkpoint 8 — contador de etiquetas publicado e validado live — 12/09/2026

- O commit `3dd350ce5` foi publicado em `origin/rotta-custom-v1` e implantado no Easypanel; a implantação exibiu `Compose implantado` para `fix(chatwoot): use live filtered label counts`.
- A correção usa `conversationStats.allCount` da meta filtrada real na rota de etiqueta, força a meta imediatamente ao montar/trocar a rota e após add/remove, corrige `all_count` para `allCount` e remove a constante duplicada de atenção.
- Na validação live autenticada como Kelvin, `ORÇAMENTOS/Kelvin` abriu vazio sem contador no cabeçalho. O DOM confirmou `#kelvin` sem badge; a barra lateral mostrou `ORÇAMENTOS` sem número; o seletor exibiu `Kelvin 0`.
- O Rails runner read-only confirmou `Label#conversations_count = 0`, `Conversation#2308.label_list = []` e `contact.label_list = []`. O estado final da base permaneceu sem mutação de teste.
- Recarga repetida permaneceu estável. Testes focados: 9/9 aprovados; suíte frontend equivalente: 4315 aprovados e 33 falhas ambientais/locale/fuso/estado global, sem falha nos arquivos alterados. O deploy foi validado após a janela de startup.
- Pendências não mascaradas: não foi executado o fluxo completo de add/remove via API/UAZAPI nesta rodada; o teste de menu de etiquetas foi revertido/confirmado sem mutação. O runtime Ruby/RSpec continua indisponível localmente.

## Checkpoint 9 — bundle frontend recompilado e causa do composer live isolada — 12/09/2026

- Diagnóstico live: Easypanel estava saudável e a conversa `#2330` retornava `meta.channel = Channel::Api`, mas o bundle servido ainda continha o `inboxMixin` antigo que lia apenas `inbox.channel_type`. Por isso os controles de ditado/gravação não apareciam apesar do código-fonte já ter o fallback para payload de conversa.
- Causa de publicação: `docker/Dockerfile.overlay` copia `public/vite` e não executa a compilação Vite. A correção é artefatual e controlada: `corepack pnpm exec vite build` concluiu com 5.084 módulos transformados; o manifesto aponta para `dashboard-BfYWCUHY.js`/`DashboardIcon-DOxke8cM.js`, e a checagem estática encontrou `currentChat`, `i-ph-text-aa` e `uazapi` no bundle novo.
- Evidência web antes do novo deploy dos assets: HTTP 200, lista e histórico carregados, 50 conversas pré-carregadas e labels `ORÇAMENTOS`/`Caio Atenção` visíveis; os botões de voz ainda não estavam presentes, portanto não houve aprovação prematura desse critério.
- Código/backend já publicado nesta rodada: commits `1a10c1617`, `d25beeb2b`, `c3d394336`, `c8b916bae`; estes commits estão em `origin/rotta-custom-v1`. Os assets regenerados e este registro ainda precisam de commit/push/deploy.
- Testes disponíveis: `inboxMixin.spec.js` 43/43, `ReplyBox.spec.js` 93/93, `DictationRecorder.spec.js` 2/2, suíte focalizada inicial 76/76; ESLint focalizado sem erros (2 warnings i18n preexistentes), `git diff --check` sem erros materiais. Ruby/RSpec não executável localmente por ausência de Ruby/Bundler. Gate AAA permanece aberto; não há nota final até o deploy dos assets e a revalidação live dos dois controles.
- Aplicativo móvel: pesquisa oficial confirma que o campo recebe o host/base (`domain.com`), não `/app/login`; usar `n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host` ou a URL-base HTTPS, conforme a versão do app. Fontes registradas em `docs/research/chatwoot-mobile-connection-20260911.md`.

## Checkpoint 10 — chunks publicados e composer confirmado live — 12/09/2026

- O commit `fadc8f4d3` foi enviado para `origin/rotta-custom-v1` com os 34 arquivos de runtime referenciados pelo manifesto que estavam ignorados pelo Git. O primeiro deploy do manifesto isolado foi revertido operacionalmente pela correção de empacotamento: ele produziu 404 nos chunks novos e tela em branco, sem alteração de dados.
- O segundo deploy terminou com `Success` às `05:05:33 UTC`; Rails, Sidekiq e Sidekiq UAZAPI foram recriados. O Chatwoot real voltou após a janela de startup e carregou a conversa `#2330`.
- Prova live final: `i-ph-text-aa = 1`, `i-ph-microphone = 1`; a resposta de rede pós-deploy teve zero 4xx em assets Vite/manifesto. O teste não acionou microfone nem enviou áudio/mensagem, portanto a presença dos controles está aprovada e o envio efetivo de áudio permanece não exercitado nesta rodada.
- O critério de bundle/composer passa nesta revalidação. O gate AAA global continua aberto por cobertura Ruby/RSpec indisponível localmente e por cenários externos que não foram executados; não atribuir nota final AAA somente com essa prova.
- URL móvel confirmada pela pesquisa oficial: usar o host/base `n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host` ou a base HTTPS, sem `/app/login`; `app.chatwoot.com` é somente Cloud.
## Checkpoint 11 — auditoria pós-publicação e suíte focalizada — 12/09/2026

- Revalidação live após o deploy dos chunks: a conversa real `#2330` abriu autenticada, o histórico e a lista carregaram, a sessão não exibiu `Desconectado`, e a interface manteve `Caio Atenção` na navegação.
- O composer publicado exibiu exatamente 1 controle de ditado (`text-aa`) e 1 controle de gravação (`microphone`). Não foi solicitada permissão de microfone nem enviada mensagem/áudio nesta checagem, portanto o envio efetivo continua explicitamente pendente de teste com autorização operacional.
- Suíte focalizada repetida: `inboxMixin.spec.js` 43/43, `DictationRecorder.spec.js` 2/2 e `ReplyBox.spec.js` 93/93 — total 138/138. Permaneceram apenas warnings de mocks/componentes ausentes já esperados nos testes de `ReplyBox` e aviso de source map de dependência; não houve falha de teste.
- GitHub: `origin/rotta-custom-v1` continua no commit `411e226860139a9ce172b3c097f0e122c08ce2f9`. Working tree preserva somente os dois snapshots modificados anteriormente e não relacionados; eles não foram incluídos.
- Gate AAA permanece aberto: Ruby/RSpec não está disponível neste ambiente, e ainda não há prova integrada de gravação/envio de áudio, teste por sessão/permissão do agente Caio nem todos os cenários externos. Nenhuma nota final foi atribuída.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [ledger Gauntlet](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\audits\gauntlet-objetivo-20260911.md) ↔ [pesquisa de conexão móvel](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\chatwoot-mobile-connection-20260911.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1).

## Checkpoint 12 — deploy visual, endereço canônico e alerta de tempo real — 12/09/2026

- O commit `3c36b491babe8147eecf7a15d9fe710d18f493af` foi enviado para `origin/rotta-custom-v1` e o Easypanel concluiu o deploy `feat(chatwoot): distinguish voice composer controls`; o botão de implantação voltou ao estado normal e o serviço permaneceu saudável.
- Após recarga real da conversa `#2330`, o composer passou a distinguir visualmente os controles: ditado com classes `bg-n-brand/10 text-n-blue-11` e áudio com `bg-n-ruby-9/10 text-n-ruby-11`. Há exatamente 1 ícone `text-aa` e 1 `microphone`.
- O HTML público do serviço informa `chatwootConfig.hostURL = https://atendimento.via-cargo.com`. A raiz e `/app/login` responderam HTTP 200 tanto no domínio canônico quanto no alias Easypanel, e a sessão web exibiu os mesmos dados nos dois. Para o aplicativo móvel, priorizar `atendimento.via-cargo.com`, somente o host, sem `/app/login`.
- Durante a recarga forçada, o banner `Desconectado` apareceu e persistiu por cerca de 20 segundos em ambos os hosts, apesar de histórico/lista carregados. Isso é uma pendência separada de conexão Action Cable/tempo real e deve ser investigada antes de declarar o objetivo global concluído.
- Testes focalizados já repetidos: `inboxMixin.spec.js` 43/43, `DictationRecorder.spec.js` 2/2 e `ReplyBox.spec.js` 93/93 — 138/138. Ainda não houve envio real de áudio nem teste com fala portuguesa, e Ruby/RSpec continua indisponível localmente.
- Gate AAA permanece aberto; nenhuma nota final foi atribuída.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [ledger Gauntlet](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\audits\gauntlet-objetivo-20260911.md) ↔ [pesquisa de conexão móvel](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\chatwoot-mobile-connection-20260911.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1).

## Checkpoint 13 — áudio real persistido e reconexão revalidada — 12/09/2026

- Teste real autorizado no Chatwoot, conversa `#2143` do Kelvin: o controle de gravação entrou em estado ativo; o botão de parada encerrou a captura; a prévia apareceu e habilitou o envio. O ícone de microfone cancela a captura em andamento; o controle de parada/duração é o encerramento correto.
- Após o envio, a conversa recebeu a mensagem `data-message-id=41044`, com classe de mensagem de saída e bolha `data-bubble-name="audio"`. O HTML contém um `source` MP3 em Active Storage do domínio canônico (`atendimento.via-cargo.com`), comprovando gravação → prévia → upload → persistência no histórico. Não houve texto público adicional nem erro de envio observado.
- A mensagem de áudio também apareceu na lista de conversas com duração exibida e permaneceu após recarga. Nenhuma nova mensagem foi enviada depois dessa confirmação.
- Action Cable: o handshake WebSocket bruto abriu em `wss://atendimento.via-cargo.com/cable` e no alias Easypanel; o domínio canônico retornou o frame `welcome`. A sessão que havia mostrado `Desconectado` foi recarregada e permaneceu sem o banner durante 8 s de inicialização + 25 s de monitoramento, com histórico e lista estáveis. O episódio anterior fica classificado como desconexão transitória/reconexão a investigar, não como falha reproduzida nesta janela.
- Bateria frontend focalizada: 7 arquivos, 147/147 testes aprovados (`actionCable`, `ReconnectService`, `DictationRecorder`, `ReplyBox`, alerta sonoro, store e host do alerta). Warnings foram somente mocks de componentes/diretivas nos testes, source map ausente de dependência e Browserslist desatualizado.
- Limite de evidência: a captura real não continha fala portuguesa utilizável; portanto o fluxo de gravação e envio foi aprovado, mas a qualidade semântica da transcrição pt-BR não foi declarada como teste live. Ruby/RSpec continua indisponível localmente; os specs Ruby permanecem cobertos no repositório, não executados nesta máquina.
- Estado: sem alteração funcional adicional neste checkpoint. O gate AAA continua aberto até haver evidência independente do popup/som na sessão do Caio, da visibilidade agent-only da exclusão e da transcrição com fala portuguesa, ou uma justificativa operacional documentada para cada cenário não reproduzível sem um segundo dispositivo/voz.

## Checkpoint 14 — menu contextual revalidado no estado atual — 12/09/2026

- Na conversa live `#2143`, após recarga da sessão autenticada, o clique direito no cartão de conversa exibiu `Solicitar Atenção`, `Marcar como não lida`, `Adiar`, `Arquivar conversa`, `Prioridade`, `Atribuir etiqueta`, `Abrir em nova aba`, `Copiar link da conversa`, `Fixar conversa` e `Excluir conversa`.
- A mesma inspeção não encontrou `Reabrir conversa`, `Deixar pendente` ou `Fechar conversa`. O menu foi fechado com `Escape`; nenhuma ação mutável foi acionada nesta rodada.
- O estado funcional continua no deploy anterior `3c36b491b`; `508d139f` contém apenas o registro de auditoria e está sincronizado em `origin/rotta-custom-v1`.

## Checkpoint 15 — lint focado sem erros funcionais — 12/09/2026

- ESLint dos componentes e helpers funcionais da implementação terminou com `0 errors` e 4 warnings não bloqueantes: dois `vue/no-root-v-if` e dois avisos de chaves i18n dinâmicas no tratamento de permissão/ditado.
- A execução incluindo `NetworkNotification.vue` e `ReconnectService.js` acusou somente normalização CRLF (`prettier/prettier`, “Delete ␍”) nesses arquivos preexistentes. Eles não foram reformatados para evitar alteração não solicitada.

## Checkpoint 16 — vídeo fornecido reprocessado e contexto confirmado — 12/09/2026

- O vídeo `C:\Users\User\Downloads\Gravando 2026-09-10 174553.mp4` foi analisado localmente sem escrita na aplicação: duração `125,5 s`, áudio extraído temporariamente em mono/16 kHz e transcrição pt-BR aproximada feita com modelo local `faster-whisper` tiny.
- A fala confirma o defeito histórico de etiquetas/Follow-up: contador que permanece em 1 apesar de três clientes, clientes que só aparecem depois de entrar na aba, etiquetas antigas/poluição no Follow-up e atualização que funciona de forma intermitente ao adicionar/remover `Kelvin` e `Primeiro contato`.
- Quadros extraídos em quatro momentos mostram visualmente o dashboard/lista, uma conversa com o seletor de etiquetas, a área de Follow-up e a tela de etapas. Esse material confirma que a correção de contagem e sincronização é relevante ao contexto, embora não altere o escopo funcional dos quatro itens deste objetivo.
- O áudio local teve erros de reconhecimento pontuais por usar o modelo pequeno; os fatos acima foram aceitos somente quando coincidiram com o vídeo e o relato do usuário. Nenhuma mensagem, etiqueta ou conversa foi criada/modificada durante o processamento.

## Checkpoint 17 — busca live por exclusão recebida — 12/09/2026

- A busca global do Chatwoot por `Esta mensagem foi excluída` retornou somente a conversa `#2143`; todas as ocorrências carregadas estavam em bolhas `message--outgoing` do agente. Não foi encontrada uma mensagem `message--incoming` apagada pelo cliente para exercer o botão de visualização.
- A busca foi limpa por teclado e a lista original voltou a carregar. Nenhuma mensagem, etiqueta ou conversa foi criada, removida ou alterada durante a procura.
- A ausência de uma ocorrência recebida é uma limitação do dado live disponível, não uma aprovação do cenário agent-only. O contrato server-side continua coberto por policy, endpoint, retenção criptografada e specs do repositório.

## Checkpoint 18 — identidade do destinatário Caio confirmada live — 12/09/2026

- A tela autenticada de Configurações → Agentes mostrou `Caio Mazine` como agente verificado e administrador da conta Rotta Brasil Express. A conta live possui 3 agentes: Caio, Capital Bridge e Kelvin.
- Essa verificação confirma que o alvo Caio existe na conta e que a configuração de destinatário não aponta para um usuário ausente. Ela não substitui a prova de UI na sessão efetivamente autenticada do Caio, que permanece pendente.
- A consulta foi somente leitura; nenhuma conta, senha, permissão ou agente foi alterado.

## Checkpoint 19 — causa do aplicativo móvel isolada no código oficial — 12/09/2026

- O servidor live não é o bloqueio: os dois hosts retornaram `/api` HTTP 200 com Chatwoot `4.17.0`, `queue_services: ok` e `data_services: ok`; `/api/v1/profile` retornou 401 sem autenticação, como esperado.
- A tag oficial estável `v4.9.0` do aplicativo valida o campo com `new URL(url)` antes de normalizar o domínio, embora a documentação oficial peça `domain.com`. Na mesma tag, o WebSocket é montado com o texto bruto (`wss://${url}/cable`); ao informar `https://...`, o resultado pode ser `wss://https://.../cable`.
- O commit oficial `b33a43e` (#1151, 02/09/2026) corrige exatamente isso: extrai/normaliza o host, monta `wss://<host>/cable`, rejeita espaços e repara URL persistida. O release estável listado é `v4.9.0` (18/08/2026), anterior ao commit da correção.
- Orientação operacional: atualizar o app para uma versão que contenha `b33a43e`, limpar a configuração salva e informar `atendimento.via-cargo.com` somente como host. Não usar `/app/login` ou `/app/accounts/...`; `app.chatwoot.com` é somente Cloud.
- Nenhuma alteração funcional no Chatwoot/Easypanel foi feita durante este diagnóstico. O achado é do cliente móvel nativo, não do fork web.
- Fonte detalhada: [pesquisa de conexão móvel](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\chatwoot-mobile-connection-20260911.md).

## Checkpoint 20 — caminho de retenção do cliente exercitado com rollback — 12/09/2026

- No Rails live, foi escolhido um candidato real de mensagem recebida na conversa `#2143` e executado o `Messages::CustomerDeletionService` dentro de uma transação explicitamente revertida. O retorno foi `incoming=true`, `tombstone=true`, `retained=true` e `expires_in=172800`, confirmando retenção criptografada por 48 horas e marcador público de exclusão.
- A consulta somente leitura imediatamente depois do rollback confirmou o estado original: mensagem `#37372` com `content="ok"`, sem atributo `deleted` e sem `DeletedMessageContent`. Nenhuma alteração persistiu.
- Foi adicionado ao repositório um spec de integração do webhook UAZAPI que cobre o evento `message_deleted`: encontra a mensagem recebida, cria o conteúdo retido, deixa o tombstone e registra a entrega do webhook. Este spec ainda precisa ser executado em um ambiente com Ruby/RSpec; Ruby não está instalado nesta máquina.
- Como a mudança nesta rodada é somente cobertura de teste e auditoria, não houve novo deploy funcional no Easypanel. O runtime publicado continua `3c36b491b`; o spec e os registros desta rodada serão enviados ao GitHub sem incluir snapshots preexistentes não relacionados.
- Limite mantido: ainda não foi possível exercer uma mensagem apagada pelo cliente pela UI real nem observar o botão agent-only na sessão de Caio, porque a conta live não contém uma ocorrência recebida desse tipo. O teste transacional valida o motor, mas não substitui essa prova visual.

## Checkpoint 21 — suíte frontend repetida e redução visual do composer — 12/09/2026

- A suíte focalizada foi executada novamente com Vitest direto no Windows: 12 arquivos, `186/186` testes aprovados. Cobriu ReplyBox, redimensionamento, gravação, ditado, transcrição API, Action Cable/reconexão, alertas sonoros, store e host do alerta Caio.
- A execução do script `pnpm test` puro não funciona neste shell Windows porque o script usa a sintaxe Unix `TZ=UTC`; isso foi contornado executando o mesmo Vitest diretamente, sem alterar o projeto. Houve somente aviso de Browserslist/source map e os warnings Vue/i18n já conhecidos.
- ESLint focalizado dos componentes/serviços terminou com `0 errors` e 4 warnings não bloqueantes (`vue/no-root-v-if` x2 e chaves i18n dinâmicas x2). `git diff --check` não apontou erro material.
- Teste manual live no Chatwoot `#2143`: o compositor iniciou em 72 px, foi arrastado até o limite publicado de 52 px, e voltou a 72 px pelo duplo clique no puxador. Os controles `Falar e transcrever para texto` e `Gravar áudio` permaneceram distintos.
- Menu contextual live reaberto e fechado sem ação mutável: presentes `Solicitar Atenção`, `Copiar link da conversa` e as ações permitidas; ausentes `Reabrir conversa`, `Deixar pendente` e `Fechar conversa`.
- A tela não exibiu banner visível de desconexão durante a inspeção; o componente interno correspondente estava com `display:none`. As mensagens de áudio e o histórico continuaram renderizados.
- Não houve alteração funcional nem novo deploy nesta rodada. O commit publicado permanece `19d234ffd`; snapshots modificados anteriormente continuam fora do commit.

## Checkpoint 22 — botão agent-only de conteúdo retido validado live — 12/09/2026

- A causa visual foi isolada em dois pontos: `MessageList.vue` não encaminhava `deleted_content_available` para `Message.vue`, e o resumo da conversa usava `push_event_data` mesmo para a última mensagem recebida. Foram corrigidos somente esses caminhos; o resumo agora usa `agent_push_event_data` apenas quando `Current.user` é um agente, preservando o payload público do cliente.
- O bundle frontend foi reconstruído, o manifesto foi verificado (`240` assets referenciados), e os commits `aef75f49d` (frontend + assets + teste) e `bb5d049aa` (Jbuilder + Dockerfile overlay) foram enviados para `origin/rotta-custom-v1`.
- O Easypanel concluiu os dois deploys. No Chatwoot real, após recarga completa da conversa `#2143`, o tombstone temporário `41045` exibiu `Ver conteúdo apagado pelo cliente`; o clique abriu o modal agent-only com o conteúdo original `Teste temporário de exclusão do cliente — remover ao final`. A página permaneceu conectada e o composer/histórico continuaram carregados.
- Verificação dentro do Rails publicado confirmou `{active: true, event: true, file: true}` para a mensagem `41045`. Suíte focalizada após a correção: `11` arquivos, `208/208` testes aprovados; teste específico do `MessageList`: `1/1`; manifesto: `240` assets verificados.
- O fixture `source_id=codex-ui-delete-test-20260912-0326`, mensagem `41045`, continua presente apenas para permitir a conferência e precisa ser removido por comando exato; nenhuma outra mensagem deve ser tocada. A remoção permanece pendente de confirmação imediata exigida para a ação destrutiva via console.
- Limites mantidos: ainda falta prova independente na sessão do próprio Caio para popup/áudio e execução Ruby/RSpec local; a política server-side e a prova de agente autenticado estão confirmadas.

## Checkpoint 23 — menu contextual revalidado após o deploy — 12/09/2026

- Na conversa live `#2143`, o clique direito no cartão de Kelvin exibiu `Solicitar Atenção`, `Copiar link da conversa`, `Arquivar conversa`, `Atribuir etiqueta` e as demais ações permitidas.
- A mesma árvore de acessibilidade não contém `Reabrir conversa`, `Deixar pendente` nem `Fechar conversa`. O menu foi fechado clicando fora e nenhuma ação mutável foi acionada.
- O fixture `41045` continua aberto somente para a validação agent-only e segue pendente de remoção exata após confirmação de exclusão via console.

## Checkpoint 24 — conexão do aplicativo móvel pesquisada e endpoint live validado — 12/09/2026

- A documentação oficial do Chatwoot determina que o campo **Installation URL** receba o domínio do servidor (`domain.com`), não `/app/login` nem uma rota de dashboard/conversa.
- O código oficial atual do app valida `GET <host>/api`, usa a base para `api/v1/...` e monta o WebSocket em `wss://<host>/cable`. Isso confirma que `/app/login` é uma URL de navegador; no teste live, `/app/login/api` retornou HTML, enquanto `/api` retornou JSON HTTP 200.
- `https://atendimento.via-cargo.com/api` e `https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/api` responderam Chatwoot `4.17.0`, `queue_services: ok` e `data_services: ok`. A API autenticada sem credencial retornou 401, comportamento esperado.
- Procedimento indicado ao usuário: atualizar/reinstalar o app para limpar a configuração salva e informar somente `atendimento.via-cargo.com`, usando o mesmo agente da web; depois conferir conta selecionada e colaborador da inbox WhatsApp.
- Nenhum código funcional, configuração do Easypanel, conta, inbox ou conversa foi alterado. Relatório completo: [pesquisa móvel](../research/chatwoot-mobile-connection-20260911.md).

## Checkpoint 25 — fallback de ditado pt-BR coberto e bundle produzido — 12/09/2026

- O teste manual live reproduziu a falha real ao parar o ditado: `Audio transcription is not available for this account`. A auditoria read-only confirmou `captain_feature=false`, `audio_transcriptions=nil` e ausência de configuração de provedor de áudio; nenhum dado foi alterado.
- O fluxo do compositor foi ajustado de forma compatível: o caminho de transcrição do servidor continua sendo o primeiro; quando o navegador oferece `SpeechRecognition`, o gravador captura o texto em `pt-BR` junto do `MediaRecorder`, preserva o rascunho existente e usa esse texto se a API do servidor estiver indisponível. O botão de gravação de áudio e o envio de áudio não foram misturados com o ditado.
- Testes após o ajuste: suíte focalizada `2` arquivos, `97/97`; bateria relacionada `14` arquivos, `177/177`; ESLint dos quatro arquivos alterados com `0` erros e somente `3` avisos já conhecidos; build Vite concluído; manifesto verificado com `240` assets.
- O deploy live e a prova manual pós-deploy do ditado ainda são a próxima etapa. Nenhuma conversa, etiqueta, conta, inbox ou mensagem foi alterada nesta etapa; os snapshots preexistentes permanecem fora do commit.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [pesquisa móvel](../research/chatwoot-mobile-connection-20260911.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1).

## Checkpoint 26 — deploy e prova manual live do composer — 12/09/2026

- O commit `47b19f9c4` foi enviado para `origin/rotta-custom-v1` e publicado no Easypanel. O restart produziu uma janela transitória de indisponibilidade; depois o endpoint `/api` voltou a HTTP 200 com `queue_services: ok` e `data_services: ok`, e a conversa `#2143` carregou normalmente.
- No navegador live, `Falar e transcrever para texto` entrou em `Gravando ditado. Clique novamente para parar.` e saiu desse estado; como o recurso server-side da conta continua sem provedor, o retorno foi o erro conhecido `Audio transcription is not available for this account`. Nenhuma mensagem foi enviada.
- `Gravar áudio` permaneceu separado; iniciou com contador `00:00`/`00:03`, parou e restaurou o composer sem anexo e sem envio. O botão de envio permaneceu desabilitado.
- O bundle publicado contém `SpeechRecognition`, `pt-BR` e `nativeTranscript`; os testes unitários cobrem a captura de transcript e o fallback para o rascunho. A limitação honesta desta prova é não haver fala humana disponível para exercitar a qualidade final do reconhecimento no navegador; a conta também ainda precisa de um provedor server-side para o caminho de maior precisão.
- Nenhuma conversa, etiqueta, conta, inbox ou mensagem foi alterada nesta prova. Os snapshots preexistentes continuam fora do commit.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [pesquisa móvel](../research/chatwoot-mobile-connection-20260911.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1).

## Checkpoint 27 — pesquisa oficial atualizada sobre o app iOS — 12/09/2026

- A App Store oficial lista o Chatwoot iOS na versão `4.9.3` (02/09/2026; iOS 16.4+). O projeto oficial publicou no mesmo dia o commit `b33a43e` (#1151), que corrige a montagem do WebSocket a partir do host normalizado e repara uma URL persistida incorreta.
- A correção explica o sintoma relatado: a versão antiga podia rejeitar o host puro apesar da documentação pedir `domain.com`, ou aceitar `https://...` e gerar `wss://https://.../cable`, deixando API/web acessíveis e o app sem conversas/tempo real.
- Como a página pública da App Store não vincula explicitamente o binário àquele hash, a recomendação segura é atualizar para `4.9.3` ou superior, sair/reinstalar para limpar o estado salvo e informar exatamente `atendimento.via-cargo.com`.
- Probes read-only repetidos em 12/09: ambos os hosts retornaram `/api` HTTP 200 com Chatwoot `4.17.0`, serviços `ok`; `/api/v1/profile` retornou 401 sem sessão; `/app/login/api` retornou HTML. Nenhuma alteração em servidor, conta, inbox, conversa ou mensagem.
- Fontes primárias: [Mobile Apps](https://www.chatwoot.com/mobile-apps), [guia Android](https://www.chatwoot.com/hc/user-guide/articles/1677777866-mobile-app-for-android), [App Store](https://apps.apple.com/us/app/chatwoot/id1495796682), [commit oficial b33a43e](https://github.com/chatwoot/chatwoot-mobile-app/commit/b33a43e7111b0ea0c1ed52dd6d85731b3b464736).

## Checkpoint 28 — teste live de etiqueta, contador e menu contextual — 12/09/2026

- Na sessão autenticada de Kelvin, a conversa `#2143` recebeu temporariamente a etiqueta `Caio Atenção`. O evento Action Cable atualizou a conversa, o menu de etiquetas e o contador da barra lateral de forma imediata; o contador subiu de `1` para `2`.
- A remoção foi feita pelo mesmo controle visual e também propagou em tempo real: a conversa voltou a `0` selecionada e o contador da barra lateral retornou a `1`. O estado original foi restaurado; nenhuma mensagem foi enviada.
- Durante o teste, não apareceu alerta na sessão do solicitante Kelvin, confirmando o filtro por `recipient_user_id`. A exibição do popup e do áudio na sessão independente de Caio continua sendo a única validação visual pendente, embora o caminho server-side e os testes do host/áudio estejam cobertos.
- A suíte frontend focalizada executada diretamente pelo Vitest terminou com `7` arquivos e `135/135` testes aprovados, incluindo alertas, Action Cable, ditado, ReplyBox, histórico e follow-up. O comando Ruby/RSpec continua indisponível localmente porque Ruby não está instalado.
- O menu contextual live foi novamente confirmado sem `Reabrir conversa`, `Deixar pendente` ou `Fechar conversa`; `Solicitar Atenção` e `Copiar link da conversa` permaneceram presentes. Nenhuma ação mutável do menu foi acionada.
- Nenhum código funcional, conversa, mensagem, inbox ou configuração foi alterado nesta etapa. O fixture isolado `41045` permanece somente para a prova agent-only e segue pendente de remoção exata após confirmação imediata.

## Checkpoint 29 — solicitação real de atenção sem mensagem pública — 12/09/2026

- Pela sessão live autenticada de Kelvin, o item `Solicitar Atenção` foi acionado uma vez na conversa `#2143`. O Chatwoot respondeu com o toast `Solicitação enviada para o agente Caio.`
- A árvore de acessibilidade da sessão não recebeu a mensagem privada de instrução nem qualquer mensagem pública; não houve envio para o WhatsApp, alteração de etiqueta ou alteração de status.
- O endpoint/serviço direciona o evento somente ao `recipient_user_id` configurado para Caio. A sessão Kelvin não exibiu o cartão de alerta, como exigido. A confirmação visual do cartão e do áudio na sessão independente de Caio segue pendente por falta de uma sessão autenticada desse agente.
