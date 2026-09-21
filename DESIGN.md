# RottaWoot — sistema visual

## Direção

O produto herda a linguagem operacional do Chatwoot customizado: alta densidade, superfícies claras, divisórias discretas, tipografia compacta e a cor de marca aplicada apenas a seleção, foco e ações primárias.

## Regras duráveis

- Priorizar área útil de conversa; navegação e controles devem ocupar o mínimo necessário.
- Usar tokens `n-*` existentes para preservar temas claro/escuro e contraste.
- Divisórias de 1 px separam regiões operacionais; elevação só quando houver sobreposição real.
- Controles compactos mantêm alvo clicável e foco de teclado visível.
- Estados selecionado, vazio, carregando, erro e desabilitado precisam ser explícitos.
- Em telas estreitas, reduzir simultaneidade sem comprimir o conteúdo da conversa: um painel visível por vez.

## Central focada de conversas

- Cabeçalho curto com identidade da função e seletor de 1–4 painéis.
- Lista de clientes fixa à esquerda no desktop, estreita no celular.
- Painéis reutilizam a conversa nativa em instâncias isoladas, evitando divergência funcional.
- Conversas podem ser abertas por clique ou arrastadas diretamente da fila para um painel.
- Cada painel aceita redimensionamento horizontal manual e preserva a largura escolhida.
- O arranjo é persistido localmente e restaurado na abertura seguinte.
