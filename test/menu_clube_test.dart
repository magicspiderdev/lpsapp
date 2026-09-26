import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/publico/clube/menu_clube.dart';
import 'package:lpsapp/features/publico/noticias/corpo_blocos.dart';

/// O menu da app e as páginas do clube (guia público §9), e os blocos lado a
/// lado (`ocupa`, §6).
void main() {
  group('menu', () {
    test('lê páginas, modalidades, secções, links e submenus', () {
      final itens = ItemMenu.listaDe(menuExemplo);

      expect(itens.map((i) => i.rotulo), ['Quem somos', 'Formação', 'Loja']);
      expect(itens[0].destino, isA<DestinoPagina>());
      expect(itens[0].resumo, 'A família leonina de Porto Salvo, desde 1972');
      expect(itens[1].destino, isNull, reason: 'Um agrupador só abre o submenu.');
      expect(itens[1].filhos.map((f) => f.rotulo), ['Escola de futebol', 'Futsal']);
      expect(itens[1].filhos[1].destino, isA<DestinoModalidade>());
      expect(itens[2].destino, isA<DestinoUrl>());
    });

    test('um destino que a app não conhece não se mostra, e um agrupador vazio também não', () {
      final itens = ItemMenu.listaDe({
        'itens': [
          {
            'rotulo': 'Rádio',
            'destino': {'tipo': 'radio', 'canal': 1},
            'filhos': [],
          },
          {
            'rotulo': 'Secção nova',
            'destino': {'tipo': 'seccao', 'seccao': 'podcasts'},
            'filhos': [],
          },
          {
            'rotulo': 'Perigoso',
            'destino': {'tipo': 'url', 'url': 'javascript:alert(1)'},
            'filhos': [],
          },
          {
            'rotulo': 'Só coisas novas',
            'destino': null,
            'filhos': [
              {
                'rotulo': 'X',
                'destino': {'tipo': 'radio'},
                'filhos': [],
              },
            ],
          },
          {
            'rotulo': 'Agenda',
            'destino': {'tipo': 'seccao', 'seccao': 'agenda'},
            'filhos': [],
          },
          'não é um item',
        ],
      });

      expect(itens.map((i) => i.rotulo), ['Agenda']);
    });

    test('sem itens, ou com a chave em falta, é uma lista vazia', () {
      expect(ItemMenu.listaDe({}), isEmpty);
      expect(ItemMenu.listaDe({'itens': []}), isEmpty);
    });

    test('todas as secções do servidor têm rota', () {
      for (final s in ['noticias', 'agenda', 'competicao', 'modalidades', 'bilhetes', 'clube', 'comunidade']) {
        expect(rotasDasSeccoes[s], isNotNull, reason: s);
      }
    });

    test('página: resumo vazio fica nulo, corpo e capa lidos', () {
      final p = PaginaClube.fromJson({
        'slug': 'estatutos',
        'titulo': 'Estatutos',
        'resumo': '  ',
        'capa': {'url': 'https://x/media/1'},
        'corpo': [
          {'tipo': 'texto', 'html': '<p>Art. 1.º</p>'},
          'lixo',
        ],
      });

      expect(p.resumo, isNull);
      expect(p.capa?.url, 'https://x/media/1');
      expect(p.corpo, hasLength(1));
      expect(p.emHtml, isFalse);
    });

    test('página em HTML livre: abre-se no site; formato desconhecido é blocos', () {
      final html = PaginaClube.fromJson({
        'slug': 'parcerias',
        'titulo': 'Parcerias',
        'formato': 'html',
        'corpo': [],
        'html': {'documento': '<style></style><section></section>', 'pagina_inteira': false},
      });
      expect(html.emHtml, isTrue);

      final outro = PaginaClube.fromJson({'slug': 'x', 'titulo': 'X', 'formato': 'markdown', 'corpo': []});
      expect(outro.emHtml, isFalse);
    });
  });

  group('blocos lado a lado', () {
    test('fracções conhecidas; o resto é a linha inteira', () {
      expect(CorpoBlocos.fracao('1/3'), closeTo(1 / 3, 1e-9));
      expect(CorpoBlocos.fracao('3/4'), 0.75);
      expect(CorpoBlocos.fracao('5/12'), isNull);
      expect(CorpoBlocos.fracao(null), isNull);
    });

    final blocos = <Map<String, dynamic>>[
      {'tipo': 'citacao', 'texto': 'Esquerda', 'estilo': 'verde', 'ocupa': '1/3'},
      {'tipo': 'citacao', 'texto': 'Direita', 'estilo': 'verde', 'ocupa': '2/3'},
      {'tipo': 'citacao', 'texto': 'Por baixo'},
    ];

    Future<void> montar(WidgetTester t, double largura) async {
      t.view.physicalSize = Size(largura, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: SingleChildScrollView(child: CorpoBlocos(blocos))),
        ),
      );
    }

    testWidgets('num ecrã largo ficam na mesma linha, no mesmo card', (t) async {
      await montar(t, 800);

      final esquerda = t.getTopLeft(find.text('Esquerda'));
      final direita = t.getTopLeft(find.text('Direita'));
      final baixo = t.getTopLeft(find.text('Por baixo'));

      expect(esquerda.dy, direita.dy);
      expect(direita.dx, greaterThan(esquerda.dx));
      expect(baixo.dy, greaterThan(esquerda.dy));
      expect(t.takeException(), isNull);
    });

    testWidgets('num telemóvel empilham-se pela ordem', (t) async {
      await montar(t, 360);

      final esquerda = t.getTopLeft(find.text('Esquerda'));
      final direita = t.getTopLeft(find.text('Direita'));

      expect(direita.dy, greaterThan(esquerda.dy));
      expect(t.takeException(), isNull);
    });
  });

  group('blocos novos do corpo', () {
    Future<void> montar(WidgetTester t, List<Map<String, dynamic>> blocos, {Uri? noSite}) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(child: CorpoBlocos(blocos, noSite: noSite)),
          ),
        ),
      );
    }

    testWidgets('publicação do Instagram é um cartão com a legenda', (t) async {
      await montar(t, [
        {
          'tipo': 'publicacao',
          'provedor': 'instagram',
          'id_publicacao': 'Ddtf_wTicQI',
          'url': 'https://www.instagram.com/reel/Ddtf_wTicQI/',
          'legenda': null,
        },
      ]);
      expect(find.text('Publicação no Instagram'), findsOneWidget);
      expect(find.text('Ver no Instagram'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('ficheiros: nome, tipo e tamanho', (t) async {
      await montar(t, [
        {
          'tipo': 'ficheiros',
          'titulo': 'Documentos da inscrição',
          'ficheiros': [
            {
              'nome': 'Regulamento 2026/27',
              'tipo': 'PDF',
              'extensao': 'pdf',
              'bytes': 482133,
              'url': 'https://x/media/1',
              'download_url': 'https://x/media/1/descarregar',
            },
          ],
        },
      ]);
      expect(find.text('Documentos da inscrição'), findsOneWidget);
      expect(find.text('Regulamento 2026/27'), findsOneWidget);
      expect(find.text('PDF · 471 KB'), findsOneWidget);
    });

    testWidgets('galeria mostra uma miniatura por foto; vazia não aparece', (t) async {
      await montar(t, [
        {
          'tipo': 'galeria',
          'legenda': 'O jogo',
          'imagens': [
            {'url': 'https://x/media/1'},
            {'url': 'https://x/media/2'},
            {'sem': 'url'},
          ],
        },
        {'tipo': 'galeria', 'imagens': []},
      ]);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(InkWell), findsNWidgets(2));
      expect(find.text('O jogo'), findsOneWidget);
    });

    testWidgets('HTML livre vira ligação para o site, e sem ela ignora-se', (t) async {
      final bloco = {'tipo': 'html', 'html': '<style>.x{}</style><section class="x">…</section>'};

      await montar(t, [bloco], noSite: Uri.parse('https://www.leoesdeportosalvo.pt/noticias/x/'));
      expect(find.text('Há mais nesta página'), findsOneWidget);

      await montar(t, [bloco]);
      expect(find.text('Há mais nesta página'), findsNothing);
      expect(find.textContaining('section'), findsNothing);
    });
  });
}
