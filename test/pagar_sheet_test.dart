import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/cache/cache_local.dart';
import 'package:lpsapp/core/rede/ligacao.dart';
import 'package:lpsapp/features/socio/pagamentos/modelos.dart';
import 'package:lpsapp/features/socio/pagamentos/pagar_sheet.dart';

class _Sessao extends SessaoController {
  @override
  Sessao build() => sessaoDeSocio(const SocioSessao(nrSocio: 16, nomeCompleto: 'TITULAR', estado: 1));
}

class _Ligacao extends LigacaoController {
  @override
  bool build() => true;
}

class _Servidor implements HttpClientAdapter {
  _Servidor(this.resposta, {this.status = 201});

  final Map<String, dynamic> resposta;
  final int status;
  final corpos = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? corpo, Future<void>? _) async {
    if (o.method == 'POST') corpos.add((o.data as Map).cast<String, dynamic>());
    return ResponseBody.fromString(
      jsonEncode(resposta),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _quotas = Quotas.fromJson({
  'isento': false,
  'total_pendente': 4.5,
  'minimo_pagamento': 3,
  'caderneta': [],
  'selecionaveis': [
    for (final m in ['07', '08', '09', '10'])
      {'mes': '2026-$m-01', 'mes_label': '$m/2026', 'estado': 'pendente', 'valor': 1.5},
  ],
  'ordens_pendentes': [],
});

Future<GoRouter> _montar(WidgetTester t, _Servidor servidor) async {
  await initializeDateFormatting('pt_PT');
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(onPressed: () => mostrarPagarQuotas(context, _quotas), child: const Text('abrir')),
        ),
      ),
      GoRoute(path: '/socio/pagamento', builder: (_, s) => Text('resultado ${(s.extra as ResultadoPagamento).metodo}')),
      GoRoute(path: '/socio/faturas/:id', builder: (_, s) => Text('fatura ${s.pathParameters['id']}')),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sessaoProvider.overrideWith(_Sessao.new),
        ligacaoProvider.overrideWith(_Ligacao.new),
        cacheProvider.overrideWithValue(CacheEmMemoria()),
        dioSocioProvider.overrideWithValue(Dio()..httpClientAdapter = servidor),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await t.tap(find.text('abrir'));
  await t.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('começa no mínimo de meses e não deixa descer abaixo dele', (t) async {
    await _montar(t, _Servidor({}));
    expect(find.text('3 meses'), findsOneWidget);
    expect(find.textContaining('4,50'), findsOneWidget);

    await t.tap(find.byIcon(Icons.remove_rounded));
    await t.pump();
    expect(find.text('3 meses'), findsOneWidget);

    await t.tap(find.byIcon(Icons.add_rounded));
    await t.pump();
    expect(find.text('4 meses'), findsOneWidget);
  });

  testWidgets('MB WAY: envia quantidade, método e telefone — nunca um valor', (t) async {
    final servidor = _Servidor({
      'status': 'success',
      'data': {'id_pagamento': 1, 'total': 4.5, 'metodo': 'mbway', 'expira_em': '2030-01-01T00:00:00Z'},
    });
    await _montar(t, servidor);

    await t.enterText(find.byType(TextField), '912345678');
    await t.pump();
    await t.tap(find.text('Enviar pedido MB WAY'));
    await t.pumpAndSettle();

    expect(servidor.corpos.single, {'quantidade': 3, 'metodo': 'mbway', 'telefone': '912345678'});
    expect(find.text('resultado mbway'), findsOneWidget);
  });

  testWidgets('telemóvel inválido não deixa enviar', (t) async {
    await _montar(t, _Servidor({}));
    await t.enterText(find.byType(TextField), '12345');
    await t.pump();
    final botao = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enviar pedido MB WAY'));
    expect(botao.onPressed, isNull);
  });

  testWidgets('referência: não envia telefone; se o servidor devolver outro método, manda a resposta', (t) async {
    final servidor = _Servidor({
      'status': 'success',
      'data': {'id_pagamento': 1, 'total': 4.5, 'metodo': 'paybylink', 'url_pagamento': 'https://x'},
    });
    await _montar(t, servidor);
    await t.tap(find.text('Referência'));
    await t.pump();
    await t.tap(find.text('Gerar referência'));
    await t.pumpAndSettle();

    expect(servidor.corpos.single, {'quantidade': 3, 'metodo': 'paybylink'});
    expect(find.text('resultado paybylink'), findsOneWidget);
  });

  testWidgets('409 mbway_em_curso: mostra a mensagem e fica na folha', (t) async {
    final servidor = _Servidor({
      'status': 'error',
      'erro': 'mbway_em_curso',
      'message': 'Já tem um pedido MB WAY à espera no telemóvel.',
    }, status: 409);
    await _montar(t, servidor);
    await t.enterText(find.byType(TextField), '912345678');
    await t.pump();
    await t.tap(find.text('Enviar pedido MB WAY'));
    await t.pumpAndSettle();

    expect(find.text('Já tem um pedido MB WAY à espera no telemóvel.'), findsOneWidget);
    expect(find.text('Enviar pedido MB WAY'), findsOneWidget);
  });
}
