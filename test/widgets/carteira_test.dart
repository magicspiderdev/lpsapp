/// A carteira: um cartão por evento, e lá dentro os códigos um a um.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/publico/bilheteira/bilheteira.dart';
import 'package:lpsapp/features/publico/bilheteira/meus_bilhetes_page.dart';

BilheteComprado _bilhete(
  String id, {
  required String sessao,
  String titulo = 'Leões Porto Salvo x Portimonense',
  String zona = 'Sócios',
  String estado = 'valido',
  double preco = 0,
  String? encomenda,
  int daquiADias = 4,
}) => BilheteComprado.fromJson({
  'id': id,
  'codigo': 'LPS-CODIGO-$id',
  'titulo': titulo,
  'subtitulo': 'Liga Placard Futsal',
  'local': 'Complexo Desportivo Leões de Porto Salvo',
  'inicio': DateTime.now().add(Duration(days: daquiADias)).toIso8601String(),
  'zona': zona,
  'preco': preco,
  'estado': estado,
  'sessao': sessao,
  'encomenda': encomenda ?? 'E-$id',
});

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  /// O caso do utilizador: dois bilhetes gratuitos da mesma compra.
  final dois = [_bilhete('1', sessao: 'S1'), _bilhete('2', sessao: 'S1')];

  group('a lista', () {
    for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
      for (final escuro in [false, true]) {
        testWidgets('carteira · ${largura.toInt()}px · letra x$escala · ${escuro ? 'escuro' : 'claro'}', (t) async {
          await _pump(t, dois, largura: largura, escala: escala, escuro: escuro);
        });
      }
    }

    testWidgets('dois bilhetes do mesmo jogo são um cartão, não dois', (t) async {
      await _pump(t, dois);

      expect(find.text('Leões Porto Salvo x Portimonense'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      expect(find.textContaining('2 bilhetes'), findsWidgets);
    });

    testWidgets('jogos diferentes continuam a ser cartões diferentes', (t) async {
      await _pump(t, [
        _bilhete('1', sessao: 'S1'),
        _bilhete('2', sessao: 'S2', titulo: 'Leões x Benfica', daquiADias: 9),
      ]);

      expect(find.text('Leões Porto Salvo x Portimonense'), findsOneWidget);
      expect(find.text('Leões x Benfica'), findsOneWidget);
      expect(find.text('×2'), findsNothing);
    });

    testWidgets('duas compras para o mesmo jogo dizem as zonas que juntaram', (t) async {
      await _pump(t, [
        _bilhete('1', sessao: 'S1', zona: 'Sócios', encomenda: 'E1'),
        _bilhete('2', sessao: 'S1', zona: 'Não sócios', preco: 5, encomenda: 'E2'),
      ]);

      expect(find.textContaining('1 Sócios · 1 Não sócios'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
    });

    testWidgets('com um por usar, o cartão diz quantos faltam', (t) async {
      await _pump(t, [
        _bilhete('1', sessao: 'S1'),
        _bilhete('2', sessao: 'S1', estado: 'usado'),
      ]);
      expect(find.text('1 por usar'), findsOneWidget);
    });

    testWidgets('um jogo que já passou fica na secção de baixo', (t) async {
      await _pump(t, [_bilhete('1', sessao: 'S1', daquiADias: -3)]);
      expect(find.text('Já passaram'), findsOneWidget);
    });

    testWidgets('sem bilhetes, diz que não há', (t) async {
      await _pump(t, const []);
      expect(find.text('Ainda não tem bilhetes'), findsOneWidget);
    });
  });

  group('o bilhete aberto', () {
    testWidgets('abre no bilhete por onde se entrou e diz quantos há', (t) async {
      await _pump(t, dois, bilhete: '2');
      expect(find.text('Bilhete 2 de 2'), findsOneWidget);
      expect(find.text('LPS-CODIGO-2'), findsOneWidget);
    });

    testWidgets('arrastar para o primeiro muda mesmo o bilhete que se vê', (t) async {
      // O defeito de antes: com `0` a valer "ainda não mexeu", voltar ao
      // primeiro deixava o título e a partilha no bilhete de entrada.
      await _pump(t, dois, bilhete: '2');
      expect(find.text('Bilhete 2 de 2'), findsOneWidget);

      // A meio do ecrã, que é onde o polegar arrasta — e onde está o código.
      await t.fling(find.byType(PageView), const Offset(400, 0), 1200);
      await t.pumpAndSettle();

      expect(find.text('Bilhete 1 de 2'), findsOneWidget);
      expect(find.text('LPS-CODIGO-1'), findsOneWidget);
    });

    testWidgets('com mais do que um, mostra que há para arrastar', (t) async {
      await _pump(t, dois, bilhete: '1');
      expect(find.text('Arraste para o bilhete seguinte'), findsOneWidget);
    });

    testWidgets('com um só, não promete um segundo que não existe', (t) async {
      await _pump(t, [_bilhete('1', sessao: 'S1')], bilhete: '1');
      expect(find.widgetWithText(AppBar, 'Bilhete'), findsOneWidget);
      expect(find.text('Arraste para o bilhete seguinte'), findsNothing);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('partilhar envia o bilhete que está à frente', (t) async {
      await _pump(t, dois, bilhete: '1');
      // Um só botão de partilha, e é o do bilhete visível — não o da compra.
      expect(find.byTooltip('Enviar este bilhete'), findsOneWidget);
      expect(find.text('LPS-CODIGO-1'), findsOneWidget);
      expect(find.text('LPS-CODIGO-2'), findsNothing);
    });

    testWidgets('o código copia-se com um toque, sem apanhar o arrastar', (t) async {
      String? copiado;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
        if (chamada.method == 'Clipboard.setData') copiado = (chamada.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await _pump(t, dois, bilhete: '1');
      await t.tap(find.text('LPS-CODIGO-1'));
      // `pumpAndSettle` passava por cima do aviso: ele desaparece sozinho ao
      // fim de uns segundos, e o relógio adiantado leva-o com ele.
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect(copiado, 'LPS-CODIGO-1');
      expect(find.text('Código copiado'), findsOneWidget);
    });
  });
}

Future<void> _pump(
  WidgetTester t,
  List<BilheteComprado> carteira, {
  String? bilhete,
  double largura = 430,
  double escala = 1,
  bool escuro = false,
}) async {
  t.view.physicalSize = Size(largura, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        meusBilhetesProvider.overrideWith((ref) => Stream.value(Dados(carteira, DateTime.now()))),
      ],
      child: MaterialApp(
        theme: escuro ? AppTheme.dark() : AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(size: Size(largura, 900), textScaler: TextScaler.linear(escala)),
          child: bilhete == null ? const MeusBilhetesPage() : BilhetePage(id: bilhete),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}
