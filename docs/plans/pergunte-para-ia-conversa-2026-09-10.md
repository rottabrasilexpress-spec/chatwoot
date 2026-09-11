# Planejamento — Pergunte para IA dentro da conversa

Data: 10/09/2026  
Status: workflow n8n publicado; deploy/migration do Chatwoot e teste real pendentes
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

## Implementação iniciada — 11/09/2026

### Entregas realizadas na branch

- Criada a opção `Pergunte para IA` ao lado de `Responder` e `Mensagem Privada`, com descrição auxiliar e painel interno separado.
- Criada thread compartilhada por conversa, com autorização derivada do acesso normal do agente à conversa e autor preservado nas mensagens.
- Criado o contexto completo textual da conversa, incluindo mensagens públicas, notas privadas, etiquetas, contato e identificação do agente.
- Criado job server-side para chamar o webhook separado, persistir a resposta e publicar falha amigável sem enviar nada ao cliente por padrão.
- Criadas ações n8n controladas para etiqueta, remoção de etiqueta, mensagem pública explícita, nota privada explícita e status permitido.
- A associação persistida usa o `conversations.id`; a interface e o contrato externo continuam usando o `display_id` do Chatwoot.

### Workflow n8n separado

- Nome: `Rotta Chatwoot — Pergunte para IA v1`.
- Modelo: `deepseek/deepseek-v4-flash-0731`.
- Memória: Redis, chave por conta/conversa, TTL de 30 dias e janela de 50 mensagens de memória.
- Streaming desativado para reduzir variabilidade na primeira versão e devolver resposta JSON completa.
- Workflow de Follow-up existente não foi alterado.

### Evidências de teste já obtidas

- Execução sintética 575076: resposta factual sobre quantidade de móveis e reconhecimento de dado final ausente.
- Execução sintética 575077: memória compartilhada recuperou a pergunta/resposta anterior na mesma conversa.
- Execução sintética 575079: comando explícito de adicionar etiqueta acionou somente a ferramenta de etiqueta, com resultado auditável e sem efeito externo real.
- Validação n8n: workflow válido com 10 nós e sem avisos de configuração.
- ESLint focado nos arquivos Vue/JS alterados: aprovado.
- `git diff --check`: aprovado; os avisos restantes são apenas conversão de final de linha do checkout Windows.
- Vitest do `CopilotContainer`: bloqueado antes da coleta por dependência local `fake-indexeddb/auto` apontando para o checkout compartilhado; não houve falha de caso de teste. Será repetido no ambiente de CI/deploy.
- Testes Ruby/RSpec: não executáveis neste Windows porque Ruby/Bundler não estão instalados; a revisão estática foi feita e deve ser confirmada no CI do deploy.

### Próximos checkpoints obrigatórios

1. Publicar o commit no GitHub e aguardar o deploy do Chatwoot.
2. Publicar/ativar o workflow n8n separado.
3. Confirmar a rota e a migration no ambiente implantado.
4. Fazer teste real autorizado na conversa Kelvin, sem enviar mensagem externa durante a validação inicial.
5. Registrar resultado, horário, versão e rollback no Obsidian.

### Publicação n8n — 11/09/2026

- Workflow publicado/ativado: `7FQSbjNn4dfywyc6`.
- Versão ativa: `5e70ddac-d788-4739-afbf-5da34afe157b`.
- O Chatwoot chama o endpoint server-side configurado no job; o teste real só será executado após confirmar que o commit `c3535dd` chegou ao ambiente e a migration foi aplicada.

### Verificação de produção n8n — 11/09/2026

- O endpoint publicado respondeu com sucesso a um caso sintético de cronologia: `3` móveis no início, acréscimo de `2`, resposta final `5`.
- A resposta confirmou o assistente e o modelo aprovados; nenhuma ferramenta ou ação externa foi executada nesse teste.
- Verificação HTTP do Chatwoot ainda mostra o bundle anterior `dashboard-B9LgK-tZ.js` e SHA `b34f5b71...`; portanto, o deploy da branch `rotta-custom-v1` ainda não foi refletido no ambiente live.
- O teste real Kelvin e a confirmação da migration permanecem bloqueados até o deploy do Chatwoot no Easypanel.

## Validação E2E final pós-deploy — 11/09/2026

- O deploy foi concluído no Easypanel e a aplicação pública voltou a `HTTP 200`.
- Foi corrigida a publicação do bundle: o manifesto referenciava `dashboard-CSkKUU6u.js`, que foi versionado no commit `59058e4`. A tela deixou de ficar em branco e carregou histórico, lista de conversas, modo `Pergunte para IA` e texto auxiliar.
- A investigação encontrou e corrigiu as causas do `404/422/500`: arquivos Enterprise ausentes no overlay Docker, modelo Enterprise de mensagem ausente e view que assumia `assistant` não nulo.
- Diagnósticos temporários foram removidos do backend e do frontend. O bundle público foi consultado e retornou `200`, sem `ConversationAiProbe`, `X-Rotta-Conversation-Ai` ou `conversationAiStage`.
- Teste real na conversa Kelvin `#2143`, pela chamada autenticada usada pelo Chatwoot: `POST /api/v1/accounts/1/captain/copilot_threads` retornou `200`; a leitura assíncrona de mensagens retornou `200`.
- A resposta final persistida usou `deepseek/deepseek-v4-flash-0731`, consultou o histórico completo, confirmou a data `12/09/2026`, distinguiu a mensagem de teste de 08/09 e informou as pendências. O pedido sem ação não executou ferramenta externa.
- O fluxo separado permanece com Redis por conversa, TTL de 30 dias (`2.592.000 s`), janela de 50 mensagens e ferramentas controladas. O workflow de Follow-up não foi alterado nesta rodada.
- Cenários de maior risco cobertos: autorização e isolamento por conversa, resolução de identificador, thread sem assistente, autoria, contexto/histórico, job assíncrono, persistência, modelo, memória, polling, comando sem ação, carregamento visual e remoção de diagnósticos.
- A validação não enviou mensagem pública nem usou o WhatsApp Web. Os testes criaram somente mensagens internas do Copilot na thread `3` do Kelvin.
- Build Vite, ESLint focalizado e `git diff --check` aprovados. Ruby/RSpec não executáveis neste Windows por ausência de Ruby/Bundler; a execução Ruby no ambiente live foi comprovada pelo fluxo `200`.
- Commits publicados: `31f7a82` e `59058e4`, branch `rotta-custom-v1`. Registro correspondente atualizado no Obsidian, checkpoint C30.
- Limite residual: a matriz cobre os caminhos funcionais e de maior risco reproduzíveis, não todas as combinações imagináveis de produção. Deve-se manter como hardening a autenticação/assinatura dedicada do webhook n8n, se ainda não estiver configurada.

## Auditoria explícita das ações e regressão live — 11/09/2026

