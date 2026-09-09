# Auditoria Rotta/Chatwoot — 09/09/2026

## Contrato

- **Por quê:** corrigir o fluxo operacional sem perder mensagens, etiquetas, posição ou dados do contato.
- **O quê:** contadores responsivos, exclusividade/retorno do arquivado, anexos no perfil, quadro de follow-up completo, motor de etiquetas, sidebar e acabamento visual.
- **Como:** cada requisito terá teste ou inspeção antes da implementação, mudança isolada, checkpoint versionado, validação publicada e registro incremental no Obsidian.

## Invariantes de segurança

- Não executar `git reset --hard`, `git clean`, exclusão ampla ou sobrescrita do worktree existente.
- Não alterar credenciais, tokens, workflows n8n/UAZAPI ou dados de produção sem uma ação explicitamente necessária e reversível.
- O teste de WhatsApp deve usar somente a API da UAZAPI autorizada; não usar o WhatsApp aberto no navegador para envio.
- Preservar histórico de atividade e posição por `last_activity_at` ao mover conversas entre visões.
- A etiqueta `arquivado` deve ser a única etiqueta da conversa arquivada; a remoção deve reabrir a conversa no fluxo Todos.
- Anexos recebidos devem permanecer mensagens/arquivos do Chatwoot e ficar disponíveis no perfil sem remover o histórico.

## Microtarefas e donos

| ID | Dono | Escopo permitido | Entrega |
|---|---|---|---|
| M1 | Controller | modelo/serviços/controllers/specs Ruby para arquivado e contadores | regra compartilhada e testes |
| M2 | Lagrange | `Sidebar.vue` e módulos de contagem/labels JS relacionados | contadores por contato, Clientes Fechados e cores |
| M3 | Lovelace | `RottaContactProfile.vue` e componentes/API de anexos do painel | perfil reduzido e drop zone segura |
| M4 | Gauss | `FollowUp.vue`, `followUpHelpers.js`, `Index.vue` e specs JS | trilhas e quadro Kanban completos |
| M5 | Controller | composable/selector de etiquetas e estilos globais não cobertos por M2–M4 | exclusividade visual, alertas e acabamento |
| M6 | AAA reviewer | snapshot integrado, sem escrita no artefato | revisão independente com a régua AAA |

## Checkpoints

- C0: linha de base auditada; ainda sem mudança funcional.
- C1: regra de arquivado e contadores aprovados em testes.
- C2: perfil/anexos aprovados em testes e inspeção.
- C3: follow-up e motor de etiquetas aprovados em testes.
- C4: UI integrada publicada e verificada.
- C5: revisão AAA; só concluir com total >= 95, nenhum critério < 90, zero falhas críticas.

## Registro inicial

- O branch de trabalho parte de `origin/rotta-custom-v1` em `dc0132f`.
- O worktree original contém alterações do usuário e não será resetado nem limpo.
- O código atual já possui a base de unread counts e do quadro Rotta, mas a auditoria confirmou lacunas nos requisitos acima.

## Checkpoint C1/C3 — implementação integrada antes do commit — 09/09/2026

- M1: `Conversation` agora normaliza qualquer título arquivado para uma única etiqueta, registra o status anterior, resolve ao arquivar e reabre em `open` ao remover a etiqueta quando necessário. A posição usa `last_activity_at` sem alteração.
- M2: sidebar busca contagem total de contatos por etiqueta para Kelvin, Caio Atenção e Clientes Fechados; há reconciliação por eventos websocket/reconexão e fallback de 10 segundos, com proteção contra respostas fora de ordem.
- M3: o painel operacional customizado foi retirado da renderização; permanece somente Anexos, com drag/drop copy-only de anexos já recebidos e sem criar, apagar ou duplicar mensagens.
- M4: as duas abas têm botões maiores e quadro horizontal compacto por etapa; contato mostra Primeiro/Segundo/Terceiro/Quarto, orçamento mostra Feito/Segundo/Terceiro/Quarto/5/10/15 dias, e Arquivado fica fora das trilhas. A tela Etiquetas exibe ambas na ordem.
- M5: atualização de etiquetas envia exclusivamente `arquivado`, atualiza o catálogo de etiquetas para refletir contagens e exibe aviso vermelho distinto; toasts comuns preservam o comportamento neutro.
- Teste direcionado: 8 arquivos Vitest, 32 testes aprovados com configuração temporária somente para contornar o link quebrado de `fake-indexeddb`; ESLint dos arquivos alterados terminou com 0 erros.
- Build de produção: Vite transformou 5.076 módulos e terminou com sucesso usando `NODE_PATH` apontando apenas para o pacote `postcss-import` já presente no cache pnpm; nenhum pacote foi instalado ou atualizado. Manifesto novo referencia 31 artefatos hashed adicionais, todos presentes.
- Segurança: nenhum reset/clean foi executado, nenhuma credencial foi exposta, nenhum dado de produção foi alterado nesta etapa e o teste UAZAPI permanece reservado para a validação final autorizada.
