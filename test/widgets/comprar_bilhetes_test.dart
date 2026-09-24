/// O ecrã de uma sessão de bilhetes: o que o botão do fundo diz a cada
/// pessoa, e que a escolha é de **uma** zona — em ecrãs estreitos, com a letra
/// do sistema aumentada, em claro e escuro.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/auth/sessao.dart' as auth;
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/publico/bilheteira/bilheteira.dart';
import 'package:lpsapp/features/publico/bilheteira/bilheteira_page.dart';

/// Uma sessão de sócio, sem montar a app à volta dela.
class _Quem extends auth.SessaoController {
  _Quem(this.inicial);

  final auth.Sessao inicial;

  @override
  auth.Sessao build() => inicial;
}

/// Escolher uma zona num ecrã pequeno: ela pode estar abaixo da dobra, e um
/// `tap` numa linha que ainda não foi desenhada não encontra nada.
Future<void> _escolher(WidgetTester t, String zona) async {
  final alvo = find.text(zona);
  if (alvo.evaluate().isEmpty) {
    await t.dragUntilVisible(alvo, find.byType(ListView).first, const Offset(0, -120));
    await t.pumpAndSettle();
  }
  await t.tap(alvo);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  /// O caso real que está em produção: uma zona gratuita mas só de sócios, e
  /// uma paga aberta a toda a gente.
  final sessao = Sessao.fromJson({
    'id': 'S1',
    'titulo': 'Leões Porto Salvo x Portimonense',
    'subtitulo': 'Liga Placard Futsal',
    'local': 'Complexo Desportivo Leões de Porto Salvo',
    'inicio': DateTime.now().add(const Duration(days: 4)).toIso8601String(),
    'estado': 'a_venda',
    'preco_desde': 0,
    'zonas': [
      {'id': 3, 'nome': 'Sócios', 'preco': 0, 'exige_socio': true, 'max_por_conta': 4},
      {'id': 4, 'nome': 'Não sócios', 'preco': 5, 'exige_socio': false, 'max_por_conta': 4},
    ],
  });

  final anonimo = const auth.SessaoAnonima();
  final comConta = auth.SessaoConta(const auth.ContaSessao(nome: 'Sem ficha'));
  final comSocio = auth.sessaoDeSocio(const auth.SocioSessao(nrSocio: 1, nomeCompleto: 'Sócio', estado: 1));

  for (final (nome, quem) in [('anónimo', anonimo), ('só conta', comConta), ('sócio', comSocio)]) {
    for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (430.0, 1.3)]) {
      for (final escuro in [false, true]) {
        testWidgets('sessão · $nome · ${largura.toInt()}px · letra x$escala · ${escuro ? 'escuro' : 'claro'}', (
          t,
        ) async {
          await _pump(t, largura: largura, escala: escala, escuro: escuro, quem: quem, sessao: sessao);
          // Com a zona de sócios escolhida é quando mais texto aparece no fundo.
          await _escolher(t, 'Sócios');
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('sem nada escolhido, o botão pede que se escolha', (t) async {
    await _pump(t, quem: comSocio, sessao: sessao);
    expect(find.text('Escolha o bilhete'), findsOneWidget);
  });

  testWidgets('sem sessão, o botão leva a entrar — não diz que não dá', (t) async {
    await _pump(t, quem: anonimo, sessao: sessao);
    await _escolher(t, 'Não sócios');
    expect(find.text('Entrar para continuar'), findsOneWidget);
  });

  testWidgets('conta sem ficha numa zona de sócios: o caminho é associar a ficha', (t) async {
    await _pump(t, quem: comConta, sessao: sessao);
    await _escolher(t, 'Sócios');

    expect(find.text('Associar a minha ficha de sócio'), findsOneWidget);
    expect(
      find.textContaining('Esta zona é reservada a sócios'),
      findsOneWidget,
      reason: 'explicar porquê, e não só recusar',
    );
    // A zona é gratuita, mas isso não a abre a quem não tem ficha.
    expect(find.text('Levantar bilhetes'), findsNothing);
  });

  testWidgets('um menor (§2.10) não compra nem levanta: diz quem o faz, em vez do botão', (t) async {
    final menor = auth.sessaoDaConta({
      'nome': 'Rita',
      'menor': true,
      'permissoes': {'pagar': false, 'comprar': false, 'contratar': false},
      'socio': {'nr_socio': 1924, 'nome_completo': 'RITA', 'estado': 1},
    });
    await _pump(t, largura: 320, escala: 2, quem: menor, sessao: sessao);
    await _escolher(t, 'Sócios');

    expect(find.text('Levantar bilhetes'), findsNothing);
    expect(find.text('Os bilhetes são comprados pelo encarregado de educação.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('conta sem ficha compra na zona aberta a toda a gente', (t) async {
    await _pump(t, quem: comConta, sessao: sessao);
    await _escolher(t, 'Não sócios');
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('um sócio levanta a zona gratuita, sem passar por pagamento', (t) async {
    await _pump(t, quem: comSocio, sessao: sessao);
    await _escolher(t, 'Sócios');

    expect(find.text('Levantar bilhetes'), findsOneWidget);
    expect(find.text('Grátis'), findsWidgets);
  });

  testWidgets('escolhe-se uma zona de cada vez, e trocar recomeça em um', (t) async {
    await _pump(t, quem: comSocio, sessao: sessao);

    await _escolher(t, 'Sócios');
    await t.tap(find.widgetWithIcon(IconButton, Icons.add_rounded));
    await t.pumpAndSettle();
    expect(find.text('2 bilhetes'), findsWidgets);

    // Uma encomenda é de uma zona: escolher outra substitui, não soma.
    await _escolher(t, 'Não sócios');
    expect(find.text('1 bilhete · Não sócios'), findsOneWidget);
    expect(find.text('2 bilhetes'), findsNothing);
  });

  testWidgets('o contador pára no máximo que o servidor deu para a zona', (t) async {
    await _pump(t, quem: comSocio, sessao: sessao);
    await _escolher(t, 'Não sócios');

    final mais = find.widgetWithIcon(IconButton, Icons.add_rounded);
    for (var i = 0; i < 8 && t.widget<IconButton>(mais).onPressed != null; i++) {
      await t.tap(mais);
      await t.pumpAndSettle();
    }

    // `max_por_conta: 4` — e não os 6 do seletor.
    expect(find.text('4 bilhetes'), findsWidgets);
    expect(t.widget<IconButton>(mais).onPressed, isNull);
  });

  testWidgets('uma zona que se compra fora da app diz onde, e não finge que vende', (t) async {
    final externa = Sessao.fromJson({
      'id': 'S2',
      'titulo': 'Gala do clube',
      'inicio': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
      'estado': 'a_venda',
      'zonas': [
        {'id': 9, 'nome': 'Plateia', 'preco': 12, 'venda': 'externa', 'url_compra': 'https://www.bol.pt/x'},
      ],
    });

    await _pump(t, quem: comSocio, sessao: externa);
    await _escolher(t, 'Plateia');

    expect(find.text('Comprar no site da bilheteira'), findsOneWidget);
    expect(find.textContaining('compram-se no site'), findsOneWidget);
  });

  testWidgets('uma sessão esgotada não deixa escolher nada', (t) async {
    final esgotada = Sessao.fromJson({
      'id': 'S3',
      'titulo': 'Leões x FC Porto',
      'inicio': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
      'estado': 'a_venda',
      'esgotado': true,
      'zonas': [
        {'id': 7, 'nome': 'Bancada', 'preco': 12, 'disponivel': false},
      ],
    });

    await _pump(t, quem: comSocio, sessao: esgotada);
    expect(find.text('Esgotado'), findsWidgets);
    await _escolher(t, 'Bancada');
    // Continua sem nada escolhido: a linha não responde ao toque.
    expect(find.text('Continuar'), findsNothing);
  });

  testWidgets('a escolha feita antes de entrar volta com quem entrou', (t) async {
    await _pump(t, quem: comSocio, sessao: sessao, iniciais: const {'4': 3});
    expect(find.text('3 bilhetes · Não sócios'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester t, {
  required auth.Sessao quem,
  required Sessao sessao,
  double largura = 430,
  double escala = 1,
  bool escuro = false,
  Map<String, int> iniciais = const {},
}) async {
  t.view.physicalSize = Size(largura, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        auth.sessaoProvider.overrideWith(() => _Quem(quem)),
        sessaoProvider(sessao.id).overrideWith((ref) => Stream.value(Dados(sessao, DateTime.now()))),
      ],
      child: MaterialApp(
        theme: escuro ? AppTheme.dark() : AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(size: Size(largura, 780), textScaler: TextScaler.linear(escala)),
          child: SessaoPage(id: sessao.id, quantidadesIniciais: iniciais),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}
