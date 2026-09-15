# Auditoria live de Follow-up e recuperação do Chatwoot — 2026-09-15

## Escopo

Teste real autorizado na conversa `#2143`, contato Kelvin, telefone `5511965927865`, usando o worker publicado do n8n e envio pela UAZAPI. O navegador foi usado apenas para operar o Chatwoot; não houve uso de WhatsApp Web para envio.

## Incidente de carregamento

- `/health` respondia `200` com `{"status":"woot"}` e o HTML também respondia `200`.
- O manifesto Vite live apontava para `dashboard-C70RhjaS.js` e `dashboard-BkXOiGAs.css`, mas ambos respondiam `404`.
- Causa: o `Dockerfile.overlay` copia `public/vite` pronto, enquanto `/public/vite*` é ignorado; o manifesto novo havia sido publicado sem os bundles gerados correspondentes.
- Correção: publicação dos 13 bundles referenciados pelo manifesto, commit `6f851edf`, push em `rotta-custom-v1` e novo deploy no EasyPanel.
- Pós-deploy: HTML `200`, 29 assets Vite referenciados, `0` assets com erro, Chatwoot renderizado no navegador e console sem warnings/errors.

## Testes reais

1. Orçamento de 10 dias: job despachado pelo endpoint administrativo; execução `605060` terminou com sucesso; UAZAPI respondeu HTTP `200`/`send_accepted=true`; a etiqueta avançou de `orcamento-10-dias` para `orcamento-feito`.
2. Contato instantâneo: etiqueta aplicada pela UI; execução `605070` terminou com sucesso; mensagem enviada pela UAZAPI; a etiqueta avançou para `primeiro-contato` e o próximo job ficou em `segundo-contato`.
3. Remoção: retirada da etiqueta `primeiro-contato` pela UI; nenhum job pendente permaneceu para a conversa.
4. Orçamento instantâneo: etiqueta aplicada pela UI; execução `605105` terminou com sucesso em `82,678 s`; o modelo foi `deepseek/deepseek-v4-flash-0731`; o job foi enviado e avançou para `orcamento-feito`.
5. Janela de 5 dias: etiqueta criou job pendente com próxima etapa `orcamento-feito` e `scheduled_at` em `2026-09-20`; etiqueta removida e job cancelado.
6. Janela de 15 dias: etiqueta criou job pendente com próxima etapa `orcamento-feito` e `scheduled_at` em `2026-09-30`; etiqueta removida e job cancelado.

## Verificação visual e de consistência

- Após o deploy, a conversa carregou todo o histórico e exibiu as duas mensagens reais de orçamento no Chatwoot.
- O painel Follow-up abriu sem recarregar a página e mostrou `Na fila 0`, `Prontos agora 0`, `Etapas ativas 0` após a limpeza dos testes.
- O backend ainda conserva linhas `sent_history` para auditoria; elas não são jobs ativos. O painel visual não exibiu esses históricos como cartões pendentes.
- O menu nativo de etiquetas ainda exibe contagens históricas próprias do Chatwoot que podem divergir do painel Follow-up; isso é separado da fila operacional e não foi alterado nesta rodada.

## Código e validação

- Correção de reconciliação: `d1689052`.
- Bundles publicados para o overlay: `6f851edf`.
- Vitest focalizado: `16/16`.
- Build Vite: aprovado.
- ESLint: `0` erros; somente 14 warnings Vue preexistentes de template.
- `git diff --check`: aprovado.

## Linhas conectadas

[[Chatwoot Rotta — contexto e estado]] ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [commit de bundles](https://github.com/rottabrasilexpress-spec/chatwoot/commit/6f851edf) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot #2143](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/conversations/2143).
