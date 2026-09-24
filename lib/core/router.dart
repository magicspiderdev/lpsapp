import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/arranque/actualizar_page.dart';
import '../features/arranque/arranque_page.dart';
import '../features/auth/entrar_page.dart';
import '../features/auth/codigo_page.dart';
import '../features/auth/associar_socio_page.dart';
import '../features/auth/desbloquear_page.dart';
import '../features/auth/registo_page.dart';
import '../features/arranque/boas_vindas_page.dart';
import '../features/comunidade/comunidade_page.dart';
import '../features/comunidade/passatempo_page.dart';
import '../features/publico/agenda/agenda.dart' show ItemAgenda;
import '../features/publico/agenda/agenda_page.dart';
import '../features/publico/agenda/evento_page.dart';
import '../features/publico/bilheteira/bilheteira.dart' show quantidadesDoLink;
import '../features/publico/bilheteira/bilheteira_page.dart';
import '../features/publico/bilheteira/compra.dart' show Compra;
import '../features/publico/bilheteira/encomenda_page.dart';
import '../features/publico/bilheteira/meus_bilhetes_page.dart';
import '../features/publico/clube/clube_page.dart';
import '../features/publico/competicao/competicao_page.dart';
import '../features/publico/competicao/jogo_page.dart';
import '../features/publico/clube/clube_subpaginas.dart';
import '../features/publico/noticias/etiqueta_page.dart';
import '../features/publico/noticias/noticia_page.dart';
import '../features/publico/noticias/noticias_page.dart';
import '../features/shell/shell_page.dart';
import '../features/socio/cartao/cartao_page.dart';
import '../features/socio/documentos/documentos_page.dart';
import '../features/socio/notificacoes/notificacoes_page.dart';
import '../features/socio/pagamentos/faturas_page.dart';
import '../features/socio/perfil/perfil_page.dart';
import '../features/socio/suporte/conversa_page.dart';
import '../features/socio/suporte/suporte_page.dart';
import '../features/socio/pagamentos/mensalidades_page.dart';
import '../features/socio/pagamentos/modelos.dart';
import '../features/socio/pagamentos/quotas_page.dart';
import '../features/socio/pagamentos/resultado_page.dart';
import '../features/conta/conta_page.dart';
import 'arranque/boas_vindas.dart';
import 'arranque/versao_app.dart';
import 'links.dart';
import 'auth/biometria.dart';
import 'auth/sessao.dart';

/// Rotas protegidas por estado de sessão, não ecrãs duplicados por tipo de
/// utilizador. Tudo o que está debaixo de `/socio` exige sessão de sócio.
final routerProvider = Provider<GoRouter>((ref) {
  final mudou = ValueNotifier(0);
  ref.listen(sessaoProvider, (_, _) => mudou.value++);
  ref.listen(estadoVersaoProvider, (_, _) => mudou.value++);
  ref.listen(boasVindasProvider, (_, _) => mudou.value++);
  ref.listen(biometriaProvider.select((b) => b.bloqueada), (_, _) => mudou.value++);
  ref.onDispose(mudou.dispose);

  final router = GoRouter(
    initialLocation: '/arranque',
    refreshListenable: mudou,
    redirect: (context, estado) => destinoDoRedirect(
      estado.uri,
      // As boas-vindas também se lêem no arranque: até lá, fica-se nele.
      versaoACarregar: ref.read(estadoVersaoProvider).isLoading || ref.read(boasVindasProvider).isLoading,
      boasVindas: ref.read(boasVindasProvider).valueOrNull == false,
      bloquearVersao: ref.read(estadoVersaoProvider).valueOrNull?.bloquear ?? false,
      socio: ref.read(sessaoProvider) is SessaoSocio,
      temConta: ref.read(sessaoProvider) is! SessaoAnonima,
      bloqueada: ref.read(biometriaProvider).bloqueada,
    ),
    // Link para uma rota que não existe (ex.: de uma versão futura): notícias.
    onException: (_, _, router) => router.go('/noticias'),
    routes: rotasDaApp,
  );
  ref.onDispose(router.dispose);
  return router;
});

