# Planejamento — Pergunte para IA dentro da conversa

Data: 10/09/2026  
Status: planejamento; nenhuma publicação ou alteração funcional feita  
Escopo: Chatwoot Rotta, conversa isolada, agentes autorizados e integração OpenRouter/n8n

## Evidência do vídeo e do áudio

Arquivo analisado: `C:\Users\User\Downloads\Gravando 2026-09-10 174553.mp4`  
Duração detectada: aproximadamente 125,5 segundos  
Formato: vídeo H.264 2560×992 + áudio AAC

### O que aparece visualmente

- O vídeo percorre a tela de conversas do Chatwoot, o contato de teste, etiquetas e o Follow-up.
- A área de composição mostra os modos existentes de resposta pública e mensagem privada.
- O fluxo visual reforça o problema anterior de contadores/etiquetas atrasados e históricos antigos no Follow-up.
- Também aparecem telas administrativas de etiquetas, configuração e a área central da conversa.
- Não há ainda um controle dedicado “Pergunte para IA” na área de composição; o objetivo desta proposta é inserir essa entrada sem transformá-la em mensagem pública ou nota privada.

### Transcrição revisada do áudio

> O seguinte, eu preciso que você veja o vídeo em anexo e também transcreva o áudio e acompanhe absolutamente tudo.
>
> Eu coloquei três clientes com etiqueta Kelvin, ok, que está aqui, e a etiqueta, o número de quantidade de clientes na etiqueta não foi atualizado e continuou como um, que reflete na aba de orçamentos também como um, porém, ao clicar, não está aparecendo mais nenhum.
>
> Você fez alguma coisa, agora apareceu, agora atualizou e apareceu. Apareceu dois clientes, porém, aqui continua como um. Isso aqui está totalmente errado.
>
> Eu vou colocar uma etiqueta aqui, Primeiro contato, que diz ter dois, mas não tem dois. Atualizou e era para ter mudado para três, não mudou. Vamos voltar, não mudou ainda.
>
> Vou entrar na aba de Follow-up. Vamos lá: Primeiro contato, entrou o Caio aqui, está vendo? Mas está vendo que tem mais três clientes aqui, Kelvin, Leila e Thiago? Eles não estão com essa etiqueta e aqui já diz enviado. Isso aqui provavelmente foi coisa do passado, assim como o Terceiro contato. Isso aqui não existe, isso aqui está totalmente errado. A gente precisa focar em melhorar isso aqui, isso está completamente equivocado.
>
> Então vamos lá, está vendo que só tem um? Isso aqui estava poluído. A gente precisa ajustar isso aqui. Eu vou remover, vou remover as duas etiquetas.
>
> Você viu que removeu, agora ele atualizou e o Kelvin tem dois. Vamos ver. Agora ele atualizou. Agora vamos ver o pastor, pastora. Removi o Kelvin, ele foi para zero e ok.
>
> Note que às vezes funciona e às vezes não. Vou dar um F5 aqui para ver se retorna alguma coisa, mas a gente precisa descobrir o motivo pelo qual não está atualizando totalmente. Retorna aqui na tela de Follow-up para verificar. Veja, ainda está aqui, totalmente poluído. Precisamos ajustar isso, gente.

## Requisitos extraídos

1. Adicionar uma entrada visível “Pergunte para IA” próxima de “Responder” e “Mensagem Privada”.
2. Ao clicar, abrir uma conversa de apoio com a IA, sem enviar nada ao cliente.
3. Permitir perguntas como resumo da conversa, lista atualizada de itens, pendências, origem/destino e próximos passos.
4. Isolar o contexto por conversa: a IA não pode misturar a conversa atual com outra.
5. Permitir compartilhamento entre agentes autorizados, por exemplo, o usuário atual e Caio.
6. Usar o mesmo modelo indicado pelo atendimento atual: confirmado no workflow n8n como `deepseek/deepseek-v4-flash-0731` via credencial OpenRouter existente.
7. Usar o `rotta_n8n_mcp` para a parte de automação/integracão sem alterar o workflow de Follow-up em produção durante o planejamento.
8. Registrar decisões, testes, versão publicada e rollback no Obsidian e no GitHub.

## Estado técnico encontrado

### Chatwoot/Captain existente