- Ações do modo `Pergunte para IA` agora geram `Enterprise::AuditLog` transacional com ação, agente, conversa, `request_id`, IP, estado anterior/posterior e resultado sanitizado. Se o registro de auditoria falhar, a transação da ação falha junto.
- Foi adicionado teste request-side para ação autenticada e rejeição não autenticada em `spec/enterprise/controllers/api/v1/accounts/captain/conversation_ai_controller_spec.rb`. Ruby/RSpec não rodou localmente por ausência de Ruby/Bundler.
- Commit `cdcbe18` publicado na `rotta-custom-v1`; Easypanel mostrou o deploy `feat(chatwoot): audit conversation ai actions` concluído.
- Smoke live pós-deploy: rota de ação com operação inválida retornou `422` sem mutação; consulta interna Kelvin retornou POST `200` e GET `200`, com `deepseek/deepseek-v4-flash-0731`, resposta `12/09/2026` e nenhuma ação executada.
- O workflow n8n foi conferido na interface atual como publicado. A execução `575772` terminou com sucesso em `7,466 s`; o canvas/log mostrou o modelo DeepSeek, memória Redis nomeada para 30 dias, cinco ferramentas e a resposta persistida.
- Após o restart, o Chatwoot exibiu uma desconexão transitória; o botão `Atualizar` reconectou o canal, carregou todas as conversas automaticamente e o indicador permaneceu estável por 10 s. Nenhuma mensagem pública foi enviada.
- Pendência de hardening: ainda falta evidência direta da configuração de autenticação/assinatura dedicada do nó webhook n8n. Não declarar o objetivo totalmente encerrado até confirmar ou implementar essa proteção.

## Correção do contrato de ações e teste pós-deploy — 11/09/2026

- O primeiro smoke test autenticado revelou uma colisão do campo JSON `action` com o parâmetro reservado `action` do Rails (nome do método `actions`); por isso operações válidas eram rejeitadas como “Ação não permitida”.
- O controlador foi corrigido para ler `action` diretamente dos parâmetros do corpo da requisição, preservando o contrato do n8n. O fallback `operation` foi mantido para compatibilidade futura.
- Commit publicado no GitHub: `023d44a` (`fix(chatwoot): preserve conversation ai action payload`), branch `rotta-custom-v1`; deploy aceito e concluído no Easypanel.
- Teste live seguro após o deploy: `set_status: open` retornou `200` com resultado `open`, sem alterar o estado efetivo; `remove_label: audit-probe` retornou `200` com `labels: []`, sem mutação.
- Consulta posterior da conversa Kelvin `#2143` confirmou `status: open` e `labels: []`; não foi enviada mensagem pública nem usado o WhatsApp Web.
- Durante o restart houve indisponibilidade transitória do domínio; o serviço voltou, a raiz retornou `HTTP 200` e o dashboard carregou novamente a lista de conversas e o modo `Pergunte para IA`.
- O endpoint administrativo `/audit_logs` respondeu `total_entries: 0` porque a feature de auditoria da conta está desabilitada para visualização; isso não invalida o `Enterprise::AuditLog.create!` dentro da transação da ação, mas deixa a consulta visual administrativa indisponível.
- Limites mantidos: Ruby/RSpec continuam sem execução local por falta de Ruby/Bundler; permanece pendente a confirmação direta de autenticação/assinatura dedicada do webhook n8n.

## Auditoria MCP do workflow e execução sintética final — 11/09/2026

- A consulta direta ao workflow `7FQSbjNn4dfywyc6` confirmou `active: true`, versão `5e70ddac-d788-4739-afbf-5da34afe157b`, 10 nós, modelo `deepseek/deepseek-v4-flash-0731`, Redis TTL `2592000` segundos, janela 50 e cinco ferramentas Chatwoot.
- A execução manual sintética `577598` terminou `success` em aproximadamente 13,6 s e respondeu `Fluxo ativo. Nenhuma ação foi executada.`; não houve ferramenta de mutação, mensagem pública ou WhatsApp.
- A auditoria também confirmou que o nó `Webhook Conversation AI` está configurado com `allowedOrigins` do Chatwoot, mas com “No credentials required”. CORS não substitui autenticação: o hardening de assinatura/segredo dedicado permanece aberto.
- Não foi reutilizada nenhuma credencial existente de API como autenticação de entrada do webhook. Isso evitaria expor/compartilhar segredo incorreto e exigiria criar um segredo específico, configurar n8n e enviar o mesmo segredo server-side pelo Chatwoot.

## Autenticação server-side e regressão E2E — 11/09/2026

- O job server-side do Chatwoot passou a enviar um segredo dedicado no header `X-Rotta-Conversation-AI-Secret`, obtido exclusivamente de `ROTTA_CONVERSATION_AI_WEBHOOK_SECRET`; se a variável não existir, o job falha de forma controlada e não chama o n8n. Commit `ac8404d` publicado em `origin/rotta-custom-v1`.
- O mesmo segredo foi configurado no Chatwoot e no serviço n8n pelo Easypanel. O workflow ativo foi republicado na versão `d1a5aadf-a340-46e2-945c-8b883d977564`. O segredo não é registrado neste plano, no Obsidian, no bundle ou nos logs.
- A primeira tentativa de usar `$env` no nó Webhook foi rejeitada pelo runtime n8n por política de acesso a variáveis (`577673`). O guard foi corrigido para comparar o header no próprio workflow publicado, sem depender de leitura de ambiente pelo nó. A validação do nó ficou sem erros.
- Regressão negativa: header incorreto não criou nova execução do workflow e não alcançou o agente; o proxy respondeu `502` por causa do `onlyRunIf`/`responseNode`. Isso fecha a condição de não execução, mas mantém como melhoria residual responder `401/403` limpo, caso seja possível sem abrir o fluxo.
- Regressão sintética autorizada: execução `577715` terminou `success`, com modelo `deepseek/deepseek-v4-flash-0731`, memória carregada/salva e zero chamadas de ferramenta.
- Regressão E2E pelo próprio Chatwoot: POST autenticado do Copilot criou/atualizou a mensagem interna, GET de mensagens retornou `200`, e a execução n8n `577740` terminou `success` em aproximadamente `15,7 s`. A resposta persistida no thread `3` usou `deepseek/deepseek-v4-flash-0731`; nenhuma mensagem pública, etiqueta, nota ou status foi alterada.
- Nenhum WhatsApp Web foi usado e nenhum teste enviou mensagem pelo canal externo. O Follow-up permaneceu separado e sem alteração.
- Limitações honestas: Ruby/RSpec continua indisponível neste Windows; a interface administrativa de audit logs da conta continua desabilitada (`total_entries: 0`), embora as ações live tenham retornado `200` com auditoria transacional no código. O hardening HTTP `401/403` é o único refinamento residual identificado nesta rodada.

