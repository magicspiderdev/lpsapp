/// As fichas de um jogo e de um evento: o que cada uma mostra, e que o cartão
/// da agenda leva lá — em ecrãs estreitos, com a letra do sistema aumentada,
/// em claro e escuro.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/publico/agenda/agenda.dart';
import 'package:lpsapp/features/publico/agenda/agenda_widgets.dart';
import 'package:lpsapp/features/publico/agenda/evento_page.dart';
import 'package:lpsapp/features/publico/competicao/competicao.dart';
import 'package:lpsapp/features/publico/competicao/jogo_page.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  final jogos = agendaExemplo.where((i) => i.tipo == TipoItem.jogo).toList();
  final jogado = jogos.firstWhere((j) => j.temResultado);
  final porJogar = jogos.firstWhere((j) => !j.temResultado);
  final evento = agendaExemplo.firstWhere((i) => i.tipo == TipoItem.evento && i.descricao != null);

  group('a rota de cada item', () {
    test('um jogo vai pela ficha do servidor, um evento pelo slug', () {
      expect(rotaDoItem(jogado), '/agenda/jogo/${jogado.id}');
      expect(rotaDoItem(evento), '/agenda/evento/${evento.slug}');
    });

    test('um evento sem slug vai pelo id', () {
      final semSlug = ItemAgenda.fromJson({'tipo': 'evento', 'id': 42, 'titulo': 'Sem slug'});
      expect(rotaDoItem(semSlug), '/agenda/evento/42');
    });

    test('um tipo que a app não conhece não abre nada', () {
      final futuro = ItemAgenda.fromJson({'tipo': 'estagio', 'id': 7, 'titulo': 'Estágio de pré-época'});
      expect(rotaDoItem(futuro), isNull);
    });
  });

  group('ficha de jogo', () {
    for (final (nome, detalhe) in [
      ('com ficha', jogoExemplo(jogado.id)),
      ('sem ficha', jogoExemplo(porJogar.id)),
    ]) {
      for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
        for (final escuro in [false, true]) {
          testWidgets('$nome · ${largura.toInt()}px · letra x$escala · ${escuro ? 'escuro' : 'claro'}', (t) async {
            await _pump(
              t,
              largura: largura,
              escala: escala,
              escuro: escuro,
              overrides: [
                jogoProvider(detalhe.jogo.id).overrideWith((ref) => Stream.value(Dados(detalhe, DateTime.now()))),
              ],
              ecra: JogoPage(id: detalhe.jogo.id),
            );
          });
        }
      }
    }

    testWidgets('o marcador oficial é o do jogo, e a ficha diz o que aconteceu', (t) async {
      final detalhe = jogoExemplo(jogado.id);

      await _pump(
        t,
        largura: 430,
        escala: 1,
        escuro: false,
        overrides: [
          jogoProvider(jogado.id).overrideWith((ref) => Stream.value(Dados(detalhe, DateTime.now()))),
        ],
        ecra: JogoPage(id: jogado.id),
      );

      expect(find.text('${jogado.golosCasa} - ${jogado.golosFora}'), findsOneWidget);
      expect(find.text('Início do jogo'), findsOneWidget);
      expect(find.text('Assistência de Miguel Faria'), findsOneWidget);
      // Numa substituição, `atleta` é quem entra e `atleta_saiu` quem sai.
      expect(find.text('Entra André Lopes'), findsOneWidget);
      expect(find.text('Sai Miguel Faria'), findsOneWidget);
      // O autogolo conta para a outra equipa, e o marcador já vem contado.
      expect(find.text('Na própria baliza'), findsOneWidget);
      expect(find.text('2-2'), findsOneWidget);
    });

    testWidgets('um tipo de linha que a app não conhece é ignorado, não rebenta', (t) async {
      final comTipoNovo = JogoComFicha.fromJson({
        'jogo': {
          'tipo': 'jogo',
          'id': 99,
          'titulo': 'Leões x Oeiras',
          'inicio': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'estado': 'terminado',
          'equipa_casa': {'nome': 'Leões Porto Salvo', 'do_clube': true},
          'equipa_fora': {'nome': 'CD Oeiras'},
          'resultado': {'casa': 1, 'fora': 0},
        },
        'ficha': [
          {'tipo': 'golo', 'minuto': 10, 'equipa': 'casa', 'atleta': 'Diogo', 'marcador': {'casa': 1, 'fora': 0}},
          {'tipo': 'tempo_morto', 'minuto': 12, 'equipa': 'fora', 'marcador': {'casa': 1, 'fora': 0}},
        ],
      });

      await _pump(
        t,
        largura: 430,
        escala: 1,
        escuro: false,
        overrides: [
          jogoProvider('99').overrideWith((ref) => Stream.value(Dados(comTipoNovo, DateTime.now()))),
        ],
        ecra: const JogoPage(id: '99'),
      );

      expect(find.text('Diogo'), findsOneWidget);
      expect(find.text('Ficha por escrever'), findsNothing);
    });

    testWidgets('um jogo já jogado sem ficha diz que ela está por escrever', (t) async {
      final semFicha = JogoComFicha(jogo: jogado);

      await _pump(
        t,
        largura: 430,
        escala: 1,
        escuro: false,
        overrides: [
          jogoProvider(jogado.id).overrideWith((ref) => Stream.value(Dados(semFicha, DateTime.now()))),
        ],
        ecra: JogoPage(id: jogado.id),
      );

      expect(find.text('Ficha por escrever'), findsOneWidget);
    });

    testWidgets('antes do jogo não se promete ficha nenhuma', (t) async {
      await _pump(
        t,
        largura: 430,
        escala: 1,
        escuro: false,
        overrides: [
          jogoProvider(porJogar.id).overrideWith((ref) => Stream.value(Dados(JogoComFicha(jogo: porJogar), DateTime.now()))),
        ],
        ecra: JogoPage(id: porJogar.id),
      );

      expect(find.text('A ficha abre quando o jogo começar'), findsOneWidget);
      expect(find.text('vs'), findsOneWidget);
    });

    testWidgets('o cartão da lista desenha o placard enquanto a ficha não chega', (t) async {
      await _pump(
        t,
        largura: 430,
        escala: 1,
        escuro: false,
        assentar: false, // o pedido nunca responde
        overrides: [
          jogoProvider(jogado.id).overrideWith((ref) => const Stream<Dados<JogoComFicha>>.empty()),
        ],
        ecra: JogoPage(id: jogado.id, inicial: jogado),
      );

      // Sem resposta do servidor, o que o cartão trazia já está no ecrã.
      expect(find.text('${jogado.golosCasa} - ${jogado.golosFora}'), findsOneWidget);
      expect(find.text('SL Benfica'), findsOneWidget);
    });
  });

  group('ficha de um evento', () {
    for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
      for (final escuro in [false, true]) {
        testWidgets('evento · ${largura.toInt()}px · letra x$escala · ${escuro ? 'escuro' : 'claro'}', (t) async {
          await _pump(
            t,
            largura: largura,
            escala: escala,
            escuro: escuro,
            overrides: const [],
            ecra: EventoPage(referencia: evento.slug!, inicial: evento),
          );
        });
      }
    }

    testWidgets('a descrição parte-se em parágrafos e o resumo fica por cima', (t) async {
      await _pump(
        t,
        largura: 430,
        escala: 1,
        escuro: false,
        overrides: const [],
        ecra: EventoPage(referencia: evento.slug!, inicial: evento),
      );

      expect(find.text(evento.titulo), findsOneWidget);
      expect(find.text(evento.resumo!), findsOneWidget);
      // Dois parágrafos, separados por linha em branco — e nenhum com a linha
      // em branco lá dentro.
      final paragrafos = evento.descricao!.split(RegExp(r'\n\s*\n'));
      expect(paragrafos.length, 2);
      for (final p in paragrafos) {
        expect(find.text(p.trim()), findsOneWidget);
      }
    });

    testWidgets('sem o item em mão, procura-o na agenda já carregada', (t) async {
      await _pump(
        t,
        largura: 430,
        escala: 1,
        escuro: false,
        overrides: [
          agendaProvider.overrideWith((ref) => Stream.value(Dados(agendaExemplo, DateTime.now()))),
        ],
        ecra: EventoPage(referencia: evento.slug!),
      );

      expect(find.text(evento.titulo), findsOneWidget);
    });

    testWidgets('um evento que já não está na agenda não finge que está', (t) async {
      await _pump(
        t,
        largura: 430,
        escala: 1,
        escuro: false,
        overrides: [
          agendaProvider.overrideWith((ref) => Stream.value(Dados(agendaExemplo, DateTime.now()))),
        ],
        ecra: const EventoPage(referencia: 'evento-que-ja-nao-existe'),
      );

      expect(find.text('Evento não encontrado'), findsOneWidget);
    });
  });

  testWidgets('tocar num cartão abre a ficha; o botão dos bilhetes vai à bilheteira', (t) async {
    final comBilhetes = agendaExemplo.firstWhere((i) => i.tipo == TipoItem.jogo && i.temBilhetes);
    final visitadas = <String>[];

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ListView(children: [CartaoAgenda(comBilhetes)]),
          ),
        ),
        GoRoute(
          path: '/agenda/jogo/:id',
          builder: (_, s) {
            visitadas.add('jogo:${s.pathParameters['id']}');
            return const Scaffold(body: Text('ficha'));
          },
        ),
        GoRoute(
          path: '/bilhetes/:id',
          builder: (_, s) {
            visitadas.add('bilhetes:${s.pathParameters['id']}');
            return const Scaffold(body: Text('bilheteira'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
      ),
    );
    await t.pumpAndSettle();

    // O botão está dentro do cartão: quem já sabe o que quer não passa pela ficha.
    await t.tap(find.text('Bilhetes'));
    await t.pumpAndSettle();
    expect(visitadas, ['bilhetes:${comBilhetes.sessaoBilhetes}']);

    router.go('/');
    await t.pumpAndSettle();

    await t.tap(find.text(comBilhetes.casa!.nome));
    await t.pumpAndSettle();
    expect(visitadas.last, 'jogo:${comBilhetes.id}');
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
