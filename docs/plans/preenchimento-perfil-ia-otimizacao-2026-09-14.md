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
- O cliente OpenRouter mantém 40 segundos para os fluxos existentes e aceita 50 segundos apenas no preenchimento do perfil.
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
porque a chamada DeepSeek permaneceu aberta por 45 s. A próxima correção evita
chamar a LLM quando a própria conversa já contém um orçamento estruturado com os
campos operacionais essenciais, incluindo ajudantes de origem e destino. Para
conversas que realmente precisarem da LLM, o timeout fica abaixo do limite Rack,
evitando `Rack::Timeout::RequestTimeoutException` e retornando erro controlado.

1. Abrir a conversa `#2085` e acionar `Preencher com IA`.
2. Confirmar `200`, campos preenchidos e persistência no contato.
3. Repetir a ação e verificar que o fluxo segue responsivo e não envia anexos/áudios no contexto.
4. Confirmar nos logs somente as métricas redigidas e, em caso de lentidão, resposta `504` em vez de `500` genérico.
