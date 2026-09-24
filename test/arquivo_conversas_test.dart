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

class _Servidor implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async => ResponseBody.fromString(
    jsonEncode({
      'status': 'success',
      'data': {
        'conversas': [
          {'id': 97, 'fechada': false, 'ultima_mensagem': 'Dúvida sobre quotas', 'ultima_em': '2026-09-10 10:00:00'},
          {'id': 98, 'fechada': true, 'ultima_mensagem': 'Resolvido', 'ultima_em': '2026-08-01 10:00:00'},
        ],
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

Conversa _c(String ultima) => Conversa.fromJson({'id': 1, 'ultima_em': ultima});

void main() {
  group('estaArquivada', () {
    test('não arquivada', () => expect(estaArquivada(_c('2026-09-10 10:00:00'), {}), isFalse));

    test('arquivada e sem nada de novo', () {
      expect(estaArquivada(_c('2026-09-10 10:00:00'), {1: DateTime(2026, 9, 10, 10)}), isTrue);
    });

    test('mensagem nova depois de arquivar: volta à lista', () {
      expect(estaArquivada(_c('2026-09-12 08:00:00'), {1: DateTime(2026, 9, 10, 10)}), isFalse);
    });
  });

  testWidgets('deslizar arquiva, "Desfazer" repõe, e fica guardado na cache da sessão', (t) async {
    await initializeDateFormatting('pt_PT');
    final cache = CacheEmMemoria();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SuportePage())],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sessaoProvider.overrideWith(_Sessao.new),
          ligacaoProvider.overrideWith(_Ligacao.new),
          cacheProvider.overrideWithValue(cache),
          dioSocioProvider.overrideWithValue(Dio()..httpClientAdapter = _Servidor()),
        ],
        child: MaterialApp.router(theme: Tema.claro(), routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Dúvida sobre quotas'), findsOneWidget);

    await t.drag(find.text('Resolvido'), const Offset(-600, 0));
    await t.pumpAndSettle();

    expect(find.text('Resolvido'), findsNothing, reason: 'saiu da lista e o arquivo está fechado');
    expect(find.text('Arquivadas (1)'), findsOneWidget);
    expect((await cache.ler(Ambito.sessao, 'suporte.arquivo.16'))?.dados.keys, ['98']);

    await t.tap(find.text('Desfazer'));
    await t.pumpAndSettle();
    expect(find.text('Resolvido'), findsOneWidget);
    expect(find.text('Arquivadas (1)'), findsNothing);
  });
}
