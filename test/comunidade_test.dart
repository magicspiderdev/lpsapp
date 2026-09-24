import 'dart:convert';
import 'dart:typed_data';

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
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/comunidade/bloco_comunidade.dart';
import 'package:lpsapp/features/comunidade/comunidade.dart';
import 'package:lpsapp/features/comunidade/comunidade_page.dart';
import 'package:lpsapp/features/comunidade/passatempo_page.dart';

/// A forma do guia (§4.23, 1), com um jogo por relatar.
Map<String, dynamic> _jogo({
  bool palpitesAberto = false,
  bool relatosAberto = true,
  Map<String, dynamic>? meuPalpite,
  Map<String, dynamic>? meuRelato,
  Map<String, dynamic>? confirmado,
}) => {
  'jogo': {
    'tipo': 'jogo',
    'id': 1234,
    'titulo': 'Cr Leões Porto Salvo x Sl Benfica',
    'inicio': '2026-09-27 15:00:00',
    'data_confirmada': true,
    'hora_confirmada': true,
    'estado': confirmado == null ? 'agendado' : 'terminado',
    'equipa_casa': {'nome': 'Cr Leões Porto Salvo', 'emblema_url': null, 'do_clube': true},
    'equipa_fora': {'nome': 'Sl Benfica', 'emblema_url': null, 'do_clube': false},
    'resultado': confirmado == null ? null : {'casa': confirmado['casa'], 'fora': confirmado['fora']},
    'modalidade': {'slug': 'futsal', 'nome': 'Futsal'},
  },
  'relatos': {
    'aberto': relatosAberto,
    'motivo': relatosAberto ? null : 'por_comecar',
    'necessarios': 3,
    'propostas': [
      {'casa': 3, 'fora': 1, 'relatos': 2},
      {'casa': 3, 'fora': 2, 'relatos': 1},
    ],
    'meu': meuRelato,
    'confirmado': confirmado,
  },
  'palpites': {
    'aberto': palpitesAberto,
    'fecha_em': '2026-09-27 15:00:00',
    'total': 41,
    'distribuicao': {'vitoria_casa': 30, 'empate': 6, 'vitoria_fora': 5},
    'meu': meuPalpite,
  },
};

final _passatempo = {
  'uid': '01KPASSA',
  'titulo': 'Ganhe 2 bilhetes para o dérbi',
  'resumo': 'Acerte e habilite-se.',
  'descricao': 'Acerte em quem marcou e habilite-se a 2 bilhetes.',
  'premio': '2 bilhetes',
  'regulamento': 'Uma participação por conta.\nSorteio no fim.',
  'imagem': null,
  'tipo': 'escolha',
  'pergunta': 'Quem marcou o primeiro golo da época?',
  'opcoes': ['Rui', 'Zé', 'Tó'],
  'so_socios': false,
  'vencedores': 2,
  'inicio': '2026-09-20 00:00:00',
  'fim': '2026-10-01 00:00:00',
  'fase': 'a_decorrer',
  'participantes': 57,
  'pode_participar': true,
  'motivo': null,
  'resposta_certa': null,
  'minha_participacao': null,
};

/// Responde como o CISOC e guarda o que lhe pedem.
class _Servidor implements HttpClientAdapter {
  /// (método, caminho, corpo em JSON): o JSON compara o que vai no fio.
  final pedidos = <(String, String, String?)>[];
  Map<String, dynamic> jogo = _jogo();
  bool confirmar = false;

