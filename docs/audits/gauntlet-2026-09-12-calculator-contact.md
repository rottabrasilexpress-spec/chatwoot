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

- Cartão conhecido com área mínima de `min-h-16` e `min-w-[20rem]`.
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
