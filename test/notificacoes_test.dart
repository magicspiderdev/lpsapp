import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/cache/cache_local.dart';
import 'package:lpsapp/core/rede/ligacao.dart';
import 'package:lpsapp/features/socio/notificacoes/notificacoes.dart';

class _LigacaoFake extends LigacaoController {
  @override
  bool build() => true;
}

class _SessaoFake extends SessaoController {
  @override
  Sessao build() => sessaoDeSocio(const SocioSessao(nrSocio: 16, nomeCompleto: 'TITULAR', estado: 1));
}

/// Devolve páginas de notificações por ordem decrescente de id, como o servidor.
class _Servidor implements HttpClientAdapter {
  final pedidos = <RequestOptions>[];
  int total = 3;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async {
    pedidos.add(o);
    final limite = int.parse('${o.queryParameters['limite'] ?? 30}');
    final antesDe = o.queryParameters['antes_de'];
    final primeiro = antesDe == null ? total : int.parse('$antesDe') - 1;
    final ids = [
      for (var id = primeiro; id > primeiro - limite && id >= 1; id--) id,
    ];

    return ResponseBody.fromString(
      jsonEncode({
        'status': 'success',
        'data': {
          'notificacoes': [
            for (final id in ids)
              {
                'id': id,
                'titulo': 'Aviso $id',
                'texto': 'Linha um\r\nLinha dois',
                'pessoal': id == 1,
                'topico': 'all',
                'enviada_em': '2026-09-1${id % 10} 18:00:00',
              },
          ],
          'proxima_pagina': ids.isNotEmpty && ids.last > 1 ? {'antes_de': ids.last} : null,
        },
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
  late CacheEmMemoria cache;
  late ProviderContainer c;

  setUp(() {
    servidor = _Servidor();
    cache = CacheEmMemoria();
    c = ProviderContainer(
      overrides: [
        sessaoProvider.overrideWith(_SessaoFake.new),
        ligacaoProvider.overrideWith(_LigacaoFake.new),
        cacheProvider.overrideWithValue(cache),
        dioSocioProvider.overrideWithValue(Dio()..httpClientAdapter = servidor),
      ],
    );
    addTearDown(c.dispose);
    // Os providers são `autoDispose`: sem ouvintes, o container deitava-os fora
    // entre leituras e o estado não sobrevivia ao teste.
    c.listen(notificacoesProvider, (_, _) {});
    c.listen(maisNotificacoesProvider, (_, _) {});
    c.listen(vistasProvider, (_, _) {});
  });

  test('primeira página: mais recentes primeiro e sem X-Socio', () async {
    final d = await c.read(notificacoesProvider.future);

    expect(d.valor.notificacoes.map((n) => n.id), [3, 2, 1]);
    expect(d.valor.maiorId, 3);
    expect(d.valor.antesDe, isNull);
    // `/notificacoes` é da conta da app: com X-Socio daria 403 (guia §2.3.4).
    expect(servidor.pedidos.single.headers.containsKey('X-Socio'), isFalse);
  });

  test('as quebras de linha do servidor ficam só com \\n', () async {
    final d = await c.read(notificacoesProvider.future);
    expect(d.valor.notificacoes.first.texto, 'Linha um\nLinha dois');
  });

  test('campos em falta não rebentam', () {
    final n = Notificacao.fromJson({'id': 9, 'titulo': 'Só o título'});
    expect(n.texto, '');
    expect(n.pessoal, isFalse);
    expect(n.imagemUrl, isNull);
    expect(n.enviadaEm, isNull);
  });

  test('página seguinte pede antes_de e acrescenta ao fim', () async {
    servidor.total = 35; // mais do que os 30 de uma página

    final primeira = await c.read(notificacoesProvider.future);
    expect(primeira.valor.notificacoes.first.id, 35);
    expect(primeira.valor.notificacoes.length, 30);
    expect(primeira.valor.antesDe, 6, reason: 'continua na anterior à última recebida');

    await c.read(maisNotificacoesProvider.notifier).carregar(primeira.valor.antesDe);

    expect(servidor.pedidos.last.queryParameters['antes_de'], 6);
    expect(c.read(maisNotificacoesProvider).notificacoes.map((n) => n.id), [5, 4, 3, 2, 1]);
    expect(c.read(maisNotificacoesProvider).temMais(primeira.valor.antesDe), isFalse, reason: 'chegou ao fim');
  });

  test('sem mais páginas não vai ao servidor', () async {
    final primeira = await c.read(notificacoesProvider.future);
    servidor.pedidos.clear();

    await c.read(maisNotificacoesProvider.notifier).carregar(primeira.valor.antesDe);
    expect(servidor.pedidos, isEmpty);
  });

  test('sem nada visto, tudo o que veio conta como novo', () async {
    await c.read(notificacoesProvider.future);
    await c.read(vistasProvider.future);
    expect(c.read(notificacoesNovasProvider), 3);
  });

  test('marcar vistas apaga a marca e fica guardado', () async {
    await c.read(notificacoesProvider.future);
    await c.read(vistasProvider.future);

    await c.read(vistasProvider.notifier).marcarVistas(3);
    expect(c.read(notificacoesNovasProvider), 0);

    final guardado = await cache.ler(Ambito.sessao, 'notificacoes.vistas.16');
    expect(guardado?.dados['id'], 3);
  });

  test('uma notificação mais recente do que a última vista volta a ser nova', () async {
    await cache.guardar(Ambito.sessao, 'notificacoes.vistas.16', {'id': 2});
    c.invalidate(vistasProvider); // o `setUp` já o tinha construído com a cache vazia

    await c.read(notificacoesProvider.future);
    await c.read(vistasProvider.future);
    expect(c.read(notificacoesNovasProvider), 1);
  });

  test('marcar vistas nunca anda para trás', () async {
    await cache.guardar(Ambito.sessao, 'notificacoes.vistas.16', {'id': 3});
    c.invalidate(vistasProvider);
    await c.read(vistasProvider.future);

    await c.read(vistasProvider.notifier).marcarVistas(1);
    expect(c.read(vistasProvider).valueOrNull, 3);
  });
}
