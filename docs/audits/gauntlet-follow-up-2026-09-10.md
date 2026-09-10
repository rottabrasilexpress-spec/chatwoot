# Gauntlet — Follow-up lento e contadores fantasmas

Data: 2026-09-10  
Branch: `rotta-gauntlet-20260909` → publicação autorizada em `rotta-custom-v1`  
Baseline: `0e68ca8`  

## Contrato

### Por quê

Eliminar os números fantasmas do Follow-up e reduzir o atraso ao abrir uma conversa com duplo clique.

### O quê

Reproduzir no Chatwoot real, medir o atraso e requests sobrepostos, localizar o caminho que reintroduz estado stale, corrigir somente esse fluxo, criar regressão, publicar e validar novamente. WhatsApp Web, envio de mensagens, n8n/UAZAPI e exclusão de histórico ficam fora.

### Como

Diagnóstico live + auditoria estática em paralelo; regressão no seam correto; integração mínima; deploy controlado; repetição do cenário original; revisão AAA independente.

## Hipóteses ranqueadas

1. Duplo clique dispara duas navegações/reconciliações sobrepostas.
2. O card abre antes de limpar o estado/rota do quadro e espera por dados antigos.
3. Algum caminho ainda usa `body.counts` ou histórico externo sem `reconciledJobs`.
4. ActionCable/refresh de etiquetas reintroduz jobs stale depois da reconciliação inicial.
5. Sidebar e Follow-up usam fontes diferentes e chegam em ordens distintas.

## Microtarefas e allowlists

| ID | Dono | Objetivo | Arquivos próprios | Aceite | Dependências |
|---|---|---|---|---|---|
| M1 | controlador | Reproduzir e medir no Chatwoot real | nenhum | uma captura red-capable com tempo, DOM e requests | — |
| M2 | agente diagnóstico | Auditar os caminhos de Follow-up, labels e abertura | somente relatório; sem edição | causa provável e pontos de instrumentação | — |
| M3 | controlador | Fixar regressão no seam confirmado | arquivo de spec focalizado | falha antes do fix e passa depois | M1/M2 |
| M4 | agente executor | Implementar correção mínima | arquivos Vue/helper definidos após M2 | lint/teste local do escopo | M3 |
| M5 | controlador | Integrar, buildar e testar original | arquivos da implementação + audit | build, regressão e loop live verdes | M4 |
| M6 | revisor AAA | Revisar snapshot integrado independente | nenhum | nota ≥95, todos critérios ≥90, zero falhas críticas | M5 |

## Régua AAA fixada

Correção 25, Completude 20, Verificação 20, Coerência integrada 15, Utilidade 10, Acabamento 10. AAA exige total ≥95, nenhum critério abaixo de 90, zero falhas críticas e todos os testes obrigatórios aprovados.

## Registro de rodadas

| Rodada | Estado | Hash | Evidência | Nota |
|---|---|---|---|---|
| 1 | diagnóstico iniciado | `0e68ca8` | M1/M2 pendentes | — |
| 2 | diagnóstico concluído | `9bb6617` | M1 live + M2 estático: cascade de navegação completa e reconciliação stale identificados | — |
| 3 | correção integrada | `313ba77` | M3/M4/M5: SPA, fetch paralelo, fail-closed/dedupe, `active_labels`, bundle publicado | pendente AAA |
| 4 | correção pós-revisão | `dc9f99e` | M6 devolveu 88/100; regressões fortalecidas, contrato Ruby criado e Vitest focalizado passou 17/17 | — |
| 5 | AAA aprovado | `dc9f99e` | segunda revisão independente: 96/100, todos critérios ≥90, zero falhas críticas | aprovado |

## Evidência de diagnóstico e correção

- M1 reproduziu o atraso no Chatwoot real sem usar WhatsApp Web, enviar mensagens ou executar n8n/UAZAPI. O baseline medido para o duplo clique ficou em aproximadamente `8,5 s` ou mais e incluía navegação completa do documento, detalhe da conversa, mensagens paginadas, etiquetas, anexos e `update_last_seen`.
- M2 confirmou dois caminhos independentes: a abertura do Follow-up usava `window.location.href`, iniciando reload completo; a `ConversationView` aguardava a conclusão da lista antes de solicitar a conversa profunda. O painel também aceitava histórico sem confirmação das etiquetas ativas e não eliminava duplicatas por conversa/etapa.
- Correção mínima em `9bb6617`: `router.push` com guarda contra duplo clique, `fetchConversationIfUnavailable()` no início da montagem, deduplicação por conversa/etapa, reconciliação fail-closed e enriquecimento backend com `active_labels`.
- `8ef1e47` e `313ba77`: manifesto e assets Vite publicados para servir o bundle corrigido no overlay de produção.

## Verificação técnica

