# Auditoria de encaminhamento, desfazer e Follow-up — 2026-09-17

## Escopo autorizado

- Restaurar o menu de botão direito que encaminha conversas para Emitir Contrato e FINALIZADOS.
- Garantir que as conversas apareçam nas respectivas áreas do sidebar.
- Restaurar uma ação explícita de desfazer sem reintroduzir os estados nativos resolvido, pendente ou adiado.
- Auditar a atualização dinâmica das etiquetas, contadores e trilhas de Follow-up.
- Usar somente os contatos 11965927865 e +5511991262866 para testes reais controlados e restaurar o estado original ao final.

## Diagnóstico

- O atalho Emitir Contrato continuava simétrico: adicionava emitir-contrato e, quando já atribuída, exibia Remover etiqueta Emitir Contrato.
- Para FINALIZADOS, a condição canFinalize escondia completamente o item assim que a etiqueta era atribuída. Não existia ação explícita equivalente para desfazer.
- A remoção anterior dos estados nativos não é a causa do encaminhamento por etiqueta e foi preservada. O fluxo corrigido continua sem alterar o status nativo da conversa.
- O bundle servido antes desta correção continha os atalhos existentes, confirmando que a lacuna também estava presente no frontend publicado e não era apenas cache do navegador.
- O primeiro teste real revelou que a proteção atômica de etiquetas não estava chegando à imagem: `labels_controller.rb` aceitava `{ add, remove }` no repositório, mas não era copiado pelo `Dockerfile.overlay`. O frontend exibia a etiqueta otimista e o backend oficial ignorava a mutação.
- Depois de publicar o controller, a contagem de Emitir Contrato passou a atualizar para 1, mas a fila continuou vazia para uma conversa em estado nativo não aberto. A rota de Emitir Contrato ainda filtrava somente `open`, ao contrário de FINALIZADOS.
- O teste de FINALIZADOS encontrou uma última defasagem visual: a rota já continha a conversa, mas o cartão reutilizado ainda podia oferecer “Enviar” até atualizar suas etiquetas. A rota ativa passou a ser também fonte de verdade para a ação de desfazer.

## Correção restrita

- Conversas com a etiqueta FINALIZADOS agora exibem Desfazer envio para FINALIZADOS, com ícone de retorno.
- O desfazer remove somente a etiqueta FINALIZADOS; não resolve, reabre, adia ou altera o status nativo.
- Conversas ainda não finalizadas preservam o popup de confirmação e o fluxo já existente de substituir as etiquetas atuais por FINALIZADOS.
- O atalho Emitir Contrato e sua remoção não foram alterados funcionalmente.
- O controlador atômico de etiquetas passou a ser incluído explicitamente na imagem de produção.
- As filas Emitir Contrato e FINALIZADOS agora consultam todos os estados nativos, sem expor novamente os comandos resolvido, pendente ou adiado.
- Dentro das próprias filas, o menu reconhece a etiqueta da rota imediatamente e mantém o desfazer disponível mesmo durante a atualização do cartão.

## Validação local

- Regressão diferencial: antes da correção, 2 testes falharam exatamente porque o item desaparecia e o menu não apresentava ação de desfazer.
- Após a correção: 48/48 testes focalizados passaram, cobrindo menu, atribuição/remoção de etiquetas, rollback/reconciliação, contadores do sidebar, prefetch e transições do Follow-up.
- ESLint focalizado: aprovado.
- Prettier: aprovado.
- git diff --check: aprovado.
- Build Vite: 5.100 módulos transformados, concluído com sucesso.
- Manifesto: 240 assets referenciados e presentes.
- Após os achados live, ESLint permaneceu sem erros, Prettier passou, o build Vite transformou 5.100 módulos e o verificador confirmou novamente os 240 assets.
- A tentativa de repetir a suíte Vitest depois do último fallback não coletou testes porque o Vite resolveu `fake-indexeddb` pelo junction de outro worktree. É uma limitação do harness local; a suíte de 48 testes havia passado antes desse fallback isolado, e foi acrescentada uma regressão específica para a rota FINALIZADOS.