/// A árvore de rotas. Fora do provider para se poder ler num teste sem montar
/// a app inteira — o sítio de cada rota é uma regra, não um detalhe.
final rotasDaApp = <RouteBase>[
  GoRoute(path: '/arranque', builder: (_, _) => const ArranquePage()),
  GoRoute(path: '/actualizar', builder: (_, _) => const ActualizarPage()),
  GoRoute(path: '/boas-vindas', builder: (_, _) => const BoasVindasPage()),
  StatefulShellRoute.indexedStack(
    builder: (_, _, navegacao) => ShellPage(navegacao: navegacao),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/noticias',
            builder: (_, _) => const NoticiasPage(),
            routes: [
              GoRoute(
                path: 'clube',
                builder: (_, _) => const ClubePage(),
                routes: [
                  GoRoute(path: 'historia', builder: (_, _) => const HistoriaClubePage()),
                  GoRoute(path: 'contactos', builder: (_, _) => const ContactosClubePage()),
                  GoRoute(
                    path: 'modalidades',
                    builder: (_, _) => const ModalidadesPage(),
                    routes: [
                      GoRoute(
                        path: ':slug',
                        builder: (_, s) => ModalidadePage(slug: s.pathParameters['slug']!),
                      ),
                    ],
                  ),
                ],
              ),
              // Antes de ':slug': as rotas são vistas por ordem.
              GoRoute(
                path: 'etiqueta/:slug',
                builder: (_, s) => EtiquetaPage(
                  slug: s.pathParameters['slug']!,
                  // O nome bonito vem de quem tocou na etiqueta; sem ele,
                  // fica o slug, que é sempre legível.
                  nome: s.uri.queryParameters['nome'],
                ),
              ),
              GoRoute(
                path: ':slug',
                builder: (_, s) => NoticiaPage(slug: s.pathParameters['slug']!),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/agenda',
            builder: (_, _) => const AgendaPage(),
            routes: [
              // A competição vive debaixo da agenda: é a mesma pergunta
              // ("quando se joga"), feita para a época inteira.
              GoRoute(
                path: 'competicao',
                builder: (_, _) => const CompeticaoPage(),
                routes: [
                  GoRoute(
                    path: ':slug',
                    builder: (_, s) => ProvaPage(slug: s.pathParameters['slug']!),
                  ),
                ],
              ),
              // A ficha de um jogo e a de um evento. O `extra` é o item que o
              // cartão já tinha: desenha o ecrã sem espera. Por link não vem
              // nada, e cada página sabe ir buscar o que precisa.
              GoRoute(
                path: 'jogo/:id',
                builder: (_, s) => JogoPage(id: s.pathParameters['id']!, inicial: s.extra as ItemAgenda?),
              ),
              GoRoute(
                path: 'evento/:ref',
                builder: (_, s) => EventoPage(referencia: s.pathParameters['ref']!, inicial: s.extra as ItemAgenda?),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/comunidade',
            builder: (_, _) => const ComunidadePage(),
            routes: [
              // A ficha do jogo, a mesma da agenda, com o bloco da comunidade.
              // Aqui e não em `/agenda/jogo`: tocar num jogo não muda de separador.
              GoRoute(
                path: 'jogo/:id',
                builder: (_, s) => JogoPage(id: s.pathParameters['id']!, inicial: s.extra as ItemAgenda?),
              ),
              GoRoute(
                path: 'passatempos/:uid',
                builder: (_, s) => PassatempoPage(uid: s.pathParameters['uid']!),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/bilhetes',
            builder: (_, _) => const BilheteiraPage(),
            routes: [
              // 'meus' e 'encomenda' antes de ':id': as rotas são vistas por ordem.
              GoRoute(
                // O resultado de uma compra. Pelo `id` no caminho, e não só
                // pelo `extra`: quem sai a pagar e volta tem de reencontrar o
                // ecrã, e a encomenda pede-se outra vez ao servidor.
                path: 'encomenda/:id',
                builder: (_, s) => EncomendaPage(id: s.pathParameters['id']!, inicial: s.extra as Compra?),
              ),
              GoRoute(
                path: 'meus',
                builder: (_, _) => const MeusBilhetesPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => BilhetePage(id: s.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) => SessaoPage(
                  id: s.pathParameters['id']!,
                  // Escolha feita antes de ir entrar: volta com ela.
                  quantidadesIniciais: quantidadesDoLink(s.uri.queryParameters['z']),
                ),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/socio',
            // A raiz do separador serve as duas: com ficha é a área de sócio,
            // sem ficha é a conta. O resto, debaixo dela, é mesmo do sócio.
            builder: (_, _) => const ZonaPessoalPage(),
            routes: [
              // Da conta, e não do sócio: quem entrou só com email também
              // precisa de mudar a palavra-passe.
              GoRoute(path: 'conta/password', builder: (_, _) => const AlterarPasswordPage()),
              GoRoute(path: 'cartao', builder: (_, _) => const CartaoPage()),
              GoRoute(
                path: 'quotas',
                builder: (_, s) => QuotasPage(abrirPagamento: s.uri.queryParameters['pagar'] == '1'),
              ),
              GoRoute(
                path: 'faturas',
                builder: (_, _) => const FaturasPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => FaturaPage(id: int.parse(s.pathParameters['id']!)),
                  ),
                ],
              ),
              GoRoute(path: 'pagamentos', builder: (_, _) => const HistoricoPagamentosPage()),
              GoRoute(path: 'mensalidades', builder: (_, _) => const MensalidadesPage()),
              GoRoute(path: 'wallet', builder: (_, _) => const WalletPage()),
              GoRoute(path: 'documentos', builder: (_, _) => const DocumentosPage()),
              GoRoute(path: 'notificacoes', builder: (_, _) => const NotificacoesPage()),
              GoRoute(
                path: 'suporte',
                builder: (_, _) => const SuportePage(),
                routes: [
                  GoRoute(path: 'nova', builder: (_, _) => const ConversaPage()),
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => ConversaPage(id: int.parse(s.pathParameters['id']!)),
                  ),
                ],
              ),
              GoRoute(
                path: 'perfil',
                builder: (_, _) => const PerfilPage(),
                routes: [GoRoute(path: 'password', builder: (_, _) => const AlterarPasswordPage())],
              ),
              GoRoute(
                path: 'pagamento',
                // Só se chega aqui com o resultado acabado de criar; sem ele, volta ao início.
                redirect: (_, s) => s.extra is ResultadoPagamento ? null : '/socio',
                builder: (_, s) => ResultadoPagamentoPage(resultado: s.extra! as ResultadoPagamento),
              ),
            ],
          ),
          GoRoute(path: '/desbloquear', builder: (_, _) => const DesbloquearPage()),
        ],
      ),
    ],
  ),
  // O login fica **fora** dos ramos da navegação, de propósito.
  //
  // Dentro de um ramo, o ramo guardava-o como o seu último sítio; e como
  // `/entrar` com sessão reenvia para o `?voltar=`, o separador "Sócio"
  // passava a levar de volta ao que se estava a fazer antes de entrar
  // (comprar bilhetes, por exemplo), em vez de à área de sócio. Aqui não
  // há ramo nenhum para guardar um ecrã que só existe até se entrar.
  GoRoute(
    path: '/entrar',
    builder: (_, _) => const EntrarPage(),
    routes: [
      GoRoute(path: 'codigo', builder: (_, _) => const CodigoPage()),
      GoRoute(path: 'registo', builder: (_, _) => const RegistoPage()),
    ],
  ),
  // Associar a ficha a uma conta que já existe. Fora dos ramos, como o login:
  // também é um ecrã que só existe até se fazer o que ele pede.
  GoRoute(path: '/associar-socio', builder: (_, _) => const AssociarSocioPage()),
];

/// Para onde levar um pedido de rota, ou `null` para seguir.
///
/// O destino pedido nunca se perde: um deep link que chega durante o
/// arranque, ou que precisa de sessão, fica em `?para=`/`?voltar=` e é para lá
/// que se vai a seguir.
@visibleForTesting
String? destinoDoRedirect(
  Uri uri, {
  required bool versaoACarregar,
  required bool bloquearVersao,
  required bool socio,
  required bool bloqueada,
  bool temConta = false,
  bool boasVindas = false,
}) {
  // Link partilhado (`https://…/lps/noticias/x`): tira o prefixo do servidor.
  final doLink = Links.rotaDoLink(uri);
  if (doLink != null) return doLink;

  final local = uri.path;
  final pedido = uri.toString();
  String com(String rota, String chave, String valor) => Uri(path: rota, queryParameters: {chave: valor}).toString();

  if (versaoACarregar) return local == '/arranque' ? null : com('/arranque', 'para', pedido);
  if (bloquearVersao) return local == '/actualizar' ? null : '/actualizar';
  // Primeira vez neste aparelho: os slides, e depois o destino que se pedia.
  if (boasVindas) {
    if (local == '/boas-vindas') return null;
    final destino = local == '/arranque' || local == '/' ? uri.queryParameters['para'] : pedido;
    return destino == null ? '/boas-vindas' : com('/boas-vindas', 'para', destino);
  }
  if (local == '/boas-vindas') return Links.voltarSeguro(uri.queryParameters['para']) ?? '/noticias';
  if (local == '/arranque' || local == '/actualizar' || local == '/') {
    return Links.voltarSeguro(uri.queryParameters['para']) ?? '/noticias';
  }

  final voltar = Links.voltarSeguro(uri.queryParameters['voltar']);
  // Um sócio tem sempre conta: quem só passa `socio` não fica com meia verdade.
  final comSessao = temConta || socio;

  // Uma compra é da conta: sem sessão não há encomenda nenhuma para ver, e
  // um link para uma passa primeiro por entrar.
  if (local.startsWith('/bilhetes/encomenda') && !comSessao) return com('/entrar', 'voltar', pedido);

  // A raiz do separador e os ecrãs da conta abrem para qualquer sessão: é lá
  // que quem não tem ficha muda a palavra-passe, termina sessão e elimina a
  // conta. Sem isto, uma conta sem sócio não teria onde fazer nada disso.
  final daConta = local == '/socio' || local.startsWith('/socio/conta');

  // O resto da zona privada é do sócio. Quem já tem conta e lá bate não
  // precisa de entrar — precisa de associar a ficha.
  if (local.startsWith('/socio') && !socio && !(daConta && comSessao)) {
    return com(comSessao ? '/associar-socio' : '/entrar', 'voltar', pedido);
  }
  if (local.startsWith('/socio') && bloqueada) return com('/desbloquear', 'voltar', pedido);
  if (local == '/desbloquear') {
    if (!socio) return voltar == null ? '/entrar' : com('/entrar', 'voltar', voltar);
    return bloqueada ? null : voltar ?? '/socio';
  }
  if (local == '/associar-socio') {
    if (socio) return voltar ?? '/socio'; // já tem ficha: não há nada a associar
    if (!comSessao) return com('/entrar', 'voltar', pedido);
    return null;
  }
  // Já com sessão, o ecrã de entrar não tem nada para fazer.
  if (local.startsWith('/entrar') && comSessao) return voltar ?? (socio ? '/socio' : '/noticias');
  return null;
}
