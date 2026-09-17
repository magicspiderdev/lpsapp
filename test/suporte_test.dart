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
import 'package:lpsapp/features/socio/inicio_page.dart';
import 'package:lpsapp/features/socio/suporte/conversa_page.dart';
import 'package:lpsapp/features/socio/suporte/suporte.dart';

class _Sessao extends SessaoController {
  @override
  Sessao build() => const SessaoSocio(SocioSessao(nrSocio: 16, nomeCompleto: 'X', estado: 1));
}

class _Ligacao extends LigacaoController {
  @override
  bool build() => true;
}

class _Servidor implements HttpClientAdapter {
  final respostas = <String, (int, Object)>{};
  final pedidos = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async {
    pedidos.add(o);
    final (status, corpo) =
        respostas['${o.method} ${o.path}'] ?? (404, {'status': 'error', 'erro': 'nao_encontrado', 'message': 'x'});
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

Map<String, dynamic> _ok(Object data) => {'status': 'success', 'data': data};

void main() {
  test('mensagens: texto com & e <, só anexo, tipo de anexo desconhecido', () {
    final m = Mensagem.fromJson({
      'id': 1,
      'texto': 'MBWay & <ontem>',
      'do_clube': true,
      'enviada_em': '2026-08-05 22:12:42',
    });
    expect(m.texto, 'MBWay & <ontem>');
    expect(m.doClube, isTrue);

    final so = Mensagem.fromJson({
      'id': 2,
      'texto': '',
      'do_clube': false,
      'anexo_url': 'https://x/a.pdf',
      'anexo_tipo': 'pdf',
    });
    expect(so.texto, isEmpty);
    expect(so.anexoTipo, TipoAnexo.pdf);

    expect(Mensagem.fromJson({'id': 3, 'anexo_url': 'https://x', 'anexo_tipo': 'video'}).anexoTipo, TipoAnexo.outro);
  });

  group('ecrã da conversa', () {
    late _Servidor servidor;

    Future<void> montar(WidgetTester t, String inicial) async {
      await initializeDateFormatting('pt_PT');
      final router = GoRouter(
        initialLocation: inicial,
        routes: [
          GoRoute(path: '/socio/suporte/nova', builder: (_, _) => const ConversaPage()),
          GoRoute(
            path: '/socio/suporte/:id',
            builder: (_, s) => ConversaPage(id: int.parse(s.pathParameters['id']!)),
          ),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            sessaoProvider.overrideWith(_Sessao.new),
            ligacaoProvider.overrideWith(_Ligacao.new),
            cacheProvider.overrideWithValue(CacheEmMemoria()),
            dioSocioProvider.overrideWithValue(Dio()..httpClientAdapter = servidor),
            resumoProvider.overrideWith((ref) => const Stream<Dados<Resumo>>.empty()),
          ],
          child: MaterialApp.router(theme: Tema.claro(), routerConfig: router),
        ),
      );
      await t.pumpAndSettle();
    }

    setUp(() {
      servidor = _Servidor()
        ..respostas['GET /suporte'] = (
          200,
          _ok({
            'conversas': [
              {'id': 97, 'fechada': false, 'ultima_mensagem': 'olá', 'ultima_do_clube': true, 'nao_lidas': 1},
              {'id': 98, 'fechada': true, 'ultima_mensagem': 'resolvido', 'ultima_do_clube': true, 'nao_lidas': 0},
            ],
          }),
        )
        ..respostas['GET /suporte/97'] = (
          200,
          _ok({
            'id_conversa': 97,
            'mensagens': [
              {
                'id': 1,
                'texto': 'Bom dia, podem confirmar a minha quota?',
                'do_clube': false,
                'enviada_em': '2026-08-05 22:12:42',
              },
              {'id': 2, 'texto': 'Confirmado & pago.', 'do_clube': true, 'enviada_em': '2026-08-05 23:00:00'},
            ],
          }),
        )
        ..respostas['GET /suporte/98'] = (200, _ok({'id_conversa': 98, 'mensagens': []}));
    });

    testWidgets('mostra as mensagens e responde com o texto tal como foi escrito', (t) async {
      servidor.respostas['POST /suporte/97'] = (201, _ok({'id_mensagem': 3, 'id_conversa': 97}));
      await montar(t, '/socio/suporte/97');

      expect(find.text('Confirmado & pago.'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Obrigado <3 & até já');
      await t.pump();
      await t.tap(find.byTooltip('Enviar'));
      await t.pumpAndSettle();

      final post = servidor.pedidos.lastWhere((p) => p.method == 'POST');
      expect(post.data, {'mensagem': 'Obrigado <3 & até já'});
      expect((t.widget<TextField>(find.byType(TextField))).controller!.text, isEmpty);
    });

    testWidgets('conversa fechada: sem campo de escrita, com botão para abrir outra', (t) async {
      await montar(t, '/socio/suporte/98');
      expect(find.text('Abrir nova conversa'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('nova conversa: cria e passa para o ecrã dela', (t) async {
      servidor.respostas['POST /suporte'] = (201, _ok({'id_conversa': 97}));
      await montar(t, '/socio/suporte/nova');

      await t.enterText(find.byType(TextField), 'Tenho uma dúvida');
      await t.pump();
      await t.tap(find.byTooltip('Enviar'));
      await t.pumpAndSettle();

      expect(servidor.pedidos.firstWhere((p) => p.method == 'POST').data, {'mensagem': 'Tenho uma dúvida'});
      expect(find.text('Conversa n.º 97'), findsOneWidget);
    });
  });
}
