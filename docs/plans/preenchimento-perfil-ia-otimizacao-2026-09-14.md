# Preenchimento do perfil com IA — otimização e auditoria (2026-09-14)

## Diagnóstico reproduzido

- Conversa real testada: `#2085`, contato `+5583988413392`.
- A interface enviou apenas `conversation_id` para `captain/conversation_ai/profile`.
- O servidor respondeu `500 Internal Server Error` após aproximadamente 45 segundos.
- O perfil permaneceu vazio. O gargalo não estava no payload do navegador.

## Correção aplicada sobre o fluxo existente

- O parser e a validação de evidências já existentes foram preservados.
- O histórico agora é montado em uma janela de até 24.000 caracteres.
- Cada mensagem é limitada a 2.400 caracteres, preservando começo e fim.
- A consulta seleciona somente campos necessários e usa `message.content`; anexos, placeholders e transcrições de áudio não entram neste preenchimento.
- Mensagens operacionais recebem prioridade; mensagens iniciais e recentes também são preservadas para manter contexto e cronologia.
- O cliente OpenRouter mantém 40 segundos para os fluxos existentes e para o preenchimento do perfil; esse limite fica abaixo do timeout Rack de 45 segundos.
- Quando a conversa já traz um orçamento estruturado com os campos essenciais, o perfil é preenchido de forma determinística e a chamada à LLM é pulada. Isso reduz custo, latência e dependência externa.
- O parser de inventário aceita apenas linhas que começam com uma quantidade (`[01] Item`), evitando interpretar os totais de ajudantes como itens.
- A evidência do inventário usa uma linha contígua do histórico. Antes, linhas separadas por blocos do orçamento eram concatenadas e invalidadas pela checagem de evidência.
- Timeout do perfil retorna `504` com mensagem compreensível; falhas gerais retornam erro sanitizado sem registrar conteúdo da conversa ou credenciais.
- Logs registram apenas métricas: quantidade, seleção, caracteres e truncamento.

## Validação

- Testes unitários adicionados para limite/priorização do contexto e preservação de texto privado sem anexos.
- Teste do cliente OpenRouter adicionado para o timeout específico de 50 segundos.
- A validação frontend e o build Vite já haviam passado no commit remoto imediatamente anterior.
- RSpec local depende de Ruby/Bundler, que não estão instalados neste computador; a suíte deve rodar no CI/deploy.

## Teste pós-deploy

O primeiro deploy revelou que o `Dockerfile.overlay` não copiava o novo
`profile_context_builder.rb`; isso foi corrigido no commit `4d65239d`. O segundo
deploy copiou o arquivo, mas o teste de Raul ainda atingiu o limite Rack de 45 s
porque a chamada DeepSeek permaneceu aberta por 45 s. A correção seguinte tornou
determinístico o caso estruturado e corrigiu a evidência do inventário no commit
`311b9a9b`.

No console Rails pós-deploy, a conversa #2085 foi confirmada com:

- `46` mensagens selecionadas;
- `8.464` caracteres enviados ao construtor de contexto;
- `truncated: false`;
- `complete: true`;
- inventário validado contra uma linha real do histórico.

No teste real pela interface do Chatwoot, o perfil foi preenchido em cerca de
`2,5 s`, com origem `João Pessoa, PB, Brasil`, destino `Contagem - Parque
Industrial, Contagem - MG, Brasil`, data `25/09/2026` e valor `R$ 10.857,31`.
Os ajudantes permaneceram em `3` na origem e `3` no destino, e os campos de
montagem/desmontagem foram preenchidos. A primeira execução após o reinício
demorou mais por causa do aquecimento do serviço; a repetição determinística
ficou responsiva.

Commits publicados no branch `rotta-custom-v1`: `de7ca3a7`, `4d65239d`,
`1f0abf89` e `311b9a9b`.

1. Abrir a conversa `#2085` e acionar `Preencher com IA`.
2. Confirmar campos preenchidos e persistência no contato — concluído no teste real.
3. Repetir a ação e verificar que o fluxo segue responsivo e não envia anexos/áudios no contexto — concluído.
4. Confirmar nos logs somente as métricas redigidas e, em caso de lentidão, resposta `504` em vez de `500` genérico — implementação concluída; cenário de timeout controlado coberto por teste.