## Checkpoint C35 — correção de isolamento, meta ausente e Redis 70 dias — 11/09/2026

- Reprodução vermelha confirmada antes da correção: as respostas live de `GET /api/v1/accounts/1/captain/copilot_threads?conversation_id=2143|2294&request_type=conversation_ai` retornavam somente `payload`, sem `meta`. O Vuex acessava `meta.total_count` diretamente e reproduzia `TypeError: Cannot read properties of undefined (reading 'total_count')`.
- Causa raiz de produção corrigida no overlay Docker: as views Enterprise de `copilot_threads` e `copilot_messages` não eram copiadas para a imagem final. A mutação Vuex também ficou defensiva para respostas sem `meta`, evitando regressão futura.
- Isolamento e tempo real corrigidos no commit `0912875` (`fix(chatwoot): isolate copilot polling by conversation`): polling independente por `thread_id`, até 3 minutos, contagem da thread solicitada, merge sem apagar mensagens de outras conversas e descarte de respostas GET obsoletas. O job agora deriva a conversa da própria thread persistida; a associação interna usa `conversations.id`, com índice correspondente no schema.
- Testes focados locais: Store, mensagens fora de ordem e CopilotContainer passaram em conjunto com 44/44 testes; ESLint dos arquivos alterados passou sem erros; `git diff --check` passou. Ruby/RSpec continua indisponível neste Windows por ausência de Ruby/Bundler e não foi declarado como aprovado.
- Deploy Chatwoot concluído no Easypanel. Houve 502 transitório durante o reinício; depois a raiz e o manifesto voltaram a HTTP 200. Após o deploy, as duas consultas live passaram a retornar `payload + meta`: conversa 2143 com `total_count=1` e conversa 2294 com `total_count=0`. Logs do navegador não registraram `TypeError`, `total_count` ou erro de Copilot.
- Teste visual correto: o primeiro clique havia selecionado apenas Nota privada, sem chamar o agente; isso gerou somente um registro interno controlado e não enviou nada ao cliente. Em seguida foi usado o alvo visual correto `data-conversation-ai-toggle`; a pergunta interna na conversa 2294 retornou `chat isolado e funcionando.` O teste não enviou mensagem pública, não usou WhatsApp Web e não executou ferramenta de mutação.
- n8n `Rotta Chatwoot — Pergunte para IA v1` permanece ativo na versão `38222668-e540-4669-9f1e-612c8456ee95`. Redis foi alterado para TTL de `6.048.000` segundos (70 dias), chave por conta/conversa e janela 50; a descrição do workflow também foi corrigida para 70 dias. O modelo segue `deepseek/deepseek-v4-flash-0731`.
- Execução E2E n8n `578201`: `success`, modo webhook, aproximadamente 2,8 s; nós Webhook, Redis (carregamento e gravação), DeepSeek, agente e resposta executaram sem erro. A resposta foi persistida no painel interno do Chatwoot.
- O workflow de Follow-up não foi alterado. O arquivo `.audit-antonio/relacao-de-bens.docx` permaneceu fora do Git. O commit `0912875` foi enviado para `origin/rotta-custom-v1`.

## Checkpoint C36 — revisão AAA, compatibilidade e publicação de chunks — 11/09/2026

- A primeira revisão AAA independente rejeitou a nota com 78,1 por três riscos: migration não idempotente quando o schema já contém a coluna, jobs antigos com `conversation_id` e testes pouco discriminantes. Nenhuma conclusão foi mantida sem investigar esses pontos.
- Correções publicadas no commit `662f424`: migration de `copilot_threads.conversation_id` idempotente para coluna/índice; `ConversationAi::ResponseJob` continua aceitando o argumento legado `conversation_id` sem voltar a usá-lo para localizar a conversa; teste de contrato para jobs legados; teste de polling que força resposta já pronta na segunda conversa e exige polling independente da primeira; teste de resposta obsoleta na mesma thread.
- Suíte focada após as correções: 45/45 testes, ESLint focalizado sem erros e `git diff --check` aprovado. Ruby/RSpec continua indisponível localmente por ausência de Ruby/Bundler; isso permanece declarado, não mascarado.
- O smoke pós-deploy encontrou um 404 real de asset: o manifesto Vite referenciava 12 chunks que estavam ignorados pelo Git. Os 12 arquivos referenciados foram publicados no commit `8633a0e`, sem alteração de lógica.
- Segundo deploy concluído e estabilizado: raiz HTTP 200, manifesto Vite HTTP 200 e todos os 12 chunks referenciados pelo manifesto responderam HTTP 200. Reload visual do Chatwoot carregou histórico e `Pergunte para IA`; não houve log novo de erro no navegador desde o reload.
- O teste E2E n8n permanece `578201=success`, com Redis TTL de 70 dias, modelo `deepseek/deepseek-v4-flash-0731` e resposta interna persistida. Nenhuma mensagem pública, ferramenta de mutação ou WhatsApp Web foi usado.
- O workflow de Follow-up permaneceu inalterado. O arquivo `.audit-antonio/relacao-de-bens.docx` permaneceu fora do Git. O arquivo temporário de configuração Vitest foi removido após os testes.

## Checkpoint C37 — correlação da resposta, schema e validação final pós-deploy — 11/09/2026

- A segunda revisão AAA independente rejeitou a nota 81,0 por apontar risco de resposta cruzada, migration sem FK/schema completo, teste de job apenas contratual e ausência de verificação automatizada dos assets.
- O commit `5c2798f` passou a enviar `request_id` e `copilot_thread_id` junto ao contexto. O job valida `request_id`, `copilot_thread_id`, `conversation_id` e `account_id` no envelope retornado pelo n8n antes de persistir qualquer resposta; envelope ausente ou divergente cai no caminho de falha interno.
- A migration `20260911000000_add_conversation_id_to_copilot_threads` continua idempotente, agora com FK para `conversations`. O `db/schema.rb` foi alinhado para a versão `2026_09_11_000000` e passou a incluir as tabelas posteriores `message_stars` e `uazapi_webhook_deliveries`, evitando um schema:load incompleto.
- Foi adicionado `npm run verify:manifest-assets`, que verificou localmente 240 assets referenciados pelo manifesto Vite. O script também fica disponível para a etapa de CI/deploy.
- Testes repetidos após a correção: Vitest focado 45/45, ESLint focalizado sem erros, `node --check` do verificador de assets e `git diff --check` aprovados. Ruby/RSpec continua indisponível neste Windows por ausência de Ruby/Bundler; não foi mascarado.
- O workflow n8n foi atualizado e publicado na versão ativa `2b2006b8-b6a7-48fe-9953-2dbae586a236`. A resposta agora devolve os quatro identificadores de correlação; Redis permanece com TTL de 6.048.000 segundos (70 dias), janela 50 e modelo `deepseek/deepseek-v4-flash-0731`.
- Deploy Chatwoot do commit `5c2798f` estabilizado: raiz, manifesto e rota da conversa responderam HTTP 200; verificação externa encontrou 240/240 assets referenciados com HTTP 200.
- Teste visual/E2E interno pós-deploy na conversa `#2294`: a pergunta “Teste pós-deploy de correlação” retornou “vínculo confirmado.” no painel interno, sem ferramenta, mutação ou mensagem pública. A execução n8n `578744` terminou `success` em aproximadamente 1,9 s, com Redis carregado e salvo; nenhum WhatsApp Web foi usado.
- O workflow de Follow-up não foi alterado. O arquivo `.audit-antonio/relacao-de-bens.docx` continuou fora do Git e o arquivo temporário Vitest foi removido antes do commit.

