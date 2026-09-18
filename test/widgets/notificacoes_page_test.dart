import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/cache/cache_local.dart';
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/tema/tema.dart';
import 'package:lpsapp/features/socio/notificacoes/notificacoes.dart';
import 'package:lpsapp/features/socio/notificacoes/notificacoes_page.dart';

class _VistasFake extends VistasController {
  _VistasFake(this.inicial);

  final int inicial;
  int? marcada;

  @override
  Future<int> build() async => inicial;

  @override
  Future<void> marcarVistas(int id) async {
    marcada = id;
    state = AsyncData(id);
  }
}

Notificacao _n(int id, {bool pessoal = false, String texto = 'Estamos a contar com o teu apoio.'}) => Notificacao(
  id: id,
  titulo: 'Aviso $id',
  texto: texto,
  pessoal: pessoal,
  enviadaEm: DateTime(2026, 9, 12, 18),
);

Future<_VistasFake> _abrir(WidgetTester t, {required List<Notificacao> lista, int vistas = 0}) async {
  final vistasFake = _VistasFake(vistas);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        notificacoesProvider.overrideWith(
          (ref) => Stream.value(Dados(PaginaNotificacoes(lista, null), DateTime(2026, 9, 18, 10))),
        ),
        vistasProvider.overrideWith(() => vistasFake),
        cacheProvider.overrideWithValue(CacheEmMemoria()),
      ],
      child: MaterialApp(theme: Tema.claro(), home: const NotificacoesPage()),
    ),
  );
  await t.pumpAndSettle();
  return vistasFake;
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  testWidgets('sem notificações mostra o estado vazio', (t) async {
    await _abrir(t, lista: const []);
    expect(find.text('Ainda não recebeu notificações'), findsOne);
  });

  testWidgets('lista as notificações e marca como vistas ao abrir', (t) async {
    final vistas = await _abrir(t, lista: [_n(49), _n(48), _n(47)], vistas: 47);

    expect(find.text('Aviso 49'), findsOne);
    expect(find.text('Aviso 47'), findsOne);
    // As duas por ver ao abrir: continuam com ponto, mas já ficaram marcadas.
    expect(vistas.marcada, 49);
  });

  testWidgets('a que é só para o sócio diz que é só para si', (t) async {
    await _abrir(t, lista: [_n(50, pessoal: true)]);
    expect(find.text('só para si'), findsOne);
  });

  testWidgets('tocar abre o texto completo', (t) async {
    // Duas linhas no cartão não chegam para um texto comprido.
    const longo = 'Primeira linha do aviso.\nSegunda linha.\nTerceira linha, que no cartão não aparecia.';
    await _abrir(t, lista: [_n(51, texto: longo)]);
    // O cartão já tem o texto todo, só o corta a duas linhas.
    expect(find.text(longo), findsOne);

    await t.tap(find.text('Aviso 51'));
    await t.pumpAndSettle();

    expect(find.text(longo), findsNWidgets(2), reason: 'o do cartão e o da folha');
    expect(find.text('Aviso 51'), findsNWidgets(2));
  });

  testWidgets('nada a marcar quando já estavam todas vistas', (t) async {
    final vistas = await _abrir(t, lista: [_n(10), _n(9)], vistas: 10);
    expect(vistas.marcada, isNull);
  });
}