- Já existe um Copilot lateral com threads e mensagens persistidas em `copilot_threads` e `copilot_messages`.
- A entrada `ask_copilot` já abre o painel lateral do Captain.
- O backend já recebe `conversation_id` e valida acesso do agente à conversa.
- `GetConversationService` pode consultar o histórico da conversa incluindo mensagens privadas quando autorizado.
- A thread atual é vinculada a `user_id` e os controllers procuram a thread do usuário atual; por isso, ela não é compartilhada entre agentes hoje.
- O Copilot existente dispõe de ferramentas mais amplas, como busca de outras conversas e contatos. Isso não atende automaticamente ao requisito de isolamento estrito.

### n8n existente

- Workflow ativo: `utaNsnFUZYBYDf5S` — `Rotta Chatwoot — Follow-up Contextual v1`.
- Versão ativa consultada: `792140e0-e969-4d11-94f0-1bc687a40fd8`.
- O nó `Gerar Follow-up Contextual` usa OpenRouter e o modelo `deepseek/deepseek-v4-flash-0731`.
- O workflow atual é de follow-up, etiquetas e UAZAPI. Não deve receber a nova função diretamente sem uma separação de responsabilidades.

## Arquitetura proposta para aprovação

### Recomendação

Criar um modo separado chamado `conversation_ai` no Copilot, reutilizando a infraestrutura de UI, threads, ActionCable e OpenRouter, mas com contrato de segurança próprio:

- uma thread compartilhada por conversa e assistente/modelo;
- acesso permitido apenas a agentes que já podem visualizar aquela conversa;
- contexto fixado no `conversation_id` do botão clicado;
- ferramentas limitadas à conversa atual e aos dados necessários para responder;
- respostas armazenadas em `copilot_messages`, nunca em `messages` do Chatwoot;
- nenhuma chamada à UAZAPI, nenhum POST de mensagem, nenhuma nota privada automática, nenhuma alteração de etiqueta/status;
- indicador claro “Resposta interna — não enviada ao cliente”.

### Por que não ligar simplesmente ao Copilot atual

O Copilot atual já é uma boa base visual, mas a propriedade da thread é individual e as ferramentas disponíveis podem pesquisar outras conversas. Reutilizar tudo sem um modo restrito poderia violar exatamente os dois requisitos centrais: compartilhamento controlado e isolamento por conversa.

### Persistência e compartilhamento

Opção recomendada:

- adicionar vínculo `conversation_id` à thread;
- tornar a thread compartilhada por conversa, assistente e conta;
- autorizar leitura/escrita usando a mesma política de acesso da conversa;
- manter autor de cada pergunta e resposta para auditoria;
- resetar a seleção da thread ao trocar de conversa;
- usar atualização em tempo real para que o que o usuário escreve e a resposta da IA apareçam para Caio e demais agentes autorizados.

Se for necessário compartilhar somente com agentes escolhidos, adicionar uma tabela de participantes; isso é mais controlável, mas aumenta migrations, UI e testes.

### Contexto enviado à IA

Contexto mínimo recomendado:

- mensagens públicas da conversa, em ordem;
- mensagens privadas/notas internas, se a decisão abaixo autorizar;
- nome e telefone do contato;
- etiquetas e atributos da conversa;
- anexos somente quando houver extrator/transcrição confiável;
- pergunta atual do agente;
- instrução explícita para nunca consultar outra conversa nem inventar informação.

O histórico deve ter limite de tokens e estratégia de resumo progressivo, preservando fatos recentes e decisões confirmadas. O prompt deve instruir a IA a separar “confirmado”, “não informado” e “inferência”.

## Fluxo proposto

1. Agente abre a conversa e clica em “Pergunte para IA”.
2. O Chatwoot abre o painel/aba interna vinculada ao `conversation_id` atual.
3. O backend verifica a autorização do agente e carrega/cria a thread compartilhada daquela conversa.
4. A pergunta é persistida como mensagem interna da thread.
5. Um job assíncrono consulta o modelo aprovado, com contexto estritamente limitado.
6. A resposta é persistida e transmitida por ActionCable para os agentes autorizados.
7. A resposta aparece apenas no painel interno, com estado de carregamento, erro, retry e identificação do autor.
8. Ao trocar de conversa, a thread e o contexto mudam; nenhum histórico da conversa anterior permanece visível.

