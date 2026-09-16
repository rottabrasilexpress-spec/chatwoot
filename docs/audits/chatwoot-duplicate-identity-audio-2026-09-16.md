# Auditoria Chatwoot — duplicidade, identidade e áudio

Data: 16/09/2026  
Branch: `rotta-custom-v1`  
Commit funcional: `50484c0f04be6cbfdb8a9abe943127707800bcd4`

## Escopo

Foram auditados somente os três sintomas reportados: mensagens duplicadas, nome Kelvin/Caio aparecendo no envio/ecos UAZAPI e áudio enviado que reproduzia no WhatsApp Web, mas não no Chatwoot.

## Diagnóstico reproduzido

O baseline frontend passou `154` testes e falhou em `3` cenários:

1. A action Vuex de envio resolvia antes de terminar o dispatch real.
2. Duas submissões rápidas podiam iniciar dois envios antes do primeiro terminar.
3. O player de áudio alterava o estado para “tocando” antes de `play()` resolver; uma rejeição deixava a interface enganosa.

Na leitura ampliada do webhook, a hipótese inicial de processamento duplo pelo lock foi descartada: `with_uazapi_provider_lock` executa o bloco uma única vez. Essa parte não foi alterada.

As causas confirmadas no backend foram a corrida em que o eco chegava antes de o `source_id` ser persistido e a falta de mesclagem dos atributos de identidade externa no ramo de mensagem já existente.

## Correções

- `app/javascript/dashboard/store/modules/conversations/actions.js`: retorna a Promise do dispatch de envio.
- `ReplyBox.vue`: bloqueia reenvio enquanto há operação pendente, desabilita o compositor durante o envio e mantém envio múltiplo somente quando o payload foi deliberadamente dividido.
- `app/services/messages/send_on_api_service.rb`: marca o eco pendente antes do POST, grava `uazapi_track_id`, persiste o ID do provedor e remove o marcador tanto no sucesso quanto na falha.
- `app/controllers/webhooks/uazapi_controller.rb`: correlaciona por `track_id` e, em corrida curta, por conversa + conteúdo exato + mensagem pendente dos últimos cinco minutos; mescla a identidade externa da empresa e remove o marcador pendente após a confirmação.
- `Audio.vue`: usa a URL disponível de forma segura, aguarda o sucesso de `play()`, trata rejeição/erro e não deixa o estado “tocando” falso.

O transporte UAZAPI já enviava o texto da empresa sem concatenar o nome Kelvin/Caio. A correção do eco preserva a identidade externa da Rotta no registro recebido pelo Chatwoot. A identificação interna do agente pode continuar existindo para auditoria operacional, mas não é enviada como texto ao cliente.

## Verificações

- Antes: `3` falhas, `154` aprovações.
- Depois: Vitest focalizado em `3` arquivos, `157/157` aprovados.
- Build: Vite concluiu com `5.100` módulos transformados.
- Assets: `verify:manifest-assets` confirmou `240` arquivos.
- Qualidade: `git diff --check` aprovado.
- Live: conversa Chatwoot `48` carregou `2` controles de áudio; após o clique, o primeiro virou `Pausar áudio` e avançou para aproximadamente `00:01 / 00:03`; console sem `error`/`warn`.
- Saúde: após o período de subida, `GET /health` retornou HTTP `200` e `{"status":"woot"}`.
- Deploy EasyPanel: `Success` em `16/09/2026 15:18:50 GMT`, commit `50484c0f`.

## Limitações e segurança

O RSpec backend não foi executável no console Rails da imagem de produção: `bundler: command not found: rspec`; o host Windows também não possui Ruby/Bundler. Isso fica registrado como limitação, não como aprovação falsa. A confirmação backend foi feita por inspeção do fluxo, testes frontend, build, healthcheck e teste live do player.

Não foi enviada mensagem real para cliente e não foram alterados conversa, etiqueta, Follow-up, credencial ou status.

## Links conectados

- [GitHub branch `rotta-custom-v1`](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1)
- [Commit `50484c0f`](https://github.com/rottabrasilexpress-spec/chatwoot/commit/50484c0f04be6cbfdb8a9abe943127707800bcd4)
- [EasyPanel deployments](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments)
- [Chatwoot conversa 48](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/conversations/48)
- Obsidian: `00 - Contexto e estado.md`
