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
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/rede/ligacao.dart';
import 'package:lpsapp/core/tema/tema.dart';
import 'package:lpsapp/features/socio/suporte/suporte.dart';
import 'package:lpsapp/features/socio/suporte/suporte_page.dart';

class _Sessao extends SessaoController {
  @override
  Sessao build() => sessaoDeSocio(const SocioSessao(nrSocio: 16, nomeCompleto: 'X', estado: 1));
}

class _Ligacao extends LigacaoController {
  @override
  bool build() => true;
}

/// O servidor com o arquivo: `GET /suporte` sem as arquivadas, `?arquivadas=1`
/// só essas, e `POST /suporte/{id}/arquivar|desarquivar` a mudar o estado.
class _Servidor implements HttpClientAdapter {
  final conversas = <Map<String, dynamic>>[
    {'id': 97, 'fechada': false, 'ultima_mensagem': 'Dúvida sobre quotas', 'ultima_em': '2026-09-10 10:00:00'},
    {'id': 98, 'fechada': true, 'ultima_mensagem': 'Resolvido', 'ultima_em': '2026-08-01 10:00:00'},
  ];
  final arquivadas = <int>{};
  final pedidos = <String>[];

  /// Estado a devolver em todos os pedidos (`503` = serviço em baixo).
  int? falhar;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async {
    final pedido = '${o.method} ${o.path}${o.queryParameters.isEmpty ? '' : '?arquivadas=1'}';
    pedidos.add(pedido);
    if (falhar != null) return _resposta(falhar!, {'status': 'error', 'erro': 'x', 'message': 'Falhou.'});

    final acao = RegExp(r'^POST /suporte/(\d+)/(arquivar|desarquivar)$').firstMatch(pedido);
    if (acao != null) {
      final id = int.parse(acao[1]!);
      acao[2] == 'arquivar' ? arquivadas.add(id) : arquivadas.remove(id);
      return _resposta(200, {
        'status': 'success',
        'data': {'id_conversa': id, 'arquivada': arquivadas.contains(id)},
      });
    }
    final soArquivadas = pedido == 'GET /suporte?arquivadas=1';
    return _resposta(200, {
      'status': 'success',
      'data': {
        'conversas': [
          for (final c in conversas)
            if (arquivadas.contains(c['id']) == soArquivadas) {...c, 'arquivada': soArquivadas},
        ],
      },
    });
  }

