/// A ficha de um sócio de 13 a 17 anos (§2.12): vê-se, mas não se edita — nem
/// os contactos, nem a fotografia. O servidor responderia `403 sem_capacidade`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/cache/com_cache.dart';
import 'package:lpsapp/core/theme/app_theme.dart';
import 'package:lpsapp/features/socio/perfil/perfil.dart';
import 'package:lpsapp/features/socio/perfil/perfil_page.dart';

class _Quem extends SessaoController {
  _Quem(this.inicial);

  final Sessao inicial;

  @override
  Sessao build() => inicial;
}

Sessao _sessao(List<String> capacidades) => sessaoDaConta({
  'nome': 'Rita',
  'faixa_etaria': 'teen',
  'capacidades': capacidades,
  'socio': {'nr_socio': 1924, 'nome_completo': 'RITA', 'estado': 1},
});

Future<void> _pump(WidgetTester t, Sessao quem) async {
  t.view.physicalSize = const Size(360, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final perfil = Perfil.fromJson({
    'nr_socio': 1924,
    'nome_completo': 'RITA',
    'estado': 1,
    'estado_label': 'Ativo',
    'email': 'rita@exemplo.pt',
  });

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sessaoProvider.overrideWith(() => _Quem(quem)),
        perfilProvider.overrideWith((ref) => Stream.value(Dados(perfil, DateTime.now()))),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const PerfilPage()),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  testWidgets('um menor vê a ficha sem a poder alterar, e sabe quem o faz', (t) async {
    await _pump(t, _sessao(const ['view_member_card', 'view_own_tickets']));

    expect(find.text('Guardar alterações'), findsNothing);
    expect(find.textContaining('alteradas pela secretaria'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
    final email = t.widget<TextField>(find.widgetWithText(TextField, 'Email'));
    expect(email.readOnly, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('um adulto continua a editar', (t) async {
    await _pump(t, _sessao(const ['edit_profile', 'upload_photo']));

    expect(find.text('Guardar alterações'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    final email = t.widget<TextField>(find.widgetWithText(TextField, 'Email'));
    expect(email.readOnly, isFalse);
  });
}
