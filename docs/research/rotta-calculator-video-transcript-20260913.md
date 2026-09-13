# Transcrição e auditoria visual — vídeo da Calculadora Rotta

Data da auditoria: 2026-09-13

## Fonte

- Arquivo: `C:\Users\User\AppData\Local\Packages\Microsoft.ScreenSketch_8wekyb3d8bbwe\TempState\Recordings\20260913-1641-57.0463571.mp4`
- Duração: 81,109 s
- Método: revisão visual por quadros e transcrição local em português com `faster-whisper` medium, seguida de conferência manual do sentido.
- O vídeo anexado anteriormente `20260913-0158-44.8167241.mp4` também foi revisado no ciclo anterior e permanece registrado no ledger.

## Transcrição conferida

| Tempo | Fala |
|---|---|
| 00:00–00:06 | Continuando, agora a gente vai para essa parte, que é o detalhamento financeiro, né? |
| 00:06–00:10 | Que basicamente está extremamente confuso aqui. |
| 00:10–00:13 | Isso está muito embolado, está pegando as duas páginas. |
| 00:13–00:21 | Na hora que tem uma partição aqui, que ela se desfaça, aqui ela já acabou, não existe mais essa partição, né? |
| 00:21–00:25 | E vem todo esse resultado de operação, que, assim, está muito confuso. |
| 00:25–00:29 | Nós precisamos ajustar, eliminar o que não for preciso, tá? |
| 00:29–00:33 | Cards enormes, tá vendo? O outro é extremamente mais compacto. |
| 00:33–00:36 | E não está dando para clicar. |
| 00:36–00:40 | Note aqui, ao clicar não muda o outro não. |
| 00:40–00:42 | Olha aqui, olha como vem organizadinho. |
| 00:42–00:47 | Preciso que venha nessa organização e olhe como os cards são clicáveis. |
| 00:47–00:51 | Assim como esse motor de ajuste adicional. |
| 00:51–00:53 | Ok. |
| 00:53–00:57 | E por fim, vem a mensagem pronta, né? |
| 00:57–01:01 | Que você colocou aqui, mas note, o campo está muito pequeno. |
| 01:01–01:04 | Precisa que esse campo seja grande, esse campo da mensagem. |
| 01:04–01:09 | Para conseguir copiar, para ver o inventário, o inventário também precisa copiar, tá? |
| 01:09–01:14 | E tem um texto correto, esse texto você mesmo irá extrair. |
| 01:14–01:18 | Você irá extrair esse texto exatamente igual daqui, ok? |
| 01:18–01:21 | Então precisamos adaptar isso. |

## Requisitos extraídos

- Remover a poluição do detalhamento financeiro e separar resultado, preço, serviços e proposta.
- Usar cartões compactos, clicáveis e com estado selecionado visível.
- Manter o motor de ajuste adicional funcional e sem acumulação indevida.
- Exibir uma área grande para a mensagem pronta do WhatsApp.
- Exibir o inventário em área própria e permitir copiar proposta e inventário.
- Preservar a organização visual do Hub: leitura e mapa na mesma tela, serviços compactos e precificação separada.

## Verificação após a implementação

- Proposta e inventário foram publicados com `rows=14` e `min-h-[20rem]`.
- Bundle live confirmado: `dashboard-L18rxRjp.js`.
- O mapa foi desenhado no primeiro cálculo pós-deploy, sem clicar em `VER ROTA` para reparar os tiles.
- Cópia da proposta: confirmada, 591 caracteres no teste real.
- Cópia do inventário: confirmada, 81 caracteres no teste real.
- Seleção `Econômica` e restauração para `Padrão`: confirmadas no live.
- `Satélite` mudou o link do mapa para `t=k`; `Mapa` restaurou `t=m`.
- Nenhuma mensagem, conversa, etiqueta, contato ou credencial foi alterada durante a auditoria.

Linhas conectadas: [[Chatwoot Rotta — contexto e estado]] ↔ [ledger](../audits/gauntlet-2026-09-12-calculator-contact.md) ↔ [comparação Hub](rotta-calculator-hub-comparison-20260912.md) ↔ [GitHub rotta-custom-v1](https://github.com/rottabrasilexpress-spec/chatwoot/tree/rotta-custom-v1).
