/// A agenda e a competição cabem em ecrãs pequenos, com a letra do sistema
/// aumentada, em claro e escuro — com jogos a sério e com o pouco que uma
/// época a começar tem.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/publico/agenda/agenda.dart';
import 'package:lpsapp/features/publico/agenda/agenda_page.dart';
import 'package:lpsapp/features/publico/competicao/competicao.dart';
import 'package:lpsapp/features/publico/competicao/competicao_page.dart';

/// A agenda sem recuo no passado: nos testes de desenho não se pede à rede, e
/// um indicador de carregamento a girar nunca deixaria o ecrã assentar.
class _SemRecuo extends MaisAnterioresController {
  _SemRecuo({this.haMais = false, this.itens = const []});

  final bool haMais;
  final List<ItemAgenda> itens;

  @override
  MaisAnteriores build() => MaisAnteriores(desde: DateTime.now(), itens: itens, fim: !haMais);

  @override
  Future<void> carregar() async => pedidos++;

  int pedidos = 0;
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  final detalhe = provaExemplo('campeonato-nacional-hoquei-2026-27');

  // Uma época que ainda não começou: a prova existe, jogos é que não.
  const provaVazia = ProvaDetalhe(
    prova: Prova(slug: 'taca-2026-27', nome: 'Taça de Portugal', epoca: '2026-27', formato: 'taca'),
  );

  final agendas = <String, List<ItemAgenda>>{'com jogos': agendaExemplo, 'vazia': const []};

