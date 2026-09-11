# Auditoria de responsividade do Chatwoot — 11/09/2026

## Escopo

Validar a interface do Chatwoot em desktop, tablet e mobile, preservando o comportamento funcional já existente. Esta rodada não altera etiquetas, Follow-up, WhatsApp, API, histórico, permissões ou regras de negócio.

## Evidência antes da alteração

- Em `320x568`, o cabeçalho da lista de conversas sobrepunha os controles `Ler tudo` e `Filtrar por etiqueta`.
- Em `390x844`, a lista ocupava a largura disponível e carregava as conversas sem scroll inicial.
- Em `768x1024`, a navegação e a lista se ajustavam sem overflow horizontal do documento.
- Na conversa aberta, o perfil do contato usava painel sobreposto no mobile, com fechamento disponível, preservando a área principal.
- No Follow-up em `320x568`, as abas `Trilha de contato` e `Trilha de orçamento` usavam largura mínima fixa; a segunda aba ficava parcialmente cortada.

## Alteração aplicada

- `ChatListHeader.vue`: em larguras de até `479px`, o cabeçalho passa a quebrar os controles em duas linhas, eliminando a sobreposição sem remover ações.
- `FollowUp.vue`: em larguras de até `640px`, as abas passam a dividir a largura disponível em duas colunas, permitindo quebra de texto sem corte horizontal.

## Validação local

- `vite build --config vite.config.ts`: aprovado; 5.079 módulos transformados e build final concluído em 58s.
- `git diff --check`: aprovado para os arquivos alterados.
- ESLint focalizado: o checkout possui arquivos com CRLF enquanto o Prettier exige LF; o lint reportou a conversão de fim de linha em praticamente todo o conteúdo preexistente. Nenhum arquivo foi reformatado em massa para evitar diff fora do escopo. O componente Follow-up manteve somente os warnings preexistentes de formatação de tags.

## Publicação e validação live

- O primeiro deploy (`a125e67`) confirmou que o container copia `public/vite` diretamente e não recompila o front-end; por isso, os assets gerados precisaram ser publicados junto com o código.
- O ajuste de precedência do Follow-up foi publicado em `aa5d614`, com o manifesto Vite e somente os 14 assets novos referenciados. O verificador confirmou 240 assets referenciados e nenhum ausente.
- Easypanel confirmou `Compose implantado` e o domínio passou a servir `dashboard-Cl8CPd29.css`.
- Dashboard live: `320x568`, `390x844`, `480x800`, `768x1024` e `1440x900` sem overflow horizontal; o cabeçalho não sobrepõe controles e a lista renderiza conversas imediatamente, sem scroll inicial.
- Follow-up live: em `320x568`, as abas ficaram em `110.125px + 110.125px`, com `scrollWidth 233 = clientWidth 233`; em `390x844`, `480x800` e `768x1024`, também não houve corte nem overflow.
- Conversa live em `390x844`: histórico, composer e painel `Contatos`/`Perfil da mudança` presentes; o painel sobreposto permaneceu utilizável e o documento não teve overflow horizontal.
- Console do navegador após a bateria: zero erros.

## Critério de aceite live

Após o deploy, repetir a captura em `320x568`, `390x844`, `480x800`, `768x1024` e no viewport desktop. Aceitar somente se:

- os controles do cabeçalho não se sobrepuserem;
- as duas abas do Follow-up forem integralmente visíveis e utilizáveis;
- a lista continuar carregando automaticamente;
- não houver overflow horizontal do documento;
- conversa, perfil, composer e navegação mantiverem o comportamento funcional anterior.

Resultado: aprovado nos tamanhos testados. A alteração ficou restrita ao layout responsivo e aos assets necessários para servi-lo em produção; `.audit-antonio/` permaneceu fora do commit.