## Checkpoint C38 — reforço de testes do job e documentação do modelo — 11/09/2026

- Após a terceira revisão AAA (93,5; sem falha crítica), foram fechadas as lacunas de evidência no código: o teste de sucesso verifica todos os identificadores enviados ao `ContextBuilder`, e o teste negativo executa o `ResponseJob` inteiro com envelope cruzado e comprova que somente a resposta amigável de falha é persistida.
- O comentário de schema de `CopilotThread` agora documenta `conversation_id` e o índice único por conta/conversa.
- Regressão repetida após o reforço: Vitest focado 45/45, ESLint focalizado sem erros, `node --check` e `npm run verify:manifest-assets` com 240 assets verificados; o arquivo temporário de configuração foi removido.
- Ruby/RSpec/RuboCop continuam sem execução neste Windows por ausência de Ruby/Bundler. O limite permanece explicitamente registrado; não foi declarado como aprovado.
- As mudanças deste checkpoint são testes/comentários, sem alteração de lógica de produção nem novo deploy; o runtime publicado continua sendo o commit `5c2798f`, documentado no C37 e validado visualmente/E2E.
- O workflow de Follow-up e o arquivo `.audit-antonio/relacao-de-bens.docx` permaneceram fora do escopo/Git.

## Checkpoint C39 — redeploy e validação pós-retomada — 11/09/2026

- O branch `rotta-gauntlet-20260909`, no commit `3d79be7`, foi redeployado no Easypanel após a retomada do trabalho. O serviço voltou a responder HTTP 200; os logs confirmaram Rails/Ruby 3.4.4 em produção, Redis conectado e banco pronto.
- A imagem de produção informa que os grupos `development` e `test` não são instalados. Por segurança, a imagem e os dados não foram alterados apenas para instalar RSpec; isso explica a limitação de teste Ruby sem representar falha do runtime.
- Verificação externa pós-deploy: raiz, manifesto Vite e rota da conversa `#2294` responderam HTTP 200; todos os 240 assets referenciados pelo manifesto também responderam HTTP 200.
- Reload visual no Chatwoot carregou o histórico e o painel `Pergunte para IA`. A pergunta interna “Teste final pós-deploy. Responda somente: deploy íntegro. Não execute ações.” retornou “deploy íntegro.” no painel interno, sem ferramenta, mutação ou mensagem pública.
- A execução n8n `578908` terminou `success` em aproximadamente 2,3 s; o Redis carregou e salvou memória, o nó final foi o responder e a resposta foi `deploy íntegro.`. O workflow permanece ativo, com modelo `deepseek/deepseek-v4-flash-0731`, janela 50 e TTL de 70 dias.
- Regressão local repetida: Vitest focado 45/45, ESLint focalizado, `node --check` e `npm run verify:manifest-assets` passaram. Ruby/RSpec/RuboCop continuam não executados neste Windows por ausência de Ruby/Bundler.
- Não houve envio pelo WhatsApp Web, mensagem pública, alteração de Follow-up ou mudança no arquivo `.audit-antonio/relacao-de-bens.docx`. O registro foi sincronizado com o Obsidian e publicado no GitHub.

## Checkpoint C40 — auditoria real de contexto, visibilidade e ações — 11/09/2026

- Teste real na conversa `#2294`: a pergunta sobre origem, destino e inventário retornou somente dados presentes no histórico — Guarujá/SP, Marabá/PA, itens informados e ausência de endereço de rua. A resposta apareceu no painel interno sem reload durante o teste; o n8n carregou e salvou a memória da conversa.
- Teste real de isolamento na conversa `#2143`: como origem e destino não existem nesse histórico, a resposta foi `Não consta`; não houve vazamento dos dados Guarujá/Marabá da conversa `#2294`. A execução n8n `578983` terminou `success` em aproximadamente 9,5 s, sem ferramentas, com memória carregada e salva.
- Visibilidade: o compositor informa “A mensagem será visível apenas para agentes”; as perguntas/respostas do Copiloto ficam no painel interno e não foram inseridas como mensagens públicas no histórico do cliente. Nenhuma mensagem pública ou WhatsApp foi enviada nesta auditoria.
- Falha reproduzida: solicitar pela IA a etiqueta `Caio Atenção` criou a execução n8n `578959`, mas o nó `Adicionar etiqueta` falhou com `supplyData method but no execute method`. O workflow respondeu uma falha amigável e nenhuma etiqueta foi adicionada. Como os cinco nós de ação usam o mesmo tipo `toolHttpRequest`, o mesmo bloqueio afeta adicionar/remover etiqueta, mensagem pública, nota privada e alteração de status pela IA até a correção do nó/runtime.
- Contraprova do Chatwoot: adicionar `Caio Atenção` diretamente pela interface elevou o contador de 0 para 1; remover voltou a 0 após reload. A etiqueta e o contador ficaram sem resíduo. Isso isola o defeito no caminho IA→n8n, não no CRUD visual da etiqueta.
- Persistência visual: a conversa `#2143` abriu diretamente com o histórico do Copiloto carregado. Já a conversa `#2294`, após F5 e também em uma nova aba direta, voltou a `Comece a usar o Copiloto`, apesar de as respostas terem aparecido antes no painel. A persistência/recuperação do thread da `#2294` precisa de investigação adicional; não declarar histórico visual universalmente resolvido.
- Identidade: a conta possui os agentes `Caio Mazine` e `Kelvin`; a sessão usada nesta auditoria está autenticada como `Kelvin`. As perguntas aparecem como Kelvin e as respostas do assistente como `Capitão`. A visibilidade para o agente Caio não foi testada com login de Caio.
- Ações visíveis no Chatwoot: `Resolver/Reabrir`, `Adiar`, `Deixar pendente`, etiquetas, `Bloquear Contato` e `Enviar Transcrição`. O workflow IA atual expõe cinco ações: adicionar/remover etiqueta, enviar mensagem pública, criar nota privada e alterar status (`open`, `pending`, `resolved`). Não há ferramenta IA dedicada para arquivar/desarquivar; a interface usa resolução/reabertura e existe a etiqueta especial `Arquivado`.
- Esta auditoria não alterou código nem workflow. Os testes de resolver/reabrir e etiqueta foram revertidos; a conversa `#2294` terminou aberta e sem `Caio Atenção`. A falha de ação e a recuperação visual do histórico permanecem pendências técnicas objetivas.

