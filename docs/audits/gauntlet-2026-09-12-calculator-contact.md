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

## Sétima rodada — paridade visual/funcional com o Hub e mapa operacional — 2026-09-12

### Escopo comparado

- Referência visual e funcional: `https://hub-completo-ashen.vercel.app/`.
- Contrato desta rodada: preservar a central de leitura, liberar espaço real para o mapa, separar a tela em duas colunas, manter serviços/quantidades/valores unitários, separar a precificação, disponibilizar proposta de WhatsApp e manter a rota visível após o cálculo.
- O Hub foi usado como referência de layout e comportamento; não foram copiados segredos, dados de clientes ou estado externo.

### Paridade implementada

- Leitura e mapa agora ocupam a mesma tela em colunas, com o mapa operacional no lado direito.
- O painel de mapa carrega o Google Maps de forma assíncrona, exibe a polilinha completa da rota, controles Mapa/Satélite/fullscreen/street view, link para abrir no Google Maps, distância, tempo estimado e pedágios explicitamente desativados.
- Quando a chave de rotas server-side não está disponível, o backend usa fallback OSRM para obter rota e polilinha; isso não ativa pedágios nem inventa valores. A visualização continua sendo Google Maps quando a chave de navegador está configurada.
- Serviços aparecem como cartões coloridos e independentes; inventário/cubagem, quantidades e unidades ficam separados da precificação.
- A precificação apresenta seis cartões comerciais: Econômica, Padrão, Equilibrada, Prioritária, Premium e Rota ruim, com valor e preço por quilômetro.
- As abas Proposta e Inventário permitem revisar/copiar o texto de WhatsApp e a lista estruturada de itens.
- A consulta de IA recebe somente fatos da rota e do cálculo, sem transportar a polilinha gigante para o prompt; isso reduz latência e mantém o contexto controlado.

### Evidência live pós-deploy

- Sessão autenticada do Caio no Chatwoot: `/app/accounts/1/calculator?audit=20260912-final-map`.
- POST real para `/api/v1/accounts/1/calculator/calculate`: HTTP `200` em aproximadamente `14,77 s`, abaixo do limite do proxy observado anteriormente.
- Resultado visual confirmado: `Rota traçada`, `1855,3 km`, `1586 min`, pedágios `Desativados`, polilinha laranja visível entre Palotina/PR e Linhares/ES, controles do Google Maps e botão `Abrir no Google Maps`.
- A mesma resposta exibiu inventário, seis cartões de preço e os dados do frete; as abas de Inventário e Proposta foram abertas durante a auditoria.
- Reprodução direta do serviço Rails no container: `ok=true`, provider `osm-osrm-fallback`, polilinha com `83926` caracteres e serialização UTF-8 válida. Nenhuma mensagem WhatsApp foi enviada e nenhum registro de cliente/conversa/etiqueta foi alterado.

### Otimizações e publicação

- Geocodificação fallback de origem/destino em paralelo.
- Consulta de rota e geração de proposta de IA em paralelo; o modelo permanece `deepseek/deepseek-v4-flash-0731`.
- Carregamento assíncrono do script do Google Maps e espera explícita pela API antes de desenhar a rota.
- Commits funcionais encadeados: `eea4808db`, `1b1114955`, `23c665036`, `a1ba0157e`, `79976efad`, `b9d562c50`, `4e5ce91d1`, `36937d0c2` e `909cf127f`.
- A branch publicada `rotta-custom-v1` e a branch de trabalho apontam para `909cf127f`; o último deploy do EasyPanel terminou com sucesso e o serviço voltou saudável.

### Verificação e limitações honestas

- Vitest focalizado da Calculadora: `7/7` aprovados.
- Build Vite: aprovado, `5091` módulos transformados; manifesto: `240` assets verificados.
- Teste live de rota/mapa: aprovado com HTTP `200` e captura visual do layout.
- ESLint direcionado não foi considerado aprovado neste checkout Windows porque os arquivos existentes usam CRLF e o comando reportou erros de formatação `Delete ␍`; não foi executado `--fix` para não reformatar arquivos fora do escopo.
- RSpec não foi contado como aprovado: Ruby/Bundler não estão disponíveis localmente e a tentativa remota não retornou resultado conclusivo. A prova Rails usada foi a reprodução direta do serviço no container.
- A chave server-side `GOOGLE_ROUTES_API_KEY` não estava presente no ambiente final da última medição; por isso o provider factual foi OSRM fallback. Para forçar Google Routes no backend, basta cadastrar essa variável no EasyPanel sem colocá-la no GitHub/Obsidian.

### Veredito da rodada

- O layout e as funções solicitadas do Hub estão publicados e verificados no Chatwoot live.
- Não há blocker funcional para a solicitação atual. A única melhoria opcional restante é configurar uma chave server-side de Google Routes se a preferência for usar o motor Google no backend, mantendo pedágios desligados.

## Quinta rodada — propriedade Kelvin e auditoria segura de credenciais — 2026-09-12

- O estado persistido da conta 1 foi confirmado no Rails: `rotta_calculator_shared=false` e `rotta_calculator_owner_id=1` (Kelvin). A sessão do Caio (usuário 2) recebeu a mensagem de acesso restrito e não exibiu a Calculadora; a sessão do proprietário Kelvin havia exibido o formulário normalmente.
- O ambiente do serviço foi conferido após a prova: voltou às 34 variáveis originais e não contém `OPENROUTER_*` nem `GOOGLE_*` adicionadas nesta rodada. Nenhum deploy foi disparado.
- O caminho local informado é uma pasta contendo `rotta-secrets.env.txt`, não um arquivo `.env` diretamente. O modelo desejado foi identificado como `deepseek/deepseek-v4-flash-0731`; a linha da chave de IA está malformada/colada ao modelo e deve ser regenerada antes do uso. As variáveis Google existem no catálogo da Vercel, mas os valores secretos são write-only e não foram copiados. O arquivo local não possui valores válidos para as chaves Google.
- Por segurança, não foram persistidos segredos no código, GitHub ou Obsidian. A integração real de IA/Google Maps ainda não está funcional nesta implantação; o código permanece com placeholders explícitos. Pedágios continuam totalmente desativados e não devem ser calculados.
- Para concluir a integração, é necessário um arquivo corrigido ou o preenchimento direto no EasyPanel com três valores válidos, sempre em linhas separadas: `OPENROUTER_API_KEY`, `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` e `GOOGLE_ROUTES_API_KEY`. Depois disso: cadastrar no serviço, validar sem expor valores, implantar e testar a calculadora ponta a ponta. O modelo ficará fixo em `deepseek/deepseek-v4-flash-0731`.

