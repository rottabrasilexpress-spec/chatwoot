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