## Checkpoint C41 — correções finais de histórico e ações IA, deploy e regressão real — 11/09/2026

- Correção publicada no commit `fe80b77` (`fix(chatwoot): restore copilot history and normalize AI labels`): o watcher do `CopilotContainer` passou a executar imediatamente na montagem, e o backend passou a comparar etiquetas por chave normalizada, aceitando o nome visual `Caio Atenção` e salvando/removendo o título canônico `caio-atencao`.
- O teste de regressão de montagem reproduz o reload com conversa `2294`, recupera a thread `conversation_ai`, carrega as mensagens e verifica a renderização. A suíte local focalizada passou: `CopilotContainer` 4/4, `storeFactory` 40/40 e `copilotMessages` 2/2; ESLint e `git diff --check` passaram. Ruby/RSpec não executou neste Windows por ausência de Ruby/Bundler.
- O workflow n8n `7FQSbjNn4dfywyc6` foi publicado com os cinco nós `n8n-nodes-base.httpRequestTool` v4.5, credencial HTTP funcional e corpos dinâmicos usando `$fromAI`; versão ativa `b85ebe61-fff6-46a4-9466-3f9d5a813154`. Modelo, Redis de 70 dias e janela 50 foram preservados.
- Teste real de adicionar etiqueta na conversa `#2294`: execução `579477` terminou `success` em aproximadamente 7,0 s, retornou `labels: ["caio-atencao"]`, exibiu `Caio Atenção` no Chatwoot e confirmou que nenhuma mensagem pública foi enviada.
- Teste real de remover a mesma etiqueta: execução `579494` terminou `success` em aproximadamente 5,3 s, retornou `labels: []`, removeu a etiqueta visual da conversa e confirmou novamente ausência de mensagem pública. A falha anterior `579340` (`Etiqueta não encontrada`) ficou explicada pelo slug visual e foi coberta pela correção do backend.
- Após reload com o modo IA ativo, o histórico completo da conversa `#2294` reapareceu automaticamente. A consulta factual `579516` terminou `success` em aproximadamente 6,6 s, sem ferramenta, e retornou somente origem, destino, inventário e a ausência de endereço de rua presentes no histórico. O compositor continuou indicando visibilidade apenas para agentes.
- Deploy do commit `fe80b77` concluído no Easypanel: houve `502` transitório durante o restart, seguido de recuperação para `HTTP 200`. Nenhuma mensagem pública foi enviada, nenhum teste usou WhatsApp Web e o arquivo `.audit-antonio/relacao-de-bens.docx` permaneceu fora do Git.
- Registro sincronizado no Obsidian. Limites mantidos: a sessão live permanece autenticada como Kelvin, não como Caio; nesta rodada foram validadas add/remove label e consulta factual, enquanto envio público, nota privada e alteração de status não foram disparados para evitar mutações externas desnecessárias.

## Checkpoint C42 — bateria real final, modos independentes, ações e histórico — 11/09/2026

- Alvo real: o nome exato “Leal Moreira” não apareceu na busca; a conversa disponível usada como alvo foi `#2304`, contato `Eliel Moreira`. A sessão autenticada no Chatwoot era `Kelvin`, não `Caio`; portanto a visibilidade específica do login de Caio continua uma limitação declarada.
- Publicação final: commits `55bc7b4`, `b59266c`, `d07ddbb` e `0a8b6e4` foram enviados para `origin/rotta-custom-v1` e o commit `0a8b6e4` foi implantado. O bundle servido passou a ser `dashboard-DQfqy-Ml.js`, com o marcador de nova pergunta do Copiloto e os três controles independentes.
- Regressão local final: Vitest focalizado `7/7` e ESLint dos arquivos alterados passaram. Ruby/RSpec/RuboCop continuam não executados neste Windows por ausência de Ruby/Bundler; isso não foi mascarado.
- Teste visual real: `Responder`, `Mensagem Privada` e `Pergunte para IA` aparecem como controles separados. Alternar os dois primeiros não enviou mensagem e não removeu o painel interno do Copiloto; o modo IA continuou independente.
- Histórico do Copiloto: após responder uma pergunta, F5 retornou a tela `Comece a usar o Copiloto`, sem mensagens antigas; uma nova pergunta exibiu apenas a pergunta/resposta atual. O painel interno não foi inserido no histórico público do cliente.
- Segurança de ação: a solicitação da etiqueta inexistente `Teste Etiqueta Inexistente 2026` foi recusada, sem criar etiqueta. A IA só confirmou `Primeiro Contato` depois que o Chatwoot mostrou o chip; ao remover, o chip desapareceu sem F5. A conversa terminou sem etiquetas de teste.
- Precisão: a pergunta factual retornou `Origem: Pentecoste (CE)` e `Destino: Altamira (PA)`. A consulta seguinte retornou somente o nome Eliel e os itens presentes no histórico (geladeira, armário, fogão, guarda-roupa, cama de casal, máquina de lavar, 10 sacolas e 10–15 caixas), sem dados de outras conversas.
- Status: `Resolver` arquivou/resolved a conversa e mudou o botão para `Reabrir`; `Reabrir` restaurou o estado aberto. O teste foi revertido e não deixou mutação pendente.
- n8n permanece ativo com `deepseek/deepseek-v4-flash-0731`, janela 50 e Redis por 70 dias. As 20 execuções mais recentes retornaram `success`; em uma amostra de 50, houve 49 sucessos e um erro histórico `577673` de 13:00, causado pela antiga expressão de ambiente bloqueada. Não houve erro nas execuções desta rodada; os IDs recentes incluem `580157`, `580158`, `580166` e `580172`.
- Capacidades confirmadas no produto: responder ao cliente, mensagem privada, consulta interna ao Copiloto, etiquetas, filtrar por etiqueta, resolver/reabrir, pendente/adiar, bloquear contato, enviar transcrição e abrir histórico. Pela IA, estão expostas ações de adicionar/remover etiqueta, enviar mensagem pública, criar nota privada e alterar status; nesta bateria só foram executadas etiquetas e status reversível para não enviar conteúdo externo.
- A lista de conversas apareceu preenchida automaticamente após o carregamento, sem depender de scroll inicial. Como a lista é virtualizada, a inspeção visual não conta 50 nós simultaneamente; a garantia dos 50 primeiros permanece coberta pelos testes de código anteriores.
- Nenhum WhatsApp Web foi usado, nenhuma mensagem pública foi enviada e o workflow de Follow-up permaneceu intocado. O arquivo `.audit-antonio/relacao-de-bens.docx` continuou fora do Git.

