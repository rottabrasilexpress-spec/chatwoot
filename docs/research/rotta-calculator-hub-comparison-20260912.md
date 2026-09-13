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
