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

## Checkpoint C53 — matriz ampliada e correção de largura persistida em tablet — 11/09/2026

- A matriz ampliada encontrou um caso real em `768x1024`: uma largura de lista salva em `640px` fazia o cabeçalho terminar fora da viewport, embora o documento não denunciasse overflow. A correção ficou restrita a `ChatList.vue`: entre `768px` e `1023px`, a lista pode encolher (`flex-shrink: 1; min-width: 0`) sem alterar a largura salva nem a lógica da lista.
- O commit `e891a24` foi enviado ao GitHub (`origin/rotta-custom-v1`) e implantado no Easypanel. O bundle live passou a servir `dashboard-DgU-tDL8.css`.
- Dashboard live pós-deploy: `280x600`, `320x568`, `360x640`, `375x667`, `390x844`, `414x896`, `480x800`, `540x720`, `768x1024`, `800x600`, `1024x768`, `1280x800` e `1920x1080`. Em todos: cabeçalho presente, sem sobreposição, sem overflow do cabeçalho/documento, dentro da viewport e com conversas renderizadas.
- A implantação teve uma indisponibilidade transitória durante a reinicialização; após a recuperação, a tela voltou a carregar e a conexão ao vivo ficou estabelecida. Um `502` capturado às `18:22:52 BRT` pertence à janela de startup; não houve novo erro nas validações posteriores dessa versão.

## Checkpoint C54 — correção final da aba em 280px e validação final — 11/09/2026

- A matriz do Follow-up encontrou em `280x600` um overflow interno de 4px na aba `Trilha de orçamento` (`scrollWidth 94` contra `clientWidth 90`). Foi corrigido somente o CSS de até `320px` em `FollowUp.vue`, empilhando label e contador e reduzindo o espaçamento interno; a lógica e os dados não foram tocados.
- O commit `054835b` foi enviado ao GitHub e implantado no Easypanel. Build final: `5.079` módulos transformados; verificador do manifesto: `240` assets referenciados e nenhum ausente. O bundle live final serviu `dashboard-BZfb-w9n.css`.
- Follow-up live pós-deploy: `280x600`, `320x568`, `360x640`, `375x667`, `390x844`, `414x896`, `480x800`, `540x720`, `768x1024`, `800x600`, `1024x768`, `1280x800` e `1920x1080`. Em todos, as duas abas ficaram dentro do contêiner, `scrollWidth == clientWidth`, sem overflow interno dos botões e sem overflow horizontal do documento.
- Dashboard com o bundle final foi rechecado em `280x600`, `768x1024` e `1920x1080`: sem indisponibilidade, sobreposição ou overflow; a lista carregou conversas sem scroll inicial. A viewport temporária foi restaurada ao tamanho normal ao final.
- O estado funcional permaneceu fora do escopo; `.audit-antonio/relacao-de-bens.docx` continuou não rastreado. O console reteve somente o `502` transitório da inicialização descrito no C53; a interface ficou estável nas verificações finais.
