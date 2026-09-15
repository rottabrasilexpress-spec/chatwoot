# Correção e validação de etiquetas em conversas — 2026-09-15

## Escopo

- Corrigir o falso sucesso do atalho de etiqueta no menu de contexto para uma conversa.
- Serializar mudanças rápidas de etiquetas na mesma conversa e preservar a última intenção (adicionar/remover).
- Conferir o contato de teste autorizado `#2143`, sem envio de mensagens.
- Manter separado o estado nativo da conversa (aberta/resolvida) das etiquetas customizadas.

## Diagnóstico reproduzido

O menu de contexto de uma conversa usava `POST /bulk_actions`. Esse endpoint confirma o enfileiramento do `BulkActionsJob`, não a persistência final da etiqueta. A interface relia o estado antes do job terminar e mostrava um toast de sucesso enquanto a etiqueta ainda não estava gravada; a reprodução ao vivo resultou em zero etiquetas após aguardar e recarregar. O seletor nativo, por outro lado, persistiu a mesma alteração.

Um teste de regressão para a conversa individual foi executado antes da correção e falhou, mostrando o caminho `bulkActions/process` em vez da mutação individual síncrona.

## Alteração

- Atalhos adicionar/remover no menu para uma conversa agora usam `conversationLabels/mutate`, que consulta as etiquetas atuais e grava a lista resultante pela API síncrona do Chatwoot.
- A mutação usa a fila/lock por ID de conversa já existente. Cada operação lê o estado persistido depois de adquirir o lock, e um contador de versão impede que uma resposta antiga substitua visualmente a intenção mais recente.
- A camada de API agora recebe deltas `add/remove` e os aplica sob `conversation.with_lock`. O seletor de etiquetas também calcula deltas em vez de enviar uma lista inteira; duas sessões que alterem etiquetas diferentes não apagam as mudanças uma da outra. Substituições completas ainda são aceitas pelo endpoint legado para compatibilidade.
- A ação retorna `success`, `failed` ou `superseded`. Se outra ação começar durante o refresh dos contadores, a ação antiga não mostra toast nem atualiza contagens com estado obsoleto.
- A UI só confirma sucesso depois da resposta de persistência; em erro, reconcilia o estado com o servidor e mostra falha.
- Ações de seleção em lote permanecem no endpoint assíncrono original; este ajuste é para o caminho de uma conversa do menu contextual.
- Não houve mudança no estado nativo de resolver/reabrir conversa. “Resolver” permanece ação nativa separada; a remoção da ação customizada de IA já constava dos commits anteriores.

## Proteção complementar do Follow-up

Consulta somente leitura à versão ativa do workflow `Rotta Chatwoot — Follow-up Contextual v1` (`utaNsnFUZYBYDf5S`, versão `c1814ecd-25f7-4e79-a836-3a36d30b9b7e`, 28 nós; ativa e igual ao draft) confirmou:

- ordenação/validação dos eventos por `source_updated_at` e `last_event_id`;
- reivindicação exclusiva do job com `FOR UPDATE SKIP LOCKED` e `pg_try_advisory_xact_lock`;
- checagem de que a etiqueta ainda está ativa antes de autorizar o envio.

Não foi alterado o workflow nesta rodada. Limite inerente: depois que a chamada externa de envio à UAZAPI começou, remover a etiqueta não consegue recolher uma mensagem já aceita pelo provedor. Portanto, a proteção evita jobs antigos ainda não autorizados, não uma chamada externa já em trânsito.

## Verificações locais

- Regressão red antes da correção e verde após ela.
- Vitest direcionado: 24/24 (11 testes de store/API, 8 do seletor/composable e 5 do menu contextual), incluindo add→remove serializado e ausência de toast obsoleto.
- ESLint nas fontes e specs alterados: 0 erros; 2 avisos conhecidos `vue/one-component-per-file` no spec de `useBulkActions`. Prettier aprovado.
- Spec Rails da rota de etiquetas foi ampliada para cobrir deltas aditivos/removidos sem substituir etiquetas preexistentes. Não foi possível executá-la localmente: Ruby/Bundler não estão instalados nesta máquina; a rota precisa ser validada após o deploy.
- Build Vite: 5.102 módulos transformados; concluído. Persistem avisos conhecidos de Browserslist desatualizado e chunks grandes.
- `verify:manifest-assets`: passou com 240 referências do manifesto.

