# Auditoria Gauntlet — cartão de contato e Calculadora Rotta

Data: 2026-09-12

## Contrato

- O cartão de um contato WhatsApp conhecido deve ser grande, mostrar nome/número e oferecer ação interna para abrir a conversa existente.
- Número desconhecido continua como opção WhatsApp sem criar contato ou enviar mensagem.
- A Calculadora deve aparecer como item independente da barra lateral, ficar privada para o primeiro agente e permitir compartilhamento explícito.
- A interface deve deixar preparados leitura, frete, serviços, inventário/cubagem, rota/mapa, proposta e cópia, sem inventar dados de IA, Maps, preço ou motoristas.

## Evidência de reprodução antes da correção

- No Chatwoot real, ao buscar `11965927865`, o contato Kelvin era exibido em um botão de aproximadamente `405 x 30` px, sem ação para abrir a conversa.
- O vídeo `20260912-1811-26.9171207.mp4` foi revisado e transcrito; ele confirma o problema do cartão, a necessidade de navegação interna e a nova estrutura visual da calculadora baseada apenas como referência no EasyMove.

## Implementação auditada

- Cartão conhecido com área mínima de `min-h-24` e `min-w-[26rem]`, ação dedicada de `w-40` e texto de nome/telefone sem truncamento.
- Ação `Abrir conversa` consulta a conversa mais recente do contato e navega para `/app/accounts/:accountId/conversations/:id`; não usa `wa.me` nem abre WhatsApp externo.
- Número desconhecido mantém o fluxo WhatsApp já existente.
- Calculadora em `/app/accounts/:accountId/calculator`, fora do conjunto de rotas de configurações, com item independente na barra lateral.
- Calculadora com central de leitura, campos de cliente/data/origem/destino, serviços, inventário/cubagem, prévia de rota, métricas pendentes, abas de proposta/inventário, cópia e placeholders explícitos para IA/Google Maps/preço.
- Visibilidade privada por padrão, com compartilhamento controlado pelo agente proprietário.

## Verificações

- Testes focados: 5 arquivos, 48/48 aprovados.
- Lint dos arquivos alterados: 0 erros; apenas 5 avisos preexistentes de chaves i18n dinâmicas.
- Build Vite: aprovado, 5.089 módulos transformados.
- Manifest: 240 assets verificados.
- Suíte completa: 4.344/4.377 testes aprovados; 33 falhas não relacionadas, concentradas em timezone/locale e expectativas preexistentes de macros, auditoria, datas, disponibilidade, métricas e atalhos.

## Lacunas intencionais

As integrações reais de IA, Google Maps, motor de preço e envio direto ao WhatsApp ainda não foram ativadas nesta etapa. A interface sinaliza esses estados como pendentes e não apresenta números externos simulados.

## Segunda rodada — correção do bundle e validação live

- A primeira implantação do commit `d33088743` revelou tela branca: o HTML referenciava `dashboard-V7xDVE8I.js`, mas o asset retornava `404` porque `public/vite` é ignorado e os bundles novos não estavam no commit.
- O hotfix `6f10c5dc8` adicionou os 31 bundles realmente ausentes do manifesto, foi publicado nas branches `codex/rotta-objective-20260911` e `rotta-custom-v1` e recebeu deploy com sucesso no Easypanel.
- Após o hotfix: `/api`, `dashboard-V7xDVE8I.js` e `dashboard-Ci3QOPok.css` responderam HTTP `200`; o Chatwoot carregou sem erros de console.
- Teste live conhecido: `11965927865` exibiu cartão ampliado de Kelvin com ação `Abrir conversa`; o clique navegou internamente para `/app/accounts/1/conversations/2143`, sem URL externa.
- Teste live desconhecido: `11965927866` exibiu somente `WhatsApp (11965927866)`, sem cartão de conversa; o fluxo foi descartado sem criação ou envio.
- Calculadora live: barra lateral mostrou `Calculadora` fora de `Configurações`; rota `/app/accounts/1/calculator` abriu com leitura, limpar/calcular, frete, serviços, inventário/cubagem, placeholders de IA/Maps e privacidade `Privada`.
- Cálculo local de auditoria: dois itens produziram `2.160 m³`; proposta e inventário foram copiados para o clipboard com sucesso. Preço/distância/tempo/pedágios permaneceram `Aguardando`, sem dados falsos.
- Health/deploy final: Chatwoot `4.17.0`, `queue_services: ok`, `data_services: ok`, manifest com 240 assets e console live sem erros.

## Situação para a próxima revisão

O bloqueio P1 de evidência end-to-end da primeira revisão foi coberto nesta rodada. Permanecem como ressalvas: a suíte completa baseline tem 33 falhas não relacionadas de locale/timezone/estado e o teste live de privacidade com uma segunda sessão de agente não foi executado; a interface e os testes unitários confirmam o estado privado por padrão e o compartilhamento explícito.

## Veredito AAA independente

- Revisor independente: aprovado, `96/100`.
- Não foram encontrados defeitos críticos, regressões funcionais ou uso de `wa.me`.
- Ressalvas P2: privacidade entre duas sessões não foi executada; a regra está coberta por código/testes. A suíte completa mantém 33 falhas baseline fora dos arquivos alterados, com totais históricos de `4.344/4.377` e `4.329/4.362` devido a execuções/ambiente distintos. P3: arquivo físico ainda está em `settings/calculator`, embora rota e sidebar sejam independentes.
- Encerramento: contrato funcional aprovado; IA, Maps, preço e WhatsApp real permanecem placeholders explícitos para próxima etapa.

## Terceira rodada — telefone formatado e tamanho visual — 2026-09-12

