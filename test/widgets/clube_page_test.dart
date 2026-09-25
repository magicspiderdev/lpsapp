import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/publico/clube/clube.dart';
import 'package:lpsapp/features/publico/clube/clube_page.dart';
import 'package:lpsapp/features/publico/clube/clube_paginas.dart';
import 'package:lpsapp/features/publico/clube/clube_subpaginas.dart';
import 'package:lpsapp/features/publico/clube/clube_widgets.dart';
import 'package:lpsapp/features/publico/clube/menu_clube.dart';

/// O ecrã do clube e as sub-páginas cabem em ecrãs pequenos, com a letra do
/// sistema aumentada, em claro e escuro — com tudo preenchido e com o pouco
/// que a produção tem hoje.
void main() {
  final quaseVazio = Clube.fromJson({
    'redes': [],
    'site': 'https://www.leoesdeportosalvo.pt/',
    'horario': ['2ª Feira - 6ª Feira 13h00 - 20h00'],
    'modalidades': [
      {'slug': 'futsal', 'nome': 'Futsal', 'escaloes': 'Todos', 'tem_pagina': true},
      {'slug': 'walking-football', 'nome': 'Walking Football'},
    ],
  });

  final ecras = <String, Widget>{
    'principal': const ClubePage(),
    'história': const HistoriaClubePage(),
    'modalidades': const ModalidadesPage(),
    'modalidade': const ModalidadePage(slug: 'futsal'),
    'contactos': const ContactosClubePage(),
    // Com uma foto (citação) a 1/3 e o texto a 2/3: a 320 px empilham-se.
    'página': const PaginaClubePage(slug: 'quem-somos'),
    'submenu': const GrupoMenuPage(indice: 1),
  };

  for (final (nomeClube, clube) in [('completo', clubeExemplo), ('quase vazio', quaseVazio)]) {
    for (final MapEntry(key: nomeEcra, value: ecra) in ecras.entries) {
      for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
        for (final escuro in [false, true]) {
          final caso =
              '$nomeEcra · $nomeClube · ${largura.toInt()}px · letra x$escala · ${escuro ? 'escuro' : 'claro'}';
          testWidgets(caso, (t) async {
            t.view.physicalSize = Size(largura, 780);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);

            await t.pumpWidget(
              ProviderScope(
                overrides: [
                  clubeProvider.overrideWith((ref) => Stream.value(Dados(clube, DateTime.now()))),
                  // Com uma tabela de quatro colunas: a 320 px desliza, não transborda.
                  menuAppProvider.overrideWith(
                    (ref) => Stream.value(Dados(ItemMenu.listaDe(menuExemplo), DateTime.now())),
                  ),
                  paginaClubeProvider.overrideWith(
                    (ref, slug) => Stream.value(Dados(PaginaClube.fromJson(paginaExemplo), DateTime.now())),
                  ),
                  paginaModalidadeProvider.overrideWith(
                    (ref, slug) => Stream.value(
                      Dados(PaginaModalidade(Modalidade(nome: slug), corpoModalidadeExemplo), DateTime.now()),
                    ),
                  ),
                ],
                child: MaterialApp(
                  theme: escuro ? AppTheme.dark() : AppTheme.light(),
                  home: MediaQuery(
                    data: MediaQueryData(size: Size(largura, 780), textScaler: TextScaler.linear(escala)),
                    child: ecra,
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();

            // Um overflow do Flutter chega aqui como excepção.
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets('sem história nem contactos, a principal não mostra os cartões', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          clubeProvider.overrideWith(
            (ref) => Stream.value(
              Dados(
                Clube.fromJson({
                  'modalidades': [
                    {'slug': 'futsal', 'nome': 'Futsal'},
                  ],
                }),
                DateTime.now(),
              ),
            ),
          ),
          // O clube ainda não montou o menu da app.
          menuAppProvider.overrideWith((ref) => Stream.value(Dados(const <ItemMenu>[], DateTime.now()))),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const ClubePage()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Futsal'), findsOneWidget);
    expect(find.text('Conhecer o clube'), findsNothing);
    expect(find.text('Mais sobre o clube'), findsNothing, reason: 'Sem menu, a secção não aparece.');
    expect(find.text('Leões de Porto Salvo'), findsOneWidget);
  });

  testWidgets('as entradas do menu aparecem, com o resumo de cada uma', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          clubeProvider.overrideWith((ref) => Stream.value(Dados(clubeExemplo, DateTime.now()))),
          menuAppProvider.overrideWith((ref) => Stream.value(Dados(ItemMenu.listaDe(menuExemplo), DateTime.now()))),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const ClubePage()),
      ),
    );
    await t.pumpAndSettle();

    // A lista do ecrã, e não o carrossel das modalidades, que também desliza.
    await t.scrollUntilVisible(find.text('Mais sobre o clube'), 300, scrollable: find.byType(Scrollable).first);
    // "Formação" também é escalão de modalidades: procura-se nos cartões.
    expect(find.widgetWithText(CartaoEntrada, 'Quem somos'), findsOneWidget);
    expect(find.widgetWithText(CartaoEntrada, 'Formação'), findsOneWidget);
    expect(find.text('Escola de futebol · Futsal'), findsOneWidget, reason: 'Um agrupador resume o que tem dentro.');
  });
}