  /// A última escrita: as leituras (o perfil, as listas) chegam por qualquer ordem.
  (String, String, String?) get escrita => pedidos.lastWhere((p) => p.$1 != 'GET');

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? _) async {
    pedidos.add((o.method, o.path, o.data == null ? null : jsonEncode(o.data)));
    final caminho = o.path;
    Object? dados;
    var estado = 200;

    if (caminho.endsWith('/comunidade/jogos')) {
      dados = {
        'jogos': o.queryParameters['quando'] == 'proximos' ? [_jogo(palpitesAberto: true, relatosAberto: false)] : [jogo],
      };
    } else if (caminho.endsWith('/comunidade/jogos/1234')) {
      dados = jogo;
    } else if (caminho.endsWith('/resultado')) {
      final m = o.data as Map;
      jogo = _jogo(meuRelato: {'casa': m['casa'], 'fora': m['fora'], 'anulado': false});
      dados = {...jogo, 'confirmou': confirmar};
    } else if (caminho.endsWith('/palpite')) {
      jogo = _jogo(palpitesAberto: true, relatosAberto: false, meuPalpite: o.method == 'DELETE' ? null : {...o.data as Map, 'pontos': null});
      dados = jogo;
    } else if (caminho.endsWith('/comunidade/perfil')) {
      final alcunha = o.method == 'PUT' ? (o.data as Map)['alcunha'] : null;
      dados = {
        'perfil': {'alcunha': alcunha, 'bloqueado': false},
      };
    } else if (caminho.endsWith('/comunidade/classificacao')) {
      dados = {
        'epoca': '2026-27',
        'regras': {'exacto': 3, 'vencedor': 1},
        'classificacao': [
          {'posicao': 1, 'alcunha': 'Leão do Norte', 'pontos': 17, 'exactos': 3, 'palpites': 9, 'eu': false},
          // Um salto na numeração: o 2.º não escolheu alcunha.
          {'posicao': 3, 'alcunha': 'Rugido', 'pontos': 12, 'exactos': 2, 'palpites': 9, 'eu': false},
        ],
        'eu': {'posicao': 4, 'alcunha': null, 'pontos': 9, 'exactos': 1, 'palpites': 7},
      };
    } else if (caminho.endsWith('/comunidade/palpites')) {
      dados = {'palpites': []};
    } else if (caminho.endsWith('/comunidade/passatempos')) {
      dados = {
        'passatempos': [_passatempo],
      };
    } else if (caminho.endsWith('/participar')) {
      estado = 201;
      dados = {
        'passatempo': {
          ..._passatempo,
          'pode_participar': false,
          'motivo': 'ja_participou',
          'participantes': 58,
          'minha_participacao': {'opcao': (o.data as Map)['opcao'], 'resposta': null, 'em': '…', 'vencedor': null},
        },
      };
    } else if (caminho.endsWith('/comunidade/passatempos/01KPASSA')) {
      dados = {'passatempo': _passatempo};
    } else {
      estado = 404;
    }

    return ResponseBody.fromString(
      jsonEncode(
        estado == 404
            ? {'status': 'error', 'erro': 'nao_encontrado', 'message': 'Não encontrado.'}
            : {'status': 'success', 'data': dados},
      ),
      estado,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ComConta extends SessaoController {
  @override
  Sessao build() => const SessaoConta(ContaSessao(nome: 'Adepto sem ficha'));
}

class _SemConta extends SessaoController {
  @override
  Sessao build() => const SessaoAnonima();
}

class _Online extends LigacaoController {
  @override
  bool build() => true;
}

List<Override> _overrides(_Servidor s, {bool comConta = true}) => [
  sessaoProvider.overrideWith(comConta ? _ComConta.new : _SemConta.new),
  ligacaoProvider.overrideWith(_Online.new),
  cacheProvider.overrideWithValue(CacheEmMemoria()),
  dioContaProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'http://cisoc/api/v2'))..httpClientAdapter = s),
];

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  group('contrato', () {
    test('um jogo com os dois blocos', () {
      final c = JogoComunidade.fromJson(_jogo(meuPalpite: {'casa': 2, 'fora': 1, 'pontos': 3}));
      expect(c.jogo.casa?.doClube, isTrue);
      expect(c.relatos.aberto, isTrue);
      expect(c.relatos.propostas.first.marcador, const Marcador(3, 1));
      expect(c.relatos.propostas.first.relatos, 2);
      expect(c.palpites.vitoriaCasa, 30);
      expect(c.palpites.meu, const Marcador(2, 1));
      expect(c.palpites.meusPontos, 3);
    });

    test('um relato anulado pelo clube', () {
      final c = JogoComunidade.fromJson(_jogo(meuRelato: {'casa': 1, 'fora': 0, 'anulado': true}));
      expect(c.relatos.meuAnulado, isTrue);
    });

    test('classificação: quem vê fica em "eu", mesmo sem alcunha', () {
      final c = Classificacao.fromJson({
        'epoca': '2026-27',
        'classificacao': [
          {'posicao': 1, 'alcunha': 'A', 'pontos': 5, 'exactos': 1, 'palpites': 3, 'eu': false},
        ],
        'eu': {'posicao': 4, 'alcunha': null, 'pontos': 2, 'exactos': 0, 'palpites': 2},
      });
      expect(c.eu?.posicao, 4);
      expect(c.eu?.eu, isTrue);
      expect(c.eu?.alcunha, isNull);
    });

    test('passatempo de um tipo novo não se consegue preencher', () {
      final p = Passatempo.fromJson({..._passatempo, 'tipo': 'fotografia'});
      expect(p.tipoConhecido, isFalse);
      expect(Passatempo.fromJson(_passatempo).tipoConhecido, isTrue);
    });
  });

  group('últimos: hoje e ontem, já acabados', () {
    JogoComunidade j(String inicio, {String estado = 'agendado', bool hora = true, Map<String, int>? resultado}) {
      final base = _jogo();
      return JogoComunidade.fromJson({
        ...base,
        'jogo': {
          ...base['jogo'] as Map<String, dynamic>,
          'inicio': inicio,
          'estado': estado,
          'hora_confirmada': hora,
          'resultado': resultado,
        },
      });
    }

    final agora = DateTime(2026, 9, 27, 18, 0);
    List<String> horas(List<JogoComunidade> l) => [for (final c in l) c.jogo.inicio.toString().substring(0, 16)];

    test('hora e meia depois do início conta como acabado, mesmo com o estado por mudar', () {
      final l = ultimosJogos([j('2026-09-27 16:30:00'), j('2026-09-27 16:31:00')], agora);
      expect(horas(l), ['2026-09-27 16:30']);
    });

    test('ontem entra, anteontem não; o mais recente primeiro', () {
      final l = ultimosJogos([j('2026-09-25 20:00:00'), j('2026-09-26 11:00:00'), j('2026-09-27 15:00:00')], agora);
      expect(horas(l), ['2026-09-27 15:00', '2026-09-26 11:00']);
    });

    test('sem hora confirmada: só no dia seguinte, a não ser que já tenha resultado', () {
      expect(ultimosJogos([j('2026-09-27 00:00:00', hora: false)], agora), isEmpty);
      expect(ultimosJogos([j('2026-09-26 00:00:00', hora: false)], agora), hasLength(1));
      expect(
        ultimosJogos([j('2026-09-27 00:00:00', hora: false, estado: 'terminado', resultado: {'casa': 2, 'fora': 1})], agora),
        hasLength(1),
      );
    });

    test('cancelados e adiados não aparecem', () {
      expect(ultimosJogos([j('2026-09-27 10:00:00', estado: 'cancelado'), j('2026-09-27 10:00:00', estado: 'adiado')], agora), isEmpty);
    });
  });

  group('escritas', () {
    late _Servidor servidor;
    late ProviderContainer c;

    setUp(() {
      servidor = _Servidor();
      c = ProviderContainer(overrides: _overrides(servidor));
      addTearDown(c.dispose);
    });

    test('relatar substitui o jogo pelo que vem, e diz se confirmou', () async {
      final sub = c.listen(jogoComunidadeProvider('1234'), (_, _) {});
      addTearDown(sub.close);
      await c.read(jogoComunidadeProvider('1234').future);

      servidor.confirmar = true;
      final confirmou = await c.read(jogoComunidadeProvider('1234').notifier).relatar(const Marcador(3, 1));

      expect(confirmou, isTrue);
      expect(servidor.escrita, ('POST', '/comunidade/jogos/1234/resultado', jsonEncode({'casa': 3, 'fora': 1})));
      expect(c.read(jogoComunidadeProvider('1234')).value?.relatos.meu, const Marcador(3, 1));
    });

    test('palpitar é um PUT, retirar um DELETE', () async {
      final sub = c.listen(jogoComunidadeProvider('1234'), (_, _) {});
      addTearDown(sub.close);
      await c.read(jogoComunidadeProvider('1234').future);
      final jogo = c.read(jogoComunidadeProvider('1234').notifier);

      await jogo.palpitar(const Marcador(2, 0));
      expect(c.read(jogoComunidadeProvider('1234')).value?.palpites.meu, const Marcador(2, 0));
      await jogo.retirarPalpite();
      expect(c.read(jogoComunidadeProvider('1234')).value?.palpites.meu, isNull);
      expect([for (final p in servidor.pedidos) if (p.$1 != 'GET') p.$1], ['PUT', 'DELETE']);
    });

    test('sair da classificação envia alcunha null, não o nome', () async {
      final sub = c.listen(perfilComunidadeProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(perfilComunidadeProvider.future);
      await c.read(perfilComunidadeProvider.notifier).mudarAlcunha(null);
      expect(servidor.escrita, ('PUT', '/comunidade/perfil', jsonEncode({'alcunha': null})));
    });

    test('participar numa escolha envia só a opção', () async {
      final sub = c.listen(passatempoProvider('01KPASSA'), (_, _) {});
      addTearDown(sub.close);
      await c.read(passatempoProvider('01KPASSA').future);
      await c.read(passatempoProvider('01KPASSA').notifier).participar(opcao: 1);
      expect(servidor.escrita, ('POST', '/comunidade/passatempos/01KPASSA/participar', jsonEncode({'opcao': 1})));
      expect(c.read(passatempoProvider('01KPASSA')).value?.minha?.opcao, 1);
    });
  });

  group('ecrãs', () {
    Future<void> montar(WidgetTester t, Widget ecra, _Servidor s, {bool comConta = true, double largura = 320, double escala = 2}) async {
      t.view.physicalSize = Size(largura, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => ecra),
          GoRoute(path: '/entrar', builder: (_, _) => const Text('ecrã de entrar')),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: _overrides(s, comConta: comConta),
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('sem sessão: explica o que é e leva a entrar', (t) async {
      await montar(t, const ComunidadePage(), _Servidor(), comConta: false, escala: 1, largura: 400);
      expect(find.text('Entrar ou criar conta'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    for (final (largura, escala) in [(320.0, 2.0), (430.0, 1.0)]) {
      testWidgets('os três separadores cabem · ${largura.toInt()}px · letra x$escala', (t) async {
        await montar(t, const ComunidadePage(), _Servidor(), largura: largura, escala: escala);
        expect(find.textContaining('Confirma?'), findsOneWidget);
        await t.ensureVisible(find.text('Classificação'));
        await t.tap(find.text('Classificação'));
        await t.pumpAndSettle();
        expect(find.text('Escolha uma alcunha'), findsOneWidget);
        // O salto fica: não se renumera (o 2.º não escolheu alcunha).
        await t.dragUntilVisible(find.text('3.º'), find.byType(ListView).hitTestable(), const Offset(0, -200));
        expect(find.text('3.º'), findsOneWidget);
        await t.ensureVisible(find.text('Passatempos'));
        await t.tap(find.text('Passatempos'));
        await t.pumpAndSettle();
        expect(find.text('Ganhe 2 bilhetes para o dérbi'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('a tab "Últimos" só aparece com um jogo acabado de terminar, e vem primeiro', (t) async {
      await montar(t, const ComunidadePage(), _Servidor(), escala: 1, largura: 400);
      expect(find.text('Últimos'), findsNothing); // o jogo do exemplo é daqui a uns dias

      final ha2h = DateTime.now().subtract(const Duration(hours: 2));
      final s = _Servidor()
        ..jogo = {
          ..._jogo(),
          'jogo': {
            ...(_jogo()['jogo'] as Map<String, dynamic>),
            'inicio': ha2h.toIso8601String().substring(0, 19).replaceFirst('T', ' '),
          },
        };
      await t.pumpWidget(const SizedBox());
      await montar(t, const ComunidadePage(), s, escala: 1, largura: 400);
      expect(find.text('Últimos'), findsOneWidget);
      expect(find.textContaining('Conte-nos como acabou'), findsOneWidget); // aberta à partida
      expect(t.takeException(), isNull);
    });

    testWidgets('na ficha: confirmar a proposta dos outros envia esse resultado', (t) async {
      final s = _Servidor();
      await montar(t, const Scaffold(body: SingleChildScrollView(child: BlocoComunidade('1234'))), s);
      expect(find.text('2 pessoas dizem'), findsOneWidget);
      await t.ensureVisible(find.text('Confirmo').first);
      await t.tap(find.text('Confirmo').first);
      await t.pumpAndSettle();
      expect(s.escrita, ('POST', '/comunidade/jogos/1234/resultado', jsonEncode({'casa': 3, 'fora': 1})));
      expect(find.textContaining('Obrigado'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('palpitar com os contadores, sem teclado', (t) async {
      final s = _Servidor()..jogo = _jogo(palpitesAberto: true, relatosAberto: false);
      await montar(t, const Scaffold(body: SingleChildScrollView(child: BlocoComunidade('1234'))), s, escala: 1);
      expect(find.text('41 palpites'), findsOneWidget);
      await t.ensureVisible(find.text('Palpitar'));
      await t.tap(find.text('Palpitar'));
      await t.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await t.tap(find.byTooltip('Mais um golo de Cr Leões Porto Salvo'));
        await t.pump(const Duration(milliseconds: 400));
      }
      await t.tap(find.text('Enviar 2–0'));
      await t.pumpAndSettle();
      expect(s.escrita, ('PUT', '/comunidade/jogos/1234/palpite', jsonEncode({'casa': 2, 'fora': 0})));
      expect(find.text('Mudar palpite'), findsOneWidget);
    });

    testWidgets('participar pede confirmação e depois mostra a participação', (t) async {
      final s = _Servidor();
      await montar(t, const PassatempoPage(uid: '01KPASSA'), s, escala: 1, largura: 400);
      await t.tap(find.text('Zé'));
      await t.pump();
      await t.ensureVisible(find.text('Participar'));
      await t.tap(find.text('Participar'));
      await t.pumpAndSettle();
      expect(find.textContaining('não dá para mudar'), findsOneWidget);
      await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Participar')));
      await t.pumpAndSettle();
      expect(s.escrita, ('POST', '/comunidade/passatempos/01KPASSA/participar', jsonEncode({'opcao': 1})));
      expect(find.text('Está a participar'), findsOneWidget);
      expect(find.text('Respondeu: Zé'), findsOneWidget);
    });
  });
}