## Testes planejados antes de qualquer publicação

### Segurança e isolamento

- pergunta na conversa A nunca retorna texto da conversa B;
- agente sem acesso à conversa recebe 403/404 e não acessa a thread;
- cliente não recebe webhook, mensagem, nota ou evento da pergunta;
- troca rápida A→B não mistura respostas tardias;
- thread antiga não pode ser reaberta em outra conversa por alteração manual de ID;
- logs não exibem token, prompt integral sensível ou segredo da OpenRouter.

### Colaboração

- usuário pergunta e Caio vê a pergunta/resposta;
- Caio pergunta e o usuário vê a atualização;
- dois agentes perguntando simultaneamente não sobrescrevem mensagens;
- uma resposta lenta não bloqueia o composer público;
- agente removido da conversa deixa de receber atualizações.

### Produto e visual

- botão aparece junto dos modos existentes sem deslocar o composer;
- diferenciação visual clara entre resposta pública, nota privada e IA;
- estados vazio, carregando, streaming, erro, retry e sem permissão;
- Enter envia pergunta para a IA e nunca para o cliente;
- F5 e troca de conversa preservam a thread correta;
- telas estreitas e desktop;
- leitores de tela e foco de teclado.

### Modelo e dados

- resumo de conversa longa;
- lista de itens atualizada com mensagens conflitantes;
- pergunta sobre origem/destino ausentes;
- mensagens privadas incluídas ou excluídas conforme decisão;
- anexos sem texto legível;
- uso do modelo indisponível, timeout, rate limit e resposta inválida;
- custo/limite por conta e telemetria sem conteúdo sensível.

## Fases sem publicação imediata

1. Responder às decisões abertas abaixo.
2. Fechar ADR de isolamento, compartilhamento, retenção e fonte do modelo.
3. Criar contrato de API e migrations em branch/worktree separado.
4. Criar workflow n8n separado e inativo para testes, sem tocar o Follow-up publicado.
5. Implementar UI e backend com testes automatizados.
6. Testar com dados sintéticos e uma conversa autorizada, sem cliente real.
7. Fazer revisão de segurança e regressão do composer público/nota privada.
8. Somente após aprovação explícita, publicar/deployar.
9. Registrar commit, versão n8n, evidências e rollback no GitHub e Obsidian.

## Perguntas que precisam de resposta antes da implementação

1. Confirma que o identificador exato do modelo é `deepseek/deepseek-v4-flash-0731`? O áudio parece dizer “DeepSeek V4 Flash 07-31”; o n8n confirma esse ID.
2. A IA deve incluir mensagens privadas/notas internas no contexto? Recomendação: sim, porque são informações operacionais dos agentes; elas nunca devem sair para o cliente.
3. O compartilhamento deve ser automático para todo agente que já tenha acesso à conversa ou somente para agentes convidados, como Caio? Recomendação inicial: qualquer agente com acesso Chatwoot à conversa.
4. Deve existir uma única thread compartilhada por conversa ou uma thread privada por agente com opção de compartilhar? Recomendação: uma thread compartilhada por conversa para evitar divergência.
5. A função será somente leitura/análise ou poderá futuramente criar nota, etiqueta ou executar ação? Recomendação inicial: somente leitura/análise, sem ferramentas de mutação.
6. O histórico da conversa com a IA deve ser permanente, arquivado junto da conversa, ou ter retenção definida em dias?
7. Devemos incluir anexos, imagens, PDFs e áudios no contexto na primeira versão, ou começar apenas com texto, etiquetas e atributos? Recomendação: começar com texto/metadados e deixar anexos para fase 2.
8. Você prefere o terceiro modo diretamente no seletor `Responder | Mensagem Privada | Pergunte para IA` ou um botão que abra o painel lateral existente? Recomendação: terceiro modo visível que abre o painel lateral interno.
9. A resposta deve aparecer progressivamente em streaming ou somente quando estiver completa? Recomendação: streaming se a infraestrutura atual permitir sem afetar o realtime; caso contrário, estado de processamento com resposta completa.
10. O n8n deve hospedar o endpoint dessa função em um workflow separado, ou a função deve usar diretamente o Copilot/Captain do Chatwoot? Recomendação: workflow n8n separado se a exigência for compartilhar exatamente a credencial/modelo atual; nunca acoplar ao workflow de Follow-up.
11. Você autoriza testes reais apenas com o contato Kelvin `11965927865`, como no trabalho anterior, ou prefere usar somente dados sintéticos durante o planejamento?
12. Devemos mostrar no painel quem fez cada pergunta e quem recebeu cada resposta, incluindo Caio? Recomendação: sim, para auditoria e colaboração.

