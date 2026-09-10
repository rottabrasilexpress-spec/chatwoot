# Auditoria — etiquetas, follow-up e carregamento inicial

Data: 2026-09-10  
Escopo: somente sincronização das etiquetas de follow-up e carregamento inicial das conversas.

## Diagnóstico

- O Chatwoot envia `conversation_updated` quando `label_list` muda, mas a fila externa podia conservar jobs ativos incompatíveis e aceitar mais de um job para o mesmo cliente/etapa.
- O painel mostrava duas entradas do Kelvin porque havia dois históricos para o mesmo telefone em conversas diferentes (`206` e `2143`), ambos como `Primeiro contato`.
- A lista principal do Chatwoot usava 25 por página e não solicitava explicitamente as 50 conversas iniciais.

## Alterações aplicadas

### Workflow n8n em produção

Workflow: `Rotta Chatwoot — Follow-up Contextual v1`  
ID: `utaNsnFUZYBYDf5S`  
Versão publicada após o ajuste: `e0c0ef67-d609-40ef-93bb-fc287a7d6b38` (a versão intermediária `46cb69ec-061e-408d-b1c8-420120759ed6` foi substituída após a validação final).

- Ao remover uma etiqueta de trilha, jobs ativos da conversa são cancelados.
- Ao trocar de etapa, jobs ativos de outras etapas são cancelados.
- A fila é idempotente por telefone e etapa, com índice único parcial para impedir duplicidade ativa.
- Uma reconciliação administrativa sem envio foi executada para limpar duplicatas já existentes.
- O histórico do painel passa a exibir uma única entrada por telefone e etapa; o histórico interno permanece preservado.
- O worker e o nó de envio Uazapi não foram executados durante a auditoria.
- Correção final de execução: `activeJobStatuses` foi inicializado antes da construção das expressões SQL que o utilizam; a versão final foi publicada sem warnings para que os eventos futuros de adição/remoção de etiqueta não encontrem a constante em estado temporal inválido.

### Chatwoot

- `ChatList.vue` passa a solicitar `perPage: 50` desde o carregamento inicial.
- `ConversationApi` envia `per_page=50` somente quando solicitado.
- `ConversationFinder` respeita o tamanho explícito e limita o máximo a 100; os demais consumidores continuam com o padrão configurado.
- Foram adicionados testes de contrato da API e do finder para 50 e para o limite seguro.

## Evidência ao vivo após a reconciliação

O painel respondeu com 5 históricos, distribuídos em:

- Primeiro contato: 3 — Tiago, Linda e Kelvin.
- Terceiro contato: 2 — Liliane e Waldir.
- Kelvin (`5511965927865`): uma única entrada visível.

Tiago continuar em `Primeiro contato` e Liliane em `Terceiro contato` corresponde às etiquetas/históricos atuais observados; nenhuma etiqueta existente foi alterada manualmente.

## Verificações

- Workflow n8n atualizado e publicado sem warnings de validação.
- ESLint direcionado: sem erros de regra; permaneceu apenas um warning preexistente de chave dinâmica i18n.
- Ruby local não está instalado neste ambiente.
- Vitest foi impedido pela instalação compartilhada de dependências apontando para um caminho ausente de `fake-indexeddb`; o código e os testes foram mantidos no repositório para execução no pipeline/deploy.
