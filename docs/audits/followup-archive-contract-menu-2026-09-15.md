# Auditoria de Follow-up, arquivamento e menu de contrato — 2026-09-15

## Escopo

- Acrescentar `Emitir Contrato` ao menu de contexto da conversa, usando o roxo `#7c3aed` já definido para o item do sidebar e atribuindo a etiqueta existente sem duplicá-la.
- Manter o popup de confirmação da ação `Enviar para FINALIZADOS`.
- Auditar as trilhas de contato e orçamento, incluindo as janelas de 5, 10 e 15 dias, e corrigir a representação da próxima etapa até o arquivamento.
- Publicar no GitHub, fazer deploy pelo EasyPanel e validar a versão servida antes de declarar a conclusão.

## Diagnóstico baseado em estado ativo

Workflow n8n `utaNsnFUZYBYDf5S`, ativo na versão `1e1e93fd-15fe-4b15-a3f2-860a60139b9c`:

- Contato: `primeiro-contato` → `segundo-contato` → `terceiro-contato` → `ultimo-contato` → `arquivado`, com esperas de 36, 55, 72 e 96 horas.
- Orçamento: `orcamento-feito` → tentativas 2, 3 e 4 → `arquivado`, com esperas de 36, 55, 72 e 96 horas.
- Janelas adicionais: `orcamento-5-dias`, `orcamento-10-dias` e `orcamento-15-dias` estão no workflow com 120, 240 e 360 horas. Cada uma é reconhecida pela trilha de orçamento e retorna a `orcamento-feito`; não é uma etapa linear posterior à tentativa 4.
- O arquivamento já está configurado no workflow; não houve alteração de workflow, dados de clientes ou filas nesta rodada.

## Defeito reproduzido e correção

`FollowUp.vue` escolhia a etapa seguinte pela posição na lista fixa antes de considerar `next_label`. Para `orcamento-tentativa-4 → arquivado`, a lógica antiga mostrava incorretamente `orcamento-5-dias`. O teste diferencial local reproduziu esse resultado legado e confirmou o esperado na nova função: `arquivado`.

A interface agora usa `next_label` enviado pelo workflow como fonte de verdade, com mapa de transições explícito como fallback. Uma lista apenas visual acrescenta `arquivado` ao fim das trilhas; as listas operacionais, filtros e contagens continuam excluindo arquivados.

## Menu e confirmação

- O menu de contexto apresenta `Emitir Contrato` com `text-violet-600` (Tailwind `#7c3aed`), correspondente à cor definida para o item do sidebar.
- A ação atribui a etiqueta já existente e desaparece quando a conversa já a possui.
- `ConversationItem.vue` já abre `ConfirmationModal` ao selecionar `FINALIZE`; o título, a explicação e os botões de confirmar/cancelar são mantidos. Ao confirmar, remove etiquetas anteriores, atribui `FINALIZADOS` e resolve a conversa; cancelar não executa a finalização.

## Validações locais

- Vitest focado: 20 testes passaram (18 helpers Follow-up, 2 do menu de contexto).
- ESLint: 0 erros; 14 avisos preexistentes de `vue/html-closing-bracket-newline` em `FollowUp.vue`.
- Prettier: passou nos arquivos alterados.
- Build Vite: 5.101 módulos transformados; build concluído. O Vite ainda alerta para chunks grandes e o Browserslist local desatualizado.
- `verify:manifest-assets`: passou, validando 240 assets referenciados.
- O bundle compilado local contém a opção do nome do agente, o rótulo de contrato e os marcadores das etapas de orçamento.

## Publicação e estado do deploy

- A implantação inicial foi executada no EasyPanel após conferir repositório `rottabrasilexpress-spec/chatwoot`, branch `rotta-custom-v1`, caminho `/` e `docker-compose.yml`. O painel confirmou “Compose implantado”; o build sincronizou o commit `e883571b`.
- Pós-implantação inicial, `/health` e `/app/login` responderam HTTP 200 e o manifesto passou a servir `assets/dashboard-BVX23J0I.js` e `assets/dashboard-B0hRD4UQ.css`; os marcadores do recurso de nome do agente e do atalho de contrato estavam no bundle.
- A validação visual em produção encontrou que a sidebar mostrava “Emitir Contrato”, mas o menu contextual mostrava o slug `emitir-contrato`. O teste de regressão reproduziu exatamente `esperado: Emitir Contrato; recebido: emitir-contrato`.
- Causa: `ConversationItem.vue` passava `label.title` técnico diretamente para o menu. A correção agora usa `getLabelPresentationTitle`, o formatador compartilhado que já produz o nome de exibição.
- A correção local passou 22 testes focados, ESLint e Prettier; build Vite de 5.101 módulos concluído. O manifesto local valida 240 assets e o novo bundle é `assets/dashboard-B7HXAyoV.js`.
- **Estado no momento desta anotação:** o primeiro deploy estava ativo, mas continha o defeito visual reproduzido. A publicação corretiva e a verificação posterior estão registradas abaixo.
- O log do EasyPanel avisou sobre containers órfãos antigos (`ui_proxy`, `redis`, `postgres`); nenhum container foi removido.

## Resultado final — segundo deploy e validação em produção

