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
