# Gauntlet — Implementações operacionais Rotta/Chatwoot

Data de início: 2026-09-11  
Branch de trabalho: `codex/rotta-objective-20260911`  
Base: `rotta-custom-v1` (`cfeb0630a`)  
Deploy alvo: Easypanel/Chatwoot Rotta

## Contrato

### Por quê

Entregar quatro melhorias solicitadas para o atendimento no Chatwoot sem quebrar o fluxo existente de conversas, Follow-up, etiquetas, WhatsApp ou IA.

### O quê

1. Menu de contexto: remover reabrir/pendente e adicionar `Solicitar Atenção`, restrito ao agente autorizado, com aviso interno direcionado ao Caio e dados do cliente.
2. Etiqueta `Caio Atenção`: alerta visual e sonoro para o agente Caio quando a etiqueta for aplicada.
3. Mensagens apagadas pelo cliente: retenção interna por dois dias e visualização somente para agentes autorizados.
4. Composer: permitir reduzir mais a área e diferenciar transcrição por áudio de gravação de áudio para envio.

### Fora do escopo

Alterar o motor de Follow-up, os workflows UAZAPI/n8n ou a aparência/fluxos já estabilizados sem necessidade técnica direta.

## Régua AAA fixada

| Critério | Peso |
|---|---:|
| Correção | 25 |
| Completude | 20 |
| Verificação | 20 |
| Coerência integrada | 15 |
| Utilidade | 10 |
| Acabamento | 10 |

Gate: nota total >= 95, nenhum critério < 90, zero falha crítica e todos os testes obrigatórios aprovados.

## Microtarefas

| ID | Objetivo | Dono | Arquivos próprios | Aceite local | Estado |
|---|---|---|---|---|---|
| M1 | Implementar ação `Solicitar Atenção` com autorização e aviso interno | especialista de conversas | menu/ações de conversa, endpoint/serviço próprio, specs correspondentes | agente não autorizado não executa; Caio recebe aviso sem mensagem pública | planejada |
| M2 | Implementar alerta de `Caio Atenção` | especialista de etiquetas/notificações | componentes de sidebar/notificação, canal/evento e specs correspondentes | aplicação da etiqueta gera alerta apenas no alvo e sem duplicação | planejada |
| M3 | Reter e exibir mensagem apagada por dois dias | especialista de mensagens | modelo/migration/serviço/bubble e specs correspondentes | cliente não vê conteúdo; agente autorizado vê até TTL; após TTL não vê | planejada |
| M4 | Ajustar composer e separar transcrição de gravação | especialista de composer/áudio | composer, recorder/transcriber, i18n e specs correspondentes | controles distintos; gravação envia áudio; transcrição envia texto pt-BR | planejada |
| I1 | Integrar, publicar manifestos/assets e validar E2E | controlador | interfaces compartilhadas, testes integrados, ledger | testes automatizados e navegador aprovados | pendente |
| R1 | Revisão independente AAA do snapshot integrado | revisor independente | nenhum | relatório com nota e veto por critério | pendente |

## Hipóteses iniciais verificáveis

1. O fork já possui pontos de extensão para Follow-up, IA e etiquetas; cada implementação deve reutilizar os canais existentes antes de criar infraestrutura nova.
2. A autorização de `Solicitar Atenção` precisa ser aplicada no backend, não apenas ocultada no menu.
3. O evento de etiqueta já chega ao frontend por Action Cable, mas o alerta deve deduplicar por conversa/etiqueta/evento.
4. A exclusão atual de mensagem pode preservar metadados, mas não conteúdo; a retenção deve ser independente do texto público renderizado.
5. O composer já possui gravação ou transcrição parcial; a entrega deve separar ações sem duplicar upload ou envio público.

## Checkpoints

| Rodada | Snapshot | Estado | Evidência | Nota |
|---:|---|---|---|---:|
| 0 | `cfeb0630a` | base limpa inspecionada | branch `rotta-custom-v1` e working tree limpos | — |

