import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/api_exception.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/features/socio/conta/contas.dart';
import 'package:lpsapp/features/socio/documentos/documentos.dart';
import 'package:lpsapp/features/socio/pagamentos/modelos.dart';

class _Sessao extends SessaoController {
  @override
  Sessao build() => const SessaoSocio(SocioSessao(nrSocio: 16, nomeCompleto: 'X', estado: 1));
}

class _Servidor implements HttpClientAdapter {
  _Servidor(this.status, this.corpo, this.tipo);
  final int status;
  final List<int> corpo;
  final String tipo;
  RequestOptions? ultimo;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async {
    ultimo = o;
    return ResponseBody.fromBytes(
      corpo,
      status,
      headers: {
        Headers.contentTypeHeader: [tipo],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('mensalidades (guia §4.6)', () {
    final m = Mensalidades.fromJson({
      'total_pendente': 0,
      'subscricoes': [
        {
          'id': 121,
          'modalidade': 'FUTEBOL',
          'epoca': '2026/2027',
          'ativa': true,
          'inclui_quota': true,
          'valor_fixo': null,
        },
      ],
      'caderneta': [
        {
          'mes': '2026-07-01',
          'mes_label': 'Jul. 2026',
          'estado': 'pendente',
          'valor': 260,
          'estimado': false,
          'id_fatura': 96,
        },
        {
          'mes': '2026-09-01',
          'mes_label': 'Set. 2026',
          'estado': 'futuro',
          'valor': 36.5,
          'estimado': true,
          'id_fatura': null,
        },
        {
          'mes': '2026-10-01',
          'mes_label': 'Out. 2026',
          'estado': 'pendente',
          'valor': 36.5,
          'estimado': true,
          'id_fatura': null,
        },
      ],
    });

    test('só com fatura emitida é pagável; estimado nunca', () {
      expect(m.caderneta[0].pagavel, isTrue);
      expect(m.caderneta[1].pagavel, isFalse);
      expect(m.caderneta[2].pagavel, isFalse, reason: 'estimado mesmo que venha "pendente"');
    });

    test('valor_fixo nulo = preço por escalão', () => expect(m.subscricoes.single.valorFixo, isNull));
  });

  test('wallet: valor sempre positivo, o sinal vem do tipo', () {
    final w = Wallet.fromJson({
      'saldo': 25,
      'movimentos': [
        {'id': 1, 'tipo': 'credito', 'valor': 25, 'descricao': 'Devolução', 'data': '2026-05-10 11:02:00'},
        {'id': 2, 'tipo': 'DEBITO', 'valor': 10, 'descricao': null, 'data': null},
      ],
    });
    expect(w.saldo, 25.0);
    expect(w.movimentos.map((m) => m.credito), [true, false]);
  });

  test('documento: caminho relativo à API, não o download_url do servidor', () {
    final i = Inscricao.fromJson({
      'id_inscricao': 129,
      'modalidade': 'FUTEBOL',
      'documentos': [
        {
          'tipo': 'ficha_inscricao',
          'titulo': 'Ficha de Inscrição',
          'disponivel': true,
          'download_url': 'https://cisoc.test/api/v1/documentos/129/ficha_inscricao',
        },
        {'tipo': 'tipo_novo', 'disponivel': false},
      ],
    });
    expect(i.documentos.first.caminho, '/documentos/129/ficha_inscricao');
    expect(i.documentos.last.titulo, 'tipo_novo');
    expect(i.documentos.last.disponivel, isFalse);
  });

  group('descarregar ficheiros', () {
    ProviderContainer montar(_Servidor s) {
      final c = ProviderContainer(
        overrides: [
          sessaoProvider.overrideWith(_Sessao.new),
          dioSocioProvider.overrideWithValue(Dio()..httpClientAdapter = s),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    PedidosNaConta pedidos(ProviderContainer c) => c.read(Provider((ref) => PedidosNaConta(ref)));

    test('PDF chega em bytes', () async {
      final s = _Servidor(200, [0x25, 0x50, 0x44, 0x46], 'application/pdf');
      expect(await pedidos(montar(s)).bytes('/documentos/1/x'), [0x25, 0x50, 0x44, 0x46]);
    });

    test('erro em JSON dentro de bytes vira ApiException com a mensagem', () async {
      final s = _Servidor(
        404,
        utf8.encode(jsonEncode({'status': 'error', 'erro': 'nao_encontrado', 'message': 'Documento não encontrado.'})),
        'application/json',
      );
      await expectLater(
        pedidos(montar(s)).bytes('/documentos/1/x'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Documento não encontrado.')),
      );
    });

    test('na conta de um dependente leva X-Socio', () async {
      final s = _Servidor(200, [1], 'application/pdf');
      final c = montar(s);
      c.read(contaActivaProvider.notifier).escolher(5643);
      await pedidos(c).bytes('/documentos/1/x');
      expect(s.ultimo?.headers['X-Socio'], '5643');
    });
  });
}