## Sexta rodada — integração real publicada e bateria pós-deploy — 12/09/2026 19:31 BRT

- O ambiente do EasyPanel foi preenchido sem registrar os valores das credenciais em código, GitHub ou Obsidian. Foram usados `OPENROUTER_MODEL=deepseek/deepseek-v4-flash-0731`, a chave existente do OpenRouter e duas chaves Google separadas: Routes restrita ao IP de saída `69.62.95.45` e Maps Browser restrita aos domínios do Chatwoot.
- O primeiro deploy desta rodada mostrou que o `Dockerfile.overlay` não copiava os novos arquivos Rails; isso foi corrigido no commit `1f7cfe6d0`. O teste live seguinte revelou um erro real de Zeitwerk em `errors.rb`; o namespace esperado foi declarado no commit `0a811fb9f`. Ambos foram enviados para `codex/rotta-objective-20260911` e `rotta-custom-v1`.
- O deploy final do commit `0a811fb9f` terminou com `Success` no EasyPanel. O container Rails atualizado carregou todos os serviços `RottaCalculator`.
- Teste real interno pós-deploy, sem WhatsApp e com dados fictícios: `api_status=complete`, `ai_status=complete`, `toll_status=disabled`, `distance_km=92.6`, `duration_minutes=81`, `price=null` por ausência de tabela explícita e `proposal_present=true`. O cálculo consultou rota e IA; nenhum valor de pedágio foi calculado, consultado ou mencionado.
- Validação segura do ambiente Rails: `owner=1`, `shared=false`, modelo exato confirmado, comprimentos das variáveis presentes (`73`, `39`, `39`) e rota `/calculator/calculate=true`. Nenhum segredo foi impresso.
- Validação do proprietário: `User.find(1)` confirmou Kelvin. Na sessão real autenticada do Caio, a rota `/app/accounts/1/calculator` recarregou responsivamente e exibiu o bloqueio “Esta Calculadora está disponível somente para o agente que a criou.”, confirmando a privacidade por padrão.
- Os únicos avisos do teste Rails foram o aviso de compatibilidade futura do RubyLLM e a ausência opcional de `IP_LOOKUP_API_KEY`; não bloquearam o cálculo. RSpec segue não executável localmente porque a imagem/estação não possui o binário `rspec` disponível.
- Resultado desta rodada: integração real de IA/Google Routes publicada e validada; pedágios permanentemente desativados; privacidade Kelvin/Caio confirmada; nenhuma mensagem, etiqueta, conversa ou contato foi criado ou alterado.

## Oitava rodada — vídeo final, paridade Hub, timeout de IA e bateria live — 13/09/2026

- O vídeo `20260913-0158-44.8167241.mp4` foi revisado integralmente: 1m51s, áudio transcrito e quadro visual conferido. Requisitos extraídos: caixa de leitura ampla, divisão em duas colunas, mapa responsivo, fotos de origem/destino, ver rota, GPS, Mapa/Satélite/Relevo, serviços compactos, preço dinâmico e proposta formatada para WhatsApp.
- O Hub `https://hub-completo-ashen.vercel.app/` foi usado como referência visual/funcional. A calculadora publicada recebeu o mesmo agrupamento de leitura + mapa, controles de mapa, modo logístico/exclusivo, cards compactos de serviços, seis faixas comerciais e proposta copiável.
- O primeiro pós-deploy revelou duas falhas reais: chave técnica de tradução aparecendo na tela e timeout de 15 s quando o OpenRouter demorava. A primeira foi corrigida em `a37bc66de`; o fallback externo ganhou limites explícitos em `b3077094f`; a IA passou a degradar com leitura determinística em `7eaf67287`, evitando derrubar rota/proposta com HTTP 500.
- Saúde live após o deploy final: `/health` HTTP 200 (`status=woot`) e `/api` HTTP 200 (`Chatwoot 4.17.0`, filas e dados `ok`).
- Teste real no Chatwoot autenticado como Caio: cálculo Palotina - PR → Linhares - ES concluído; rota `1857.4 km`, tempo `1591 min`, pedágios desativados, provider visual `Fallback de rota`; `FOTO ORIGEM`, `FOTO DESTINO`, `ABRIR GPS`, `Mapa`, `Satélite`, `Relevo` e `VER ROTA` presentes. O mapa em Relevo ficou ativo e a linha da rota apareceu.
- Resultado real: seis cards (`Econômica`, `Padrão`, `Equilibrada`, `Prioritária`, `Premium`, `Rota ruim`), proposta para WhatsApp presente e com `ORÇAMENTO FINAL — ROTTA BRASIL EXPRESS`; nenhum `Internal Server Error` e nenhuma chave `CALCULATOR.INTEGRATIONS...` no corpo visível.
- Responsividade em viewport 390×844: `scrollWidth=390`, sem overflow horizontal; caixa de leitura `274×320 px`; serviços, resultado, cards e proposta continuam acessíveis. Viewport normal restaurado ao final.
- Vitest focalizado: `3` arquivos, `9/9` aprovados. Build Vite: `5092` módulos transformados; manifesto verificado com `240` assets. RSpec do host local não pôde rodar porque Ruby/Bundler não estão instalados; o teste de regressão foi adicionado e a validação determinante foi feita no container live.
- Nenhuma mensagem, etiqueta, conversa, contato, inbox, credencial ou dado do WhatsApp foi criado ou alterado nesta rodada.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [audit ledger](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\audits\gauntlet-2026-09-12-calculator-contact.md) ↔ [pesquisa Hub](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-hub-comparison-20260912.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator).

## Nona rodada — janela segura da IA, regressão de proxy e confirmação final — 13/09/2026

