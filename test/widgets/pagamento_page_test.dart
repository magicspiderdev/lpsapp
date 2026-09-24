/// O ecrã de um pagamento — o destino da notificação "pagamento emitido"
/// (pedido `2026-09-24-push-pagamento-emitido`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/push/push.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/socio/pagamentos/dados.dart';
import 'package:lpsapp/features/socio/pagamentos/modelos.dart';
import 'package:lpsapp/features/socio/pagamentos/pagamento_page.dart';

class _Quem extends SessaoController {
  _Quem(this.inicial);

  final Sessao inicial;

  @override
  Sessao build() => inicial;
}

Sessao _socio(List<String> capacidades) => sessaoDaConta({
  'nome': 'João',
  'capacidades': capacidades,
  'socio': {'nr_socio': 16, 'nome_completo': 'JOÃO', 'estado': 1},
});

final _pendente = Pagamento.fromJson({
  'id_pagamento': 20544,
  'referencia': 26142,
  'descricao': 'Quotas 07/2026 a 09/2026',
  'valor': 4.5,
  'estado': 'PENDENTE',
  'data': '2026-09-24 10:00:00',
  'limite': DateTime.now().add(const Duration(days: 10)).toIso8601String().substring(0, 10),
  'metodo': 'paybylink',
  'url_pagamento': 'https://ifthenpay.example/pagar',
});

Future<void> _pump(WidgetTester t, {required Sessao quem, required int id, bool actual = true}) async {
  t.view.physicalSize = const Size(360, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final obtido = actual ? DateTime.now() : DateTime.now().subtract(const Duration(days: 2));
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sessaoProvider.overrideWith(() => _Quem(quem)),
        historicoPagamentosProvider.overrideWith(
          (ref) => Stream.value(Dados([_pendente], obtido, actuais: actual)),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: PagamentoPage(id: id),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  testWidgets('um pagamento em aberto mostra a referência, o valor e o botão de pagar', (t) async {
    await _pump(t, quem: _socio(const ['pay_membership']), id: 20544);

    expect(find.text('26142'), findsOneWidget);
    expect(find.textContaining('4,50'), findsWidgets);
    expect(find.textContaining('Pagar até'), findsOneWidget);
    expect(find.text('Pagar agora'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('sem a capacidade de pagar, diz quem paga em vez do botão', (t) async {
    await _pump(t, quem: _socio(const ['view_member_card']), id: 20544);

    expect(find.text('Pagar agora'), findsNothing);
    expect(find.textContaining('encarregado de educação'), findsOneWidget);
  });

  testWidgets('um pagamento que já não está na conta leva à lista', (t) async {
    await _pump(t, quem: _socio(const ['pay_membership']), id: 1);

    expect(find.text('Este pagamento já não aparece na conta.'), findsOneWidget);
    expect(find.text('Ver os pagamentos'), findsOneWidget);
  });

  test('a notificação de um pagamento de um educando abre-o na conta dele', () {
    expect(
      destinoDoPush({'route': '/socio/pagamentos/20544', 'params': '{"socio":5643}'}),
      '/socio/pagamentos/20544?socio=5643',
    );
  });
}
