# Comparação Hub ↔ Calculadora Rotta

Data: 2026-09-12

## Referência

- Hub observado: https://hub-completo-ashen.vercel.app/
- Produto auditado: https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/calculator

## Mapeamento visual

| Área | Referência do Hub | Implementação Rotta verificada |
|---|---|---|
| Composição | Leitura e mapa na mesma tela | Duas colunas; leitura à esquerda e mapa operacional à direita |
| Rota | Ação de calcular e visualização geográfica | Google Maps, polilinha da rota, Mapa/Satélite, fullscreen, street view e link externo |
| Serviços | Cartões por serviço | Ajudantes, Desmontagem e montagem, Material e embalagem e Taxas especiais em cartões coloridos |
| Inventário | Itens e cubagem separados | Itens, quantidades, volume e cópia do inventário em aba própria |
| Preço | Precificação separada do inventário | Seis cartões comerciais com valor e preço/km |
| Comunicação | Preparação da proposta | Aba Proposta com texto pronto para WhatsApp e ação de cópia |
| Estado da rota | Feedback após calcular | Distância, duração e pedágios explícitos; sem cálculo de pedágio |

## Comportamento verificado

1. Texto de auditoria foi inserido com origem `Palotina - PR`, destino `Linhares - ES` e dois itens.
2. O cálculo real retornou HTTP 200 em aproximadamente 14,77 segundos.
3. A tela mostrou a rota desenhada, `1855,3 km`, `1586 min` e `Desativados` em pedágios.
4. Inventário, Proposta e cartões de preço foram exibidos e inspecionados.
5. Nenhuma mensagem, etiqueta, contato ou conversa foi criada/alterada pela prova.

## Decisões de segurança

- Chaves não são registradas neste documento.
- O backend desativa pedágios por contrato.
- O prompt de IA recebe fatos compactos da rota, não a polilinha completa nem dados fora do cálculo.
- Sem `GOOGLE_ROUTES_API_KEY`, o provider factual é `osm-osrm-fallback`; isso é sinalizado no resultado e não é apresentado como Google Routes.

## Reprodutibilidade

- Último commit publicado: `909cf127f`.
- Branch de publicação: `rotta-custom-v1`.
- Testes focados: `7/7`.
- Build Vite: aprovado; `240` assets verificados.
- A auditoria de formatação ESLint permanece condicionada ao problema de CRLF do checkout Windows; não foi feita regravação automática de arquivos.

## Atualização da inspeção visual — 2026-09-13

- O Hub foi percorrido sem mutações em todas as áreas operacionais: Dashboard, Calculadora, Cadastro, Contrato, Ordem de Serviço, Inventário, Orçamento, Motoristas, Serviços, Pesquisa, Financeiro e Assinaturas.
- O Hub confirma a referência de layout: leitura e cálculo em duas colunas, mapa operacional com rota e botões de origem/destino/GPS, controles Mapa/Satélite/Relevo, serviços compactos, seis cartões de preço clicáveis, ajuste por quilômetro e proposta/inventário separados.
- O Chatwoot live foi comparado com essa referência no mesmo fluxo de Washington, Teresina - PI → Campo Grande - MS. O mapa passou a aparecer completo no primeiro cálculo após `ResizeObserver` + `google.maps.event.trigger(map, 'resize')`.
- A proposta e o inventário passaram de 8 para 14 linhas com altura mínima de 20rem. O teste visual confirmou que o campo permite leitura ampla; as duas ações de cópia também passaram.
- Os cartões `Econômica` e `Padrão` foram alternados no live; `Satélite` e `Mapa` foram alternados e seus links `t=k`/`t=m` conferidos.
- Commits publicados: `8cac7d376` (redesenho responsivo do mapa) e `7e3783e37` (saídas ampliadas). O último deploy verde do EasyPanel é `fix(calculator): enlarge proposal and inventory outputs`.
- Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [transcrição do vídeo](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\research\rotta-calculator-video-transcript-20260913.md) ↔ [ledger](C:\Users\User\Documents\Codex\rotta-custom-v1-source\docs\audits\gauntlet-2026-09-12-calculator-contact.md) ↔ [GitHub](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1) ↔ [EasyPanel](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments).

## Auditoria de rota e persistência das integrações — 2026-09-13

- No Hub, o teste Washington / Teresina - PI → Campo Grande - MS produziu `2760,7 km` e `1 dia 20h 31min`, com pedágios desativados.
- No Chatwoot, o mesmo teste produziu `2713,4 km` e `2096 min`, com provider `osm-osrm-fallback`. A UI identifica isso como `Fallback de rota`; não foi apresentada falsa equivalência com Google Routes.
- A diferença de `47,3 km` mostra que ainda não há paridade de motor entre Hub e Chatwoot. O layout e os controles estão alinhados, mas a quilometragem só deve ser considerada equivalente após uma chave server-side válida e persistida para Google Routes.
- A configuração persistida do EasyPanel não contém as variáveis Google server/browser esperadas, embora o processo live ainda tenha servido a chave visual do mapa. Isso é drift de ambiente e precisa ser corrigido antes do próximo deploy para evitar regressão.
- Não houve alteração de código ou de dados nesta rodada; nenhum segredo foi registrado nesta pesquisa.

## Reteste após restauração das chaves Google — 2026-09-13

- As chaves Google já existentes e dedicadas ao Chatwoot foram persistidas no EasyPanel, sem criação de credencial nova e sem registrar valores neste documento.
- O Chatwoot passou a exibir `Google Routes` e retornou `2755,9 km` para Teresina - PI → Campo Grande - MS; o Hub retornou `2760,7 km`. A diferença ficou em `4,8 km` (aprox. `0,17%`), muito menor que os `47,3 km` do OSRM fallback.
- Pedágios permaneceram `Desativados`; a proposta foi copiada (`591` caracteres); `Satélite`/`Mapa` alternaram `t=k`/`t=m`; cards e ajuste/km recalcularam e foram restaurados ao padrão.
- Deploy concluído e health HTTP `200`. Duas execuções consecutivas da IA ficaram em fallback determinístico por janela de resposta, isoladas da rota Google e sem inventar dados de inventário; a latência do provedor permanece uma pendência separada.

## Reteste da latência da IA após otimização — 2026-09-13

- A chamada mínima ao mesmo modelo respondeu HTTP 200 em `14.949 ms` e `14.416 ms` com `max_tokens=700`; com `max_tokens=350`, mantendo prompt e modelo, respondeu em `7.867 ms`.
- O Hub não foi alterado. A comparação de rota segue `2760,7 km` no Hub contra `2755,9 km` no Chatwoot Google Routes (`4,8 km`, `0,17%`).
- No Chatwoot pós-deploy, três cálculos consecutivos exibiram `Integração respondendo`, `Google Routes`, pedágios desativados, preço padrão `R$ 9.168,67`, proposta e mapa. Não houve fallback em `3/3`.
- A mudança foi apenas `OpenRouterClient::MAX_TOKENS = 350`, publicada no commit `51a0496ef`; nenhum segredo foi gravado neste documento.
