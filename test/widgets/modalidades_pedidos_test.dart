/// Os ecrãs de pedidos de modalidade (§4.22): a lista diz o valor sem
/// inventar, o formulário mostra quem não pode com a razão, avisa que a baixa
/// não fecha nada, e os erros levam a algum lado — em ecrãs estreitos, com a
/// letra grande, em claro e escuro.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/api/api_exception.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/modalidades_pedidos/modalidades_pedidos.dart';
import 'package:lpsapp/features/modalidades_pedidos/modalidades_pedidos_page.dart';
import 'package:lpsapp/features/modalidades_pedidos/pedido_modalidade_page.dart';
import 'package:lpsapp/features/modalidades_pedidos/pedir_modalidade_page.dart';
import 'package:lpsapp/features/publico/clube/clube.dart';

class _Quem extends SessaoController {
  _Quem(this.inicial);

  final Sessao inicial;

  @override
  Sessao build() => inicial;
}

/// Responde a `pedir` com o que o teste mandar, sem rede.
class _Accoes extends AccoesModalidades {
  _Accoes(this.resposta) : super(Dio());

  final Future<PedidoModalidade> Function() resposta;
  final enviados = <Map<String, Object?>>[];

  @override
  Future<PedidoModalidade> pedir({
    required String modalidade,
    required String tipo,
    required int nrSocio,
    String? observacoes,
  }) {
    enviados.add({'modalidade': modalidade, 'tipo': tipo, 'nr_socio': nrSocio, 'observacoes': observacoes});
    return resposta();
  }
}

final _dados = PedidosModalidades.fromJson({
  'pedidos': [
    {
      'id': 'P1',
      'tipo': 'inscricao',
      'tipo_label': 'Inscrição',
      'estado': 'submetido',
      'estado_label': 'Por decidir',
      'aberto': true,
      'cancelavel': true,
      'modalidade': {'slug': 'patinagem', 'nome': 'Patinagem artística'},
      'atleta': {'nr_socio': 9302, 'nome_completo': 'CARMINHO EXEMPLO'},
      'valor_estimado': null,
      'criado_em': '2026-09-22 18:40:00',
    },
    {
      'id': 'P2',
      'tipo': 'baixa',
      'tipo_label': 'Baixa',
      'estado': 'recusado',
      'estado_label': 'Recusado',
      'aberto': false,
      'cancelavel': false,
      'modalidade': {'slug': 'futsal', 'nome': 'Futsal'},
      'atleta': {'nr_socio': 9301, 'nome_completo': 'JOÃO EXEMPLO'},
      'valor_estimado': null,
      'motivo': 'Falta devolver o equipamento.',
      'criado_em': '2026-09-10 10:00:00',
    },
    {
      'id': 'P3',
      'tipo': 'inscricao',
      'tipo_label': 'Inscrição',
      'estado': 'em_lista_de_espera',
      'estado_label': 'Em lista de espera',
      'aberto': false,
      'cancelavel': false,
      'modalidade': {'slug': 'futsal', 'nome': 'Futsal'},
      'atleta': {'nr_socio': 9301, 'nome_completo': 'JOÃO EXEMPLO'},
      'valor_estimado': 25,
      'criado_em': '2026-09-01 10:00:00',
    },
  ],
  'atletas': [
    {'nr_socio': 9301, 'nome_completo': 'JOÃO EXEMPLO', 'idade': 41, 'relacao': 'proprio', 'pode_inscrever': true},
    {
      'nr_socio': 9303,
      'nome_completo': 'RUI EXEMPLO',
      'idade': 15,
      'relacao': 'pai',
      'pode_inscrever': false,
      'porque_nao': 'A ficha deste sócio não está activa. Fale com a secretaria.',
    },
  ],
});

final _clube = Clube.fromJson({
  'nome': 'Leões',
  'modalidades': [
    {'slug': 'futsal', 'nome': 'Futsal', 'tem_pagina': true},
    {'slug': 'patinagem', 'nome': 'Patinagem artística'},
    {'nome': 'Sem slug, não se pede'},
  ],
});

final _socio = sessaoDeSocio(const SocioSessao(nrSocio: 9301, nomeCompleto: 'JOÃO EXEMPLO', estado: 1));
final _menor = sessaoDaConta({
  'nome': 'Rita',
  'menor': true,
  'permissoes': {'pagar': false, 'comprar': false, 'contratar': false},
  'socio': {'nr_socio': 1924, 'nome_completo': 'RITA', 'estado': 1},
});

