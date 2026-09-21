# RottaWoot — contexto do produto

## Produto e usuários

RottaWoot é a central operacional de atendimento da Rotta Brasil Express, construída sobre o Chatwoot. É usada principalmente por Kelvin, Caio e demais agentes autorizados para atender clientes do WhatsApp em alto volume.

## Objetivo

Centralizar conversas em tempo real, etiquetas, follow-up e assistência operacional, com resposta rápida e estado consistente entre todas as superfícies.

## Contexto de uso

- Uso diário em desktop e celular, frequentemente com muitas conversas simultâneas.
- Envio precisa funcionar com teclado e controles visuais, sem perda nem duplicação.
- O agente precisa localizar, filtrar e alternar entre clientes com baixa latência.

## Compromissos confirmados

- Preservar integralmente o Chatwoot normal enquanto recursos focados são adicionados.
- O modo focado de conversas será uma janela independente, sem a barra lateral global.
- O modo focado terá layouts para 1, 2, 3 ou 4 conversas simultâneas.
- O último layout e arranjo utilizados serão restaurados na próxima abertura.
- Ferramentas internas e nomes dos agentes não devem ser expostos ao cliente.
- Identidade: RottaWoot / Rotta Brasil Express, seguindo a linguagem visual já estabelecida no fork.

## Princípios

1. Confiabilidade em tempo real: nenhum envio perdido ou duplicado.
2. Densidade com clareza: muitas conversas visíveis sem sacrificar leitura e operação.
3. Compatibilidade: recursos novos reutilizam os fluxos nativos e não quebram o atendimento existente.
4. Acessibilidade operacional: navegação por teclado, nomes acessíveis, foco visível e responsividade móvel.

## Decisões desta superfície

- Máximo de quatro conversas abertas simultaneamente.
- Layouts sugeridos de um, dois, três e quatro painéis.
- Persistência local do último layout e das conversas fixadas.
- Confirmação explicativa antes de abrir o modo focado em uma nova janela.

## Pontos ainda inferidos

- A seleção de conversas deverá reutilizar a pesquisa e os filtros já existentes sempre que possível.
- Em telas estreitas, o modo focado exibirá um painel por vez com troca rápida entre conversas abertas.
