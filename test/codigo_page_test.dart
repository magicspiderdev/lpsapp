import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/tema/tema.dart';
import 'package:lpsapp/features/auth/codigo_page.dart';

/// Regista o que o ecrã pediu, sem servidor.
class _Sessao extends SessaoController {
  final pedidos = <({String? email, int? nrSocio})>[];
  final confirmacoes = <({String? email, int? nrSocio, String codigo})>[];

  @override
  Sessao build() => const SessaoAnonima();

  @override
  Future<String> pedirCodigo({String? email, int? nrSocio}) async {
    pedidos.add((email: email, nrSocio: nrSocio));
    return 'Se a conta existir, enviámos um código.';
  }

  @override
  Future<void> confirmarCodigo({String? email, int? nrSocio, required String codigo, required String password}) async {
    confirmacoes.add((email: email, nrSocio: nrSocio, codigo: codigo));
  }
}

/// "Esqueci-me da palavra-passe" também para quem não é sócio: a conta só
/// com email não tem número, e o ecrã só o pedia a ele.
void main() {
  late _Sessao sessao;

  Future<void> montar(WidgetTester t) async {
    sessao = _Sessao();
    await t.pumpWidget(
      ProviderScope(
        overrides: [sessaoProvider.overrideWith(() => sessao)],
        child: MaterialApp(theme: Tema.claro(), home: const CodigoPage()),
      ),
    );
  }

  Future<void> pedirEConfirmar(WidgetTester t, String quem) async {
    await t.enterText(find.widgetWithText(TextFormField, 'Email ou número de sócio'), quem);
    await t.tap(find.text('Enviar código'));
    await t.pumpAndSettle();
    expect(find.text('Verifique o email'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextFormField, 'Código recebido'), '123456');
    await t.enterText(find.widgetWithText(TextFormField, 'Palavra-passe nova'), 'segredo123');
    await t.enterText(find.widgetWithText(TextFormField, 'Repetir palavra-passe'), 'segredo123');
    await t.tap(find.text('Confirmar e entrar'));
    await t.pumpAndSettle();
  }

  testWidgets('conta só com email: o código pede-se e confirma-se pelo email', (t) async {
    await montar(t);
    await pedirEConfirmar(t, '  ana@exemplo.pt ');
    expect(sessao.pedidos.single, (email: 'ana@exemplo.pt', nrSocio: null));
    expect(sessao.confirmacoes.single, (email: 'ana@exemplo.pt', nrSocio: null, codigo: '123456'));
  });

  testWidgets('sócio: só algarismos é o número de sócio, como no login', (t) async {
    await montar(t);
    await pedirEConfirmar(t, '1924');
    expect(sessao.pedidos.single, (email: null, nrSocio: 1924));
    expect(sessao.confirmacoes.single, (email: null, nrSocio: 1924, codigo: '123456'));
  });
}
