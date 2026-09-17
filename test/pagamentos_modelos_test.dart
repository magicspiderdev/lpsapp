import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/features/socio/pagamentos/modelos.dart';

void main() {
  group('quotas (guia §4.5)', () {
    final q = Quotas.fromJson({
      'isento': false,
      'ultima_quota': '2026-06-01',
      'total_pendente': 3,
      'minimo_pagamento': 3,
      'caderneta': [
        {
          'mes': '2026-03-01',
          'mes_label': 'Mar. 2026',
          'estado': 'pago_legacy',
          'valor': null,
          'tipo': null,
          'pago_em': null,
        },
        {
          'mes': '2026-07-01',
          'mes_label': 'Jul. 2026',
          'estado': 'pendente',
          'valor': 1.5,
          'tipo': 'Infantil',
          'pago_em': null,
        },
        {
          'mes': '2026-10-01',
          'mes_label': 'Out. 2026',
          'estado': 'estado_novo',
          'valor': 2,
          'tipo': null,
          'pago_em': null,
        },
      ],
      'selecionaveis': [
        {'mes': '2026-07-01', 'mes_label': 'Jul. 2026', 'estado': 'pendente', 'valor': 1.5},
      ],
      'ordens_pendentes': [
        {
          'id_pagamento': 20544,
          'valor': 4.5,
          'estado': 'PENDENTE',
          'meses': '07/2026',
          'metodo': 'PAYBYLINK',
          'url_pagamento': 'https://x',
          'referencia': null,
          'limite': '2026-08-20',
          'criado_em': '2026-08-05 19:30:00',
          'cancelavel': true,
        },
      ],
    });

    test('pago_legacy tem valor desconhecido, não zero', () {
      expect(q.caderneta.first.estado, EstadoMes.pagoLegacy);
      expect(q.caderneta.first.valor, isNull);
      expect(q.caderneta.first.pago, isTrue);
    });

    test('estado de mês desconhecido não rebenta', () => expect(q.caderneta.last.estado, EstadoMes.desconhecido));

    test('inteiros no dinheiro passam a double', () {
      expect(q.totalPendente, 3.0);
      expect(q.caderneta.last.valor, 2.0);
    });

    test('método da ordem normalizado para minúsculas', () => expect(q.ordensPendentes.single.metodo, 'paybylink'));

    test('isento ou sem meses selecionáveis: sem botão de pagar', () {
      expect(q.podePagar, isTrue);
      expect(
        Quotas.fromJson({
          'isento': true,
          'caderneta': [],
          'selecionaveis': [
            {'mes': '2026-07-01', 'mes_label': 'x', 'estado': 'pendente'},
          ],
        }).podePagar,
        isFalse,
      );
      expect(Quotas.fromJson({'isento': false, 'caderneta': [], 'selecionaveis': []}).podePagar, isFalse);
    });
  });

  group('faturas (guia §4.8)', () {
    test('"quota sócio" e "quota" contam as duas como quota; tipos novos não', () {
      LinhaFatura l(String tipo) => LinhaFatura.fromJson({'descricao': 'x', 'tipo': tipo, 'valor': 1});
      expect(l('quota sócio').eQuota, isTrue);
      expect(l('quota').eQuota, isTrue);
      expect(l('mensalidade').eQuota, isFalse);
      expect(l('tipo_novo').eQuota, isFalse);
    });

    test('sem pagamento gerado e nr_fatura nulo', () {
      final d = DetalheFatura.fromJson({
        'fatura': {
          'id': 96,
          'mes_ano': '2026-07-01',
          'mes_label': 'Julho 2026',
          'valor_total': 260,
          'valor_pago': 60,
          'estado': 'pendente',
          'paga': false,
          'nr_fatura': null,
          'gerado_em': '2026-07-21 16:13:49',
        },
        'linhas': [],
        'pagamento': null,
      });
      expect(d.pagamento, isNull);
      expect(d.fatura.nrFatura, isNull);
      expect(d.fatura.emFalta, 200.0);
    });
  });

  group('resultado de pagamento (guia §4.11–4.12)', () {
    test('pediu MB WAY e o servidor devolveu PayByLink: manda a resposta', () {
      final r = ResultadoPagamento.fromJson({
        'id_pagamento': 1,
        'referencia': 26142,
        'total': 4.5,
        'meses': ['07/2026'],
        'metodo': 'paybylink',
        'url_pagamento': 'https://ifthenpay',
        'limite': '2026-08-20',
      });
      expect(r.mbway, isFalse);
      expect(r.temLink, isTrue);
      expect(r.referencia, '26142');
    });

    test('MB WAY reutilizado traz expira_em', () {
      final r = ResultadoPagamento.fromJson({
        'id_pagamento': 2,
        'total': 81.5,
        'metodo': 'mbway',
        'request_id': 'abc',
        'reutilizado': true,
        'expira_em': '2026-08-05T18:35:00+01:00',
      });
      expect(r.mbway, isTrue);
      expect(r.reutilizado, isTrue);
      expect(r.expiraEm, DateTime.utc(2026, 8, 5, 17, 35));
    });
  });

  test('estado de pagamento: normalizado e aberto', () {
    final p = Pagamento.fromJson({'id_pagamento': 3, 'estado': 'pago', 'valor': 10});
    expect(p.pago, isTrue);
    expect(Pagamento.fromJson({'id_pagamento': 4, 'estado': 'EM_ANALISE', 'valor': 10}).pendente, isFalse);
  });
}
