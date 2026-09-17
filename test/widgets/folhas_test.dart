import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/auth/biometria.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/rede/ligacao.dart';
import 'package:lpsapp/core/tema/tema.dart';
import 'package:lpsapp/features/socio/conta/contas.dart';
import 'package:lpsapp/core/widgets/blocos.dart';
import 'package:lpsapp/features/socio/barra_socio.dart';
import 'package:lpsapp/features/socio/inicio_page.dart';

class _Sessao extends SessaoController {
  @override
  Sessao build() => const SessaoSocio(SocioSessao(nrSocio: 16, nomeCompleto: 'JOÃO PEDRO LOPES MENDES', estado: 1));
}

class _Ligacao extends LigacaoController {
  @override
  bool build() => true;
}

final _resumo = Resumo.fromJson({
  'socio': {'nome_completo': 'JOÃO PEDRO LOPES MENDES', 'estado_label': 'Ativo', 'estado': 1, 'nr_socio': 16},
  'tem_modalidade': false,
  'divida': {'total': 0, 'meses_pendentes': 0},
  'mensagens_nao_lidas': 0,
});

/// Folhas que abrem do início: têm de caber em ecrãs pequenos e com letra grande.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_PT');
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final (largura, altura, escala) in [(360.0, 640.0, 1.0), (320.0, 568.0, 1.3), (360.0, 740.0, 2.0)]) {
    testWidgets('folha do perfil · ${largura.toInt()}x${altura.toInt()} · letra x$escala', (t) async {
      t.view.physicalSize = Size(largura, altura);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      await t.pumpWidget(
        ProviderScope(
          overrides: [
            sessaoProvider.overrideWith(_Sessao.new),
            ligacaoProvider.overrideWith(_Ligacao.new),
            biometriaStoreProvider.overrideWithValue(BiometriaStore(const FlutterSecureStorage())),
            tipoBiometriaProvider.overrideWith((ref) async => TipoBiometria.digital),
            resumoProvider.overrideWith((ref) => Stream.value(Dados(_resumo, DateTime.now()))),
            dependentesProvider.overrideWith((ref) => Stream.value(Dados(const <Dependente>[], DateTime.now()))),
          ],
          child: MaterialApp(
            theme: Tema.claro(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
            home: const SocioShell(child: InicioPage()),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: "ecrã inicial");

      // A foto na barra do sócio abre a folha do perfil.
      await t.tap(find.byType(Avatar).first);
      await t.pumpAndSettle();

      expect(find.text('Terminar sessão'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
