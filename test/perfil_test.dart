import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/api_exception.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/auth/token_store.dart';
import 'package:lpsapp/features/socio/perfil/perfil.dart';

/// Servidor falso: responde por caminho e guarda o que recebeu.
class _Servidor implements HttpClientAdapter {
  final respostas = <String, (int, Map<String, dynamic>)>{};
  final pedidos = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async {
    pedidos.add(o);
    final (status, corpo) = respostas['${o.method} ${o.path}'] ?? (404, {'status': 'error', 'erro': 'nao_encontrado'});
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

Map<String, dynamic> _socio([Map<String, dynamic> extra = const {}]) => {
  'nr_socio': 16,
  'nome_completo': 'JOÃO',
  'estado': 1,
  'estado_label': 'Ativo',
  ...extra,
};

void main() {
  test('guardar só envia campos editáveis', () async {
    final s = _Servidor()
      ..respostas['PUT /me'] = (
        200,
        {
          'status': 'success',
          'data': {
            'socio': _socio({'email': 'novo@x.pt'}),
            'atualizado': ['email'],
          },
        },
      );
    final r = await guardarPerfil(Dio()..httpClientAdapter = s, {
      'email': 'novo@x.pt',
      'nif': '999999990',
      'nome_completo': 'OUTRO',
    });

    expect(s.pedidos.single.data, {'email': 'novo@x.pt'});
    expect(r.atualizado, ['email']);
    expect(r.perfil.email, 'novo@x.pt');
  });

  group('sessão', () {
    late _Servidor servidor;
    late TokenStore tokens;
    late ProviderContainer c;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({
        'lps.access_token': 'antigo',
        'lps.refresh_token': 'refresh-antigo',
        'lps.socio': jsonEncode(_socio()),
      });
      servidor = _Servidor();
      final dio = Dio()..httpClientAdapter = servidor;
      tokens = TokenStore(const FlutterSecureStorage(), dio);
      await tokens.carregar();
      c = ProviderContainer(
        overrides: [tokenStoreProvider.overrideWithValue(tokens), dioSocioProvider.overrideWithValue(dio)],
      );
      addTearDown(c.dispose);
    });

    test('alterar a palavra-passe guarda os tokens novos', () async {
      servidor.respostas['POST /auth/password'] = (
        200,
        {
          'status': 'success',
          'data': {'access_token': 'novo', 'refresh_token': 'refresh-novo', 'socio': _socio()},
        },
      );
      await c.read(sessaoProvider.notifier).alterarPassword(actual: 'a', nova: 'bbbbbbbb');

      expect(tokens.accessToken, 'novo');
      expect(await const FlutterSecureStorage().read(key: 'lps.refresh_token'), 'refresh-novo');
      expect(c.read(sessaoProvider), isA<SessaoSocio>());
    });

    test('password errada ao alterar: sessão e tokens ficam como estavam', () async {
      servidor.respostas['POST /auth/password'] = (
        403,
        {'status': 'error', 'erro': 'password_incorreta', 'message': 'Palavra-passe incorrecta.'},
      );
      await expectLater(
        c.read(sessaoProvider.notifier).alterarPassword(actual: 'x', nova: 'bbbbbbbb'),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.accessToken, 'antigo');
      expect(c.read(sessaoProvider), isA<SessaoSocio>());
    });

    test('eliminar a conta: DELETE com corpo JSON, sessão e tokens apagados', () async {
      servidor.respostas['DELETE /me/conta'] = (
        200,
        {
          'status': 'success',
          'data': {'eliminada': true, 'mensagem': 'A sua conta da app foi eliminada.'},
        },
      );
      final mensagem = await c.read(sessaoProvider.notifier).eliminarConta('segredo');

      final pedido = servidor.pedidos.single;
      expect(pedido.method, 'DELETE');
      expect(pedido.data, {'password': 'segredo'});
      expect(mensagem, 'A sua conta da app foi eliminada.');
      expect(c.read(sessaoProvider), isA<SessaoAnonima>());
      expect(tokens.temSessao, isFalse);
      expect(await const FlutterSecureStorage().read(key: 'lps.refresh_token'), isNull);
    });
  });
}
