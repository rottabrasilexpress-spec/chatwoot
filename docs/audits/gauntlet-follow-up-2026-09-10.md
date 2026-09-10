# Gauntlet — Follow-up lento e contadores fantasmas

Data: 2026-09-10  
Branch: `rotta-gauntlet-20260909` → publicação autorizada em `rotta-custom-v1`  
Baseline: `0e68ca8`  

## Contrato

### Por quê

Eliminar os números fantasmas do Follow-up e reduzir o atraso ao abrir uma conversa com duplo clique.

### O quê

Reproduzir no Chatwoot real, medir o atraso e requests sobrepostos, localizar o caminho que reintroduz estado stale, corrigir somente esse fluxo, criar regressão, publicar e validar novamente. WhatsApp Web, envio de mensagens, n8n/UAZAPI e exclusão de histórico ficam fora.

### Como

Diagnóstico live + auditoria estática em paralelo; regressão no seam correto; integração mínima; deploy controlado; repetição do cenário original; revisão AAA independente.

## Hipóteses ranqueadas

1. Duplo clique dispara duas navegações/reconciliações sobrepostas.
2. O card abre antes de limpar o estado/rota do quadro e espera por dados antigos.
3. Algum caminho ainda usa `body.counts` ou histórico externo sem `reconciledJobs`.
4. ActionCable/refresh de etiquetas reintroduz jobs stale depois da reconciliação inicial.
5. Sidebar e Follow-up usam fontes diferentes e chegam em ordens distintas.

## Microtarefas e allowlists

| ID | Dono | Objetivo | Arquivos próprios | Aceite | Dependências |
|---|---|---|---|---|---|
| M1 | controlador | Reproduzir e medir no Chatwoot real | nenhum | uma captura red-capable com tempo, DOM e requests | — |
| M2 | agente diagnóstico | Auditar os caminhos de Follow-up, labels e abertura | somente relatório; sem edição | causa provável e pontos de instrumentação | — |
| M3 | controlador | Fixar regressão no seam confirmado | arquivo de spec focalizado | falha antes do fix e passa depois | M1/M2 |
| M4 | agente executor | Implementar correção mínima | arquivos Vue/helper definidos após M2 | lint/teste local do escopo | M3 |
| M5 | controlador | Integrar, buildar e testar original | arquivos da implementação + audit | build, regressão e loop live verdes | M4 |
| M6 | revisor AAA | Revisar snapshot integrado independente | nenhum | nota ≥95, todos critérios ≥90, zero falhas críticas | M5 |

## Régua AAA fixada

Correção 25, Completude 20, Verificação 20, Coerência integrada 15, Utilidade 10, Acabamento 10. AAA exige total ≥95, nenhum critério abaixo de 90, zero falhas críticas e todos os testes obrigatórios aprovados.

## Registro de rodadas

| Rodada | Estado | Hash | Evidência | Nota |
|---|---|---|---|---|
| 1 | diagnóstico iniciado | `0e68ca8` | M1/M2 pendentes | — |
