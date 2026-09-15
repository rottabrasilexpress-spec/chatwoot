# Auditoria de carregamento do Chatwoot — 2026-09-15

## Sintoma

Foi relatado que o Chatwoot não estava carregando.

## Verificações realizadas

- `GET /health`: HTTP `200`, corpo `{"status":"woot"}`.
- `GET /app/login`: HTTP `200`.
- `GET /app/accounts/1/dashboard`: HTTP `200`.
- EasyPanel: último deploy `fix(inbox): reset pagination gate on scope changes` finalizado com `Success`.
- Containers Rails, Sidekiq e Sidekiq UAZAPI permaneceram `Running`.
- Chrome: após reload controlado, a lista de conversas, a conversa `#628` e o histórico carregaram normalmente.
- Edge: Follow-up carregou e mostrou `Na fila 0`, `Prontos agora 0` e `Etapas ativas 0`.
- Console do navegador: nenhum erro ou warning capturado nas sessões verificadas.

## Conclusão

Não há indisponibilidade ativa do Chatwoot nem falha reproduzível no servidor. O evento observado foi compatível com a breve janela de troca de containers/bundles durante a publicação ou com uma aba mantendo estado/cache antigo. A recarga controlada recuperou a sessão sem alteração de dados funcionais.

## Orientação operacional

Se voltar a ocorrer, abrir diretamente `https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/login` ou fazer recarga forçada. Antes de qualquer nova alteração, coletar horário, URL e mensagem exibida para correlacionar com os logs do EasyPanel.

## Referências

- Código publicado: [`6d0d1d9b`](https://github.com/rottabrasilexpress-spec/chatwoot/commit/6d0d1d9b).
- Deploy: [EasyPanel — Chatwoot Rotta](https://easypanel.via-cargo.com/projects/n8nsaas/compose/chatwoot-rotta/deployments).
- Serviço: [Chatwoot Rotta](https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/app/accounts/1/dashboard).
