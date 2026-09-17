# LPS Neo

App Flutter (Android/iOS) dos sócios dos Leões de Porto Salvo. Consome a API do
Sócio (v1) servida pelo CISOC — o backend está noutro repositório, em
`C:\home\cisoc`.

## Sincronização com o CISOC

O backend (`C:\home\cisoc`) também é desenvolvido com o Claude, em paralelo.
Manter os dois projectos sincronizados sempre que possível:

- **Antes de implementar algo que use a API**, ver o que mudou no CISOC:
  `git -C C:\home\cisoc log --oneline -15`, o histórico do §9 de
  `api-socio-flutter.md` e o estado dos pedidos em `C:\home\cisoc\docs\pedidos-app\`.
- **Quando falta algo na API**, não contornar na app nem chamar outro servidor:
  escrever um pedido em `C:\home\cisoc\docs\pedidos-app\` (um ficheiro por
  pedido, e uma linha no `README.md` dessa pasta) e referi-lo aqui.
- **Quando um pedido passa a `feito`**, alinhar a app com o contrato publicado
  (guia + `openapi-v2.yaml`), não com o texto do pedido.
- Decisões de produto tomadas deste lado que afectem o backend (como as zonas da
  app) vão também para um pedido, para o CISOC as conhecer.

Pedidos abertos:

| Pedido | Bloqueia |
|--------|----------|
| `C:\home\cisoc\docs\pedidos-app\2026-09-16-contas-nao-socios.md` | Conta com email para não-sócios; associar conta a sócio; push para não-sócios |

## Referências para construir a app

Ler antes de implementar qualquer ecrã ou chamada à API.

### API (fonte principal)

| Ficheiro | Para quê |
|----------|----------|
| `C:\home\cisoc\docs\api-socio-flutter.md` | **Guia de integração da app.** Endpoints, respostas reais, erros, interceptor Dio, modelos Dart, ecrãs sugeridos (§6), armadilhas (§7), o que ainda não existe (§8) |
| `C:\home\cisoc\docs\contratos\openapi-v2.yaml` | Especificação OpenAPI formal (também servida em `/api/docs`) |

### Código do backend (quando o guia não chega)

| Caminho | Para quê |
|---------|----------|
| `C:\home\cisoc\app\Config\Routes.php` | Rotas — grupos `api/v1` (sócio) e `api/v2/publico` (público) |
| `C:\home\cisoc\modules\Content\Controllers\Api\` | Controllers da API pública (notícias) |
| `C:\home\cisoc\app\Controllers\Api\V1\` | Controllers da API (`Auth`, `Socio`, `Conta`, `Pagamentos`, `Suporte`, `Notificacoes`, `Dispositivos`, `Status`) |
| `C:\home\cisoc\app\Controllers\Api\V1\README.md` | Notas dos controllers da API |

### Contexto do CISOC

| Ficheiro | Para quê |
|----------|----------|
| `C:\home\cisoc\docs\ARQUITETURA-PLATAFORMA-LPS.md` | Desenho da plataforma: backend único para app, site e backoffice; autenticação; `/api/v1` congelada |
| `C:\home\cisoc\PLANO-BACKEND-LPS.md` | Plano de engenharia do backend (o que se constrói, por que ordem) |
| `C:\home\cisoc\docs\PLANO-EXECUCAO.md` | Plano de execução por fases |
| `C:\home\cisoc\docs\inventario-bd.md` | Tabelas da base de dados |
| `C:\home\cisoc\docs\inventario-legado.md` | Sistemas legados (incl. a API antiga) |
| `C:\home\cisoc\docs\runbooks\ambiente-local.md` | Pôr o CISOC a correr localmente (necessário para testar a app contra `localhost`) |

## Publicação

Código em `https://github.com/magicspiderdev/lpsapp` (branch `main`).

App escrita de raiz para **Android e iOS**. No Android **substitui a app antiga na
Play Store** (sem compatibilidade com ela), por isso mantém o identificador da antiga.
No iOS a app antiga nunca existiu: é uma publicação nova na App Store.

