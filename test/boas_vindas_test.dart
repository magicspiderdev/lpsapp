import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lpsapp/core/arranque/boas_vindas.dart';
import 'package:lpsapp/core/cache/cache_local.dart';
import 'package:lpsapp/core/router.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/arranque/boas_vindas_page.dart';

String? ir(String rota, {bool boasVindas = true}) => destinoDoRedirect(
  Uri.parse(rota),
  versaoACarregar: false,
  bloquearVersao: false,
  socio: false,
  bloqueada: false,
  boasVindas: boasVindas,
);

void main() {
  group('router', () {
    test('primeira vez: do arranque para os slides', () {
      expect(ir('/arranque'), '/boas-vindas');
    });

    test('um link aberto à primeira não se perde: fica em ?para=', () {
      expect(ir('/arranque?para=%2Fnoticias%2Fx'), '/boas-vindas?para=%2Fnoticias%2Fx');
      expect(ir('/agenda'), '/boas-vindas?para=%2Fagenda');
    });

    test('já vistas: /boas-vindas segue para o destino, e o resto não passa por lá', () {
      expect(ir('/boas-vindas?para=%2Fagenda', boasVindas: false), '/agenda');
      expect(ir('/boas-vindas', boasVindas: false), '/noticias');
      expect(ir('/agenda', boasVindas: false), isNull);
    });
  });

  group('ecrã', () {
    Future<CacheEmMemoria> montar(WidgetTester t, {double largura = 360, double altura = 740, double escala = 1}) async {
      t.view.physicalSize = Size(largura, altura);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final cache = CacheEmMemoria();
      final router = GoRouter(
        initialLocation: '/boas-vindas?para=%2Fagenda',
        routes: [
          GoRoute(path: '/boas-vindas', builder: (_, _) => const BoasVindasPage()),
          GoRoute(path: '/agenda', builder: (_, _) => const Text('agenda')),
          GoRoute(path: '/entrar', builder: (_, s) => Text('entrar ${s.uri.queryParameters['voltar']}')),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [cacheProvider.overrideWithValue(cache)],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      return cache;
    }

    for (final (largura, altura, escala) in [(320.0, 568.0, 2.0), (360.0, 740.0, 1.0), (430.0, 932.0, 1.3)]) {
      testWidgets('os cinco slides cabem · ${largura.toInt()}×${altura.toInt()} · letra x$escala', (t) async {
        await montar(t, largura: largura, altura: altura, escala: escala);
        for (var i = 0; i < 4; i++) {
          await t.tap(find.text('Seguinte'));
          await t.pumpAndSettle();
        }
        expect(find.text('Começar'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('saltar marca como vistas e segue para onde ia', (t) async {
      final cache = await montar(t);
      await t.tap(find.text('Saltar'));
      await t.pumpAndSettle();
      expect(find.text('agenda'), findsOneWidget);
      expect(await cache.ler(Ambito.publico, 'app.boas-vindas'), isNotNull);
    });

    testWidgets('no fim, "Já tenho conta" leva a entrar e volta ao destino', (t) async {
      await montar(t);
      for (var i = 0; i < 4; i++) {
        await t.drag(find.byType(PageView), const Offset(-400, 0));
        await t.pumpAndSettle();
      }
      await t.tap(find.text('Já tenho conta · Entrar'));
      await t.pumpAndSettle();
      expect(find.text('entrar /agenda'), findsOneWidget);
    });

    test('uma cache que falha não prende ninguém nos slides', () async {
      final c = ProviderContainer(overrides: [cacheProvider.overrideWithValue(_CacheQueFalha())]);
      addTearDown(c.dispose);
      expect(await c.read(boasVindasProvider.future), isTrue);
    });
  });
}

class _CacheQueFalha extends CacheEmMemoria {
  @override
  Future<EntradaCache?> ler(Ambito ambito, String chave) => throw Exception('disco');
}