## Checkpoint C43 — endurecimento de resposta e regressão pós-publicação — 11/09/2026

- O prompt do agente n8n foi endurecido para português brasileiro revisado, resposta de ação em no máximo duas frases e confirmação somente com estado final comprovado. A publicação foi concluída na versão ativa `56ad7cb9-250d-4282-9b7e-f2f2f83c596b`.
- Regressão live pós-publicação na conversa `#2304`: reload iniciou o Copiloto vazio; `Primeiro Contato` foi realmente adicionado e apareceu como chip; a IA confirmou a ação; a etiqueta foi realmente removida e desapareceu sem F5; a consulta de origem/destino retornou apenas `Pentecoste (CE)` e `Altamira (PA)`.
- As dez execuções mais recentes do workflow terminaram `success`, incluindo `580291`, `580293`, `580306`, `580310` e `580313`. A execução mais recente anterior (`580206`) também percorreu Webhook, Redis, DeepSeek, agente e resposta sem erro.
- O estado final da conversa ficou aberto, sem etiqueta de teste, com o painel do Copiloto zerado após o último reload. Nenhuma mensagem pública, nota privada ou envio pelo WhatsApp foi realizado.
- Observação de apresentação de baixa severidade: a resposta de ação ficou curta e correta quanto ao estado, mas o modelo ainda exibiu ocasionalmente a grafia “Nenhuna”. Isso não produz confirmação falsa nem altera o estado; permanece como refinamento textual, separado da correção funcional já validada.

## Checkpoint C44 — normalização defensiva e preparação do último redeploy — 11/09/2026

- A camada visual do Copiloto passou a normalizar somente mensagens do assistente antes da renderização: corrige `Nenhuna/nenhuna` para `Nenhuma/nenhuma` e `cree-a` para `crie-a`, sem modificar a pergunta original do agente nem o histórico do cliente.
- Regressão local concluída: Vitest focalizado `8/8` e ESLint dos arquivos alterados passaram. O build Vite foi concluído com o bundle `dashboard-BsjbfJOB.js`; o manifesto referencia 13 chunks novos que serão publicados junto com o bundle para evitar 404 de asset.
- O ajuste é apenas de apresentação e não altera ferramentas, etiquetas, Follow-up, WhatsApp, Redis, modelo ou regras de autorização. O arquivo `.audit-antonio/relacao-de-bens.docx` continua fora do Git.

## Checkpoint C45 — redeploy e validação real concluída — 11/09/2026

- O commit `dcc194e` foi publicado em `origin/rotta-custom-v1` e implantado no Easypanel. A raiz, o manifesto e o bundle `dashboard-BsjbfJOB.js` responderam HTTP 200; o bundle contém o marcador do Copiloto e o manifesto local validou 240 assets.
- Na conversa real `#2304` (`Eliel Moreira`), o Copiloto iniciou vazio após reload. Adicionar `Primeiro Contato` criou o chip imediatamente e a resposta exibiu `Nenhuma`; remover a mesma etiqueta removeu o chip imediatamente e exibiu `nenhuma`, sem F5 e sem alterar outras etiquetas.
- Após novo reload, o histórico público permaneceu intacto, o painel interno voltou a `Comece a usar o Copiloto`, e não havia etiqueta de teste. O console do navegador terminou com zero erros. As execuções n8n correspondentes `580471` e `580473` terminaram `success`; as 10 mais recentes consultadas também terminaram `success`.
- O workflow n8n continua ativo na versão `56ad7cb9-250d-4282-9b7e-f2f2f83c596b`, usando `deepseek/deepseek-v4-flash-0731`, Redis de 70 dias e janela 50. Não houve mensagem pública, WhatsApp Web, nota privada, Follow-up ou alteração de status nesta rodada.
- Limitações mantidas com transparência: a busca não encontrou o nome exato `Leal Moreira`; o alvo disponível foi Eliel. A sessão live está autenticada como Kelvin, não Caio; portanto a permissão específica do login Caio não foi revalidada nesta rodada. O arquivo `.audit-antonio/relacao-de-bens.docx` continua fora do Git.

## Checkpoint C46 — auditoria real ampliada e bateria pós-deploy — 11/09/2026

- O commit `699461e` foi publicado em `origin/rotta-custom-v1` e implantado no ambiente live. A alteração cobre contagens de etiquetas por conversas ativas distintas, contagem de etapas ativas do Follow-up e estados visuais explícitos do compositor.
- Regressão local: suíte Vitest focalizada `22/22`; ESLint focalizado sem erros (somente 14 warnings preexistentes no componente grande de Follow-up); build Vite direto concluído com 5.079 módulos; manifesto verificado com 240 assets; `git diff --check` aprovado. Ruby/RSpec/RuboCop continuam indisponíveis neste Windows por ausência de Ruby/Bundler e não foram declarados como aprovados.
- Teste real de etiqueta e contagem na conversa `#1764` (`Barbeta`): adicionar `Primeiro contato` atualizou o contador em menos de 1 segundo e marcou o chip; a visão Follow-up passou para `Na fila 1` e `Etapas ativas 1`; remover a etiqueta voltou para `Na fila 0`, `Etapas ativas 0` e nenhuma conversa. O estado final ficou sem etiqueta de teste.
- O detalhe de Follow-up exibiu os controles `Disparar agora`, adiantar, atrasar, cancelar e remover etiqueta, além do próximo estágio `Segundo contato`. A tentativa automatizada de duplo clique não abriu a conversa; o cartão apenas expandiu. Isso fica registrado como limitação do controle CUA, não como aprovação de latência do duplo clique.
- O filtro real `ORÇAMENTOS`/`kelvin` passou a mostrar a visão vazia correta em vez de contador órfão. O Follow-up vazio mostrou `Na fila 0`, `Prontos agora 0`, `Etapas ativas 0` e nenhuma conversa. A lista inicial foi carregada sem scroll; a garantia estrutural dos 50 primeiros continua coberta pelo `perPage: 50` do prefetch e pelos testes anteriores.
- O histórico público da conversa `#1764` continuou presente antes e depois de reload, com mensagens de datas diferentes. A visão `Arquivados` abriu uma conversa arquivada e exibiu `Reabrir`; nenhum estado foi alterado nesta verificação.
- O workflow ativo `Rotta Chatwoot — Pergunte para IA v1` está ativo com `deepseek/deepseek-v4-flash-0731`, contexto de 50 mensagens e Redis de 70 dias (`6.048.000` segundos). Três execuções reais de webhook (`580911`, `580920`, `580933`) terminaram `success`. As perguntas de cidade, ajudantes e CPF retornaram somente evidências do histórico da conversa; a resposta de CPF declarou corretamente que não constava.
- Visibilidade: o painel `Pergunte para IA` permaneceu interno, com histórico de perguntas e respostas para o agente; não foi inserida resposta no histórico público nem enviada mensagem ao cliente/WhatsApp. A sessão live estava autenticada como `Kelvin`, não `Caio`; portanto a validação específica do login Caio permanece pendente.
- Ações que ficaram confirmadas ou disponíveis na interface: responder publicamente, mensagem privada, Copiloto interno, buscar/filtrar conversas, etiquetas e seus contadores, abrir perfil, histórico e conversas anteriores, resolver/reabrir, pendente/adiar, bloquear contato, enviar transcrição, macros/respostas prontas, participantes, notas, anexos e ações de mensagem. No Follow-up: filtrar por etapa, abrir detalhes, disparar, adiantar, atrasar, cancelar e remover etiqueta. Pela IA: adicionar/remover etiqueta, enviar mensagem pública, criar nota privada e alterar status; somente consulta e etiquetas não externas foram acionadas nesta bateria, para não produzir efeitos fora do teste.
- Incidente de teste: uma primeira tentativa de automação colocou por engano uma pergunta no compositor público. O envio falhou, ficou marcado `Falha ao enviar` e não chegou ao WhatsApp; o botão de tentar novamente não foi acionado. O usuário `Kelvin` não expôs a opção de excluir essa mensagem, então o registro falho permanece para remoção por um agente com permissão de exclusão. Nenhuma mensagem pública adicional foi enviada.
- Console final do navegador: zero erros. O workflow de Follow-up, o arquivo `.audit-antonio/relacao-de-bens.docx` e dados funcionais fora do escopo permaneceram inalterados. Este checkpoint é uma auditoria concluída com as ressalvas acima, não uma declaração de cobertura absoluta de todos os logins, navegadores e cenários externos.