- Android `applicationId`: `pt.magicspider.mslps` (confirmado pelos links da Play Store nos emails do CISOC)
- iOS Bundle ID: `pt.magicspider.mslps` — o mesmo, por coerência; registá-lo no
  Apple Developer ao criar a app no App Store Connect
- Android: a assinatura de release tem de usar a chave da app antiga (ou Play App Signing)
- O `versionCode` (número depois do `+` em `pubspec.yaml`) tem de ser maior do que o
  da última versão publicada da app antiga — confirmar na Play Console
- A versão da app nova começa em `2.0.0`

## Zonas da app

A app **não é só para sócios**. Tem duas zonas:

- **Zona pública** — para todos, sem ser preciso ser sócio. Consome
  `/api/v2/publico/*` (sem autenticação, cacheável, sem dados pessoais — ADR-10 e
  §7.2 da arquitectura). Hoje só existem `noticias`, `noticias/{slug}`,
  `categorias` e `media/{uid}`; jogos, classificações, modalidades, agenda,
  galerias, bilhetes e loja estão desenhados mas não implementados.
- **Zona privada** — só para sócios. Consome `/api/v1` (guia `api-socio-flutter.md`).

Os utilizadores da app **podem não ser sócios**. Decisão (2026-09-16): **conta
opcional**.

- Sem login: toda a zona pública.
- Conta com email (qualquer pessoa): funções pessoais — modalidades/equipas que
  segue, notificações por interesse, bilhetes.
- Conta associada a um sócio: abre também a zona privada. Um sócio pode entrar
  directamente com o nº de sócio (fluxo v1 actual).

O backend ainda não suporta contas de não-sócios: a v1 só autentica por `nr_socio` (tabela `users`), e o `lps_idt_contas`
desenhado na §6.2 da arquitectura só prevê `tipo` `socio|staff|servico`.
Contas de não-sócios são uma alteração a pedir no CISOC, não algo a contornar na app.

Consequências para a app:
- Arranca na zona pública sem login; a zona privada abre-se ao entrar como sócio.
- Push para quem não tem sessão: tópicos FCM (`POST /dispositivos` exige token).
- Rotas protegidas por estado de sessão, não ecrãs duplicados por tipo de utilizador.

## Estrutura e stack

- Estado: `flutter_riverpod` (2.x, sem geração de código). Rotas: `go_router`, com
  `redirect` por estado de sessão e de versão (`lib/core/router.dart`).
- `lib/core/` — `config.dart` (endereços), `api/` (clientes Dio, envelope →
  `ApiException`), `auth/` (`TokenStore`, `AuthInterceptor`, `sessaoProvider`),
  `arranque/` (`/ping` e versão mínima).
- `lib/features/<zona ou área>/` — ecrãs e o respectivo acesso à API
  (`publico/noticias`, `auth`, `socio`, `shell`).
- Dois clientes Dio: `dioPublicoProvider` (`/api/v2/publico`, nunca leva token) e
  `dioSocioProvider` (`/api/v1`, com o interceptor).
- Correr contra o CISOC local: `flutter run --dart-define=LPS_API_RAIZ=http://10.0.2.2:8080`
  (emulador Android) ou `http://localhost:8080` (simulador iOS). Sem o define, produção.

## Endereços da API

- Produção: `https://mylps.leoesdeportosalvo.pt/lps/api/v1`
- Dev local: `http://localhost:8080/api/v1` (no emulador Android: `http://10.0.2.2:8080/api/v1`)

Não chamar o backend antigo `api.leoesdeportosalvo.pt`.

## Regras que não se deduzem do código

- Se faltar um endpoint, pedi-lo no backend — não o inventar nem usar outro servidor.
- Tokens só em `flutter_secure_storage`; refresh automático apenas em `401 token_expirado`.
- Dinheiro: não somar quotas e modalidades (usar `divida.total`); `estimado: true` não é pagável; `201` num pagamento não significa pago.
- Tratar listas de estados/tipos vindas da API como abertas (`default` nos `switch`).
