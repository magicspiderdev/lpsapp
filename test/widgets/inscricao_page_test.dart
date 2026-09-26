/// O ecrã da inscrição de sócio (§4.21): conduzido só pelo `proximo_passo`,
/// com o quadro de assinatura, os meses num contador e o que um menor não
/// pode fazer — em ecrãs estreitos, com a letra aumentada, em claro e escuro.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/auth/token_store.dart';
import 'package:lpsapp/core/cache/cache_local.dart';
import 'package:lpsapp/core/rede/ligacao.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/inscricao/assinatura.dart';
import 'package:lpsapp/features/inscricao/inscricao_form_page.dart';
import 'package:lpsapp/features/inscricao/inscricao_page.dart';
import 'package:lpsapp/features/inscricao/inscricoes_page.dart';

import '../inscricao_test.dart' show inscricaoJson;

/// Responde como o CISOC e guarda o que lhe pedem.
class _Servidor implements HttpClientAdapter {
  final pedidos = <RequestOptions>[];
  final respostas = <String, (int, Object)>{};

  RequestOptions ultimo(String metodo) => pedidos.lastWhere((p) => p.method == metodo);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? _) async {
    pedidos.add(o);
    final (status, corpo) =
        respostas['${o.method} ${o.path}'] ??
        (404, {'status': 'error', 'erro': 'nao_encontrado', 'message': 'Não encontrado.'});
    return ResponseBody.fromString(
      jsonEncode(corpo),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _ok(Object dados) => {'status': 'success', 'data': dados};

class _Quem extends SessaoController {
  _Quem(this.inicial);

  final Sessao inicial;

  @override
  Sessao build() => inicial;
}

class _Online extends LigacaoController {
  @override
  bool build() => true;
}

final _adulto = SessaoConta(const ContaSessao(nome: 'Maria Silva Santos', email: 'maria@exemplo.pt'));

/// Uma conta de 13–17 anos (§2.10): não contrata nem paga.
final _menor = sessaoDaConta({
  'nome': 'Rita',
  'menor': true,
  'faixa_etaria': 'teen',
  'permissoes': {'pagar': false, 'comprar': false, 'contratar': false},
  'capacidades': ['view_own_tickets', 'manage_consents'],
});

Future<void> _pump(
  WidgetTester t,
  _Servidor s, {
  String local = '/inscricoes/01MINSC',
  Sessao? quem,
  double largura = 430,
  double altura = 1600,
  double escala = 1,
  bool escuro = false,
}) async {
  t.view.physicalSize = Size(largura, altura);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final router = GoRouter(
    initialLocation: local,
    routes: [
      GoRoute(path: '/socio', builder: (_, _) => const Text('zona de sócio')),
      GoRoute(
        path: '/inscricoes',
        builder: (_, _) => const InscricoesPage(),
        routes: [
          GoRoute(path: 'nova', builder: (_, _) => const InscricaoFormPage()),
          GoRoute(
            path: ':id',
            builder: (_, e) => InscricaoPage(id: e.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sessaoProvider.overrideWith(() => _Quem(quem ?? _adulto)),
        ligacaoProvider.overrideWith(_Online.new),
        cacheProvider.overrideWithValue(CacheEmMemoria()),
        dioContaProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'http://cisoc/api/v2'))..httpClientAdapter = s),
        // Uma inscrição própria concluída renova a sessão.
        tokenStoreProvider.overrideWithValue(
          TokenStore(
            const FlutterSecureStorage(),
            Dio(BaseOptions(baseUrl: 'http://cisoc/api/v2'))..httpClientAdapter = s,
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: escuro ? AppTheme.dark() : AppTheme.light(),
        routerConfig: router,
        builder: (context, filho) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
          child: filho!,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

/// Deixa o pedido ir e voltar sem esperar que tudo assente: com o pagamento a
/// ser acompanhado há sempre um indicador a girar.
Future<void> _esperar(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Desmonta a árvore: o acompanhamento do pagamento tem temporizadores.
Future<void> _fechar(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  late _Servidor s;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    s = _Servidor();
    // A lista fica por baixo da inscrição, na pilha do router.
    s.respostas['GET /me/inscricoes'] = (200, _ok({'inscricoes': <Object>[]}));
  });

  void responder(Map<String, dynamic> inscricao) =>
      s.respostas['GET /me/inscricoes/01MINSC'] = (200, _ok({'inscricao': inscricao}));

  group('cabe em qualquer ecrã', () {
    final passos = {
      'aguardar': inscricaoJson(),
      'assinar': inscricaoJson(estado: 'admitida', proximo: 'assinar', nrSocio: 7412, firme: true),
      'pagar': inscricaoJson(estado: 'assinada', proximo: 'pagar', nrSocio: 7412, firme: true, porAssinar: []),
      'concluida': inscricaoJson(estado: 'concluida', proximo: 'nada', nrSocio: 7412, firme: true, porAssinar: []),
    };
    for (final MapEntry(key: nome, value: json) in passos.entries) {
      for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
        for (final escuro in [false, true]) {
          testWidgets('$nome · ${largura.toInt()}px · letra x$escala · ${escuro ? 'escuro' : 'claro'}', (t) async {
            responder(json);
            await _pump(t, s, largura: largura, altura: 780, escala: escala, escuro: escuro);
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  });

  testWidgets('à espera do clube: nada a fazer, e o valor diz que é estimativa', (t) async {
    responder(inscricaoJson());
    await _pump(t, s);

    expect(find.text('O clube está a ver o pedido'), findsOneWidget);
    expect(find.textContaining('Valor estimado'), findsOneWidget);
    expect(find.byType(QuadroAssinatura), findsNothing);
    expect(find.textContaining('Enviar pedido MB WAY'), findsNothing);
  });

  testWidgets('admitida: mostra o número reservado e assina um documento de cada vez', (t) async {
    responder(inscricaoJson(estado: 'admitida', proximo: 'assinar', nrSocio: 7412, firme: true));
    s.respostas['POST /me/inscricoes/01MINSC/assinar'] = (
      200,
      _ok({
        'inscricao': inscricaoJson(
          estado: 'admitida',
          proximo: 'assinar',
          nrSocio: 7412,
          firme: true,
          porAssinar: ['termo_responsabilidade'],
        ),
      }),
    );
    await _pump(t, s);

    expect(find.text('N.º 7412'), findsOneWidget);
    expect(find.text('Documento 1 de 2'), findsOneWidget);
    final assinar = find.widgetWithText(FilledButton, 'Assinar Ficha de Sócio');
    expect(t.widget<FilledButton>(assinar).onPressed, isNull, reason: 'sem traço, não há assinatura');

    // Um traço vertical: é o que o scroll da lista roubaria.
    final dedo = await t.startGesture(t.getCenter(find.byType(QuadroAssinatura)) - const Offset(80, 40));
    for (var i = 0; i < 8; i++) {
      await dedo.moveBy(const Offset(20, 10));
      await t.pump();
    }
    await dedo.up();
    await t.pump();
    expect(t.widget<FilledButton>(assinar).onPressed, isNotNull);

    await t.runAsync(() async {
      await t.tap(assinar);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pumpAndSettle();

    final corpo = s.ultimo('POST').data as Map;
    expect(corpo['documento'], 'ficha_socio');
    expect(corpo['assinatura'] as String, startsWith('data:image/png;base64,'));
    expect(corpo.containsKey('assinante_nome'), isFalse);
    // Veio a inscrição nova: segue-se o termo, com o quadro em branco.
    expect(find.text('Documento 2 de 2'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Assinar Termo de Responsabilidade'), findsOneWidget);
    expect(find.text('Ficha de Sócio'), findsOneWidget, reason: 'fica nos documentos assinados');
  });

  testWidgets('assinar cedo demais: mostra a mensagem do servidor e recarrega', (t) async {
    responder(inscricaoJson(estado: 'admitida', proximo: 'assinar', nrSocio: 7412));
    s.respostas['POST /me/inscricoes/01MINSC/assinar'] = (
      409,
      {'status': 'error', 'erro': 'estado_invalido', 'message': 'O clube ainda está a ver o seu pedido.'},
    );
    await _pump(t, s);

    await t.drag(find.byType(QuadroAssinatura), const Offset(120, 40));
    await t.pump();
    // Entretanto o clube voltou atrás: o GET seguinte diz que é para aguardar.
    responder(inscricaoJson());
    await t.runAsync(() async {
      await t.tap(find.widgetWithText(FilledButton, 'Assinar Ficha de Sócio'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pumpAndSettle();

    expect(s.pedidos.where((p) => p.method == 'GET' && p.path == '/me/inscricoes/01MINSC'), hasLength(2));
    expect(find.text('O clube está a ver o pedido'), findsOneWidget);
  });

  testWidgets('um menor não assina: diz quem o faz, em vez do quadro', (t) async {
    responder(inscricaoJson(estado: 'admitida', proximo: 'assinar', nrSocio: 7412));
    await _pump(t, s, quem: _menor, largura: 320, altura: 2400, escala: 2);

    expect(find.byType(QuadroAssinatura), findsNothing);
    expect(find.text('As inscrições são feitas pelo encarregado de educação.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('um menor não paga', (t) async {
    responder(inscricaoJson(estado: 'assinada', proximo: 'pagar', nrSocio: 7412, porAssinar: []));
    await _pump(t, s, quem: _menor);

    expect(find.text('Os pagamentos são feitos pelo encarregado de educação.'), findsOneWidget);
    expect(find.textContaining('Enviar pedido'), findsNothing);
  });

  testWidgets('pagar: meses num contador entre o mínimo e o máximo, sem enviar valores', (t) async {
    responder(inscricaoJson(estado: 'assinada', proximo: 'pagar', nrSocio: 7412, firme: true, porAssinar: []));
    s.respostas['POST /me/inscricoes/01MINSC/pagamento'] = (
      201,
      _ok({
        'pagamento': {
          'referencia': 10422,
          'metodo': 'paybylink',
          'valor': 8,
          'meses': 4,
          'url_pagamento': 'https://pay.exemplo/x',
          'telefone': null,
          'limite': '2026-10-07',
        },
        'inscricao': inscricaoJson(estado: 'assinada', proximo: 'pagar', nrSocio: 7412, firme: true, porAssinar: []),
      }),
    );
    await _pump(t, s);

    final menos = find.widgetWithIcon(IconButton, Icons.remove_rounded);
    final mais = find.widgetWithIcon(IconButton, Icons.add_rounded);
    expect(find.text('3 meses'), findsOneWidget);
    expect(t.widget<IconButton>(menos).onPressed, isNull, reason: 'o mínimo são 3');

    for (var i = 0; i < 12; i++) {
      if (t.widget<IconButton>(mais).onPressed == null) break;
      await t.tap(mais);
      await t.pump();
    }
    expect(find.text('12 meses'), findsOneWidget, reason: 'o máximo que o servidor deu');
    for (var i = 0; i < 8; i++) {
      await t.tap(menos);
      await t.pump();
    }
    expect(find.text('4 meses'), findsOneWidget);

    await t.tap(find.text('Multibanco'));
    await t.pumpAndSettle();
    await t.tap(find.text('Gerar referência'));
    await _esperar(t);

    expect(s.ultimo('POST').data, {'meses': 4, 'metodo': 'paybylink'});
    // O que se mostra é o que veio: o total e o método da resposta.
    expect(find.text('Falta pagar'), findsOneWidget);
    expect(find.textContaining('8,00'), findsOneWidget);
    expect(find.text('Multibanco / link'), findsOneWidget);
    expect(find.text('Abrir página de pagamento'), findsOneWidget);
    expect(find.text('Já paguei — verificar'), findsOneWidget);

    // O pagamento entra: a consulta seguinte leva ao fim, sem tocar em nada.
    responder(inscricaoJson(estado: 'concluida', proximo: 'nada', nrSocio: 7412, firme: true, porAssinar: []));
    await t.pump(const Duration(seconds: 5));
    await _esperar(t);
    expect(find.text('Já é sócio'), findsOneWidget);

    await _fechar(t);
  });

  testWidgets('voltar a uma inscrição por pagar mostra o pagamento já pedido, não um novo', (t) async {
    responder({
      ...inscricaoJson(estado: 'assinada', proximo: 'pagar', nrSocio: 7412, firme: true, porAssinar: []),
      'pagamento': {
        'referencia': 10422,
        'metodo': 'paybylink',
        'valor': 8,
        'meses': 4,
        'url_pagamento': 'https://pay.exemplo/x',
        'telefone': null,
        'limite': '2026-10-07',
      },
    });
    await _pump(t, s);

    expect(find.text('Abrir página de pagamento'), findsOneWidget);
    expect(find.text('Gerar referência'), findsNothing);
    expect(find.text('Enviar pedido MB WAY'), findsNothing);

    // Outro método continua a ser possível, e diz que anula o anterior.
    await t.ensureVisible(find.text('Escolher outro método'));
    await t.tap(find.text('Escolher outro método'));
    await t.pumpAndSettle();
    expect(find.text('Enviar pedido MB WAY'), findsOneWidget);
    expect(find.textContaining('deixa de valer'), findsOneWidget);
    expect(s.pedidos.where((p) => p.method == 'POST'), isEmpty, reason: 'escolher outro não pede nada sozinho');

    await _fechar(t);
  });

  testWidgets('MB WAY pede um telemóvel válido antes de deixar enviar', (t) async {
    responder(inscricaoJson(estado: 'assinada', proximo: 'pagar', porAssinar: []));
    await _pump(t, s);

    final enviar = find.widgetWithText(FilledButton, 'Enviar pedido MB WAY');
    expect(t.widget<FilledButton>(enviar).onPressed, isNull);
    await t.enterText(find.byType(TextField), '812345678');
    await t.pump();
    expect(find.text('Telemóvel com 9 dígitos, começado por 9'), findsOneWidget);
    await t.enterText(find.byType(TextField), '912345678');
    await t.pump();
    expect(t.widget<FilledButton>(enviar).onPressed, isNotNull);
  });

  testWidgets('recusada: mostra o motivo que a secretaria escreveu', (t) async {
    responder(inscricaoJson(estado: 'recusada', proximo: 'nada', motivo: 'Já existe uma ficha com este NIF.'));
    await _pump(t, s);

    expect(find.text('O pedido não foi aceite'), findsOneWidget);
    expect(find.text('Já existe uma ficha com este NIF.'), findsOneWidget);
  });

  testWidgets('um passo desconhecido mostra o rótulo do servidor, sem botões', (t) async {
    responder(inscricaoJson(estado: 'em_revisao', proximo: 'confirmar_documento'));
    await _pump(t, s);

    expect(find.text('Noutro estado'), findsWidgets);
    expect(find.byType(FilledButton), findsNothing);
    expect(t.takeException(), isNull);
  });

  group('o formulário', () {
    Future<void> preencher(WidgetTester t) async {
      await t.enterText(find.widgetWithText(TextFormField, 'Nome completo').first, 'Tomás Silva');
      await t.tap(find.text('Data de nascimento'));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
    }

    testWidgets('"um menor" mostra os campos do encarregado, já com o nome da conta', (t) async {
      await _pump(t, s, local: '/inscricoes/nova');
      expect(find.text('O encarregado de educação'), findsNothing);

      await t.tap(find.text('Um menor a meu cargo'));
      await t.pumpAndSettle();

      expect(find.text('O encarregado de educação'), findsOneWidget);
      expect(find.text('Mãe'), findsOneWidget);
      // O nome da conta passa para o encarregado; o do menor fica por escrever.
      final nomes = t.widgetList<TextFormField>(find.widgetWithText(TextFormField, 'Nome completo')).toList();
      expect(nomes.first.controller!.text, isEmpty);
      expect(nomes.last.controller!.text, 'Maria Silva Santos');
    });

    testWidgets('o 422 do servidor aparece com a razão escrita — a app não calcula idades', (t) async {
      s.respostas['POST /me/inscricoes'] = (
        422,
        {
          'status': 'error',
          'erro': 'dados_invalidos',
          'message': 'Quem tem menos de 18 anos é inscrito pelo encarregado de educação.',
        },
      );
      await _pump(t, s, local: '/inscricoes/nova');
      await preencher(t);
      await t.tap(find.text('Enviar pedido'));
      await t.pumpAndSettle();

      expect(find.text('Quem tem menos de 18 anos é inscrito pelo encarregado de educação.'), findsOneWidget);
      expect((s.ultimo('POST').data as Map)['para'], 'propria');
    });

    testWidgets('409 ja_existe abre a inscrição que está a meio, em vez de recomeçar', (t) async {
      s.respostas['POST /me/inscricoes'] = (
        409,
        {
          'status': 'error',
          'erro': 'ja_existe',
          'message': 'Já tem uma inscrição a meio para esta pessoa. Continue essa.',
          'inscricao': '01MINSC',
          'estado': 'admitida',
        },
      );
      responder(inscricaoJson(estado: 'admitida', proximo: 'assinar', nrSocio: 7412));
      await _pump(t, s, local: '/inscricoes/nova');
      await preencher(t);
      await t.tap(find.text('Enviar pedido'));
      await t.pumpAndSettle();

      expect(find.byType(InscricaoPage), findsOneWidget);
      expect(find.text('N.º 7412'), findsOneWidget);
    });

    testWidgets('um menor não vê o botão de enviar', (t) async {
      await _pump(t, s, local: '/inscricoes/nova', quem: _menor);
      expect(find.text('Enviar pedido'), findsNothing);
      expect(find.text('As inscrições são feitas pelo encarregado de educação.'), findsOneWidget);
    });
  });

  testWidgets('a lista mostra o estado de cada inscrição', (t) async {
    s.respostas['GET /me/inscricoes'] = (
      200,
      _ok({
        'inscricoes': [
          inscricaoJson(estado: 'admitida', proximo: 'assinar', nrSocio: 7412),
          {...inscricaoJson(estado: 'recusada', proximo: 'nada', para: 'dependente'), 'id': '01MOUTRA'},
        ],
      }),
    );
    await _pump(t, s, local: '/inscricoes', largura: 320, altura: 780, escala: 1.3);

    expect(find.text('Admitido — por assinar'), findsOneWidget);
    expect(find.text('Recusada'), findsOneWidget);
    expect(find.text('Nova inscrição'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