- A primeira tentativa com janela de IA em `14,5 s` confirmou que o modelo podia responder normalmente, mas a repetição mais lenta encostou no limite de `15 s` do proxy e produziu HTTP `500` (`Rack::Timeout::RequestTimeoutException`). Essa regressão foi tratada antes do encerramento.
- Correção final `7bd7179ac`: janela síncrona reduzida para `12,5 s`, timeout do cliente OpenRouter para `12,0 s` e resposta limitada a `700` tokens, mantendo o modelo exato `deepseek/deepseek-v4-flash-0731`. O fallback determinístico permanece explícito e o cartão visual não chama fallback de “IA conectada”.
- O commit foi publicado em `codex/rotta-objective-20260911` e `rotta-custom-v1`; o deploy do EasyPanel concluiu e `/health` voltou a HTTP `200` após a janela normal de reinício.
- Duas repetições live pós-correção no Chatwoot autenticado como Caio retornaram sem `Internal Server Error`, sem chave técnica exposta e com `Integração respondendo`; ambas exibiram rota `1857.4 km`, seis cards, mapa/controles e proposta preenchida no campo `ORÇAMENTO FINAL — ROTTA BRASIL EXPRESS`.
- A visualização continua identificada honestamente como `Fallback de rota` no motor server-side quando aplicável; o Google Maps visual, linha da rota, links de origem/destino/GPS, Mapa/Satélite/Relevo e pedágios desativados permaneceram ativos.
- Teste responsivo repetido em `390×844`: `scrollWidth=390` e caixa de leitura `274×320 px`; o override temporário de viewport foi removido ao final. Vitest focalizado: `9/9`; build Vite: `5092` módulos; manifesto: `240` assets.
- RSpec continua não executável no host local por ausência de Ruby/Bundler. Nenhuma mensagem, etiqueta, conversa, contato, inbox, credencial ou dado de WhatsApp foi criado ou alterado.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [ledger da rodada](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\audits\gauntlet-2026-09-12-calculator-contact.md) ↔ [Hub](https://hub-completo-ashen.vercel.app/) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [deploy EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator).

## Décima rodada — parser real, segurança do catálogo e controles de preço — 13/09/2026

- O deploy `7db04067b` corrigiu uma regressão descoberta no teste live: o fallback fuzzy do catálogo transformava nomes específicos desconhecidos, como `Mesa com 6 cadeiras` e `Televisores 55\"`, em itens genéricos. A regra agora exige correspondência exata/alias ou que o candidato contenha o nome inteiro informado; caso contrário, o item permanece em `Revisar` sem cubagem inventada.
- O bloco real de pré-orçamento foi processado sem alterar WhatsApp/Chatwoot: nove linhas, quantidades entre colchetes, origem/destino, ajudantes de carga/descarga, serviços explicitamente negados e forma de pagamento. O parser confirmou `Cama box casal`, `Sofá 2 lugares` e `Caixas` pelo catálogo; os demais itens sem correspondência segura ficaram em revisão manual. Isso preserva a segurança operacional e evita preço falso.
- O teste live autenticado no Chatwoot/Caio terminou com HTTP `200`, rota `Palotina-PR → Linhares-ES`, `1857,5 km`, `1591 min`, Google Maps visual, linha da rota, controles `Mapa/Satélite/Relevo`, origem/destino/GPS, seis cartões comerciais e pedágios `Desativado`.
- A proposta sem serviços cobrados exibiu uma única linha `Valor do transporte`, sem duplicar Opção 1/Opção 2. O padrão de ajuste iniciou em `R$ 0,25/km`; o botão `+` levou a `R$ 0,50/km`, o botão `−` retornou a `R$ 0,25/km` e, após a conclusão assíncrona, os seis preços retornaram exatamente ao estado inicial. Não houve acúmulo de ajuste.
- A IA respondeu como `Fallback determinístico — IA fora da janela` nesta execução; não foram inventadas estimativas para itens sem dimensões suficientes. O modelo configurado permanece `deepseek/deepseek-v4-flash-0731`; a ausência de estimativa AI não bloqueou rota, inventário seguro, precificação ou proposta.
- Vitest focalizado executado novamente: 4 arquivos e `10/10` testes aprovados. O teste Rails/RSpec continua não executável no host local por ausência de Ruby/Bundler; a resposta live do container foi usada como validação de integração. Não foi feita alteração de bundle nesta rodada, pois o hotfix foi exclusivamente Rails.
- Os bundles publicados no deploy foram verificados anteriormente após a correção de manifesto/asset. O health live permaneceu HTTP `200` (`status=woot`). Nenhuma mensagem WhatsApp, conversa, contato, etiqueta, inbox ou credencial foi criada/alterada.
- Commits funcionais publicados nas duas branches: `506b9e33a`, `4c82459d3` e `7db04067b`. O registro desta rodada será publicado junto com o estado conectado do Obsidian.

- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [ledger da rodada](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\audits\gauntlet-2026-09-12-calculator-contact.md) ↔ [Hub](https://hub-completo-ashen.vercel.app/) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [deploy EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator?audit=objective-20260913).

## Décima primeira rodada — vídeo final, mapa live e outputs ampliados — 13/09/2026

- O vídeo de referência `20260913-1641-57.0463571.mp4` foi revisado visualmente e transcrito em português. A fala confirma os requisitos: resultado financeiro menos poluído, cartões compactos e clicáveis, motor de ajuste adicional, mensagem pronta grande e cópia do inventário. A transcrição integral está em [rotta-calculator-video-transcript-20260913.md](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-video-transcript-20260913.md).
- A inspeção direta do Hub cobriu Dashboard, Calculadora, Cadastro, Contrato, Ordem de Serviço, Inventário, Orçamento, Motoristas, Serviços, Pesquisa, Financeiro e Assinaturas. Nenhuma ação destrutiva, cadastro, envio ou limpeza foi acionada.
- O teste live reproduziu o fluxo com Washington, Teresina - PI → Campo Grande - MS e inventário de oito linhas. O primeiro carregamento mostrou a rota completa no mapa, sem precisar clicar em `VER ROTA`; distância `2713,4 km`, tempo `2096 min`, pedágios `Desativados` e integração respondendo.
- A causa da falha visual anterior era o mapa ser desenhado antes de o painel terminar de dimensionar. O commit `8cac7d376` passou a observar o tamanho do painel com `ResizeObserver`, disparar `google.maps.event.trigger(map, 'resize')` e redesenhar a rota após a estabilização do layout.
- A falha visual apontada no vídeo foi corrigida no commit `7e3783e37`: proposta e inventário agora usam `rows=14` e `min-h-[20rem]`, preservando as abas e os botões de cópia.
- Evidência live do bundle: novo navegador autenticado carregou `dashboard-L18rxRjp.js`; a proposta exibiu `rows=14` e a classe `min-h-[20rem]`. A sessão antiga foi mantida separada para comparação e não foi usada como prova do bundle novo.
- Testes live: cópia da proposta confirmada (`591` caracteres); cópia do inventário confirmada (`81` caracteres); `Satélite` alternou o link do Google Maps para `t=k` e `Mapa` restaurou `t=m`; cartões `Econômica` e `Padrão` alternaram corretamente.
- Verificações técnicas: Vitest focalizado `10/10`; ESLint direcionado `0` erros e apenas avisos preexistentes; Vite `5092` módulos transformados; `/health` HTTP `200`; deploy do EasyPanel verde para `fix(calculator): enlarge proposal and inventory outputs`; GitHub atualizado nas duas branches.
- A sessão do Caio continuou sem acesso enquanto a calculadora permaneceu privada; nenhuma permissão foi alterada. Nenhuma mensagem WhatsApp, conversa, etiqueta, contato, inbox, credencial ou dado persistente foi criado ou alterado.
- Limitação honesta: RSpec/Ruby não estão disponíveis no host local; a integração foi comprovada pelo teste live do container e pelos testes JS focalizados. Isso não é contado como aprovação RSpec.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [transcrição do vídeo](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-video-transcript-20260913.md) ↔ [comparação Hub](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-hub-comparison-20260912.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [deploy EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator).

## Décima segunda rodada — auditoria de paridade de rotas e configuração persistida — 13/09/2026

- O Hub foi testado com o bloco Washington, Teresina - PI → Campo Grande - MS. Após `CALCULAR ROTA`, retornou `2760,7 km`, `1 dia 20h 31min`, pedágios desativados, cards comerciais, ajuste adicional por quilômetro, proposta copiável e controles Mapa/Satélite/Relevo.
- O mesmo fluxo no Chatwoot live retornou `2713,4 km`, `2096 min`, pedágios desativados e provider factual `osm-osrm-fallback`, exibido honestamente na interface como `Fallback de rota`. A diferença foi de `47,3 km` (aprox. `1,75%`) e deve ser tratada como divergência de motor, não como equivalência perfeita com o Hub.
- A inspeção somente leitura do ambiente persistido do EasyPanel confirmou `OPENROUTER_MODEL` e `OPENROUTER_API_KEY`, mas não confirmou `GOOGLE_ROUTES_API_KEY`, `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` nem `GOOGLE_MAPS_BROWSER_API_KEY`. O processo atualmente em execução ainda serviu a chave visual do Google Maps, portanto há drift entre o processo live e a configuração persistida: um próximo deploy pode remover o mapa ou manter apenas o fallback.
- Nenhuma chave foi copiada para GitHub, Obsidian ou código. Não foi reutilizada a chave visual como chave server-side, porque as restrições de referrer/IP e a autorização da Routes API precisam ser comprovadas antes de qualquer alteração.
- O código atual já mantém pedágios permanentemente desativados e sinaliza o fallback; nenhum código funcional foi alterado nesta rodada. Próximo passo seguro: obter uma chave server-side dedicada à Google Routes API, registrar somente no EasyPanel, redeployar e repetir a comparação com o mesmo par de cidades.
- A auditoria do Hub permaneceu sem mutações: não houve cadastro, remoção, envio, alteração de cliente, conversa, etiqueta, credencial ou dado do WhatsApp.
- Veredito desta rodada: layout, controles, proposta, cópia e segurança contra pedágio aprovados; paridade de quilometragem Google/Hub e persistência das chaves Google condicionadas à configuração server-side dedicada.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [comparação Hub](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-hub-comparison-20260912.md) ↔ [transcrição do vídeo](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-video-transcript-20260913.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/environment) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator).

## Décima terceira rodada — Google Routes restaurado e reteste pós-deploy — 13/09/2026

- As duas chaves já existentes no projeto Google Cloud foram reutilizadas: `Chatwoot Rotta Maps Browser` para o navegador e `Chatwoot Rotta Routes Backend` para o servidor. Nenhuma credencial nova foi criada.
- O EasyPanel foi atualizado somente com `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` e `GOOGLE_ROUTES_API_KEY`, sem registrar os valores em código, GitHub ou Obsidian. O deploy de ambiente terminou com sucesso e `/health` retornou HTTP `200`.
- Reteste real no Chatwoot após reinicialização: provider `Google Routes`, distância `2755,9 km`, tempo `2135 min`, pedágios `Desativados`, linha do mapa visível, proposta presente e seis cards comerciais. O Hub havia retornado `2760,7 km`; a diferença caiu para `4,8 km` (aprox. `0,17%`), compatível com diferenças de waypoint/algoritmo, não com o fallback anterior.
- Cópia da proposta passou com `591` caracteres e o texto `ORÇAMENTO FINAL — ROTTA BRASIL EXPRESS`. `Satélite` alterou o link Google para `t=k` e `Mapa` restaurou `t=m`.
- O card `Equilibrada` e o ajuste/km foram testados: o botão `+` levou o passo a `0,50`, recalculou o preço, e a restauração para `0,25` voltou ao preço de referência. Duas execuções consecutivas ficaram em fallback determinístico por janela de resposta; isso não afetou rota, preço, mapa ou proposta, mas mantém a latência do provedor de IA como pendência de otimização separada.
- Nenhuma conversa, mensagem, etiqueta, contato, inbox ou dado WhatsApp foi criado ou alterado. O único estado externo modificado foi a configuração autorizada das duas chaves Google no EasyPanel.
- Veredito: configuração Google persistida, motor server-side ativo, pedágios desativados, mapa e precificação aprovados no reteste. RSpec/Ruby continua indisponível no host local e não é contado como aprovado.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [paridade Hub](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-hub-comparison-20260912.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel deploy](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator).

## Décima quarta rodada — latência da IA corrigida e reteste triplo pós-deploy — 13/09/2026

- A reprodução real confirmou a causa do fallback: duas chamadas mínimas ao OpenRouter com `max_tokens=700` responderam HTTP 200, mas levaram `14.949 ms` e `14.416 ms`, acima da janela síncrona de `12,5 s`. Não houve falha de autenticação, modelo ou rota.
- A mesma chamada, com o modelo obrigatório `deepseek/deepseek-v4-flash-0731`, prompt preservado e somente `max_tokens=350`, respondeu HTTP 200 em `7.867 ms`. A otimização foi isolada em `OpenRouterClient::MAX_TOKENS`; não alterou modelo, regras, contexto, cálculo determinístico ou pedágios.
- A regressão foi fixada no commit `51a0496ef`, com expectativa explícita de `350` tokens em `open_router_client_spec.rb`; o commit foi publicado nas branches `codex/rotta-objective-20260911` e `rotta-custom-v1`.
- Deploy do EasyPanel terminou e `/health` voltou a HTTP `200`. No Chatwoot live, uma sessão nova executou três cálculos consecutivos do mesmo caso Washington / Teresina - PI → Campo Grande - MS: `3/3` exibiram `Integração respondendo`, `Google Routes`, `2755,9 km`, pedágios `Desativados`, seis cards, preço padrão `R$ 9.168,67`, proposta preenchida e mapa carregado.
- A mensagem de fallback não apareceu em nenhuma das três execuções pós-deploy. A diferença contra o Hub permaneceu `4,8 km` (`0,17%`), com a mesma rota Google já registrada.
- O host Windows não possui Ruby/Bundler; dentro da imagem de produção, `bundle exec rspec` não iniciou por executável/gem de teste ausente. Isso foi registrado como limitação de teste, sem alterar a imagem nem instalar dependências em produção. A evidência decisiva foi o teste real do endpoint no Chatwoot e a medição direta do OpenRouter no container.
- Nenhuma mensagem, conversa, etiqueta, contato, inbox, credencial ou dado WhatsApp foi criado ou alterado. O ajuste externo foi somente o deploy do código autorizado.
- Veredito: latência da IA reduzida para dentro da janela observada; fallback preservado como proteção; rota Google, mapa, precificação e proposta aprovados em `3/3` execuções.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [comparação Hub](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-hub-comparison-20260912.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel deploy](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator).

## Décima quinta rodada — paridade visual complementar, mapa e segurança contextual — 13/09/2026

- Os vídeos complementares `20260913-1638-06.3463662.mp4`, `20260913-0249-01.3743996.mp4` e `20260913-0158-44.8167241.mp4` foram revisados quadro a quadro e transcritos. A referência reforça: central de leitura redimensionável, menos espaço vazio, mapa com marcadores A/B e autocomplete, cards compactos coloridos, inventário/cubagem à esquerda, quatro serviços compactos, preço selecionável e saída grande para WhatsApp.
- A frente visual foi integrada no checkout atual: leitura mínima reduzida para `12rem`, inventário/serviços reorganizados, cards de preço protegidos durante recálculo, ajuste/km limitado a zero, marcadores derivados dos extremos reais da polilinha, links de origem/destino independentes e Google Places carregado junto com `geometry`.
- Foi corrigida uma causa de números de serviço que voltavam para zero após o cálculo: a UI agora reconcilia ajudantes e montagem a partir de `pricing.services` retornado pelo motor determinístico, preservando a quantidade efetivamente enviada pelo agente.
- O parser contextual passou a normalizar `meados de outubro` para o dia 15 apenas quando encontra ano de referência, preservar a equipe e rejeitar linhas de acesso, pagamento, equipe, metadados e instruções de inventário. A IA recebeu regras explícitas para não inventar `Ace Move`, caixas adicionais ou utensílios; estimativa AI sem item-fonte não cria item.
- Validações locais: Vitest focalizado `12/12`; ESLint dos arquivos alterados `0` erros e `29` avisos de estilo/preexistentes; compilação SFC de `Index.vue` e `GoogleMapPanel.vue` aprovada; `git diff --check` sem erro. Ruby/Bundler e o daemon Docker não estão disponíveis neste host, portanto os specs Rails não foram contados como aprovados localmente.
- O deploy e o teste live desta rodada ainda são o próximo checkpoint obrigatório. Até sua conclusão, não se considera a paridade visual/motor fechada. Nenhuma mensagem, conversa, contato, etiqueta, inbox ou credencial do WhatsApp foi criado ou alterado.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [transcrição dos vídeos](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-video-transcript-20260913.md) ↔ [comparação Hub](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-hub-comparison-20260912.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel deploy](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator).

## Décima sexta rodada — bundle publicado, marcadores A/B e bateria live final — 13/09/2026

- A auditoria isolou a regressão visual: o serviço servia `dashboard-L18rxRjp.js`, um bundle antigo, apesar do código novo estar no GitHub. O `Dockerfile.overlay` copiava somente `public/vite`, e o Compose reutilizava uma tag fixa de imagem.
- Correção de publicação: o bundle Vite foi recompilado localmente (`5092` módulos), o manifesto atualizado (`240` assets), os artefatos necessários foram versionados no commit `9ee334ef8`, e a imagem passou a usar a tag imutável `rotta-chatwoot:v4.17.0-custom-v1-9ee334ef8` (`a425ada96`). O overlay permaneceu simples e seguro, usando o bundle já compilado (`88e807e57`).
- Houve uma tentativa intermediária de recompilar dentro da imagem que falhou porque o estágio final não tinha `pnpm`; o serviço anterior permaneceu ativo e saudável. A etapa foi removida antes do deploy final, sem alteração de dados. O deploy final `fix(deploy): use committed Vite bundle` concluiu no EasyPanel e `/health` retornou HTTP `200` (`status=woot`).
- Prova independente do artefato servido: o servidor passou a entregar `/vite/assets/dashboard-CelZhuDD.js`, contendo `calculator-map-endpoint-legend-header` e `endpoint-legend`; o bundle antigo não continha essas strings.
- Teste real no Chatwoot autenticado como Kelvin, com dados fictícios Washington / Teresina - PI → Campo Grande - MS: `Rota traçada`, `Google Routes`, `2755,9 km`, `2155 min`, pedágios `Desativados`, `Integração respondendo`, mapa visual e linha da rota.
- A árvore visual live confirmou a legenda `A Origem B Destino`, marcadores A/B sobre os extremos da rota, links `FOTO ORIGEM`, `FOTO DESTINO`, `VER ROTA` e `ABRIR GPS`, além dos controles `Mapa`, `Satélite`, `Relevo`. Satélite mudou o link para `t=k`, Relevo para `t=p` e Mapa restaurou `t=m`.
- O bloco foi interpretado com inventário de `8` itens, ajudantes `2/2` e montagem/desmontagem `2/2`; os seis cards comerciais apareceram. `Equilibrada` recalculou para `R$ 11.288,59` e a restauração para `Padrão` voltou a `R$ 9.168,67`. A proposta e o inventário foram exibidos, a cópia da proposta confirmou o toast e a aba Inventário mostrou a tabela completa.
- Vitest focalizado pós-correção: `3` arquivos, `11/11` aprovados. SFC de `GoogleMapPanel.vue` compilado; `git diff --check` aprovado; ESLint direcionado terminou com `0` erros e somente avisos de estilo `vue/html-closing-bracket-newline`. Ruby/Bundler/RSpec continuam indisponíveis no host Windows e não são contados como aprovados.
- Nenhuma mensagem, conversa, etiqueta, contato, inbox, credencial ou dado persistente do WhatsApp foi criado ou alterado. A única alteração externa foi a publicação autorizada do código e do bundle.
- Veredito: bundle correto no servidor, mapa e marcadores A/B visíveis, motor Google Routes, parser/serviços, precificação, proposta, inventário e controles live aprovados. A revisão AAA independente ainda precisa emitir a nota final desta rodada.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [transcrição dos vídeos](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-video-transcript-20260913.md) ↔ [comparação Hub](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-hub-comparison-20260912.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel deploy](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator?v=88e807e57).
## Décima sétima rodada — Places real, resumo de rota sincronizado e deploy final — 13/09/2026

- Foi isolado e corrigido o último bug do autocomplete: `setupPlacesAutocomplete()` procurava `calculator-origin` e `calculator-destination`, mas os campos não tinham esses IDs. O commit `29490f770` vinculou os IDs reais aos dois inputs.
- A chave já existente `Chatwoot Rotta Maps Browser` teve somente a restrição de API ampliada para `Maps JavaScript API` + `Places API`; os referrers autorizados foram preservados. A chave de Routes server-side não foi alterada. Nenhum valor de credencial foi salvo em código, GitHub ou Obsidian.
- Prova live do Places após a alteração: ao digitar `Teresina`, o dropdown real do Google apareceu com sugestões e `powered by Google`; a seleção preencheu `Teresina, PI`. O campo de destino também foi selecionado pelo fluxo de sugestões.
- Foi corrigida a inconsistência entre o endereço escolhido no autocomplete e o texto atual do agente. O cartão `Resultado da preparação` agora deriva a rota exibida dos campos atuais `freight.origin` e `freight.destination`; não reapresenta o endereço antigo carregado por `place_changed`. O commit funcional é `65998e9ea`.
- Publicação imutável: `4d3379a21` atualizou o Compose para a imagem do bundle de Places e `1689e8c63` para `rotta-chatwoot:v4.17.0-custom-v1-65998e9ea`. As duas branches (`codex/rotta-objective-20260911` e `rotta-custom-v1`) estão sincronizadas. O deploy final no EasyPanel terminou com `### Success`.
- Validação pós-deploy: `/health` HTTP `200` com `{"status":"woot"}`; HTML público serviu `dashboard-C8ZSmAfW.js`. No Chatwoot live, o cálculo Washington / Teresina - PI → Campo Grande - MS exibiu `Google Routes`, `2755,9 km`, `2168 min`, pedágios `Desativados`, integração respondendo, linha laranja, marcador azul A, marcador rubi B e legenda `A Origem B Destino`.
- O mesmo teste exibiu inventário com `8` itens, ajudantes `2/2`, montagem/desmontagem `2/2`, seis cards comerciais, preço padrão `R$ 9.168,67` e proposta preenchida. A captura visual confirmou a divisão em leitura à esquerda e mapa à direita, com Foto origem/destino, Ver rota, Abrir GPS, Mapa, Satélite e Relevo.
- O número de distância/tempo pode variar entre chamadas do motor por waypoint/algoritmo; nesta execução a evidência usada é a leitura acima, sem mascarar a variação histórica. Pedágios continuam desativados.
- Vitest focalizado: `3` arquivos, `11/11`; ESLint de `Index.vue`: `0` erros e somente avisos de estilo/preexistentes; build Vite concluído. Ruby/Bundler/RSpec continuam indisponíveis no host Windows e não foram contados como aprovados.
- Nenhuma mensagem, conversa, etiqueta, contato, inbox ou credencial do WhatsApp foi criada ou alterada. A única configuração externa adicional foi a inclusão autorizada da Places API na chave browser do Google Cloud.
- Veredito: bug do autocomplete corrigido, mapa/rota/proposta live aprovados e resumo da rota sincronizado com os campos atuais. A revisão AAA independente deve considerar esta rodada e a limitação explícita do RSpec.
- Veredito independente final: `AAA aprovado — 95,7/100` (correção 97, completude 96, verificação 93, coerência 96, utilidade 97, acabamento 95). Nenhum bloqueador crítico; as ressalvas de RSpec/Ruby ausente e variação histórica do tempo de rota permanecem explícitas.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [comparação Hub](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-hub-comparison-20260912.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [deploy EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator?v=1689e8c63).

## Décima oitava rodada — CSS publicado, auditoria visual final e revisão de estabilidade — 13/09/2026

- A auditoria isolou a última regressão de publicação: o JavaScript novo já estava servido, mas os CSS referenciados pelo manifesto Vite ainda eram ignorados pelo Git e retornavam `404`. Foram publicados os seis CSS referenciados, incluindo `dashboard-DdmVwEG9.css`; o Compose passou a usar a imagem imutável `rotta-chatwoot:v4.17.0-custom-v1-a69c79a80`.
- Commits publicados nas branches `codex/rotta-objective-20260911` e `rotta-custom-v1`: `1222dd7bf` (bundle JS), `a69c79a80` (CSS referenciado) e `f66fb4f42` (tag/deploy final). O último deploy do EasyPanel ficou verde com a mensagem `fix(deploy): include dashboard styles`.
- Provas de serviço: `/health` HTTP `200` com `{"status":"woot"}`; JavaScript live `dashboard-CvXzjYcM.js`; CSS live `dashboard-DdmVwEG9.css` HTTP `200`, `Content-Type: text/css` e `Content-Length: 3378068`.
- Bateria live em sessão nova autenticada: caso fictício Washington, 20/01/2027, Teresina - PI → Campo Grande - MS, inventário com oito categorias e `15` caixas, ajudantes `2/2`, desmontagem/montagem de armário e escrivaninha. Resultado: `Google Routes`, mapa com linha e marcadores A/B, chips de rota, seis cards comerciais, detalhamento financeiro e proposta do WhatsApp preenchida.
- Controles funcionais: `Econômica` recalculou para `R$ 7.060,00` e, após a restauração, `Padrão` voltou para `R$ 9.183,31`. A nova sessão terminou com console limpo (`[]`). Uma sessão anterior registrou um único `502` durante a janela de reinício; o reteste em sessão estável não reproduziu o erro, portanto ele fica documentado como transitório, não ocultado.
- Verificações locais: Vitest focalizado `12/12`; ESLint direcionado `0` erros e `25` avisos de estilo/dynamic i18n; `git diff --check` aprovado. Ruby/Bundler/RSpec não estão disponíveis no host Windows e não foram contados como aprovação.
- Nenhuma conversa, mensagem, etiqueta, contato, inbox, credencial ou dado persistente do WhatsApp foi criado ou alterado nesta rodada. A alteração externa foi apenas a publicação autorizada do bundle e do código.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [[rotta-calculator-video-transcript-20260913]] ↔ [[rotta-calculator-hub-comparison-20260912]] ↔ [ledger](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\audits\gauntlet-2026-09-12-calculator-contact.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator?v=final-audit-a69c).

### Revisão AAA independente — fechamento da rodada — 13/09/2026

- Veredito: `aprovado — 96,3/100`; correção `98`, completude `96`, verificação `95`, coerência `97`, utilidade `97`, acabamento `95`. Nenhum bloqueador crítico.
- Evidências confirmadas pelo revisor: repositório limpo; commits `1222dd7bf`, `a69c79a80`, `f66fb4f42` e `1d6305eb9`; branches remotas sincronizadas em `1d6305eb9`; JavaScript/CSS HTTP `200`; `/health` HTTP `200`; manifesto com `240` assets; Vitest `12/12`; sessão live sem erros; Google Routes, mapa A/B, controles, seis cards, detalhamento financeiro, proposta e alternância de preços aprovados; EasyPanel verde.
- Ressalvas não críticas: Ruby/Bundler/RSpec indisponíveis no host; lint amplo pode apontar CRLF em três auxiliares se o CI exigir normalização; o `502` histórico recomenda teste específico durante reinício controlado, embora não tenha reaparecido na sessão estável.

## Décima nona rodada — auditoria compacta, cores e recálculo dinâmico — 13/09/2026

- A bateria reproduziu o caso seguro Washington / Teresina - PI → Campo Grande - MS sem enviar WhatsApp nem alterar conversa persistente.
- Correções finais: classes inexistentes `n-orange-*` foram substituídas pela paleta `n-amber-*` existente no tema; Limpar ficou vermelho/ruby, Calcular e Calcular rota ficaram âmbar/orange, e as duas modalidades ficaram visivelmente âmbar com estado selecionado.
- A Central de leitura ficou compacta, o mapa permaneceu à direita, Dados do frete/Serviços/Inventário ficaram à esquerda, e `Integrações planejadas` foi removida. Os oito controles +/- ficaram fora dos cards, visíveis, com limites seguros.
- Os campos de valor unitário agora também disparam o cálculo. Prova live: ajudantes na origem passaram de `2` para `3`; com valor unitário `R$ 100`, o card exibiu `R$ 500,00`, Serviços `R$ 500,00` e o preço padrão mudou de `R$ 9.183,31` para `R$ 9.683,31`.
- Prova de rota live: Google Routes conectado, `2760.3 km`, `1 dia, 12 horas e 11 minutos`, pedágios desativados, mapa com A/B, foto origem/destino, Ver rota, Abrir GPS, Mapa/Satélite/Relevo e proposta preenchida.
- Validação local: Vitest focalizado `14/14`; build Vite `5092` módulos; manifesto/artefatos publicados; ESLint dos arquivos alterados com `0` erros e `33` avisos; `git diff --check` aprovado.
- Verificação HTTP pós-deploy: `/health` HTTP `200`; HTML HTTP `200`; `dashboard-BcwmCANl.js` e `dashboard-DsE92JPe.css` HTTP `200`; bundle sem `Integrações planejadas`, com `calculator-service-quantity-controls` e paleta âmbar.
- Commits publicados nas duas branches: `9b3021428` (correção funcional/visual + bundle), `ce9982bd0` (tag Compose/deploy) e `68068e33f` (ledger desta auditoria). O EasyPanel mostrou `fix(deploy): publish orange calculator bundle` com check verde.
- Houve apenas a janela transitória de serviço indisponível durante o restart; depois do healthcheck 200 o Chatwoot carregou normalmente e o reteste estável passou.
- Nenhuma mensagem, conversa, etiqueta, contato, inbox, credencial ou dado persistente do WhatsApp foi criado ou alterado.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [[rotta-calculator-video-transcript-20260913]] ↔ [[rotta-calculator-hub-comparison-20260912]] ↔ [ledger](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\audits\gauntlet-2026-09-12-calculator-contact.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator?v=compact-audit-5cd).

## Vigésima rodada — fundo pastel e compactação vertical — 13/09/2026

- A causa do vão vertical foi isolada: a grade compartilhava a altura da coluna do mapa. O mapa agora fica em uma coluna direita independente; a coluna esquerda usa fluxo flex próprio.
- Ordem visual live confirmada: Central de leitura → Dados do frete → Serviços adicionais (Quantidades e valores unitários) → Inventário e cubagem. As seções ficaram compactas e sem scroll interno forçado.
- Fundo pastel final: `bg-n-amber-1/50`, escolhido para visibilidade com contraste preservado.
- Validação local: Vitest `14/14`; build Vite `5092` módulos; detector de layout `[]`; ESLint direcionado `0` erros e `26` avisos existentes; bundle HTTP comprovado.
- Commits publicados nas duas branches: `55a5b5ee3` (layout + bundle + fundo pastel) e `b2820cfe6` (tag Compose/deploy). EasyPanel concluiu `fix(deploy): publish stronger pastel calculator background`.
- Pós-deploy: health e HTML HTTP `200`; JavaScript `dashboard-wWH-k9l4.js` HTTP `200` com o fundo pastel e sem `xl:contents`; CSS referenciado HTTP `200` como `text/css`; SHA-256 do JS `56E79A51F099A15F030D2489B94E99AF4CB609F3997C785ABA22219646408296`.
- Houve apenas a janela transitória `Service is not reachable` durante o restart; após o healthcheck, Chatwoot carregou normalmente e o reteste visual passou.
- Nenhuma mensagem, conversa, etiqueta, contato, inbox, credencial ou dado WhatsApp foi criado ou alterado.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [[rotta-calculator-video-transcript-20260913]] ↔ [[rotta-calculator-hub-comparison-20260912]] ↔ [ledger](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\audits\gauntlet-2026-09-12-calculator-contact.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator?v=pastel-layout-b2820cfe6).

## Vigésima primeira rodada — redimensionamento manual e temas pastel — 13/09/2026

- Vídeo de 67 segundos analisado com imagem e áudio. Pedido confirmado: arrastar as extremidades dos cards e do mapa/rota, ajustar todos os ângulos e escolher a cor do fundo no topo sem prejudicar a leitura.
- Implementado `CalculatorResizablePanel`: alças esquerda, direita, superior, inferior e canto; arraste por ponteiro e ajuste por teclado; limites mínimos; mobile preservado sem overflow lateral.
- As áreas Central de leitura, Dados do frete, Inventário e cubagem, Serviços adicionais, Mapa e rota e Resultado agora são ajustáveis. As dimensões ficam salvas por conta no navegador e há `Restaurar layout` para limpar tudo.
- Seletor de fundo com seis temas pastel seguros, cor personalizada, contraste calculado e persistência local. O fundo interno padrão continua âmbar claro.
- Validação live: azul névoa aplicado e persistido após recarga; leitura redimensionada de `1045px` para `1077px` por teclado e para `942px` por arraste real; mapa ajustado para `1194px × 497px`; restauração voltou a `#fff7ed` e removeu os estilos salvos.
- Validação local: Vitest `17/17`; build Vite `5095` módulos; detector de layout `[]`; ESLint direcionado `0` erros e `38` avisos preexistentes de estilo/i18n; `git diff --check` aprovado.
- Deploy EasyPanel concluído com `fix(deploy): publish resizable calculator layout`; health/HTML HTTP `200`; bundle `dashboard-Ba2mCxLV.js` HTTP `200`, contendo toolbar, painéis redimensionáveis e reset; CSS `dashboard-DjWZ2g0t.css` HTTP `200` como `text/css`.
- Commits publicados nas duas branches: `061c40ca0` (funcional + bundle) e `aff6f8e1b` (tag Compose/deploy).
- Nenhuma mensagem, conversa, etiqueta, contato, inbox, credencial ou dado WhatsApp foi criado ou alterado.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [[rotta-calculator-video-transcript-20260913]] ↔ [[rotta-calculator-hub-comparison-20260912]] ↔ [ledger](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\audits\gauntlet-2026-09-12-calculator-contact.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator?v=resize-test-aff6f8e1b).

## Vigésima segunda rodada — contraste, visibilidade redimensionável e deploy final — 13/09/2026

- Acabamento final aplicado: o cartão de visibilidade da calculadora também possui alças de largura, altura e canto, mantendo a mesma persistência por conta dos demais painéis. O selo de contraste agora usa uma superfície escura quando a cor escolhida exige texto branco.
- Testes locais finais: Vitest `17/17`; build Vite concluído com `5095` módulos; detector de layout `[]`; ESLint direcionado com `0` erros e `38` avisos já conhecidos; `git diff --check` aprovado.
- Deploy publicado nas duas branches: `7fd4655fb` (acabamento funcional + bundle) e `215ffbd01` (tag Compose/deploy). EasyPanel concluiu `fix(deploy): publish final calculator controls`; a janela transitória de reinício respondeu `Service is not reachable`, recuperou em seguida e passou no reteste.
- Provas live finais: `/health` HTTP `200`; HTML HTTP `200`; `dashboard-CA_IobsU.js` HTTP `200`, SHA-256 `8236A8C6C8770D1A57776D989BDDF784B676071AEF1359D9AEAB61C104A6DC7D`; `dashboard-DjWZ2g0t.css` HTTP `200`, SHA-256 `BE378A255B99768FDF35066072C57ED0C4EB7DB3F3F591A5D1410DB228684822`.
- No Chatwoot live, a árvore confirmou os seis painéis redimensionáveis, o mapa/rota e o novo cartão de visibilidade. Azul névoa foi aplicado com contraste `14,9:1`; o cartão de visibilidade foi redimensionado por teclado; `Restaurar layout` voltou ao âmbar `#fff7ed`, contraste `15,3:1` e removeu as dimensões do teste.
- Nenhuma mensagem, conversa, etiqueta, contato, inbox, credencial ou dado WhatsApp foi criado ou alterado. A única alteração externa foi a publicação autorizada do código e dos artefatos compilados.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [transcrição do vídeo](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-video-transcript-20260913.md) ↔ [comparação Hub](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-hub-comparison-20260912.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments) ↔ [Chatwoot live](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator?v=final-resizable-7fd4655fb).