  for (final MapEntry(key: nome, value: itens) in agendas.entries) {
    for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
      for (final escuro in [false, true]) {
        testWidgets('agenda · $nome · ${largura.toInt()}px · letra x$escala · ${escuro ? 'escuro' : 'claro'}', (
          t,
        ) async {
          await _pump(
            t,
            largura: largura,
            escala: escala,
            escuro: escuro,
            overrides: [
              agendaProvider.overrideWith((ref) => Stream.value(Dados(itens, DateTime.now()))),
              maisAnterioresProvider.overrideWith(_SemRecuo.new),
            ],
            ecra: const AgendaPage(),
          );
        });
      }
    }
  }

  for (final (nome, detalhes) in [('com jogos', detalhe), ('sem jogos', provaVazia)]) {
    for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
      for (final escuro in [false, true]) {
        testWidgets('prova · $nome · ${largura.toInt()}px · letra x$escala · ${escuro ? 'escuro' : 'claro'}', (
          t,
        ) async {
          await _pump(
            t,
            largura: largura,
            escala: escala,
            escuro: escuro,
            overrides: [
              provaProvider(
                detalhes.prova.slug,
              ).overrideWith((ref) => Stream.value(Dados(detalhes, DateTime.now()))),
            ],
            ecra: ProvaPage(slug: detalhes.prova.slug),
          );
        });
      }
    }
  }

  for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
    testWidgets('competições · ${largura.toInt()}px · letra x$escala', (t) async {
      await _pump(
        t,
        largura: largura,
        escala: escala,
        escuro: false,
        overrides: [
          provasProvider(null).overrideWith((ref) => Stream.value(Dados(provasExemplo(null), DateTime.now()))),
        ],
        ecra: const CompeticaoPage(),
      );
    });
  }

  testWidgets('o selector de épocas só aparece quando há mais do que uma', (t) async {
    final umaSo = Provas.fromJson({
      'epoca_actual': '2026-27',
      'epoca': '2026-27',
      'epocas': ['2026-27'],
      'provas': [
        {'slug': 'liga-2026-27', 'nome': 'Liga Placard Futsal', 'epoca': '2026-27', 'formato': 'liga'},
      ],
    });

    await _pump(
      t,
      largura: 430,
      escala: 1,
      escuro: false,
      overrides: [provasProvider(null).overrideWith((ref) => Stream.value(Dados(umaSo, DateTime.now())))],
      ecra: const CompeticaoPage(),
    );

    expect(find.text('2026-27 · época actual'), findsNothing);
    expect(find.text('Liga Placard Futsal'), findsOneWidget);
  });

  testWidgets('as contagens da prova são as de jogos do clube', (t) async {
    await _pump(
      t,
      largura: 430,
      escala: 1,
      escuro: false,
      overrides: [
        provasProvider(null).overrideWith((ref) => Stream.value(Dados(provasExemplo(null), DateTime.now()))),
      ],
      ecra: const CompeticaoPage(),
    );

    expect(find.text('9 jogados · 13 por jogar'), findsOneWidget);
  });

  testWidgets('a agenda abre nos próximos e o passado fica no outro separador', (t) async {
    ItemAgenda jogo(String titulo, Duration daqui) => ItemAgenda.fromJson({
      'tipo': 'jogo',
      'id': titulo.hashCode,
      'titulo': titulo,
      'inicio': DateTime.now().add(daqui).toIso8601String(),
      'equipa_casa': {'nome': titulo, 'do_clube': true},
      'equipa_fora': {'nome': 'Outros'},
    });

    await _pump(
      t,
      largura: 430,
      escala: 1,
      escuro: false,
      overrides: [
        agendaProvider.overrideWith(
          (ref) => Stream.value(
            Dados([
              jogo('Jogo que vem', const Duration(days: 2)),
              jogo('Jogo que passou', const Duration(days: -2)),
            ], DateTime.now()),
          ),
        ),
        maisAnterioresProvider.overrideWith(_SemRecuo.new),
      ],
      ecra: const AgendaPage(),
    );

    expect(find.text('Jogo que vem'), findsOneWidget);
    expect(find.text('Jogo que passou'), findsNothing);

    await t.tap(find.text('Anteriores'));
    await t.pumpAndSettle();

    expect(find.text('Jogo que passou'), findsOneWidget);
    expect(find.text('Jogo que vem'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('havendo mais passado, os anteriores mostram que estão a ir buscá-lo', (t) async {
    final recuo = _SemRecuo(haMais: true);

    await _pump(
      t,
      largura: 430,
      escala: 1,
      escuro: false,
      assentar: false, // o indicador de carregamento nunca pára de girar
      overrides: [
        agendaProvider.overrideWith((ref) => Stream.value(Dados(const <ItemAgenda>[], DateTime.now()))),
        maisAnterioresProvider.overrideWith(() => recuo),
      ],
      ecra: const AgendaPage(),
    );

    await t.tap(find.text('Anteriores'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    // Com mais para trás não se diz "não há nada": diz-se que vem a caminho.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Nada para trás'), findsNothing);
    // E vai buscá-lo sozinho, sem ninguém ter de carregar em nada.
    expect(recuo.pedidos, greaterThan(0));
  });

  testWidgets('uma prova acabada abre no que já se jogou, não num ecrã vazio', (t) async {
    final acabada = ProvaDetalhe(
      prova: const Prova(slug: 'liga-2025-26', nome: 'Liga', epoca: '2025-26', formato: 'liga'),
      realizados: [
        ItemAgenda.fromJson({
          'tipo': 'jogo',
          'id': 1,
          'titulo': 'Último da época',
          'inicio': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
          // O cartão de um jogo mostra as equipas, não o título.
          'equipa_casa': {'nome': 'Leões do último jogo', 'do_clube': true},
          'equipa_fora': {'nome': 'Outros'},
          // Pela data já se jogou, mesmo sem resultado registado.
          'resultado': null,
        }),
      ],
    );

    await _pump(
      t,
      largura: 430,
      escala: 1,
      escuro: false,
      overrides: [
        provaProvider('liga-2025-26').overrideWith((ref) => Stream.value(Dados(acabada, DateTime.now()))),
      ],
      ecra: const ProvaPage(slug: 'liga-2025-26'),
    );

    expect(find.text('Leões do último jogo'), findsOneWidget);
  });

  testWidgets('um evento cancelado continua na lista, com o aviso', (t) async {
    final cancelado = ItemAgenda.fromJson({
      'tipo': 'evento',
      'id': 9,
      'titulo': 'Torneio de Verão',
      'inicio': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      'estado': 'cancelado',
      'local': 'Complexo Desportivo Leões de Porto Salvo',
      'resumo': 'Três dias de torneio para todos os escalões de formação.',
    });

    // O pior caso de largura: ecrã estreito com a letra do sistema no máximo.
    await _pump(
      t,
      largura: 320,
      escala: 2,
      escuro: false,
      overrides: [
        agendaProvider.overrideWith((ref) => Stream.value(Dados([cancelado], DateTime.now()))),
        maisAnterioresProvider.overrideWith(_SemRecuo.new),
      ],
      ecra: const AgendaPage(),
    );

    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.text('Torneio de Verão'), findsOneWidget);
  });

  testWidgets('um jogo sem hora não anuncia hora nenhuma, e nunca 00:00', (t) async {
    final semHora = ItemAgenda.fromJson({
      'tipo': 'jogo',
      'id': 11,
      'titulo': 'UPVN x Leões',
      'inicio': '${DateTime.now().add(const Duration(days: 2)).toIso8601String().split('T').first} 00:00:00',
      'hora_confirmada': false,
      'equipa_casa': {'nome': 'Up Venda Nova'},
      'equipa_fora': {'nome': 'Cr Leões Porto Salvo', 'do_clube': true},
    });

    await _pump(
      t,
      largura: 430,
      escala: 1,
      escuro: false,
      overrides: [
        agendaProvider.overrideWith((ref) => Stream.value(Dados([semHora], DateTime.now()))),
        maisAnterioresProvider.overrideWith(_SemRecuo.new),
      ],
      ecra: const AgendaPage(),
    );

    // Sem hora, o lugar dela fica vazio — e nunca com `00:00`, que é o que a
    // API manda quando a hora não existe.
    expect(find.text('Hora por confirmar'), findsNothing);
    expect(find.text('00:00'), findsNothing);
    // O jogo continua lá, com o dia e as equipas.
    expect(find.text('Cr Leões Porto Salvo'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester t, {
  required double largura,
  required double escala,
  required bool escuro,
  required List<Override> overrides,
  required Widget ecra,
  bool assentar = true,
}) async {
  t.view.physicalSize = Size(largura, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: escuro ? AppTheme.dark() : AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(size: Size(largura, 780), textScaler: TextScaler.linear(escala)),
          child: ecra,
        ),
      ),
    ),
  );
  if (assentar) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
  }

  // Um overflow do Flutter chega aqui como excepção.
  expect(t.takeException(), isNull);
}
