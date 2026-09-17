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

## Correção restrita

- Conversas com a etiqueta FINALIZADOS agora exibem Desfazer envio para FINALIZADOS, com ícone de retorno.
- O desfazer remove somente a etiqueta FINALIZADOS; não resolve, reabre, adia ou altera o status nativo.
- Conversas ainda não finalizadas preservam o popup de confirmação e o fluxo já existente de substituir as etiquetas atuais por FINALIZADOS.
- O atalho Emitir Contrato e sua remoção não foram alterados funcionalmente.

## Validação local

- Regressão diferencial: antes da correção, 2 testes falharam exatamente porque o item desaparecia e o menu não apresentava ação de desfazer.
- Após a correção: 48/48 testes focalizados passaram, cobrindo menu, atribuição/remoção de etiquetas, rollback/reconciliação, contadores do sidebar, prefetch e transições do Follow-up.
- ESLint focalizado: aprovado.
- Prettier: aprovado.
- git diff --check: aprovado.
- Build Vite: 5.100 módulos transformados, concluído com sucesso.
- Manifesto: 240 assets referenciados e presentes.

## Pendências históricas revisadas

- Permanecem registradas, sem relação com esta regressão: endpoint Enterprise opcional 404; eventos unknown/422 sem identificadores suficientes; Ruby/RSpec indisponível no host Windows; stress destrutivo amplo não executado em produção; teste de chamada bloqueado por ausência de canal de voz.
- Nenhuma dessas pendências exige ampliar esta correção ou alterar o motor de mensagens.

## Publicação e teste real

- A preencher após push, deploy e restauração dos dois contatos autorizados.

## Linhas conectadas

[[Chatwoot Rotta — contexto e estado]] ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/dashboard)