- O commit corretivo `d9e58b9e` (`fix(conversations): render contract shortcut name`) foi publicado na branch `rotta-custom-v1` do GitHub.
- O segundo deploy foi executado pelo EasyPanel. O log sincronizou exatamente esse commit, construiu a imagem, recriou e iniciou Rails, Sidekiq e Sidekiq UAZAPI e terminou com `Success`.
- Smoke tests após o deploy: `/health` e `/app/login` retornaram HTTP `200`. O HTML do Chatwoot passou a carregar `/vite/assets/dashboard-B7HXAyoV.js` e `/vite/assets/dashboard-B0hRD4UQ.css`; ambos responderam HTTP `200`. O JS público contém `Emitir Contrato` e `rotta_include_agent_name_in_whatsapp`.
- Após recarga da sessão de produção, o menu contextual foi aberto sem executar nenhuma ação. A opção aparece como **Emitir Contrato**, em roxo, e não como `emitir-contrato`. Nenhuma etiqueta, arquivamento ou estado de conversa foi alterado durante essa conferência.
- A regressão que reproduzia o slug técnico agora passa; suíte Vitest focalizada: `25/25`, incluindo regressões de abrir a confirmação, cancelar sem efeitos e confirmar a finalização. ESLint, Prettier, build Vite (5.101 módulos) e `verify:manifest-assets` (240 referências) também passaram.
- O popup de `Enviar para FINALIZADOS` permanece conectado ao fluxo: o código aguarda confirmação antes de remover/atribuir etiquetas ou resolver a conversa. Não foi clicado em produção, para não finalizar uma conversa real sem uma conversa descartável designada.
- As trilhas do workflow n8n permaneceram sem alterações: as janelas de 5/10/15 dias seguem independentes (120/240/360 h) e voltam para `orcamento-feito`; transições de contato/orçamento e arquivamento foram auditadas na seção acima.
- O EasyPanel ainda reportou containers órfãos antigos. O deploy não usou `--remove-orphans`; nenhum foi removido.
- Estado final: **correção de exibição implantada e comprovada visualmente em produção; health e assets públicos saudáveis**. Única validação não feita em produção é clicar para finalizar uma conversa real; o modal e a guarda estão presentes no código.

## Revalidação da continuação — 15/09/2026

- Worktree de auditoria `rotta-profile-context-cap` estava limpo antes desta atualização documental. Nenhum arquivo funcional ou workflow foi alterado nesta revalidação.
- Regressões focadas executadas: `ConversationItem.spec.js` (4), `contextMenu/specs/Index.spec.js` (2) e `followUpHelpers.spec.js` (18): **24/24 passaram**. Cobrem o rótulo do atalho, a classe roxa `text-violet-600` (cor sidebar `#7c3aed`), popup antes de mutação, cancelamento sem efeito, confirmação e transições/ordenação das trilhas.
- O Vitest padrão inicialmente não coletou os testes porque a junction local de `node_modules` aponta para `work/chatwoot-source`, fora do root do Vite. As suítes passaram usando um config temporário que permitiu esse caminho; o arquivo temporário foi removido depois.
- EasyPanel confirmou o deploy mais recente `fix(deploy): include all manifested Vite assets`, commit funcional `ad452c07`, com log final `Success` (15/09/2026 15:34:39 UTC). Esse deploy sucede e contém o ajuste de exibição do commit `d9e58b9e`; não foi necessário disparar outro deploy.
- Smoke test atual: `/health` e `/app/login` HTTP `200`; os 17 assets referenciados pela página de login responderam `200`. O `DashboardIcon` publicado contém as chaves da confirmação; a classe `text-violet-600` está no CSS publicado. A inspeção visual anterior pós-deploy continua registrada acima; a aba Chatwoot não abriu via automação nesta continuação, então não se reivindica nova conferência visual aqui.
- Consulta somente leitura ao `rotta_n8n_mcp`: workflow `utaNsnFUZYBYDf5S` continua ativo na versão `1e1e93fd-15fe-4b15-a3f2-860a60139b9c` (28 nós; `activeVersionId` igual à versão atual). Contato: 36/55/72/96 h até `arquivado`; orçamento: mesmas etapas até `arquivado`. As janelas `orcamento-5-dias`, `orcamento-10-dias` e `orcamento-15-dias` estão na trilha de orçamento, com 120/240/360 h, e retornam a `orcamento-feito`; são janelas independentes, não passos lineares depois da tentativa 4.
- Os únicos anexos desta continuação são duas capturas PNG. Nenhum vídeo/áudio estava disponível para revisão ou transcrição; isso permanece pendente até o usuário anexá-lo.
- Nenhuma conversa foi finalizada, nenhuma etiqueta alterada e nenhuma mensagem enviada. Não houve alteração de workflow nem novo deploy nesta revalidação.

## Publicação solicitada e smoke pós-deploy — 15/09/2026 16:05 UTC

- A pedido do usuário, foi executado um novo deploy do estado sincronizado de `origin/rotta-custom-v1`. O EasyPanel identificou o commit `3971681b` (`docs(audit): revalidate follow-up tracks and menu`) e o log terminou em `Success` às 16:05:11 UTC.
- O deploy recriou os serviços necessários; Rails, Sidekiq e Sidekiq UAZAPI ficaram `Running`. O alerta de containers órfãos antigos reapareceu; não foi usado `--remove-orphans` e nenhum container foi removido.
- Pós-deploy: `/health` e `/app/login` responderam HTTP `200`; os 17 assets Vite encontrados no login responderam HTTP `200` (17/17, sem falhas).
- O commit implantado é documental e não contém alteração funcional posterior ao código já publicado. A preferência de nome do agente no WhatsApp, em especial, já está incluída no histórico funcional publicado anteriormente; este deploy sincroniza o estado atual solicitado, sem alegar um novo delta de código nessa preferência.
- Não foram enviadas mensagens nem alterados dados de conversas. O registro também foi sincronizado às duas notas locais do Obsidian.

## Artefatos relacionados

- GitHub: [branch rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1)
- EasyPanel: [deploy do serviço Chatwoot](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments)
- Chatwoot: [caixa de entrada](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/dashboard)
- Contexto Obsidian: [[Chatwoot Rotta — contexto e estado]]