  ResponseBody _resposta(int status, Object corpo) => ResponseBody.fromString(
    jsonEncode(corpo),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

Conversa _c(int id, String ultima) => Conversa.fromJson({'id': id, 'ultima_em': ultima});

Dados<List<Conversa>> _dados(List<Conversa> l, DateTime em) => Dados(l, em);

void main() {
  group('estaArquivada (arquivo local antigo)', () {
    test('não arquivada', () => expect(estaArquivada(_c(1, '2026-09-10 10:00:00'), {}), isFalse));

    test('arquivada e sem nada de novo', () {
      expect(estaArquivada(_c(1, '2026-09-10 10:00:00'), {1: DateTime(2026, 9, 10, 10)}), isTrue);
    });

    test('mensagem nova depois de arquivar: já tinha voltado à lista', () {
      expect(estaArquivada(_c(1, '2026-09-12 08:00:00'), {1: DateTime(2026, 9, 10, 10)}), isFalse);
    });
  });

  group('listasDeConversas', () {
    final a = _c(1, '2026-09-10 10:00:00'), b = _c(2, '2026-09-11 10:00:00');
    final antes = DateTime(2026, 9, 1), depois = DateTime(2026, 9, 30);

    test('à espera do servidor: muda logo de lista, pela ordem das datas', () {
      final l = listasDeConversas(
        activas: _dados([b], antes),
        arquivadas: _dados([a], antes),
        pendentes: {1: ArquivoPendente(a, arquivada: false)},
      );
      expect(l.activas.map((c) => c.id), [2, 1]);
      expect(l.arquivadas, isEmpty);
    });

    test('confirmada: conta para listas anteriores, e manda a lista pedida depois', () {
      final p = {2: ArquivoPendente(b, arquivada: true, confirmadoEm: DateTime(2026, 9, 15))};
      final daCache = listasDeConversas(activas: _dados([b], antes), arquivadas: _dados([], antes), pendentes: p);
      expect(daCache.activas, isEmpty);
      expect(daCache.arquivadas.map((c) => c.id), [2]);

      // O servidor já a desarquivou (mensagem nova): prevalece.
      final fresca = listasDeConversas(activas: _dados([b], depois), arquivadas: _dados([], depois), pendentes: p);
      expect(fresca.activas.map((c) => c.id), [2]);
      expect(fresca.arquivadas, isEmpty);
    });

    test('lista ainda por chegar: aparece a que se acabou de mover', () {
      final l = listasDeConversas(
        activas: _dados([a], antes),
        arquivadas: null,
        pendentes: {1: ArquivoPendente(a, arquivada: true)},
      );
      expect(l.activas, isEmpty);
      expect(l.arquivadas.map((c) => c.id), [1]);
    });
  });

  group('migração do arquivo local', () {
    late _Servidor servidor;
    late CacheEmMemoria cache;

    MigracaoArquivoLocal migracao() =>
        MigracaoArquivoLocal(dio: Dio()..httpClientAdapter = servidor, cache: cache, chave: 'suporte.arquivo.16');

    setUp(() {
      servidor = _Servidor();
      cache = CacheEmMemoria();
    });

    test('arquiva no servidor as que ainda estão na lista e sem nada de novo, e não repete', () async {
      await cache.guardar(Ambito.sessao, 'suporte.arquivo.16', {
        '98': '2026-08-01T10:00:00.000', // igual à última: arquiva-se
        '97': '2026-09-01T10:00:00.000', // mensagem nova depois: já tinha voltado
        '55': null, // já não vem na lista (arquivada noutro aparelho)
      });

      final m = migracao();
      await m.garantir();
      expect(servidor.pedidos, ['GET /suporte', 'POST /suporte/98/arquivar']);
      expect(servidor.arquivadas, {98});
      expect((await cache.ler(Ambito.sessao, 'suporte.arquivo.16'))!.dados, isEmpty);

      await m.garantir();
      await migracao().garantir(); // outro arranque: o arquivo local ficou vazio
      expect(servidor.pedidos, hasLength(2));
    });

    test('sem arquivo local não pede nada', () async {
      await migracao().garantir();
      expect(servidor.pedidos, isEmpty);
    });

    test('sem serviço: guarda o arquivo local e tenta outra vez depois', () async {
      await cache.guardar(Ambito.sessao, 'suporte.arquivo.16', {'98': null});
      final m = migracao();

      servidor.falhar = 503;
      await m.garantir();
      expect((await cache.ler(Ambito.sessao, 'suporte.arquivo.16'))!.dados.keys, ['98']);

      servidor.falhar = null;
      await m.garantir();
      expect(servidor.arquivadas, {98});
      expect((await cache.ler(Ambito.sessao, 'suporte.arquivo.16'))!.dados, isEmpty);
    });
  });

  group('lista', () {
    late _Servidor servidor;

    Future<void> montar(WidgetTester t, {CacheLocal? cache}) async {
      await initializeDateFormatting('pt_PT');
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const SuportePage())],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            sessaoProvider.overrideWith(_Sessao.new),
            ligacaoProvider.overrideWith(_Ligacao.new),
            cacheProvider.overrideWithValue(cache ?? CacheEmMemoria()),
            dioSocioProvider.overrideWithValue(Dio()..httpClientAdapter = servidor),
          ],
          child: MaterialApp.router(theme: Tema.claro(), routerConfig: router),
        ),
      );
      await t.pumpAndSettle();
    }

    setUp(() => servidor = _Servidor());

    testWidgets('deslizar arquiva no servidor, "Desfazer" desarquiva', (t) async {
      await montar(t);
      expect(find.text('Dúvida sobre quotas'), findsOneWidget);

      await t.drag(find.text('Resolvido'), const Offset(-600, 0));
      await t.pumpAndSettle();

      expect(servidor.pedidos, contains('POST /suporte/98/arquivar'));
      expect(find.text('Resolvido'), findsNothing, reason: 'saiu da lista e o arquivo está fechado');
      expect(find.text('Arquivadas (1)'), findsOneWidget);

      await t.tap(find.text('Arquivadas (1)'));
      await t.pumpAndSettle();
      expect(find.text('Resolvido'), findsOneWidget, reason: 'vem de GET /suporte?arquivadas=1');

      await t.tap(find.text('Desfazer'));
      await t.pumpAndSettle();
      expect(servidor.pedidos, contains('POST /suporte/98/desarquivar'));
      expect(servidor.arquivadas, isEmpty);
      expect(find.text('Resolvido'), findsOneWidget);
      expect(find.text('Arquivadas (1)'), findsNothing);
    });

    testWidgets('arquivadas noutro aparelho aparecem na secção, e desarquivam-se a deslizar', (t) async {
      servidor.arquivadas.add(98);
      await montar(t);
      expect(find.text('Resolvido'), findsNothing);

      await t.tap(find.text('Arquivadas (1)'));
      await t.pumpAndSettle();
      await t.drag(find.text('Resolvido'), const Offset(-600, 0));
      await t.pumpAndSettle();

      expect(servidor.arquivadas, isEmpty);
      expect(find.text('Arquivadas (1)'), findsNothing);
      expect(find.text('Resolvido'), findsOneWidget);
    });

    testWidgets('o servidor recusa: a conversa volta e avisa-se', (t) async {
      await montar(t);
      servidor.falhar = 404;

      await t.drag(find.text('Resolvido'), const Offset(-600, 0));
      await t.pumpAndSettle();

      expect(find.text('Resolvido'), findsOneWidget);
      expect(find.text('Arquivadas (1)'), findsNothing);
      expect(find.textContaining('Não foi possível arquivar a conversa.'), findsOneWidget);
    });

    testWidgets('o arquivo local antigo passa para o servidor ao abrir a lista', (t) async {
      final cache = CacheEmMemoria();
      await cache.guardar(Ambito.sessao, 'suporte.arquivo.16', {'98': '2026-08-01T10:00:00.000'});
      await montar(t, cache: cache);

      expect(servidor.pedidos.where((p) => p == 'POST /suporte/98/arquivar'), hasLength(1));
      expect(find.text('Resolvido'), findsNothing);
      expect(find.text('Arquivadas (1)'), findsOneWidget);
      expect((await cache.ler(Ambito.sessao, 'suporte.arquivo.16'))!.dados, isEmpty);
    });
  });
}
