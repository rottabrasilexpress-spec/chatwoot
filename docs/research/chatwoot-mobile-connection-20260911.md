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

Na auditoria web de hoje, a instalação base respondeu normalmente e a conta carregou conversas; por isso, se o app aceitar a base e ainda mostrar uma conta vazia, o próximo diagnóstico é limpar a instalação/sessão salva e comparar a versão do app, permissões do agente e conexão WebSocket. Não há evidência, nesta etapa, de que `/app/login` seja um endpoint correto para o campo móvel.
