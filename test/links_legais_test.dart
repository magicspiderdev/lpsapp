import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/config.dart';
import 'package:lpsapp/core/widgets/links_legais.dart';

/// As páginas que as lojas exigem (pedido `2026-09-25-paginas-web-lojas`).
void main() {
  test('caminhos fixos do CISOC, fora dos que a app reclama como links seus', () {
    expect(Config.privacidadeUrl, '${Config.apiRaiz}/privacidade');
    expect(Config.termosUrl, '${Config.apiRaiz}/termos');
    expect(Config.eliminarContaUrl, '${Config.apiRaiz}/conta/eliminar');
    // O AndroidManifest só reclama /noticias/ e /bilhetes/ (no site): se uma
    // destas caísse lá, a política abria dentro da app em vez do browser.
    for (final url in [Config.privacidadeUrl, Config.termosUrl, Config.eliminarContaUrl]) {
      expect(url, isNot(contains('/noticias/')));
      expect(url, isNot(contains('/bilhetes/')));
    }
  });

  testWidgets('os dois links cabem num ecrã estreito com letra grande', (t) async {
    t.view.physicalSize = const Size(320, 400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
        home: const Scaffold(body: LinksLegais()),
      ),
    );

    expect(find.text('Termos de utilização'), findsOneWidget);
    expect(find.text('Política de privacidade'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
