import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/push/push.dart';

class _SessaoSocioFake extends SessaoController {
  @override
  Sessao build() => sessaoDeSocio(const SocioSessao(nrSocio: 16, nomeCompleto: 'TITULAR', estado: 1));
}

class _SessaoAnonimaFake extends SessaoController {
  @override
  Sessao build() => const SessaoAnonima();
}

class _Servidor implements HttpClientAdapter {
  final pedidos = <RequestOptions>[];
  int estado = 201;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async {
    pedidos.add(o);
    if (estado >= 400) {
      return ResponseBody.fromString(
        jsonEncode({'status': 'error', 'erro': 'erro_interno', 'message': 'Falhou.'}),
        estado,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'status': 'success',
        'data': {'novo': estado == 201},
      }),
      estado,
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

  ProviderContainer comSessao({required bool socio}) {
    servidor = _Servidor();
    final c = ProviderContainer(
      overrides: [
        sessaoProvider.overrideWith(socio ? _SessaoSocioFake.new : _SessaoAnonimaFake.new),
        dioSocioProvider.overrideWithValue(Dio()..httpClientAdapter = servidor),
      ],
    );
    addTearDown(c.dispose);
    c.listen(pushProvider, (_, _) {});
    return c;
  }

  test('com sessão de sócio, regista o token', () async {
    final c = comSessao(socio: true);
    final push = c.read(pushProvider.notifier)..tokenDeTeste('fcm-123');

    await push.registar();

    final p = servidor.pedidos.single;
    expect(p.method, 'POST');
    expect(p.path, '/dispositivos');
    expect(p.data, {'token': 'fcm-123', 'plataforma': 'android'});
    expect(c.read(pushProvider).registado, isTrue);
  });

  test('sem sessão não regista nada — o aparelho ouve pelos tópicos', () async {
    final c = comSessao(socio: false);
    c.read(pushProvider.notifier).tokenDeTeste('fcm-123');

    await c.read(pushProvider.notifier).registar();

    expect(servidor.pedidos, isEmpty);
    expect(c.read(pushProvider).registado, isFalse);
  });

  test('não repete o registo do mesmo token', () async {
    final c = comSessao(socio: true);
    final push = c.read(pushProvider.notifier)..tokenDeTeste('fcm-123');

    await push.registar();
    await push.registar();

    expect(servidor.pedidos, hasLength(1));
  });

  test('token novo volta a ser registado', () async {
    final c = comSessao(socio: true);
    final push = c.read(pushProvider.notifier)..tokenDeTeste('fcm-123');
    await push.registar();

    push.tokenDeTeste('fcm-456'); // onTokenRefresh
    await push.registar();

    expect(servidor.pedidos.map((p) => (p.data as Map)['token']), ['fcm-123', 'fcm-456']);
  });

  test('registo falhado não fica marcado como feito', () async {
    final c = comSessao(socio: true);
    servidor.estado = 500;
    final push = c.read(pushProvider.notifier)..tokenDeTeste('fcm-123');

    await push.registar();

    expect(c.read(pushProvider).registado, isFalse, reason: 'tenta outra vez no próximo arranque');
  });

  test('apagar manda DELETE com o token e esquece o registo', () async {
    final c = comSessao(socio: true);
    final push = c.read(pushProvider.notifier)..tokenDeTeste('fcm-123');
    await push.registar();
    servidor.pedidos.clear();

    await push.apagar();

    final p = servidor.pedidos.single;
    expect(p.method, 'DELETE');
    expect(p.path, '/dispositivos');
    expect(p.data, {'token': 'fcm-123'}, reason: 'corpo em JSON, nunca form-encoded (guia §7)');
    expect(c.read(pushProvider).registado, isFalse);
  });

  test('apagar sem token não vai ao servidor', () async {
    final c = comSessao(socio: true);
    c.read(pushProvider.notifier).tokenDeTeste(null);

    await c.read(pushProvider.notifier).apagar();

    expect(servidor.pedidos, isEmpty);
  });

  test('apagar não rebenta quando o servidor recusa', () async {
    final c = comSessao(socio: true);
    final push = c.read(pushProvider.notifier)..tokenDeTeste('fcm-123');
    servidor.estado = 500;

    await expectLater(push.apagar(), completes);
  });
}