## Critério de aprovação da fase de planejamento

O planejamento só será considerado aprovado quando as decisões acima estiverem fechadas, o contrato de isolamento estiver documentado, o workflow separado estiver desenhado sem publicação e o plano de rollback/testes tiver sido aceito. Até lá, não alterar o composer, o backend, o workflow de Follow-up nem enviar mensagens reais.

## Blueprint técnico para a implementação aprovada

### Ponto de entrada no composer

- `EditorModeToggle.vue` hoje alterna somente `REPLY` e `NOTE`.
- `ReplyTopPanel.vue` já possui o acesso do Captain e o evento `ask_copilot`, mas ele abre o Copilot amplo atual.
- A implementação deverá adicionar uma ação visual específica `Pergunte para IA`, com estado próprio, sem reutilizar `isPrivate` e sem passar pelo método de envio de mensagem do `ReplyBox.vue`.
- O estado do composer público e da mensagem privada deve permanecer intacto quando o painel de IA abrir ou fechar.

### Contrato seguro entre Chatwoot e n8n

O navegador não deve chamar diretamente o webhook n8n nem receber segredo. O desenho recomendado é:

1. O navegador chama um endpoint account-scoped do Chatwoot com `conversation_id`, `thread_id` opcional, pergunta e um `request_id` idempotente.
2. O backend aplica `Captain::Copilot::ConversationAccess` antes de ler qualquer mensagem ou criar a pergunta.
3. O backend cria/recupera a thread compartilhada e registra a pergunta com autor e conversa.
4. Um job interno prepara o contexto autorizado e chama o workflow n8n separado usando segredo server-to-server.
5. O n8n recebe contexto já limitado à conversa, pergunta, identificador técnico e contrato de resposta; não recebe um `conversation_id` livre para pesquisar a conta.
6. O n8n chama OpenRouter com `deepseek/deepseek-v4-flash-0731` e devolve somente resposta estruturada, sem executar ações.
7. O backend valida que a resposta pertence ao mesmo `thread_id`/`conversation_id`, persiste a resposta e transmite a atualização por ActionCable.

Contrato lógico de entrada do workflow separado:

```json
{
  "request_id": "uuid",
  "account_id": 1,
  "conversation_id": 2143,
  "thread_id": 123,
  "agent_id": 7,
  "question": "Qual é a lista atualizada de itens?",
  "context": {
    "contact": {},
    "labels": [],
    "attributes": {},
    "messages": []
  },
  "context_policy": "conversation_only_v1"
}
```

Contrato lógico de saída:

```json
{
  "request_id": "uuid",
  "conversation_id": 2143,
  "thread_id": 123,
  "status": "completed",
  "answer": "...",
  "model": "deepseek/deepseek-v4-flash-0731",
  "usage": { "input_tokens": 0, "output_tokens": 0 }
}
```

Estados necessários: `queued`, `processing`, `completed`, `failed`, `cancelled`. O `request_id` precisa ser idempotente para retries não duplicarem respostas.

### Isolamento do contexto

- O backend monta o conjunto de mensagens a partir da conversa autorizada, em ordem cronológica, com limite de tamanho e resumo incremental.
- Cada mensagem deve carregar origem e identificador apenas para auditoria interna; não usar IDs de outra conversa.
- Conteúdo escrito pelo cliente é dado não confiável: o prompt deve tratá-lo como texto, nunca como instrução de sistema.
- A função não deve habilitar `SearchConversations`, `SearchContacts`, `SearchArticles` ou ferramentas de alteração na primeira versão.
- Se a pergunta pedir informações inexistentes, a IA deve responder “não informado” em vez de completar por inferência.
- O contexto deve declarar explicitamente: “responda apenas com os dados desta conversa; não mencione nem procure outras conversas”.

