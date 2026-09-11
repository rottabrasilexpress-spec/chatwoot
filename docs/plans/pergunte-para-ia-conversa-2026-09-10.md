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