## Checkpoint C47 — auditoria live pós-deploy, compositor e sincronização de etiquetas — 11/09/2026

- A causa raiz do clique sem efeito foi confirmada em `ReplyTopPanel.vue`: `setReplyMode` emitia o evento, mas não era retornado pelo `setup()` para o template. O teste novo reproduziu o vermelho com a propriedade ausente e passou após a correção. O commit `4dca45d` foi publicado em `origin/rotta-custom-v1`.
- Regressão local: `ReplyBox.spec.js` 93/93, `ReplyTopPanel.spec.js` 1/1, `EditorModeToggle.spec.js` 2/2, contadores de etiquetas 5/5 e prefetch de 50 conversas 1/1 — total focalizado 102/102; ESLint dos arquivos alterados passou. Build Vite com 5.079 módulos e manifesto com 240 assets passou.
- A primeira publicação do bundle expôs um asset dinâmico ausente (`commandbar-DZktXTSw.js`) no console. O asset foi incluído, junto com os demais 11 chunks referenciados que faltavam no commit, em `5b2bdbe`; o manifesto e os 12 chunks novos foram publicados no GitHub e o segundo deploy terminou `Success` às 19:10:49 UTC. O asset problemático respondeu HTTP 200 (96.940 bytes) após o segundo deploy; o único erro observado permaneceu o registro antigo de 19:08:02 UTC, anterior à correção.
- Deploys live confirmados no Easypanel: `4dca45d` terminou `Success` às 19:07:13 UTC e `5b2bdbe` terminou `Success` às 19:10:49 UTC. Após a estabilização transitória do proxy, o Chatwoot carregou `dashboard-DN79W1dV.js`.
- Matriz visual real na conversa `#1764`: `Responder -> {reply:true,note:false,ai:false}`, `Mensagem Privada -> {reply:false,note:true,ai:false}`, `Pergunte para IA -> {reply:false,note:false,ai:true}` e retorno a `Responder` passaram ao vivo. O compositor privado mostrou “A mensagem será visível apenas para agentes”. Nenhuma mensagem pública ou WhatsApp foi enviada.
- Consulta interna real no modo IA: a pergunta sobre o destino da conversa `#1764` retornou `Rio de Janeiro, RJ`, dado existente no histórico. A resposta apareceu no painel lateral interno e não entrou na timeline pública. O painel retorna a `Comece a usar o Copiloto` após navegação/reabertura; a memória do workflow permanece separada e o histórico visual do painel não deve ser declarado persistente universalmente.
- Etiqueta real `Segundo contato` na #1764: adicionar levou aproximadamente 1,85 s, o filtro `/label/segundo-contato` mostrou exatamente `#1764`/`~Barbeta` e o histórico carregou sem estado vazio falso. O Follow-up passou para `Na fila 2`/`Etapas ativas 2`; remover levou aproximadamente 4,55 s e voltou para `Na fila 1`/`Etapas ativas 1`, com `Segundo contato 0` e Barbeta ausente. A etiqueta de teste não ficou aplicada.
- Duplo clique real no Follow-up: o cartão de `Deia🌻` abriu a conversa `#892` em aproximadamente 3.169 ms; o histórico exibiu mensagens de 16/08 até hoje. A aba foi devolvida à conversa #1764.
- Limitações mantidas: a sessão live está autenticada como `Kelvin`, não como `Caio`; a visibilidade/permissões específicas do login Caio não foram revalidadas. O teste não usou WhatsApp Web, não enviou mensagem pública e não acionou mutações externas pela IA. O `.audit-antonio/relacao-de-bens.docx` permaneceu fora do Git.
- Capacidades verificadas/disponíveis: responder público, mensagem privada, Copiloto interno, buscar/filtrar, etiquetas e contadores, perfil, histórico/conversas anteriores, resolver/reabrir, pendente/adiar, bloquear, enviar transcrição, macros/respostas prontas, participantes, notas, anexos e ações de mensagem; no Follow-up, filtrar por etapa, abrir detalhes, disparar, adiantar, atrasar, cancelar e remover etiqueta; pela IA, adicionar/remover etiqueta, enviar mensagem pública, nota privada e alterar status. Ações externas pela IA continuam não disparadas nesta auditoria.

## Checkpoint C48 — auditoria de aceite, contenção da IA e ações reversíveis — 11/09/2026

