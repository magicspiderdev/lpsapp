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
| `C:\home\cisoc\docs\pedidos-app\2026-09-19-links-partilha-deeplinks.md` | `assetlinks.json`, `apple-app-site-association` e páginas web dos links partilhados (a app já partilha e já abre os links) |
| `C:\home\cisoc\docs\pedidos-app\2026-09-22-transferir-bilhete.md` | Transferência a sério de um bilhete (a app envia o código, com aviso) |
| `C:\home\cisoc\docs\pedidos-app\2026-09-22-detalhe-de-evento.md` | Abrir um evento por link ou fora da janela da agenda (a ficha já funciona com o item da lista) |
| `C:\home\cisoc\docs\pedidos-app\2026-09-22-titulos-de-sessao-mal-codificados.md` | Nada — é um erro nos dados de uma sessão; a app mostra o que a API mandar |
| `C:\home\cisoc\docs\pedidos-app\2026-09-24-inscricao-ja-existe-id.md` | Nada — o `409 ja_existe` da inscrição traz `inscricao` e não `id`; a app lê os dois |
| `C:\home\cisoc\docs\pedidos-app\2026-09-24-push-pagamento-emitido.md` | O push "pagamento emitido" (a app já abre `/socio/pagamentos/{id}?socio=`), e os destinos dos avisos de modalidades, chat e pagamento confirmado, que hoje não abrem nada |
| `C:\home\cisoc\docs\pedidos-app\2026-09-24-inscricao-pagamento-pendente.md` | Mostrar a referência já pedida ao reabrir uma inscrição por pagar (hoje a app remete para o email) |

**Menores** (§2.10–§2.12, política de menores do CISOC, fases 1 a 9): a app
**nunca calcula idades** — nem no registo, onde a data é só declarada
(`declara_idade: true`; abaixo da mínima o servidor responde `403
encarregado_necessario`). Desenha-se com `conta.capacidades`
(`ContaSessao.tem(Capacidade.x)`, `sessaoTem`); numa sessão guardada antes das
capacidades valem as `permissoes` antigas. Tudo chega também em cada
`/auth/refresh`, e a sessão muda sem login (`TokenStore.contaRenovada`). Sem a
capacidade, esconde-se o botão e põe-se a `NotaPermissao` no lugar (quem o faz é
o encarregado de educação): pagar, comprar (também zonas gratuitas,
`QuemPode.soEncarregado`), contratar, editar a ficha e a fotografia. `401
socio_menor` é fim de sessão; `422 socio_menor`, `403 menor_de_idade`, `403
sem_capacidade` mostram a `message`. Passatempos `so_maiores` pedem a idade
**verificada** (`motivo: idade_por_verificar`).

**Encarregados** (§2.3.4, §2.3.5): um encarregado pode não ser sócio. Uma conta
sem ficha com `conta.dependentes[]` (`eEncarregadoSemFicha`) entra na zona
privada sempre com `X-Socio` de um educando (`temZonaPrivada`,
`contaActivaProvider` começa no primeiro): a página da conta lista-os e abre
`/socio/educando` (o Início do sócio, sem notificações, suporte nem ficha —
isso é da ficha própria). As caches da zona privada usam `chaveDaSessao`.
Pedir para acompanhar um educando, e os consentimentos (§2.11), vivem em
`lib/features/conta/`. Bilhetes para um dependente: `para` na encomenda
(`paraQuem`), e a carteira mostra `para`/`comprado_por_outro`.

O push chega a qualquer conta (`/api/v2/dispositivos`), e os `data.params` vêm
como texto JSON (`destinoDoPush`). A época da competição é a que o clube põe em
vigor; uma época escolhida que deixou de existir dá `404` e volta-se à actual.

Inscrição de sócio (§4.21) em `lib/features/inscricao/`, pedidos de inscrição
e baixa em modalidades (§4.22) em `lib/features/modalidades_pedidos/` (rotas
em `/socio/conta/modalidades`, abertas a qualquer conta), e o arquivo das
conversas do suporte é do servidor (`POST /suporte/{id}/arquivar`).

