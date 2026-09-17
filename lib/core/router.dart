import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/arranque/actualizar_page.dart';
import '../features/arranque/arranque_page.dart';
import '../features/auth/entrar_page.dart';
import '../features/auth/codigo_page.dart';
import '../features/auth/desbloquear_page.dart';
import '../features/publico/noticias/noticia_page.dart';
import '../features/publico/noticias/noticias_page.dart';
import '../features/shell/shell_page.dart';
import '../features/socio/inicio_page.dart';
import 'arranque/versao_app.dart';
import 'auth/biometria.dart';
import 'auth/sessao.dart';

/// Rotas protegidas por estado de sessão, não ecrãs duplicados por tipo de
/// utilizador. Tudo o que está debaixo de `/socio` exige sessão de sócio.
final routerProvider = Provider<GoRouter>((ref) {
  final mudou = ValueNotifier(0);
  ref.listen(sessaoProvider, (_, _) => mudou.value++);
  ref.listen(estadoVersaoProvider, (_, _) => mudou.value++);
  ref.listen(biometriaProvider.select((b) => b.bloqueada), (_, _) => mudou.value++);
  ref.onDispose(mudou.dispose);

  final router = GoRouter(
    initialLocation: '/arranque',
    refreshListenable: mudou,
    redirect: (context, estado) {
      final local = estado.matchedLocation;
      final versao = ref.read(estadoVersaoProvider);

      if (versao.isLoading) return local == '/arranque' ? null : '/arranque';
      if (versao.valueOrNull?.bloquear ?? false) return '/actualizar';
      if (local == '/arranque' || local == '/actualizar') return '/noticias';

      final socio = ref.read(sessaoProvider) is SessaoSocio;
      final bloqueada = ref.read(biometriaProvider).bloqueada;
      if (local.startsWith('/socio') && !socio) return '/entrar';
      if (local.startsWith('/socio') && bloqueada) return '/desbloquear';
      if (local == '/desbloquear') return !socio ? '/entrar' : (bloqueada ? null : '/socio');
      if (local.startsWith('/entrar') && socio) return '/socio';
      return null;
    },
    routes: [
      GoRoute(path: '/arranque', builder: (_, _) => const ArranquePage()),
      GoRoute(path: '/actualizar', builder: (_, _) => const ActualizarPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navegacao) => ShellPage(navegacao: navegacao),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/noticias',
              builder: (_, _) => const NoticiasPage(),
              routes: [
                GoRoute(
                  path: ':slug',
                  builder: (_, s) => NoticiaPage(slug: s.pathParameters['slug']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/socio', builder: (_, _) => const InicioPage()),
            GoRoute(path: '/desbloquear', builder: (_, _) => const DesbloquearPage()),
            GoRoute(
              path: '/entrar',
              builder: (_, _) => const EntrarPage(),
              routes: [
                GoRoute(path: 'codigo', builder: (_, _) => const CodigoPage()),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
