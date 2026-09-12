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