- `corepack pnpm exec vite build`: aprovado; `5.079` módulos transformados, build concluído em aproximadamente `1m16s`.
- ESLint focalizado: sem erros; permaneceram `14` avisos preexistentes de fechamento de bracket no template de `FollowUp.vue`.
- Regressão direta do helper: aprovada (`helper regression: PASS`).
- Vitest focalizado não chegou à coleta por limitação do ambiente: o runner falha ao resolver `fake-indexeddb@6.0.0/.../auto/index.mjs`, embora o pacote exista e a importação direta funcione. A limitação foi registrada; não foi mascarada como aprovação.
- Ruby não está instalado no ambiente, portanto a checagem `ruby -c` do controller não pôde ser executada.

## Verificação live pós-deploy

- Easypanel concluiu o deploy em `2026-09-10 22:19:56 GMT`, recriando Rails, Sidekiq e Sidekiq UAZAPI sem erro fatal. O bundle ativo passou a ser `dashboard-B9LgK-tZ.js`.
- Primeiro duplo clique pós-deploy: rota em `3184 ms` (`3,184 s`). A conversa `1143` abriu e o histórico completo apareceu após a estabilização.
- Repetição independente: rota em `3161 ms`, conteúdo visível em `3205 ms`, `0` requests de documento e `7` requests relacionadas à conversa; não houve reload completo nem navegação duplicada.
- O teste live confirmou a tela de etiqueta `Kelvin` e `Caio Atenção` sem conversa ativa residual após reconciliação (`Não há conversas ativas neste grupo.`). Não houve envio de WhatsApp nem alteração de mensagens.
- O histórico completo continuou sendo carregado até o primeiro registro, preservando o requisito funcional anterior; a otimização aplicada foi no caminho de abertura e na reconciliação do Follow-up.

## Estado das microtarefas

- M1 — concluída: reprodução e medição no Chatwoot real.
- M2 — concluída: auditoria estática independente pelo agente Anscombe; relatório sem edição.
- M3 — concluída com ressalva: regressão criada, mas o Vitest ficou bloqueado na coleta pelo ambiente compartilhado; helper direto e build aprovados.
- M4 — concluída: correção mínima integrada nos arquivos Vue/helper/controller definidos.
- M5 — concluída com ressalva documentada: build, lint, helper e validação live aprovados; Vitest/Ruby indisponíveis no ambiente.
- M6 — pendente: revisão AAA independente do snapshot integrado.

## M6 e rodada de correção

- Revisão independente M6 do snapshot `313ba77`: `88/100`, sem falhas críticas; Correção `23/25`, Completude `17/20`, Verificação `16/20`, Coerência `14/15`, Utilidade `9/10`, Acabamento `9/10`. O gate não passou porque Completude e Verificação ficaram abaixo de `90`.
- Correções aplicadas nesta rodada: `ConversationView.spec.js` agora valida ordem de montagem, dispatch do deep link quando ausente e não-dispatch quando a conversa já está disponível; `followUpHelpers.spec.js` confirma que etapas históricas diferentes permanecem visíveis; o helper documenta que a deduplicação é projeção do quadro e não altera o histórico de mensagens; criado `spec/controllers/api/v1/accounts/rotta_follow_up_controller_spec.rb` para o contrato de `active_labels`.
- Vitest focalizado executado com configuração temporária que aponta o setup para o worktree correto: `2` arquivos, `17/17` testes aprovados. A configuração temporária foi removida e não faz parte do produto.
- ESLint focalizado: `0` erros e `14` avisos preexistentes do template Vue; Prettier focalizado aprovado.
- Ruby/RSpec continua pendente de execução: `ruby`, WSL com distribuição e daemon Docker indisponíveis. O spec foi criado, mas não é contabilizado como aprovado.
- A deduplicação continua restrita a `reconciledJobs` do quadro operacional; o endpoint administrativo e o histórico de mensagens não são modificados. A regressão cobre a permanência de etapas distintas.

## M6 final — gate AAA aprovado

- Segunda revisão independente no snapshot publicado `dc9f99e`: **96/100 — AAA aprovado**.
- Correção `24/25`; Completude `19/20`; Verificação `19/20`; Coerência integrada `15/15`; Utilidade `10/10`; Acabamento `9/10`.
- Todos os critérios ficaram em pelo menos `90`; não foram encontradas falhas críticas. O revisor confirmou que `HEAD` e `origin/rotta-custom-v1` apontam para `dc9f99e` e que o manifesto possui `240` referências locais sem asset ausente.
- Riscos residuais não bloqueantes: Ruby/RSpec/RuboCop não executados por falta de ambiente Ruby; não há teste direto isolado da guarda de `openConversation`; uma janela estreita ainda pode repetir uma busca de conversa, sem reload/document request duplicado na validação live.
- Decisão: manter o runtime publicado em `313ba77`, manter os testes/documentação em `dc9f99e`, sem novo deploy funcional; o bundle ativo já contém a correção aprovada.