- Reprodução vermelha criada antes da correção: `ContactSelector.spec.js` falhava ao emitir `11 9 6592-7865` como consulta literal em vez de `11965927865`.
- Correção `70ec6d837`: normalização da consulta telefônica antes da busca, preservando o formato digitado na interface. A regressão passou em `42/42` testes focados.
- Correção visual `9a20f7189`: dropdown exclusivo da nova conversa ampliado, cartão para `min-w-[26rem] min-h-24`, botão `w-40` e nome/telefone sem truncamento. Os testes focados finais passaram em `43/43`; lint ficou com `0` erros e 5 avisos i18n preexistentes.
- Deploy do commit `9a20f7189` terminou com `Success` no EasyPanel. Houve apenas a janela transitória de reinício, encerrada antes da validação.
- Teste live pós-deploy com `11 9 65 92 78 65`: cartão presente, área efetiva `465 x 90 px`, conteúdo completo e `Abrir conversa` visível; clique abriu internamente `#2143`; console sem erros.
- Testes live adicionais: `11965927865` e `11 9 6592-7865` também abriram o cartão/conversa; `11965927866` continuou somente como WhatsApp e foi descartado sem criação/envio.
- Nenhuma mensagem foi enviada, nenhuma etiqueta/conversa foi criada ou alterada. Branches `codex/rotta-objective-20260911` e `rotta-custom-v1` estão no commit `9a20f7189`.

## Quarta rodada — cartão ampliado, privacidade e validação cross-agent — 2026-09-12

- O vídeo `20260912-1941-28.4629223.mp4` foi revisado integralmente e o áudio foi transcrito. O teste confirmado foi `11 9 6 5 9 2 7 8 6 5`; o cartão deveria crescer, abrir a conversa, mover Calculadora para depois de Relatórios e permitir compartilhamento controlado com o Caio.
- O cartão passou a usar dropdown de `40rem` limitado pela viewport, cartão com `min-w-[36rem] min-h-32` e ação `Abrir conversa` de `w-48`. No live final, a busca formatada encontrou Kelvin e a ação abriu internamente `/app/accounts/1/conversations/2143`; nenhuma mensagem foi enviada.
- A ordem live final ficou `Follow-up → Etiquetas → Chamadas → Relatórios → Calculadora → Configurações` na sessão do Caio.
- O fluxo do switch ganhou modal premium antes de persistir: `Liberar a Calculadora para os agentes?` / `Manter a Calculadora privada?`, explicação do efeito, botões de cancelar e confirmação, além de cores distintas para liberar/restringir.
- A bateria encontrou e corrigiu dois bugs reais: o evento do switch estava sendo interpretado invertido; e o endpoint de contas não devolvia as configurações atualizadas. O controlador foi incluído explicitamente no `docker/Dockerfile.overlay`.
- Prova cross-agent: depois de confirmar o compartilhamento no Edge/Caio, a API retornou `rotta_calculator_shared: true` e `rotta_calculator_owner_id: 2`; no Chrome/Kelvin a Calculadora abriu. Depois o estado foi restaurado para privado; a API retornou `false`, o conteúdo ficou bloqueado para Kelvin e o item sumiu da barra lateral após recarga completa, enquanto Caio continuou com acesso.
- Vitest focalizado final: `10/10`; ESLint dos arquivos alterados: `0` erros e `8` avisos de chaves i18n dinâmicas; build Vite: `5.089` módulos; manifesto: `240` assets verificados.
- Commits funcionais publicados nas branches `codex/rotta-objective-20260911` e `rotta-custom-v1`: `fc6c5b245`, `dc6cc1916`, `77739f681`, `fe3de610f`, `80d642bab` e `200c62c22`. Deploy final do EasyPanel concluiu com sucesso.
- Nenhum cliente recebeu mensagem, nenhum contato/conversa/etiqueta foi criado ou removido e o estado final da Calculadora ficou privado, como antes da prova.

## Quinta rodada — propriedade Kelvin e auditoria segura de credenciais — 2026-09-12

- O estado persistido da conta 1 foi confirmado no Rails: `rotta_calculator_shared=false` e `rotta_calculator_owner_id=1` (Kelvin). A sessão do Caio (usuário 2) recebeu a mensagem de acesso restrito e não exibiu a Calculadora; a sessão do proprietário Kelvin havia exibido o formulário normalmente.
- O ambiente do serviço foi conferido após a prova: voltou às 34 variáveis originais e não contém `OPENROUTER_*` nem `GOOGLE_*` adicionadas nesta rodada. Nenhum deploy foi disparado.
- O caminho local informado é uma pasta contendo `rotta-secrets.env.txt`, não um arquivo `.env` diretamente. O modelo desejado foi identificado como `deepseek/deepseek-v4-flash-0731`; a linha da chave de IA está malformada/colada ao modelo e deve ser regenerada antes do uso. As variáveis Google existem no catálogo da Vercel, mas os valores secretos são write-only e não foram copiados. O arquivo local não possui valores válidos para as chaves Google.
- Por segurança, não foram persistidos segredos no código, GitHub ou Obsidian. A integração real de IA/Google Maps ainda não está funcional nesta implantação; o código permanece com placeholders explícitos. Pedágios continuam totalmente desativados e não devem ser calculados.
- Para concluir a integração, é necessário um arquivo corrigido ou o preenchimento direto no EasyPanel com três valores válidos, sempre em linhas separadas: `OPENROUTER_API_KEY`, `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` e `GOOGLE_ROUTES_API_KEY`. Depois disso: cadastrar no serviço, validar sem expor valores, implantar e testar a calculadora ponta a ponta. O modelo ficará fixo em `deepseek/deepseek-v4-flash-0731`.
