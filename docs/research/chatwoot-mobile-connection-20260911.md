# Diagnóstico de conexão do aplicativo móvel do Chatwoot — 2026-09-11

## Conclusão

O campo **Installation URL** do aplicativo deve receber a URL-base do servidor, sem a rota `/app/login`:

```text
atendimento.via-cargo.com
```

Como alternativa equivalente, desde que o aplicativo esteja apontando para a mesma instalação:

```text
n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host
```

O servidor não apresentou falha básica de DNS, HTTPS ou saúde do Chatwoot durante a verificação. Os dois domínios responderam `200` na raiz e em `/app/login`, e `/api` retornou Chatwoot `4.17.0` com `queue_services: ok` e `data_services: ok`. A consulta não autenticada a `/api/v1/profile` retornou `401`, que é o comportamento esperado antes do login.

## O que a documentação oficial determina

O guia oficial para Android e o guia oficial para iOS orientam informar o servidor no formato `domain.com`; para instalação self-hosted, deve ser usada a URL do próprio servidor, e depois o agente entra com as credenciais. Isso não corresponde a informar `/app/login` como valor do campo.

- [Guia oficial do aplicativo Android](https://www.chatwoot.com/hc/user-guide/articles/1677777866-mobile-app-for-android)
- [Guia oficial do aplicativo iOS](https://www.chatwoot.com/hc/user-guide/articles/1677776959-mobile-app-for-i_os)
- [Página oficial do Chatwoot Mobile Apps](https://www.chatwoot.com/mobile-apps)

## Hipóteses mais prováveis

1. **Rota digitada no campo:** usar `/app/login` não é o formato documentado. Deve ser usado somente o host, preferencialmente `atendimento.via-cargo.com`.
2. **Bug/limitação do aplicativo nativo:** há um relato oficial em que a inbox WhatsApp Cloud não aparece no aplicativo, embora funcione normalmente na web, mesmo com o agente colaborador da inbox e após reinstalação. O sintoma é muito próximo do caso relatado.
   - [Issue #1107 — WhatsApp inbox ausente no mobile](https://github.com/chatwoot/chatwoot-mobile-app/issues/1107)
3. **Atualização em tempo real no iOS:** há outro relato oficial exatamente com a necessidade de sair e reabrir a conversa para receber mensagens novas, enquanto a web atualiza normalmente.
   - [Issue #1114 — mensagens não atualizam em tempo real no iOS](https://github.com/chatwoot/chatwoot-mobile-app/issues/1114)
4. **Permissão da inbox:** a documentação do Chatwoot informa que a associação do agente às inboxes é explícita; ser membro da conta não garante acesso a cada inbox.
   - [Documentação oficial sobre canais e inboxes](https://www.chatwoot.com/hc/user-guide/articles/1677492191-adding-inboxes)

## Procedimento recomendado

1. No aplicativo, remover a configuração salva do servidor, se houver essa opção, e informar `atendimento.via-cargo.com` — sem `/app/login` e sem misturar o domínio `app.chatwoot.com`.
2. Entrar com o mesmo usuário que funciona na web.
3. Na web, confirmar em **Configurações → Inboxes → WhatsApp → Colaboradores** que esse usuário está vinculado à inbox WhatsApp correta.
4. Confirmar que o aplicativo mostra a mesma conta/organização do Chatwoot.
5. Se a conta entrar, mas a inbox WhatsApp continuar ausente ou vazia, testar o outro host-base (`n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host`) apenas como diagnóstico. Se ambos derem o mesmo resultado, a URL não é a causa provável.
6. Atualizar o aplicativo para a versão mais recente disponível. Se persistir, registrar versão do app, iOS, versão do servidor e se outras inboxes aparecem; esse conjunto de informações é o necessário para comparar com as issues oficiais acima.

## Limite do diagnóstico

Não há acesso ao iPhone físico nem aos logs internos do aplicativo nesta sessão. Portanto, não é possível afirmar qual das duas falhas móveis ocorre no dispositivo sem observar se a conta entra e se a inbox WhatsApp aparece. A evidência do servidor, porém, não indica erro de URL, SSL ou indisponibilidade do Chatwoot.

## Observação sobre o fork

Alterações visuais feitas no fork web não aparecem automaticamente no aplicativo nativo. O aplicativo móvel tem sua própria interface e só reutiliza as APIs do servidor. Assim, a ausência das customizações visuais no app pode ser normal; já a ausência de conversas/inbox aponta para autorização, compatibilidade da API ou bug do app móvel.

## Addendum — confirmação na documentação oficial atual (12/09/2026)

A página oficial de Mobile Apps do Chatwoot continua descrevendo o campo como **Installation URL** e exemplifica somente o domínio do servidor (`chatwoot.yourcompany.com`). O guia oficial de Android explicita `domain.com` e orienta usar a URL do servidor na instalação self-hosted. Portanto, para reduzir a chance de rejeição no aplicativo, usar nesta ordem:

1. `n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host` (somente domínio, sem rota); ou
2. `https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host` se a versão instalada aceitar o esquema HTTPS.

Não usar `/app/login`, `/app/accounts/1/dashboard`, `/app/accounts/1/conversations/...` nem `app.chatwoot.com`. A rota `/app/login` serve para o navegador; o aplicativo precisa do host para montar as chamadas de autenticação e API. Fontes: [Chatwoot Mobile Apps](https://www.chatwoot.com/mobile-apps) e [guia oficial Android](https://www.chatwoot.com/hc/user-guide/articles/1677777866-mobile-app-for-android).

Na auditoria web de hoje, a instalação base respondeu normalmente e a conta carregou conversas. A inspeção do HTML público de ambas as entradas mostrou `chatwootConfig.hostURL = https://atendimento.via-cargo.com`; portanto, este é o endereço público canônico e deve ser o primeiro valor testado no aplicativo:

```text
atendimento.via-cargo.com
```

O domínio `n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host` é um alias funcional do serviço (raiz e `/app/login` responderam HTTP 200 e a sessão web carregou os mesmos dados), mas não é o `hostURL` canônico anunciado pelo Chatwoot. Não há evidência de que `/app/login` seja um endpoint correto para o campo móvel.

Durante a recarga forçada da auditoria, o banner `Desconectado` apareceu e permaneceu por cerca de 20 segundos tanto no alias quanto no domínio canônico, embora histórico e lista continuassem carregados. Isso é uma pendência separada de Action Cable/tempo real; não deve ser usado como justificativa para trocar a URL no aplicativo.

Se o app aceitar a base e ainda mostrar uma conta vazia, o próximo diagnóstico é limpar a instalação/sessão salva, comparar a versão do app e validar permissões do agente e compatibilidade da inbox. A evidência do servidor não indica erro de DNS, HTTPS ou indisponibilidade básica.

## Addendum — causa técnica no aplicativo estável e correção oficial posterior — 12/09/2026

### Causa mais provável

A página oficial de releases lista `v4.9.0` como a versão estável mais recente do aplicativo no momento desta auditoria. O código da tag `v4.9.0` contém duas decisões incompatíveis:

1. `checkValidUrl` valida o texto bruto com `new URL(url)`, portanto o formato documentado `domain.com` pode ser rejeitado antes da conexão.
2. Depois de extrair o domínio para a API, a mesma versão monta o WebSocket usando o texto bruto (`wss://${url}/cable`). Se o valor digitado contém `https://`, isso pode resultar em `wss://https://.../cable`, que não conecta.

Esses pontos são observáveis no código oficial da tag [v4.9.0/settingsActions.ts](https://raw.githubusercontent.com/chatwoot/chatwoot-mobile-app/v4.9.0/src/store/settings/settingsActions.ts) e [v4.9.0/settingsUtils.ts](https://raw.githubusercontent.com/chatwoot/chatwoot-mobile-app/v4.9.0/src/store/settings/settingsUtils.ts).

O projeto oficial corrigiu exatamente essa combinação no commit [b33a43e — “build the websocket URL from the normalized host”](https://github.com/chatwoot/chatwoot-mobile-app/commit/b33a43e7111b0ea0c1ed52dd6d85731b3b464736), de 02/09/2026. A correção normaliza o host, monta `wss://<host>/cable` a partir dele, rejeita espaços e repara um WebSocket antigo salvo no armazenamento. O release estável `v4.9.0` foi publicado em 18/08/2026 e não lista esse commit em seu changelog; portanto, a disponibilidade dessa correção depende de uma nova versão do app ou de uma versão beta que já a contenha.

### Prova no servidor desta instalação

- `https://atendimento.via-cargo.com/api`: HTTP 200, Chatwoot `4.17.0`, `queue_services: ok`, `data_services: ok`.
- `https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/api`: o mesmo resultado.
- `/api/v1/profile` retorna HTTP 401 sem autenticação nos dois hosts, comportamento esperado antes do login.
- Raiz e `/app/login` retornam HTTP 200 nos dois hosts.

Logo, a API básica, o HTTPS e a saúde do servidor não são a causa principal observada; o problema mais provável é o app estável ainda conter a montagem incorreta do endpoint em tempo real ou manter uma URL/WebSocket antigo salvo.

### Procedimento exato

1. Atualizar o aplicativo pela App Store para uma versão que contenha a correção `b33a43e` (ou usar a versão beta oficial, se a atualização estável ainda não a incluir).
2. Remover a configuração/sessão salva do servidor no app; se não houver essa opção, desinstalar e instalar novamente.
3. Após a atualização, informar somente:

   ```text
   atendimento.via-cargo.com
   ```

   Sem `https://`, sem `/app/login`, sem `/app/accounts/...` e sem `app.chatwoot.com`.
4. Entrar com o mesmo usuário da web e confirmar que ele está associado à inbox WhatsApp correta.
5. Se ainda falhar, anotar a versão exibida no app, a versão do iOS e a mensagem exata. Com a versão `v4.9.0`, não existe um formato de entrada que seja simultaneamente confiável: o host puro segue a documentação mas pode ser rejeitado pela validação antiga; a URL absoluta pode passar da validação, mas deixa o WebSocket malformado.

Enquanto a versão corrigida não estiver disponível, a alternativa segura é usar a web/PWA pelo domínio canônico. Não há necessidade de mudar o deploy do Chatwoot para corrigir esse defeito do aplicativo nativo.

## Addendum — confirmação do endereço canônico e do comportamento live (12/09/2026)

- `https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/` e `/app/login`: HTTP 200.
- `https://atendimento.via-cargo.com/` e `/app/login`: HTTP 200.
- Em ambos os hosts, o HTML anuncia `hostURL: 'https://atendimento.via-cargo.com'`.
- O navegador autenticado abriu a mesma conta/conversas nos dois hosts.
- No aplicativo, informar primeiro **somente** `atendimento.via-cargo.com` — sem `https://`, sem `/app/login` e sem `/app/accounts/...`. Se a versão do app aceitar esquema, `https://atendimento.via-cargo.com` é equivalente; o formato documentado continua sendo `domain.com`.
- Ao recarregar o navegador, o banner `Desconectado` foi observado nos dois hosts. Isso exige investigação própria de conexão em tempo real/WebSocket; não muda a recomendação de URL do aplicativo.

## Addendum — verificação oficial do fluxo do app e teste live do endpoint — 12/09/2026

### O que o app realmente faz

O código oficial atual do aplicativo confirma que o campo não é uma página de login:

- `setInstallationUrl` extrai somente o host, monta `https://<host>/` e valida `GET <host>/api`.
- As chamadas autenticadas usam essa base e acrescentam `api/v1/...`.
- O WebSocket é montado como `wss://<host>/cable`.

Fontes primárias: [ConfigURLScreen.tsx](https://raw.githubusercontent.com/chatwoot/chatwoot-mobile-app/develop/src/screens/auth/ConfigURLScreen.tsx), [settingsActions.ts](https://raw.githubusercontent.com/chatwoot/chatwoot-mobile-app/develop/src/store/settings/settingsActions.ts), [settingsService.ts](https://raw.githubusercontent.com/chatwoot/chatwoot-mobile-app/develop/src/store/settings/settingsService.ts), [settingsUtils.ts](https://raw.githubusercontent.com/chatwoot/chatwoot-mobile-app/develop/src/store/settings/settingsUtils.ts) e [APIService.ts](https://raw.githubusercontent.com/chatwoot/chatwoot-mobile-app/develop/src/services/APIService.ts).

### Teste da instalação Rotta

Em 12/09/2026, sem autenticação e sem alteração de dados:

| Endereço | Resultado |
|---|---|
| `https://atendimento.via-cargo.com/api` | HTTP 200; JSON; Chatwoot 4.17.0; `queue_services: ok`; `data_services: ok` |
| `https://n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host/api` | Mesmo resultado |
| `https://atendimento.via-cargo.com/app/login/api` | HTTP 200, mas `text/html` — não é API |
| `https://atendimento.via-cargo.com/api/v1/accounts/1/conversations` | HTTP 401 sem autenticação — resposta esperada antes do login |

Portanto, o valor correto para o campo do aplicativo é o host, preferencialmente:

```text
atendimento.via-cargo.com
```

Não usar `https://atendimento.via-cargo.com/app/login`, nem uma URL de dashboard/conversa. O alias `n8nsaas-chatwoot-rotta.u9nqzz.easypanel.host` responde, mas o HTML público da instalação anuncia `atendimento.via-cargo.com` como `hostURL`; por isso o domínio canônico é o primeiro teste.

### Procedimento fechado para o iPhone

1. Atualizar o Chatwoot pela App Store.
2. Sair da conta no app; se o campo/URL anterior permanecer salvo, apagar o app e instalar novamente para limpar a configuração persistida.
3. No campo **URL de instalação**, digitar exatamente `atendimento.via-cargo.com`, sem `https://`, sem `/` e sem `/app/login`.
4. Tocar em **Conectar** e entrar com o mesmo usuário agente que funciona na web.
5. Se entrar numa conta vazia, conferir na web o seletor de conta e em **Configurações → Inboxes → WhatsApp → Colaboradores** se esse usuário está vinculado à inbox WhatsApp.
6. Se a URL for aceita, mas as conversas continuarem ausentes, anotar a versão do app, iOS, conta selecionada e se alguma outra inbox aparece. Nesse ponto a URL deixa de ser a hipótese principal; resta autorização da inbox, conta selecionada ou bug do app móvel.

O app oficial declara compatibilidade com Chatwoot `3.13.0+`; a instalação testada está em `4.17.0`. A página oficial também confirma compatibilidade com instalações self-hosted e o formato de domínio no campo: [Mobile Apps](https://www.chatwoot.com/mobile-apps), [guia Android](https://www.chatwoot.com/hc/user-guide/articles/1677777866-mobile-app-for-android) e [repositório oficial do app](https://github.com/chatwoot/chatwoot-mobile-app).

## Addendum — estado atual do aplicativo iOS e correção oficial — 12/09/2026

- A página oficial da App Store lista atualmente o Chatwoot para iOS na versão `4.9.3`, publicada em 02/09, e exige iOS 16.4 ou posterior: [Chatwoot na App Store](https://apps.apple.com/us/app/chatwoot/id1495796682).
- O commit oficial `b33a43e7111b0ea0c1ed52dd6d85731b3b464736` (#1151), de 02/09, corrige a causa encontrada: o aplicativo antigo derivava a API do host normalizado, mas montava o WebSocket a partir do texto bruto; com `https://host` isso gerava `wss://https://host/cable`. A correção passa a construir ambos a partir do host extraído, rejeita espaços e repara um WebSocket antigo persistido: [commit oficial](https://github.com/chatwoot/chatwoot-mobile-app/commit/b33a43e7111b0ea0c1ed52dd6d85731b3b464736).
- A data coincide com a versão `4.9.3` exibida na App Store, mas a página pública não fornece o mapeamento binário commit-versão; por isso a conclusão operacional é atualizar para a versão mais recente e testar novamente, não afirmar uma prova de binário interno.
- O formato recomendado permanece exatamente `atendimento.via-cargo.com` — sem `https://`, sem `/app/login`, sem `/app/accounts/...` e sem espaços. Se a versão atual ainda não aceitar ou conectar, a hipótese deixa de ser a URL/servidor e passa a ser sessão persistida ou bug do app; nesse caso, sair, apagar/reinstalar, atualizar e registrar a versão do app/iOS são os próximos passos.
