/// Privacidade (§2.11) e educandos (§2.3.5): o que cada conta vê e pode mexer,
/// e que os ecrãs aguentam ecrãs estreitos, letra grande, claro e escuro.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/auth/token_store.dart';
import 'package:lpsapp/core/cache/cache_local.dart';
import 'package:lpsapp/core/rede/ligacao.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/conta/educandos/acompanhar_educando_page.dart';
import 'package:lpsapp/features/conta/educandos/educandos_page.dart';
import 'package:lpsapp/features/conta/privacidade/privacidade_page.dart';

class _Servidor implements HttpClientAdapter {
  final respostas = <String, (int, Map<String, dynamic>)>{};
  final pedidos = <RequestOptions>[];

  Iterable<RequestOptions> de(String metodo) => pedidos.where((o) => o.method == metodo);

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

class _Ligado extends LigacaoController {
  @override
  bool build() => true;
}

class _Quem extends SessaoController {
  _Quem(this.inicial);
  final Sessao inicial;

  @override
  Sessao build() => inicial;
}

class _Store extends TokenStore {
  _Store() : super(const FlutterSecureStorage(), Dio());
  int renovacoes = 0;

  @override
  Future<void> renovar() async => renovacoes++;
}

// ── Contas ─────────────────────────────────────────────────────────────────

/// Mãe sem ficha de sócio, com a Carminho (activa) e um pedido por decidir.
final _mae = sessaoDaConta({
  'nome': 'Ana',
  'email': 'ana@exemplo.pt',
  'capacidades': ['manage_consents', 'manage_dependents', 'buy_tickets'],
  'dependentes': [
    {
      'nr_socio': 5643,
      'nome': 'CARMINHO EXEMPLO',
      'relacao': 'mae',
      'faixa_etaria': 'child',
      'capacidades': ['manage_consents', 'view_member_card'],
    },
  ],
});

/// Um adolescente: gere os seus consentimentos, não pede para ser encarregado.
final _teen = sessaoDaConta({
  'nome': 'Rita',
  'faixa_etaria': 'teen',
  'capacidades': ['manage_consents', 'view_own_tickets'],
});

/// Uma conta a quem o servidor não deu os consentimentos.
final _semConsentimentos = sessaoDaConta({
  'nome': 'Tiago',
  'capacidades': ['view_own_tickets'],
});

// ── Respostas ──────────────────────────────────────────────────────────────

Map<String, dynamic> _c(
  String tipo,
  String rotulo, {
  bool ativo = true,
  bool pode = true,
  String? porque,
  bool renovar = false,
  String? dadoPor = 'proprio',
}) => {
  'tipo': tipo,
  'rotulo': rotulo,
  'ativo': ativo,
  'versao': renovar ? '2025-01' : '2026-09',
  'versao_actual': '2026-09',
  'precisa_renovar': renovar,
  'concedido_em': ativo ? '2026-09-24 18:00:00' : null,
  'dado_por': ativo ? dadoPor : null,
  'pode_alterar': pode,
  'porque_nao': porque,
};

Map<String, dynamic> _lista(List<Map<String, dynamic>> l) => {
  'status': 'success',
  'data': {'consentimentos': l},
};

final _meus = _lista([
  _c('app_account', 'Conta na app (termos e privacidade)', renovar: true),
  _c('image_use', 'Uso de imagem em conteúdos públicos do clube'),
  _c('notifications_operational', 'Avisos de serviço', dadoPor: 'secretaria'),
  _c('marketing', 'Comunicações promocionais', ativo: false, pode: false, porque: 'consentimento_indisponivel'),
  _c('tipo_do_futuro', 'Um consentimento que a app ainda não conhece', ativo: false),
]);

final _daCarminho = _lista([
  _c('image_use', 'Uso de imagem em conteúdos públicos do clube', dadoPor: 'encarregado'),
  _c('marketing', 'Comunicações promocionais', ativo: false, pode: false, porque: 'consentimento_indisponivel'),
]);

Map<String, dynamic> _educandos() => {
  'status': 'success',
  'data': {
    'dependentes': [
      {
        'nr_socio': 9,
        'nome': 'Bruno',
        'estado': 'pending',
        'relacao': 'pai',
        'pode_pagar': false,
        'pedido_em': '2026-09-24 18:00:00',
      },
      {
        'nr_socio': 5643,
        'nome': 'CARMINHO EXEMPLO',
        'estado': 'active',
        'relacao': 'mae',
        'pode_pagar': true,
        'faixa_etaria': 'child',
      },
    ],
  },
};

// ── Montagem ───────────────────────────────────────────────────────────────

Future<({_Servidor servidor, _Store store})> _pump(
  WidgetTester t,
  Widget pagina, {
  required Sessao quem,
  _Servidor? servidor,
  double largura = 430,
  double escala = 1,
  bool escuro = false,
}) async {
  final s = servidor ?? _Servidor();
  final store = _Store();
  final dio = Dio(BaseOptions(baseUrl: 'http://teste/api/v2'))..httpClientAdapter = s;

  t.view.physicalSize = Size(largura, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        dioContaProvider.overrideWithValue(dio),
        cacheProvider.overrideWithValue(CacheEmMemoria()),
        ligacaoProvider.overrideWith(_Ligado.new),
        tokenStoreProvider.overrideWithValue(store),
        sessaoProvider.overrideWith(() => _Quem(quem)),
      ],
      child: MaterialApp(
        theme: escuro ? AppTheme.dark() : AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(size: Size(largura, 780), textScaler: TextScaler.linear(escala)),
          child: pagina,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  return (servidor: s, store: store);
}

_Servidor _servidor() => _Servidor()
  ..respostas['GET /me/consentimentos'] = (200, _meus)
  ..respostas['GET /me/dependentes/5643/consentimentos'] = (200, _daCarminho)
  ..respostas['GET /me/dependentes'] = (200, _educandos());

Finder _interruptor(String rotulo) => find.widgetWithText(SwitchListTile, rotulo);

bool _ligado(WidgetTester t, String rotulo) => t.widget<SwitchListTile>(_interruptor(rotulo)).value;

bool _mexivel(WidgetTester t, String rotulo) => t.widget<SwitchListTile>(_interruptor(rotulo)).onChanged != null;

void main() {
  group('privacidade', () {
    testWidgets('um interruptor por tipo, com o rótulo do servidor — também o que a app não conhece', (t) async {
      await _pump(t, const PrivacidadePage(), quem: _mae, servidor: _servidor());

      expect(find.byType(SwitchListTile), findsNWidgets(5));
      expect(_interruptor('Um consentimento que a app ainda não conhece'), findsOneWidget);
      expect(_ligado(t, 'Uso de imagem em conteúdos públicos do clube'), isTrue);
    });

    testWidgets('pode_alterar: false fecha o interruptor e explica porquê', (t) async {
      await _pump(t, const PrivacidadePage(), quem: _teen, servidor: _servidor());

      expect(_mexivel(t, 'Comunicações promocionais'), isFalse);
      expect(find.text('Não está disponível para menores de 18 anos.'), findsOneWidget);
      expect(_mexivel(t, 'Uso de imagem em conteúdos públicos do clube'), isTrue);
    });

    testWidgets('quem deu mostra-se com discrição', (t) async {
      await _pump(t, const PrivacidadePage(), quem: _mae, servidor: _servidor());

      expect(find.text('Dado por si · 24/09/2026'), findsWidgets);
      expect(find.text('Registado na secretaria · 24/09/2026'), findsOneWidget);
    });

    testWidgets('mudar um interruptor manda o PUT e fica com o que a resposta diz', (t) async {
      final s = _servidor()
        ..respostas['PUT /me/consentimentos/image_use'] = (
          200,
          _lista([_c('image_use', 'Uso de imagem em conteúdos públicos do clube', ativo: false)]),
        );
      await _pump(t, const PrivacidadePage(), quem: _mae, servidor: s);

      await t.tap(_interruptor('Uso de imagem em conteúdos públicos do clube'));
      await t.pumpAndSettle();

      expect(s.de('PUT').single.data, {'ativo': false});
      expect(_ligado(t, 'Uso de imagem em conteúdos públicos do clube'), isFalse);
      // A lista inteira foi substituída: os outros já não vieram.
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('um 403 mostra a message do servidor e recarrega', (t) async {
      final s = _servidor()
        ..respostas['PUT /me/consentimentos/image_use'] = (
          403,
          {
            'status': 'error',
            'erro': 'consentimento_do_encarregado',
            'message': 'Este consentimento é dado pelo encarregado de educação.',
          },
        );
      await _pump(t, const PrivacidadePage(), quem: _mae, servidor: s);

      await t.tap(_interruptor('Uso de imagem em conteúdos públicos do clube'));
      await t.pumpAndSettle();

      expect(find.text('Este consentimento é dado pelo encarregado de educação.'), findsOneWidget);
      expect(s.de('GET').length, 2);
      expect(_ligado(t, 'Uso de imagem em conteúdos públicos do clube'), isTrue);
    });

    testWidgets('precisa_renovar pede para aceitar de novo, e envia a versão mostrada', (t) async {
      final s = _servidor()
        ..respostas['PUT /me/consentimentos/app_account'] = (
          200,
          _lista([_c('app_account', 'Conta na app (termos e privacidade)')]),
        );
      await _pump(t, const PrivacidadePage(), quem: _mae, servidor: s);

      expect(find.text('O texto mudou desde que foi dado. É preciso aceitar de novo.'), findsOneWidget);
      await t.tap(find.text('Aceitar de novo'));
      await t.pumpAndSettle();
      expect(find.textContaining('versão 2026-09'), findsOneWidget);
      await t.tap(find.text('Aceito'));
      await t.pumpAndSettle();

      expect(s.de('PUT').single.data, {'ativo': true, 'politica_versao': '2026-09'});
      expect(find.text('Aceitar de novo'), findsNothing);
    });

    testWidgets('sem a capacidade, não há interruptores nem pedidos', (t) async {
      final r = await _pump(t, const PrivacidadePage(), quem: _semConsentimentos, servidor: _servidor());

      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('A privacidade desta conta é gerida pelo encarregado de educação.'), findsOneWidget);
      expect(r.servidor.pedidos, isEmpty);
    });

    testWidgets('os de um educando dizem de quem são', (t) async {
      final r = await _pump(t, const PrivacidadePage(nrSocio: 5643), quem: _mae, servidor: _servidor());

      expect(find.text('CARMINHO EXEMPLO'), findsOneWidget);
      expect(find.text('Sócio n.º 5643'), findsOneWidget);
      expect(find.textContaining('em nome de Carminho'), findsOneWidget);
      expect(find.text('Dado pelo encarregado de educação · 24/09/2026'), findsOneWidget);
      expect(r.servidor.pedidos.single.path, '/me/dependentes/5643/consentimentos');
    });

    testWidgets('um educando que a sessão não traz não abre nada', (t) async {
      final r = await _pump(t, const PrivacidadePage(nrSocio: 1), quem: _mae, servidor: _servidor());

      expect(find.text('Já não acompanha este sócio na app.'), findsOneWidget);
      expect(r.servidor.pedidos, isEmpty);
    });
  });

  group('educandos', () {
    testWidgets('pendente: à espera da secretaria, e só desistir. Activo: privacidade e deixar', (t) async {
      await _pump(t, const EducandosPage(), quem: _mae, servidor: _servidor());

      expect(find.text('À espera da secretaria'), findsOneWidget);
      expect(find.text('Desistir do pedido'), findsOneWidget);
      expect(find.text('Privacidade'), findsOneWidget, reason: 'só o activo');
      expect(find.text('Deixar de acompanhar'), findsOneWidget);
      expect(find.text('Mãe · Sócio n.º 5643'), findsOneWidget);
      expect(find.text('Acompanhar'), findsOneWidget);
    });

    testWidgets('sem manage_dependents, não há botão de pedir', (t) async {
      await _pump(t, const EducandosPage(), quem: _teen, servidor: _servidor());
      expect(find.text('Acompanhar'), findsNothing);
      expect(find.text('Acompanhar um educando'), findsNothing);
    });

    testWidgets('lista vazia convida a pedir', (t) async {
      final s = _Servidor()
        ..respostas['GET /me/dependentes'] = (
          200,
          {
            'status': 'success',
            'data': {'dependentes': <Object>[]},
          },
        );
      await _pump(t, const EducandosPage(), quem: _mae, servidor: s);
      expect(find.text('Ainda não acompanha nenhum educando'), findsOneWidget);
      expect(find.text('Acompanhar um educando'), findsOneWidget);
    });

    testWidgets('deixar de acompanhar pede confirmação, apaga e renova a sessão', (t) async {
      final s = _servidor()
        ..respostas['DELETE /me/dependentes/5643'] = (
          200,
          {
            'status': 'success',
            'data': {'removido': true},
          },
        );
      final r = await _pump(t, const EducandosPage(), quem: _mae, servidor: s);

      await t.tap(find.text('Deixar de acompanhar'));
      await t.pumpAndSettle();
      expect(find.text('Deixar de acompanhar CARMINHO EXEMPLO?'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Deixar de acompanhar'));
      await t.pumpAndSettle();

      expect(s.de('DELETE').single.path, '/me/dependentes/5643');
      expect(r.store.renovacoes, 1);
      expect(find.text('Deixou de acompanhar CARMINHO EXEMPLO.'), findsOneWidget);
    });

    testWidgets('cancelar a confirmação não apaga nada', (t) async {
      final r = await _pump(t, const EducandosPage(), quem: _mae, servidor: _servidor());

      await t.tap(find.text('Desistir do pedido'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();

      expect(r.servidor.de('DELETE'), isEmpty);
    });

    testWidgets('com a sessão atrasada em relação à lista, renova-a uma vez', (t) async {
      final atrasada = sessaoDaConta({
        'nome': 'Ana',
        'capacidades': ['manage_dependents'],
      });
      final r = await _pump(t, const EducandosPage(), quem: atrasada, servidor: _servidor());
      expect(r.store.renovacoes, 1);
    });
  });

  group('acompanhar um educando', () {
    Future<void> preencher(WidgetTester t) async {
      await t.enterText(find.byType(TextFormField), '5643');
      await t.tap(find.text('Data de nascimento do educando'));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.text('Mãe'));
      await t.pumpAndSettle();
    }

    testWidgets('sem nada, não envia e diz o que falta', (t) async {
      final r = await _pump(t, const AcompanharEducandoPage(), quem: _mae);

      await t.tap(find.text('Enviar pedido'));
      await t.pumpAndSettle();

      expect(find.text('Indique o número de sócio.'), findsOneWidget);
      expect(find.text('Indique a data de nascimento do educando.'), findsOneWidget);
      expect(r.servidor.pedidos, isEmpty);
    });

    testWidgets('um erro do servidor mostra a message dele', (t) async {
      final s = _Servidor()
        ..respostas['POST /me/dependentes'] = (
          422,
          {
            'status': 'error',
            'erro': 'dados_nao_conferem',
            'message': 'O número de sócio e a data de nascimento não conferem.',
          },
        );
      final r = await _pump(t, const AcompanharEducandoPage(), quem: _mae, servidor: s);
      await preencher(t);

      await t.tap(find.text('Enviar pedido'));
      await t.pumpAndSettle();

      expect(find.text('O número de sócio e a data de nascimento não conferem.'), findsOneWidget);
      expect(r.store.renovacoes, 0);
    });

    testWidgets('com sucesso, mostra a mensagem do servidor', (t) async {
      final s = _Servidor()
        ..respostas['POST /me/dependentes'] = (
          201,
          {
            'status': 'success',
            'data': {
              'dependente': {'nr_socio': 5643, 'nome': 'Carminho', 'estado': 'pending', 'relacao': 'mae'},
              'mensagem': 'Pedido registado. A secretaria confirma a ligação.',
            },
          },
        );
      final r = await _pump(t, const AcompanharEducandoPage(), quem: _mae, servidor: s);
      await preencher(t);

      await t.tap(find.text('Enviar pedido'));
      await t.pumpAndSettle();

      final corpo = s.de('POST').single.data as Map;
      expect(corpo['nr_socio'], 5643);
      expect(corpo['relacao'], 'mae');
      expect(corpo['data_nascimento'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(find.text('Pedido enviado'), findsOneWidget);
      expect(find.text('Pedido registado. A secretaria confirma a ligação.'), findsOneWidget);
      expect(r.store.renovacoes, 1);
    });

    testWidgets('sem manage_dependents, não há formulário', (t) async {
      await _pump(t, const AcompanharEducandoPage(), quem: _teen);
      expect(find.text('Enviar pedido'), findsNothing);
      expect(find.text('Só um adulto pode pedir para acompanhar um sócio.'), findsOneWidget);
    });
  });

  group('ecrãs estreitos, letra grande, claro e escuro', () {
    final paginas = <(String, Widget)>[
      ('privacidade', const PrivacidadePage()),
      ('privacidade do educando', const PrivacidadePage(nrSocio: 5643)),
      ('educandos', const EducandosPage()),
      ('acompanhar', const AcompanharEducandoPage()),
    ];
    for (final (nome, pagina) in paginas) {
      for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
        for (final escuro in [false, true]) {
          testWidgets('$nome · ${largura.toInt()}px · letra x$escala · ${escuro ? 'escuro' : 'claro'}', (t) async {
            await _pump(t, pagina, quem: _mae, servidor: _servidor(), largura: largura, escala: escala, escuro: escuro);
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  });
}