- O teste foi repetido em uma navegação nova da conversa `#1764` (`~Barbeta`) e confirmou o bundle publicado `dashboard-DN79W1dV.js`, com conexão ao Chatwoot ativa. A matriz dos controles passou novamente sem erro funcional: `Mensagem Privada` ativou apenas a nota, `Responder` ativou apenas a resposta pública e `Pergunte para IA` ativou apenas o Copiloto.
- No modo privado, o compositor exibiu “A mensagem será visível apenas para agentes”. No modo IA, duas perguntas internas foram respondidas no painel lateral: a cidade existente foi `Rio de Janeiro, RJ`; para o número de pedido/protocolo ausente, a resposta foi `Não informado no histórico`. Nenhuma das duas consultas apareceu na timeline pública nem foi enviada ao WhatsApp.
- A contenção factual passou no cenário presente e no cenário ausente, mas a apresentação ainda acrescenta ocasionalmente o prefixo “Capitão” antes da resposta. Isso é um refinamento de formato, não uma evidência de mistura com outra conversa; o conteúdo retornado permaneceu compatível com o histórico da #1764.
- Ações reversíveis reais passaram: `Resolver` mudou o botão para `Reabrir`; `Reabrir` voltou ao aberto; `Deixar pendente` mudou o botão para `Abrir`; `Abrir` retornou ao aberto. Os quatro eventos ficaram registrados no histórico pela conta autenticada como Kelvin.
- O menu `Adiar` abriu as opções “Até a próxima resposta”, “Até daqui a uma hora”, “Até amanhã”, “Até a próxima semana”, “Até o próximo mês” e “Personalizar”; o menu foi fechado sem aplicar adiamento. O menu avançado expôs “Bloquear Contato” e “Enviar Transcrição”; ambos não foram executados por causarem efeito externo.
- O painel de contato abriu sem alteração e mostrou perfil da mudança, campos operacionais, histórico de atividade, mídia/anexos e telefone. A timeline pública carregou mensagens de 01/09, 09/09, 10/09 e hoje, sem exigir rolagem para trazer o histórico antigo. A lista de conversas apareceu preenchida no carregamento; a garantia estrutural de 50 itens segue coberta pelo prefetch `perPage: 50` e pelos testes locais.
- A bateria de etiquetas anterior foi ampliada para uma sequência de três etiquetas reais (`Primeiro contato`, `Segundo contato`, `Terceiro contato`): cada adição criou o chip, o filtro exibiu exatamente `#1764`/`~Barbeta`, e cada remoção removeu o chip. Ao final, o Follow-up voltou ao baseline: `Na fila 1`, `Etapas ativas 1`, `Primeiro contato 1` (Deia🌻), `Segundo contato 0`, `Terceiro contato 0`, sem Barbeta residual.
- Tempos observados: add de etiqueta incluindo reload/filtro entre 20,68 s e 21,67 s; remoção entre 4,88 s e 4,93 s; consulta IA aguardou 12 s para resposta. O duplo clique do cartão de Follow-up previamente abriu uma conversa em ~3,17 s; o histórico foi carregado até hoje.
- Estado e escopo: a conversa terminou aberta, sem etiqueta de teste; não houve envio público, WhatsApp Web, bloqueio, transcrição ou alteração persistente de Follow-up. A sessão continua autenticada como Kelvin, então a visibilidade/permissões específicas do login Caio ainda exigem uma sessão real de Caio. O painel visual do Copiloto volta a “Comece a usar o Copiloto” após navegação/reabertura, embora as consultas sejam internas e a memória do workflow seja separada.

## Checkpoint C49 — revalidação de estado atual e regressão final — 11/09/2026

- Estado live reaberto diretamente em `#1764`: o bundle publicado continuou sendo `dashboard-DN79W1dV.js`, o histórico exibiu datas de 01/09, 09/09, 10/09 e hoje, e os logs do navegador retornaram zero erros novos.
- Auditoria dos filtros atuais: `ORÇAMENTOS`/`#kelvin` mostrou “Não há conversas ativas neste grupo”; `Caio Atenção` mostrou exatamente uma conversa real (`~Bruna`, com chip `caio-atencao`); `Clientes Fechados` mostrou vazio; Arquivados carregou duas conversas reais e o texto `arquivado`. Não foi encontrado contador órfão nesses grupos.
- Follow-up atual: `Na fila 1`, `Prontos agora 0`, `Etapas ativas 1`; Primeiro contato contém somente `Deia🌻`, enquanto Segundo, Terceiro e Quarto contato exibem “Sem clientes nesta etapa”.
- O código publicado foi revalidado com matriz de atributos `data-active`/`aria-pressed`; o estado inicial e as alternâncias continuam exclusivas. A mensagem privada continua condicionando `isPrivate` e o payload enviado pelo `ReplyBox` usa `private: this.isPrivate`; não foi necessário enviar uma nota de teste para não poluir a conversa real.
- Regressão local: a configuração padrão do Vitest encontrou a junction de dependências apontando para `work/chatwoot-source` e falhou antes da coleta ao resolver `fake-indexeddb/auto/index.mjs`. Com uma configuração temporária equivalente, omitindo somente essa entrada redundante de setup, passaram ReplyBox 93/93, ReplyTopPanel 1/1, EditorModeToggle 2/2, sidebarLabelCounts 5/5 e rottaPrefetch 1/1 — total 102/102. ESLint dos arquivos alterados e `git diff --check` passaram. A configuração temporária foi removida e não entrou no Git.
- Não houve mudança funcional nesta rodada: nenhum teste criou/removou dados persistentes, não houve mensagem pública, WhatsApp Web, bloqueio, transcrição ou etiqueta de teste. O arquivo `.audit-antonio/relacao-de-bens.docx` permaneceu fora do Git. A sessão live continua como Kelvin, portanto a verificação específica do login Caio continua sendo a única validação de acesso não realizada.

## Checkpoint C50 — verificação de agentes — 11/09/2026

- A área de configurações confirmou `2 agentes`: `Caio Mazine` (`caio.mazine@outlook.com`) e `Kelvin` (`rottabrasilexpress@gmail.com`), ambos exibidos como `Administrador Verificado`.
- Isso confirma que o agente Caio existe na conta e possui perfil administrativo, mas não substitui o teste de login/sessão como Caio. A auditoria live foi restaurada para a conversa `#1764`, sem alterações na lista de agentes.

## Checkpoint C51 — prova específica da etiqueta ORÇAMENTOS/Kelvin — 11/09/2026

- Baseline real na conversa `#1764`: `Kelvin` não selecionada e o sidebar mostrava `ORÇAMENTOS` sem contador; o Follow-up estava em `Na fila 1` e `Etapas ativas 1`.
- Adição temporária de `Kelvin`: o chip apareceu, o sidebar mudou imediatamente para `ORÇAMENTOS 1`, o menu mostrou `Kelvin 1` e o filtro `/label/kelvin` carregou somente `~Barbeta`, com `Todas as conversas carregadas 🎉`.
- Remoção temporária: o chip desapareceu, `ORÇAMENTOS` voltou sem contador e o menu voltou a `Kelvin 0`. O Follow-up retornou ao baseline (`Na fila 1`, `Etapas ativas 1`, somente Deia🌻); `Barbeta` não apareceu no Follow-up.
- O teste foi totalmente revertido, sem mensagem, sem WhatsApp e sem etiqueta persistente. Essa rodada fecha a prova do caminho exato que originava os números fantasmas.
