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

- O push para `rotta-custom-v1` foi concluído. Inclui `08d3935f` (atalho Emitir Contrato), `9244f776` (próxima etapa do follow-up), `42034801` (assets Vite de produção) e commits de auditoria com o estado do deploy.
- Checagem pública pós-push: `/health` e `/app/login` responderam HTTP 200, mas o manifesto continua apontando para `assets/dashboard-Ce8OUdV2.js` e `assets/dashboard-C4l69tM3.css`.
- O bundle atualmente servido não contém `rotta_include_agent_name_in_whatsapp`, `issue-contract` nem `issueContract`. Portanto, o GitHub está atualizado, mas o deploy dos commits ainda não foi confirmado e as alterações não devem ser consideradas ativas em produção.
- O acionamento do deploy pelo painel EasyPanel não foi concluído nesta rodada; não houve mutação do serviço. É necessário executar/reexecutar o deploy do serviço `chatwoot-rotta` e repetir a checagem do manifesto e dos marcadores do bundle.
- Não foi possível abrir o painel Obsidian nesta rodada; as notas locais foram atualizadas diretamente, sem alegar que a interface foi aberta.

## Artefatos relacionados

- GitHub: [branch rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1)
- EasyPanel: [deploy do serviço Chatwoot](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments)
- Chatwoot: [caixa de entrada](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/dashboard)
- Contexto Obsidian: [[Chatwoot Rotta — contexto e estado]]