### Persistência e autorização da thread

Modelo recomendado para a primeira versão compartilhada:

- `copilot_threads.conversation_id` obrigatório para threads `conversation_ai`;
- `copilot_threads.scope` com valor `conversation`;
- índice único parcial por `account_id`, `conversation_id` e `assistant_id` para uma thread compartilhada;
- autor da pergunta preservado em `copilot_messages`/metadados;
- cada leitura e envio revalida acesso atual à conversa;
- o acesso é derivado da permissão Chatwoot, sem confiar apenas no fato de o agente conhecer o `thread_id`.

Se o requisito evoluir para “compartilhar somente com Caio”, acrescentar `copilot_thread_memberships` com agente, concedente, data e revogação. Não usar essa tabela como substituta da autorização de conversa.

### Segurança, observabilidade e rollback

- O webhook n8n separado deve aceitar somente chamadas autenticadas do backend e rejeitar origem de navegador.
- Segredos ficam somente em credencial n8n/variáveis server-side; nunca em bundle Vue, logs ou Obsidian.
- Logs devem registrar `request_id`, conta, conversa, thread, status e latência, mas não prompt ou conteúdo integral.
- Rate limit por agente/conta e limite máximo de caracteres devem existir antes da chamada ao modelo.
- Timeout, erro de modelo e JSON inválido devem gerar estado `failed` com retry explícito e mensagem amigável.
- Rollback deve ser: desligar o workflow separado, ocultar o botão por feature flag e reverter a migration/API sem tocar mensagens públicas nem o workflow de Follow-up.

### Critérios técnicos de aceite

- O cliente nunca recebe a pergunta ou a resposta pela API de mensagens, UAZAPI ou canal WhatsApp.
- Duas conversas abertas em abas diferentes nunca compartilham `thread_id` ou contexto.
- Um agente sem acesso recebe erro de autorização antes da leitura do histórico.
- A mesma thread mostra pergunta/resposta para agentes autorizados e atribui o autor correto.
- Respostas fora de ordem não substituem mensagens mais novas.
- O botão não altera `replyType`, `isPrivate`, rascunho, anexos ou envio público.
- O workflow n8n de Follow-up permanece inalterado e ativo durante todos os testes da nova função.

## Aprovação do escopo — 10/09/2026

Decisões confirmadas pelo usuário antes do início da implementação:

- Modelo exato: `deepseek/deepseek-v4-flash-0731`.
- Contexto: a IA pode consultar todo o histórico da conversa, distinguindo falas do cliente, falas humanas, datas, mudanças de itens, valores e decisões. O prompt deve produzir respostas de assistente operacional, com fatos, cronologia e incertezas explícitas.
- Compartilhamento: agentes autorizados à conversa podem ver a mesma thread e a memória compartilhada.
- Autonomia: a IA poderá executar ações solicitadas, incluindo etiquetas e envio de mensagens, por ferramentas controladas e auditáveis.
- Entrada: somente texto; áudios não serão interpretados na primeira versão.
- Memória: Redis com retenção de 30 dias.
- Interface: terceiro modo `Pergunte para IA` junto a `Responder` e `Mensagem Privada`, com texto auxiliar explicativo.
- Transporte: workflow n8n separado do Follow-up.
- Teste: primeiro dados sintéticos; depois teste real autorizado com Kelvin.
- Auditoria: registrar o agente que perguntou, comandos, ações executadas, resultados e respostas compartilhadas.

### Ajuste de segurança decorrente da autonomia

“Pode alterar tudo” será implementado como autonomia limitada ao escopo da conversa e às ferramentas explicitamente disponibilizadas. Cada ação terá validação de autorização, confirmação de alvo, idempotência, resultado estruturado e trilha de auditoria. A IA não receberá acesso SQL arbitrário, credenciais ou uma ferramenta genérica de execução.

Para ações de alto impacto — envio de mensagem externa, resolução/arquivamento e exclusões — a primeira versão exibirá a ação proposta e exigirá confirmação no painel, salvo nova autorização explícita para modo sem confirmação. Etiquetas, leitura e alterações reversíveis poderão ser executadas diretamente.