**Comunidade** (§4.23, `lib/features/comunidade/`): 5.º separador (Clube,
Agenda, Comunidade, Bilhetes, Sócio) com Jogos, Classificação e Passatempos, e
o `BlocoComunidade` na ficha do jogo (palpitar antes, relatar depois). Com
jogos de hoje ou de ontem já acabados, aparece primeiro a tab **Últimos**
(`ultimosJogos`): um jogo dá-se por acabado hora e meia depois do início, mesmo
com o estado por mudar — é a única conta com datas, e só decide o destaque. Qual
botão aparece decide-se por `aberto`/`motivo` do servidor, nunca pelas datas;
depois de cada escrita substitui-se o jogo pelo que vem. **Sem caixas de texto
livre** (ADR-13) — o único texto é a alcunha, que nunca se preenche com o nome
da pessoa. Os resultados entram por contadores, não por teclado. A barra de
baixo é só de ícones: com cinco separadores os nomes partiam-se em duas linhas.

**A app entra pela v2** (Contas v2, §2.9), desde 2026-09-22. O que isso implica:

- A identidade é a **conta**, não o sócio. Três estados de sessão, não dois:
  `SessaoAnonima`, `SessaoConta` (sem ficha) e `SessaoSocio` (com ficha).
- O mesmo token serve a v1. **Sem ficha, a v1 responde `403 conta_sem_socio` —
  que não é fim de sessão**: esconde-se a zona privada e oferece-se
  `/associar-socio`, em vez de deitar os tokens fora.
- **O refresh roda.** Cada `/auth/refresh` devolve um par novo e o anterior
  deixa de valer: guardar só o access deixava o refresh gasto no disco, e o
  servidor lê um refresh já trocado como roubo (revoga a sessão do aparelho).
  Um refresh de cada vez — o `AuthInterceptor` já serializa.
- Sessões independentes por aparelho: entrar noutro telemóvel já não fecha
  esta. Mudar ou repor a password é que fecha as outras.
- Tokens da versão anterior (`lps.socio` no armazenamento seguro) descartam-se
  no arranque: não servem na v2.

**Páginas e menu do Clube** (guia público §9, `lib/features/publico/clube/`
`menu_clube.dart` e `clube_paginas.dart`): o clube monta no backoffice o menu
`app` (`/publico/menu/app`), que aparece em "Mais sobre o clube". Cada item leva
a uma página (`/noticias/clube/paginas/{slug}`), modalidade, secção
(`rotasDasSeccoes`) ou link; um item sem destino abre o submenu
(`/noticias/clube/menu/{indice}`). Destinos e secções desconhecidos não se
mostram. O `CorpoBlocos` põe lado a lado os blocos com `ocupa` (1/2, 1/3…)
a partir de 520 px de largura; abaixo empilha-os.

Links partilhados: `lib/core/links.dart` (raiz em `Config.linksRaiz`). O caminho
do link é o da rota; o router tira o prefixo `/lps` e guarda o destino em
`?para=`/`?voltar=` durante o arranque e o login. Comprar bilhetes exige sessão.

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
- A versão da app nova começa em `2.0.0`

### A app antiga: `C:\Users\joaop\Documents\mylps251`

O projecto Flutter da app que está na Play Store. É lá que estão as coisas que
esta app tem de herdar.

| O quê | Onde |
|-------|------|
| **Chave de assinatura** (sem ela não se actualiza a app na Play Store) | `android/app/my-release-key.jks` (cópia igual na raiz) |
| Alias e palavras-passe da chave | `android/gradle.properties` (`MYAPP_RELEASE_*`), alias `my-key-alias` |
| `versionCode` publicado | `pubspec.yaml`: `1.0.3+11` — o da app nova tem de ser maior; confirmar na Play Console, que pode ter subido |
| Projecto Firebase (push) | `android/app/google-services.json`: `mylps-3fbdb`, remetente `333604454420`, pacote `pt.magicspider.mslps` |

- **O `applicationId` é o mesmo**, por isso o Firebase da app antiga serve tal
  qual para o push desta — não é preciso projecto novo.
- A assinatura de release lê `android/key.properties` (fora do repositório, ver
  `android/key.properties.exemplo`). Sem esse ficheiro, o release é assinado com
  a chave de debug e **não serve para a loja**.
- A chave e a palavra-passe estão dentro de um repositório git na app antiga.
  Convém uma cópia de segurança fora do projecto: perder a chave é perder a app.
- Não há material de assinatura de iOS na app antiga (nunca foi publicada).

## Zonas da app

A app **não é só para sócios**. Tem duas zonas:

- **Zona pública** — para todos, sem ser preciso ser sócio. Consome
  `/api/v2/publico/*` (sem autenticação, cacheável, sem dados pessoais — ADR-10 e
  §7.2 da arquitectura). Estão implementados `noticias`, `noticias/{slug}`,
  `categorias`, `media/{uid}`, `clube`, `agenda`, `bilhetes/sessoes[/{uid}]` e
  `competicao/provas[/{slug}]` e `competicao/jogos` — todos ligados na app. Não
  existem classificações, plantéis, galerias nem loja; o guia de quem integra
  está em `C:\home\cisoc\docs\api-publica.md`.
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
- `lib/core/` — `config.dart` (endereços), `cache/` (cache local e `comCache`), `rede/` (estado da ligação), `api/` (clientes Dio, envelope →
  `ApiException`), `auth/` (`TokenStore`, `AuthInterceptor`, `sessaoProvider`),
  `arranque/` (`/ping` e versão mínima).
- `lib/core/theme/` — design system (`docs/ui-audit.md` §6): `app_colors.dart`
  (paleta, esquemas claro/escuro e `AppColors` com os estados), `app_typography.dart`,
  `app_spacing.dart` (espaço, raios, sombras, movimento) e `app_theme.dart`. Código
  novo usa estes tokens; `lib/core/tema/tema.dart` (`Tema`) só existe para os ecrãs
  antigos e já lê daqui. Contrastes fixados em `test/design_system_test.dart`.
- `lib/features/<zona ou área>/` — ecrãs e o respectivo acesso à API
  (`publico/noticias`, `auth`, `socio`, `shell`).
- Dois clientes Dio: `dioPublicoProvider` (`/api/v2/publico`, nunca leva token) e
  `dioSocioProvider` (`/api/v1`, com o interceptor).
- Correr contra o CISOC local: `flutter run --dart-define=LPS_API_RAIZ=http://10.0.2.2:8080`
  (emulador Android) ou `http://localhost:8080` (simulador iOS). Sem o define, produção.
- `--dart-define=LPS_DEMO=1` troca a zona pública pelos exemplos de
  `lib/features/publico/*/…dart` — servem para ver o desenho com dados cheios
  (uma época a começar tem dois jogos) e são o que os testes de ecrã usam. O que
  ainda não tem API (a carteira de bilhetes) mostra "brevemente" sem este modo.
- Um jogo é sempre um `ItemAgenda`: a agenda e a competição devolvem-no na
  mesma forma, e o cartão é o mesmo (`agenda/agenda_widgets.dart`). `do_clube`
  diz qual é a nossa equipa — nunca comparar nomes.
- "Próximos" e "Anteriores" cortam-se **pela data**, nunca por haver resultado:
  um jogo de ontem por registar é um jogo anterior sem resultado, e é assim que
  se mostra (§4.19). O passado carrega-se aos poucos (`maisAnterioresProvider`):
  a agenda não é paginada, por isso recua-se por janelas de datas encadeadas, e
  o pedido é decidido pela posição da lista depois de cada desenho — uma lista
  curta de mais para se arrastar nunca geraria um evento de scroll.
- A janela da agenda vai de −7 a **+365 dias**: o que o clube marca com muita
  antecedência (jantar de Natal, assembleia) é publicado meses antes e tem de
  aparecer no dia em que é publicado. A API aceita até 400 dias de intervalo e
  `limite` 100; a agenda do clube tem dezenas de itens por época.
- Tocar num cartão abre a **ficha**: um jogo tem endpoint
  (`/competicao/jogos/{id}` — placard, árbitro, assistência e a ficha com golos,
  cartões, substituições e relato, `jogo_page.dart`); um evento não tem, e
  desenha-se com o item que a agenda já trouxe (`evento_page.dart`, pedido
  `2026-09-22-detalhe-de-evento`). O item vai no `extra` da rota, para o ecrã
  não abrir a girar. **O marcador oficial é `jogo.resultado`**, não o da ficha,
  que pode estar a meio de ser escrita; o `marcador` de cada linha vem contado
  do servidor (a regra do autogolo é de lá) e os tipos de linha são lista
  aberta — o que não se conhece ignora-se.