## Vídeo analisado

Transcrição registrada da gravação fornecida:

1. “Outra coisa muito importante é que, quando clicamos do lado direito do mouse em uma conversa, aparecem as opções, ok?”
2. “Enviar para FINALIZADOS deve abrir um pop-up, tá vendo que o pop-up aqui não abriu… abriu feio e no meio da conversa.”
3. “O pop-up deve abrir no centro da tela, um pop-up grande, e não esse daqui. Então precisamos ajustar o tamanho do pop-up, ok?”
4. “Outro ponto importante: quando clicamos do lado direito, clicamos em emitir contrato, quando é clicado em emitir o contrato, deve vir exatamente para cá. Isso não é uma etiqueta, é apenas um encaminhamento para cá, porém ficar com a borda roxinha. Cada cliente que estiver selecionado em emitir o contrato virá para cá emitir o contrato e ainda continuará disponível aqui nas conversas… quando eu clicar em emitir o contrato, ele vai para a aba de emitir o contrato e quando eu clicar, deve ter o botão de remover etiqueta emitir o contrato.”

Os itens visuais do popup centralizado e do atalho roxo `Emitir Contrato` foram tratados nas alterações anteriores. O teste desta correção não executa a finalização em uma conversa de produção.

## Publicação e teste real

- Commit funcional `5c8efa96b63e1aca3aa1f7b13bb5f987f59f6b93` foi enviado à branch `rotta-custom-v1` e implantado no EasyPanel. O log do deploy terminou `Success` em 15/09/2026 às 20:05:32 UTC; `/health` respondeu `200` (`{"status":"woot"}`) depois da recriação de Rails/Sidekiq. O smoke test atual permanece HTTP `200`.
- Teste real no Chatwoot publicado com a conversa `#2143`, contato Kelvin `+5511965927865`: estado aberto confirmado pelo botão nativo `Resolver`; antes do teste, `Emitir Contrato` estava em `0`. Adicionei pela interface e o seletor passou a `1`; removi pela interface, voltou a `0`; recarreguei e confirmei `0 selecionada(s)` e `Emitir Contrato 0`. A conversa permaneceu aberta. Nenhuma mensagem foi enviada.
- A IA global `/app/accounts/1/ask-ai` foi conferida em produção: cartões de resultado não mostram ações customizadas “Marcar resolvida”/“Pendente”. A ação nativa `Resolver` permanece no cabeçalho do Chatwoot e é distinta; não foi acionada nem removida. A trilha da conversa mostra que a última transição nativa é reabertura por Kelvin.
- A tentativa de teste no seletor ocorreu com a barra lateral expandida e foi inicialmente bloqueada porque o popover ficava recortado atrás dela. Recolhi a barra apenas durante o teste, completei add→remove, restaurei a lateral expandida e recarreguei a conversa. Nenhuma preferência ou dado de negócio ficou alterado pelo teste.
- Limite de evidência: o fluxo real de uma conversa validou a persistência e restauração; a concorrência entre duas sessões/agentes é protegida pelo lock de linha no código e coberta por testes de frontend/API, mas o RSpec Rails dessa rota não foi executado localmente (Ruby/Bundler ausentes), e não foi feito teste de carga em produção. Portanto, não afirmo garantia absoluta nem concorrência multiagente validada ao vivo.
- O teste de UI anterior add→remove levou cerca de 3,8 s devido à latência da ferramenta; isso não é uma medida da latência do backend nem um teste visual sub-segundo. O Vitest modela interleavings concorrentes imediatamente.
- A leitura da sidebar também mostrou o contador de `Clientes Fechados` variar entre `2` e `1` durante a recarga/atualização da tela, enquanto `Emitir Contrato` ficou em `0`. Não foi alterado nem investigado nesta rodada; registrar como possível questão independente de sincronização de contadores, sem atribuir causalidade ao teste.

## Contexto conectado

[[Meu Cofre/Chatwoot Rotta — contexto e estado]] ↔ [GitHub `rotta-custom-v1`](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/conversations/2143).
