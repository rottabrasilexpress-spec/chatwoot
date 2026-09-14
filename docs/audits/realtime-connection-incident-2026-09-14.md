# Auditoria de incidente realtime — Chatwoot Rotta — 2026-09-14

## Sintoma

Durante a inspeção do Chatwoot, a interface exibiu `Reconectando...` e `Desconectado`. A lista de conversas ficou em `Carregando conversas` e o painel da conversa não aparecia.

## Verificações realizadas

- `GET /app/login`: HTTP 200.
- `GET /cable` sem upgrade WebSocket: HTTP 404, esperado para uma requisição HTTP comum nessa rota.
- Upgrade WebSocket para `/cable`: HTTP 101, seguido de mensagens `welcome` e `ping`.
- A aba do Chatwoot foi recarregada; a lista e a conversa voltaram a carregar normalmente.
- Após a recuperação, o estado `Desconectado` não estava mais presente na interface.

## Diagnóstico

Não houve evidência de indisponibilidade do servidor ou de falha do proxy WebSocket. O incidente foi uma conexão ActionCable presa no navegador, provavelmente durante uma reinicialização/publicação do serviço ou uma interrupção transitória da sessão.

## Impacto e ação

- A recuperação exigiu apenas recarregar a aba afetada.
- Nenhuma mensagem, etiqueta, Follow-up, conversa, contato, configuração ou dado de cliente foi alterado.
- Nenhuma alteração de código foi necessária nesta rodada.

## Critério de acompanhamento

Se o sintoma voltar fora de uma publicação/reinicialização, deve-se coletar o horário, o navegador e os logs do proxy/ActionCable para avaliar um fallback de reconexão no frontend. O endpoint WebSocket deve continuar aceitando `101 Switching Protocols`.