- O corpo de uma notícia e o da página de uma modalidade são a mesma lista de
  blocos, compostos por `CorpoBlocos` (`publico/noticias/corpo_blocos.dart`):
  `texto`, `imagem`, `video`, `tabela` (desliza para o lado, não encolhe),
  `mapa` (abre o `url`, sem mapa embebido) e as secções por `estilo`. O `texto`
  e a `historia_html` do clube levam HTML de uma lista branca garantida no
  servidor: compõem-se com `flutter_widget_from_html_core`, sem `WebView` e sem
  voltar a sanitizar. Tipos de bloco desconhecidos ignoram-se. Uma modalidade
  só se abre com `tem_pagina`.

## Endereços da API

- Produção: `https://mylps.leoesdeportosalvo.pt/lps/api/v1`
- Dev local: `http://localhost:8080/api/v1` (no emulador Android: `http://10.0.2.2:8080/api/v1`)

Não chamar o backend antigo `api.leoesdeportosalvo.pt`.

## Regras que não se deduzem do código

- Se faltar um endpoint, pedi-lo no backend — não o inventar nem usar outro servidor.
- Tokens só em `flutter_secure_storage`; refresh automático apenas em `401
  token_expirado`, e **o par novo substitui sempre o antigo** (o refresh roda).
- Dois clientes com o mesmo token: `dioContaProvider` (`/api/v2`, a conta) e
  `dioSocioProvider` (`/api/v1`, a zona privada). O público é o terceiro
  (`dioPublicoProvider`) e nunca leva token.
- Biometria só desbloqueia a sessão guardada no aparelho (`lib/core/auth/biometria.dart`); nunca guardar a palavra-passe. Desliga-se quando a sessão acaba.
- Dinheiro: não somar quotas e modalidades (usar `divida.total`); `estimado: true` não é pagável; `201` num pagamento não significa pago.
- Pagamentos (`lib/features/socio/pagamentos/`): nunca enviar valores, mostrar o `total` e o `metodo` da resposta, nunca pagar com dados da cache, acompanhar a confirmação por polling. Contra o CISOC local o IfthenPay é real — um MB WAY de teste chega a um telemóvel verdadeiro.
- Comprar bilhetes (`lib/features/publico/bilheteira/compra.dart`, §4.18) segue
  as mesmas regras e mais duas próprias. **Uma encomenda é de uma zona**
  (`{sessao, zona, quantidade}`): o ecrã escolhe um tipo de bilhete de cada vez,
  porque somar tipos prometia uma compra que a API não faz. E **quem pode
  comprar não se deduz do preço**: só `exige_socio` se explica antes
  (`quemPodeComprar`, para não mandar ninguém preencher um formulário e ouvir um
  `403`); o resto decide-se no servidor e trata-se pela resposta —
  `conta_sem_socio` oferece associar a ficha, `venda_externa` abre o
  `url_compra`, `esgotado`/`limite_bilhetes` trazem os números e recarregam a
  sessão. Uma zona gratuita nasce `paga` e já traz os bilhetes: não há folha de
  pagamento nenhuma pelo meio.
- A carteira agrupa **por evento**, não por compra (`agruparPorEvento`): dois
  bilhetes para o mesmo jogo são um cartão, e como cada compra é de uma zona,
  duas compras para o mesmo jogo continuam a ser um jogo só. Dentro do cartão
  passa-se de código em código arrastando, que é como a portaria os lê — por
  isso nada a meio do bilhete pode apanhar o arrastar horizontal (foi o que
  aconteceu com um `SelectableText` no código, agora um toque que copia).
- Partilhar um bilhete envia a **imagem** dele (`imagem_bilhete.dart`, composta
  no `Canvas` e não a partir de um widget: partilha-se de qualquer sítio e o
  resultado não depende do ecrã) **e** o texto com o mesmo código. A imagem é o
  que serve à porta; o texto é o que se pesquisa e se lê em voz alta. Não expõe
  mais nada — o QR é o código que já ia no texto. Continua a ser um bilhete de
  cada vez, com o aviso lá dentro.
- Tratar listas de estados/tipos vindas da API como abertas (`default` nos `switch`).
- Ecrãs com dados da API usam cache (`comCache` em `lib/core/cache/`): mostram logo a última informação guardada, actualizam quando há rede e, sem ligação, avisam com `AvisoDesactualizado`. Dados do sócio em `Ambito.sessao`, credenciais em `Ambito.seguro` — apagam-se com a sessão. Imagens com `ImagemRede`, nunca `Image.network`.
