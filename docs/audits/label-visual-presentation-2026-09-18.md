# Auditoria — identidade visual das etiquetas

Data: 2026-09-18  
Escopo: frontend do Chatwoot Rotta, somente apresentação visual das etiquetas.

## Objetivo

Permitir escolher a aparência das etiquetas sem alterar a semântica das etiquetas, follow-up, envio de mensagens, arquivamento ou sincronização.

## Implementação

- `Quadrado` é o padrão e preserva o formato existente.
- `Redondo` aplica cantos totalmente arredondados.
- `Nítido` reforça borda e contraste mantendo o chip compacto.
- `Contorno da mensagem` aplica uma borda fina com a cor da primeira etiqueta ativa ao balão da conversa.
- A escolha fica persistida por conta no `localStorage` do navegador e é reativa entre abas via evento `storage`.
- Os chips do card, perfil/conversa e atalho do cabeçalho recebem a mesma apresentação.
- A apresentação de contorno é opt-in e não toca no conteúdo ou no envio das mensagens.

## Segurança de escopo

Não foram alterados endpoints, stores de mutação de etiquetas, workflows n8n, regras de follow-up ou status da conversa. A borda da mensagem só é adicionada quando a apresentação `message-border` está selecionada e existe uma etiqueta ativa.

## Validação local

- `corepack pnpm exec vite build --mode production`: aprovado; 5.105 módulos transformados.
- ESLint dos arquivos alterados: aprovado.
- Prettier dos arquivos alterados: aprovado.
- Detector Impeccable: aprovado sem achados.
- Vitest focado: bloqueado antes da coleta por `fake-indexeddb` resolvido via checkout irmão `work/chatwoot-source`; não foi reportado como aprovação.

## Pós-deploy obrigatório

1. Publicar a branch no GitHub/EasyPanel.
2. Abrir Configurações → Etiquetas no Chrome.
3. Conferir as quatro prévias em desktop e viewport estreito.
4. Selecionar cada opção e confirmar atualização dinâmica em card, perfil e conversa.
5. Selecionar `Contorno da mensagem` com uma conversa etiquetada e confirmar a borda fina; voltar a `Quadrado` e confirmar que a borda desaparece.
