# Auditoria — nome do agente em mensagens WhatsApp/UAZAPI — 15/09/2026

## Objetivo

Garantir que mensagens enviadas pelas caixas API/UAZAPI não incluam automaticamente o nome do agente Kelvin ou Caio no texto recebido pelo cliente. O comportamento padrão deve ser equivalente ao WhatsApp Web: a mensagem sai somente com o conteúdo da empresa.

## Diagnóstico

- O Chatwoot associa a mensagem manual ao usuário que enviou (`sender`), por isso o nome do agente pode aparecer como identificação interna da bolha no painel.
- O adaptador `Messages::SendOnApiService` enviava `message.outgoing_content` no campo `text`; não havia prefixo de agente no payload UAZAPI.
- O eco recebido pelo webhook UAZAPI grava mensagens de saída com `sender: nil`, sem adicionar nome ao conteúdo.
- Portanto, o nome observado no histórico do Chatwoot não prova que o cliente o recebeu. O payload externo foi mantido limpo por padrão.

## Implementação

- Nova opção por caixa API: `rotta_include_agent_name_in_whatsapp`.
- A opção aparece em Configurações da caixa de entrada, desligada por padrão.
- Desligada: o texto enviado é exatamente a mensagem digitada/renderizada, sem Kelvin/Caio.
- Ligada manualmente: o texto enviado fica no formato `Nome do agente: mensagem`.
- A regra é aplicada tanto a texto quanto à legenda de áudio enviada pelo adaptador UAZAPI.
- A configuração é persistida em `channel_api.additional_attributes`, sem migration e sem alterar mensagens existentes, histórico, etiquetas, follow-up ou credenciais.

## Validação

- `corepack pnpm exec eslint app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue`: aprovado.
- Prettier nos arquivos Vue/JSON alterados: aprovado.
- `corepack pnpm exec vite build`: aprovado; 5.101 módulos transformados.
- `corepack pnpm run verify:manifest-assets`: aprovado; 232 referências do manifesto verificadas.
- Foi adicionado spec RSpec para o caminho UAZAPI, cobrindo o padrão sem nome e o opt-in com nome.
- O RSpec não foi executado nesta estação porque Ruby/Bundler não estão instalados localmente; deve ser executado no container Rails durante o deploy.
- Nenhuma mensagem real foi enviada nesta auditoria; a validação externa ficou limitada à leitura do Chatwoot e aos testes locais do payload.

## Segurança e compatibilidade

- A ausência da chave é interpretada como `false`, mantendo o padrão seguro para caixas existentes.
- O restante de `additional_attributes` é preservado ao salvar a configuração.
- A configuração não afeta e-mail, WhatsApp Cloud, histórico ou mensagens já entregues.

## Publicação e estado live

- Commit publicado na branch `rotta-custom-v1`: `06ea9d38` (`fix(whatsapp): make agent name opt-in`).
- O GitHub confirma o commit no remoto. O Chatwoot público continua respondendo `/health` e login com HTTP `200`.
- Até a última verificação, o HTML público ainda referenciava o bundle anterior e nenhum bundle servido continha a chave `rotta_include_agent_name_in_whatsapp`. Portanto, o rollout no EasyPanel ainda não foi confirmado; a implementação está pronta no GitHub, mas não deve ser considerada ativa em produção até o painel concluir o deploy.
- A checagem RSpec continua pendente no container Rails porque Ruby/Bundler não estão instalados nesta estação.

## Verificação live e correção de tradução — 15/09/2026

- A caixa única `WhatsApp Rotta` está cadastrada como Canal da API e é compartilhada por Kelvin e Caio; a preferência vale para os dois, não é individual por agente.
- A opção de incluir nome foi localizada na tela de configurações da caixa e estava desligada (`0`). O backend interpreta chave ausente como falso, e o spec do adaptador verifica o texto da empresa por padrão e o prefixo apenas no opt-in.
- Nenhuma configuração foi salva e nenhuma mensagem foi enviada durante esta verificação.
- Defeito visual encontrado: o Chatwoot renderizava as chaves `INBOX_MGMT.SETTINGS_POPUP...` em vez do rótulo e da explicação. A primeira correção foi aplicada no locale genérico `pt`, mas a sessão ativa usa `pt_BR`; nesse arquivo as duas chaves estavam no bloco `INBOX_MGMT.EDIT`, enquanto a tela consulta `INBOX_MGMT.SETTINGS_POPUP`.
- Correção refinada: as chaves foram movidas para `INBOX_MGMT.SETTINGS_POPUP` em `pt_BR`; o locale `pt` mantém a tradução no mesmo caminho. Uma asserção local confirmou ambos os caminhos. Prettier passou, o build Vite transformou 5.101 módulos e `verify:manifest-assets` confirmou 240 referências. O novo bundle `DashboardIcon-nI8fSl3G.js` contém as traduções. O RSpec do adaptador não foi executado localmente porque Ruby/Bundler não estão instalados.
- Esta correção regional ainda precisa ser publicada e verificada visualmente na interface. O valor live permanece desligado; não foi alterado o estado persistido do canal e nenhuma mensagem real foi enviada.