## Pendências históricas revisadas

- Permanecem registradas, sem relação com esta regressão: endpoint Enterprise opcional 404; eventos unknown/422 sem identificadores suficientes; Ruby/RSpec indisponível no host Windows; stress destrutivo amplo não executado em produção; teste de chamada bloqueado por ausência de canal de voz.
- Nenhuma dessas pendências exige ampliar esta correção ou alterar o motor de mensagens.

## Publicação e teste real

- Commits publicados em `origin/rotta-custom-v1`: `180a112f` (desfazer FINALIZADOS), `777444ed` (controller atômico no overlay), `74e5433d` (fila Emitir Contrato em todos os estados) e `004c2d06` (desfazer responsivo pela rota ativa).
- Os quatro deploys correspondentes concluíram no EasyPanel. O deploy final serviu `dashboard-DBA1XQu4.js`; `/health` respondeu HTTP 200 com `{"status":"woot"}`.
- Teste `11965927865` / conversa `2143`: Emitir Contrato foi aplicado, o contador mudou dinamicamente para 1, a conversa apareceu na fila, “Remover etiqueta Emitir Contrato” funcionou, a conversa saiu da fila e o contador voltou ao estado inicial.
- Teste `+5511991262866` / conversa `48`: o contato começou sem etiquetas; Enviar para FINALIZADOS abriu a confirmação, aplicou somente FINALIZADOS, atualizou contador para 1 e mostrou o cartão na fila. O menu exibiu “Desfazer envio para FINALIZADOS”; ao desfazer, cartão e contador retornaram ao estado inicial.
- Nenhuma mensagem foi enviada. Os dois contatos foram restaurados sem Emitir Contrato e sem FINALIZADOS, exatamente como estavam antes dos testes.
- Follow-up live antes do reparo: a tela carregou em modo “ao vivo” e respondeu ao botão Atualizar, porém mostrou 0 trilhas enquanto o cadastro global de etiquetas indicava 1 conversa em Primeiro contato.

## Reparo autorizado do Follow-up

- O MCP Rotta confirmou o workflow ativo `utaNsnFUZYBYDf5S`, com 28 nós, deduplicação por conversa/etapa e por telefone/etapa e cancelamento de jobs incompatíveis.
- Causa raiz no motor: o SQL do nó `Normalizar Evento de Etiquetas` fornecia `last_received_at` em `VALUES`, mas não incluía essa coluna no `INSERT`. A execução real `620963` reproduziu `INSERT has more expressions than target columns` antes da criação do job.
- O workflow foi corrigido somente nessa lista de colunas, validado sem avisos e publicado na versão ativa `ee1c9392-039f-4d17-aee4-7bdcd45911d2`.
- O Chatwoot passou a reconciliar etiquetas de trilha sem job remoto como cartões explícitos de “Conciliação pendente”. Esses cartões não disparam mensagens: eliminam o vazio/contador fantasma e permitem ao operador enxergar e remover a etiqueta com segurança. Commit `1908eb38`, deploy EasyPanel concluído e `/health` HTTP 200.
- O contato autorizado `11965927865` tinha a etiqueta `primeiro-contato` na conversa pública `206`, mas nenhum job. Após a publicação do n8n, a execução `621002` concluiu com sucesso e `queued: true`; o painel passou de 0 para exatamente 1 cartão real, status “Na fila”, sem duplicidade.
- Um job de ensaio criado inicialmente com o identificador interno incorreto `2143` foi cancelado imediatamente pela execução `620999`, antes de qualquer disparo. O job correto ficou associado somente à conversa pública `206`.
- Varredura posterior: 30 execuções do workflow desde a publicação, todas com sucesso e 0 erros/crashes. Nenhuma mensagem foi enviada durante a auditoria; o job correto segue o prazo normal da etiqueta e está agendado para o número de teste autorizado.

## Linhas conectadas

[[Chatwoot Rotta — contexto e estado]] ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/dashboard)