Future<void> _pump(
  WidgetTester t, {
  String inicio = RotasModalidades.lista,
  Sessao? quem,
  PedidosModalidades? dados,
  AccoesModalidades? accoes,
  double largura = 430,
  double escala = 1,
  bool escuro = false,
}) async {
  t.view.physicalSize = Size(largura, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final router = GoRouter(
    initialLocation: inicio,
    routes: [
      GoRoute(
        path: RotasModalidades.lista,
        builder: (_, _) => const ModalidadesPedidosPage(),
        routes: [
          GoRoute(
            path: 'pedir',
            builder: (_, s) => PedirModalidadePage(
              modalidade: s.uri.queryParameters['modalidade'],
              tipo: s.uri.queryParameters['tipo'],
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, s) => PedidoModalidadePage(id: s.pathParameters['id']!, inicial: s.extra as PedidoModalidade?),
          ),
        ],
      ),
      GoRoute(
        path: '/inscricoes',
        builder: (_, _) => const Scaffold(body: Text('ECRÃ DE INSCRIÇÃO DE SÓCIO')),
      ),
      GoRoute(
        path: '/socio/suporte',
        builder: (_, _) => const Scaffold(body: Text('ECRÃ DE SUPORTE')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sessaoProvider.overrideWith(() => _Quem(quem ?? _socio)),
        pedidosModalidadesProvider.overrideWith((ref) => Stream.value(Dados(dados ?? _dados, DateTime.now()))),
        // O detalhe abre com o `inicial`; o servidor "responde" com o da lista.
        pedidoModalidadeProvider.overrideWith(
          (ref, id) => Stream.value(Dados((dados ?? _dados).pedidos.firstWhere((p) => p.id == id), DateTime.now())),
        ),
        clubeProvider.overrideWith((ref) => Stream.value(Dados(_clube, DateTime.now()))),
        if (accoes != null) accoesModalidadesProvider.overrideWithValue(accoes),
      ],
      child: MaterialApp.router(
        theme: escuro ? AppTheme.dark() : AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: Size(largura, 900), textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _verAte(WidgetTester t, Finder alvo) async {
  if (alvo.evaluate().isEmpty) {
    await t.dragUntilVisible(alvo, find.byType(ListView).first, const Offset(0, -150));
    await t.pumpAndSettle();
  }
  // Construído não é visível: a lista desenha um pouco abaixo da dobra.
  await t.ensureVisible(alvo.first);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  group('lista', () {
    for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
      for (final escuro in [false, true]) {
        testWidgets('${largura.toInt()}px · letra x$escala · ${escuro ? 'escuro' : 'claro'}', (t) async {
          await _pump(t, largura: largura, escala: escala, escuro: escuro);
          expect(t.takeException(), isNull);
          await _pump(t, inicio: RotasModalidades.pedir, largura: largura, escala: escala, escuro: escuro);
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('valor por saber não é "0 €"; estado desconhecido mostra o label', (t) async {
      await _pump(t);
      expect(find.text('O valor é confirmado pela secretaria.'), findsOneWidget);
      expect(find.textContaining(RegExp(r'(^|[^0-9])0,00')), findsNothing);
      await _verAte(t, find.text('Em lista de espera'));
      expect(find.text('Em lista de espera'), findsOneWidget);
      expect(find.textContaining('25,00'), findsOneWidget);
    });

    testWidgets('baixa recusada: o motivo tal e qual, e o caminho para a secretaria', (t) async {
      await _pump(t);
      await _verAte(t, find.text('Falar com a secretaria'));
      expect(find.text('Falta devolver o equipamento.'), findsOneWidget);
      await t.tap(find.text('Falar com a secretaria'));
      await t.pumpAndSettle();
      expect(find.text('ECRÃ DE SUPORTE'), findsOneWidget);
    });

    testWidgets('só o que é cancelável se pode desistir, e pede confirmação', (t) async {
      await _pump(t);
      expect(find.text('Desistir do pedido'), findsOneWidget);
      await t.tap(find.text('Desistir do pedido'));
      await t.pumpAndSettle();
      expect(find.text('Desistir do pedido?'), findsOneWidget);
      await t.tap(find.text('Voltar'));
      await t.pumpAndSettle();
      expect(find.text('Desistir do pedido?'), findsNothing);
    });

    testWidgets('um sócio adulto tem o botão de pedir', (t) async {
      await _pump(t);
      expect(find.text('Pedir inscrição ou baixa'), findsOneWidget);
    });

    testWidgets('um menor não tem o botão: diz quem o faz', (t) async {
      await _pump(t, quem: _menor);
      expect(find.text('Pedir inscrição ou baixa'), findsNothing);
      expect(find.text('As inscrições são feitas pelo encarregado de educação.'), findsOneWidget);
    });

    testWidgets('conta sem ficha e sem ninguém a cargo: oferece a inscrição de sócio', (t) async {
      await _pump(
        t,
        quem: SessaoConta(const ContaSessao(nome: 'Sem ficha')),
        dados: const PedidosModalidades(),
      );
      expect(find.text('Pedir inscrição ou baixa'), findsNothing);
      expect(find.text('Ainda não fez nenhum pedido.'), findsOneWidget);
      await t.tap(find.text('Inscrever-me como sócio'));
      await t.pumpAndSettle();
      expect(find.text('ECRÃ DE INSCRIÇÃO DE SÓCIO'), findsOneWidget);
    });

    testWidgets('tocar num pedido abre-o', (t) async {
      await _pump(t);
      await t.tap(find.text('Patinagem artística'));
      await t.pumpAndSettle();
      expect(find.text('Observações'), findsNothing);
      expect(find.text('Mensalidade'), findsOneWidget);
      expect(find.text('O valor é confirmado pela secretaria.'), findsOneWidget);
    });
  });

  group('pedir', () {
    RadioListTile<int> linha(WidgetTester t, int nr) =>
        t.widget<RadioListTile<int>>(find.byWidgetPredicate((w) => w is RadioListTile<int> && w.value == nr));

    testWidgets('quem não pode inscrever-se aparece desactivado, com a razão; na baixa pode', (t) async {
      await _pump(t, inicio: RotasModalidades.pedir);
      expect(find.textContaining('A ficha deste sócio não está activa'), findsOneWidget);
      expect(linha(t, 9303).enabled, isFalse);
      expect(linha(t, 9301).enabled, isTrue);

      await t.tap(find.text('Baixa'));
      await t.pumpAndSettle();
      expect(linha(t, 9303).enabled, isTrue, reason: 'a baixa não exige ficha activa');
      expect(find.textContaining('Pedir a baixa não fecha nada'), findsOneWidget);
    });

    testWidgets('sem modalidade escolhida não se envia', (t) async {
      await _pump(t, inicio: RotasModalidades.pedir);
      await _verAte(t, find.text('Pedir a inscrição'));
      final botao = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Pedir a inscrição'));
      expect(botao.onPressed, isNull);
      // Só as modalidades com `slug` se podem pedir.
      expect(find.text('Sem slug, não se pede'), findsNothing);
    });

    testWidgets('um menor vê a explicação, e não o formulário', (t) async {
      await _pump(t, inicio: RotasModalidades.pedir, quem: _menor);
      expect(find.text('As inscrições são feitas pelo encarregado de educação.'), findsOneWidget);
      expect(find.text('Pedir a inscrição'), findsNothing);
    });

    Future<void> enviar(WidgetTester t) async {
      await _verAte(t, find.text('Pedir a baixa'));
      await t.tap(find.text('Pedir a baixa'));
      await t.pumpAndSettle();
      // Confirmar antes de enviar, com o aviso da baixa lá dentro.
      expect(find.text('Pedir a baixa?'), findsOneWidget);
      expect(find.textContaining('continua a ser cobrada'), findsWidgets);
      await t.tap(find.text('Enviar pedido'));
      await t.pumpAndSettle();
    }

    testWidgets('409 ja_existe abre o pedido que já existe', (t) async {
      final accoes = _Accoes(
        () => Future.error(
          const ApiException(
            httpStatus: 409,
            erro: 'ja_existe',
            message: 'Já há um pedido para Patinagem à espera de decisão.',
            dados: {'id': 'P1'},
          ),
        ),
      );
      await _pump(
        t,
        inicio: RotasModalidades.pedirCom(modalidade: 'patinagem', tipo: 'baixa'),
        accoes: accoes,
      );
      await enviar(t);

      expect(accoes.enviados.single, {'modalidade': 'patinagem', 'tipo': 'baixa', 'nr_socio': 9301, 'observacoes': ''});
      // O detalhe do P1: tem a linha "Mensalidade" com o valor por saber.
      expect(find.text('Mensalidade'), findsOneWidget);
      expect(find.text('Pedir modalidade'), findsNothing);
    });

    testWidgets('403 conta_sem_socio explica e oferece a inscrição de sócio', (t) async {
      final accoes = _Accoes(
        () => Future.error(
          const ApiException(
            httpStatus: 403,
            erro: 'conta_sem_socio',
            message: 'Para inscrever alguém numa modalidade é preciso ser sócio.',
          ),
        ),
      );
      await _pump(
        t,
        inicio: RotasModalidades.pedirCom(modalidade: 'futsal', tipo: 'baixa'),
        accoes: accoes,
      );
      await enviar(t);

      await _verAte(t, find.text('Inscrever-me como sócio'));
      expect(find.text('Para inscrever alguém numa modalidade é preciso ser sócio.'), findsOneWidget);
      await t.tap(find.text('Inscrever-me como sócio'));
      await t.pumpAndSettle();
      expect(find.text('ECRÃ DE INSCRIÇÃO DE SÓCIO'), findsOneWidget);
    });

    testWidgets('403 menor_de_idade mostra a message', (t) async {
      final accoes = _Accoes(
        () => Future.error(
          const ApiException(
            httpStatus: 403,
            erro: 'menor_de_idade',
            message: 'Peça ao seu encarregado de educação.',
            dados: {'permissao': 'contratar'},
          ),
        ),
      );
      await _pump(
        t,
        inicio: RotasModalidades.pedirCom(modalidade: 'futsal', tipo: 'baixa'),
        accoes: accoes,
      );
      await enviar(t);

      await _verAte(t, find.text('Peça ao seu encarregado de educação.'));
      expect(find.text('Peça ao seu encarregado de educação.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
