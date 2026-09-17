import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/api_exception.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/cache/cache_local.dart';
import 'package:lpsapp/core/rede/ligacao.dart';
import 'package:lpsapp/features/socio/conta/contas.dart';

class _LigacaoFake extends LigacaoController {
  @override
  bool build() => true;
}

class _SessaoFake extends SessaoController {
  @override
  Sessao build() => const SessaoSocio(SocioSessao(nrSocio: 16, nomeCompleto: 'TITULAR', estado: 1));
}

/// Responde conforme o cabeçalho X-Socio e guarda os pedidos feitos.
class _Servidor implements HttpClientAdapter {
  final pedidos = <RequestOptions>[];
  Set<String> dependentesValidos = {'5643'};

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async {
    pedidos.add(o);
    if (o.path == '/me/dependentes') {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'data': {'dependentes': []},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final x = o.headers['X-Socio'] as String?;
    if (x != null && !dependentesValidos.contains(x)) {
      return ResponseBody.fromString(
        jsonEncode({'status': 'error', 'erro': 'socio_nao_associado', 'message': 'Não associado'}),
        403,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'status': 'success',
        'data': {'nr_socio': int.parse(x ?? '16')},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Servidor servidor;
  late ProviderContainer c;

  setUp(() {
    servidor = _Servidor();
    c = ProviderContainer(
      overrides: [
        sessaoProvider.overrideWith(_SessaoFake.new),
        ligacaoProvider.overrideWith(_LigacaoFake.new),
        cacheProvider.overrideWithValue(CacheEmMemoria()),
        dioSocioProvider.overrideWithValue(Dio()..httpClientAdapter = servidor),
      ],
    );
    addTearDown(c.dispose);
  });

  Future<Map<String, dynamic>> pedir() => c.read(Provider((ref) => PedidosNaConta(ref))).get('/me/resumo');

  test('na conta própria não envia X-Socio', () async {
    expect((await pedir())['nr_socio'], 16);
    expect(servidor.pedidos.single.headers.containsKey('X-Socio'), isFalse);
  });

  test('na conta de um dependente envia X-Socio com o nº dele', () async {
    c.read(contaActivaProvider.notifier).escolher(5643);
    expect((await pedir())['nr_socio'], 5643);
    expect(servidor.pedidos.single.headers['X-Socio'], '5643');
  });

  test('escolher o próprio nº é o mesmo que a conta própria', () {
    c.read(contaActivaProvider.notifier).escolher(16);
    expect(c.read(contaActivaProvider), isNull);
  });

  test('ligação removida pela secretaria: volta à conta própria', () async {
    c.read(contaActivaProvider.notifier).escolher(5643);
    servidor.dependentesValidos = {};

    await expectLater(pedir(), throwsA(isA<ApiException>().having((e) => e.erro, 'erro', 'socio_nao_associado')));
    expect(c.read(contaActivaProvider), isNull);
  });

  test('dependente: relação desconhecida e campos em falta não rebentam', () {
    final d = Dependente.fromJson({
      'nr_socio': 5643,
      'nome_completo': 'CARMINHO EXEMPLO',
      'estado': 1,
      'estado_label': 'Ativo',
      'relacao': 'padrinho',
      'pode_pagar': false,
      'tem_modalidade': true,
      'tem_cartao': false,
      'divida': {'total': 81.5},
    });
    expect(d.relacaoLabel, 'padrinho');
    expect(d.dividaTotal, 81.5);
    expect(d.idade, isNull);
    expect(d.primeiroNome, 'Carminho');
  });
}
