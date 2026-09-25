import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

/// Abre uma das páginas legais do CISOC no browser.
Future<void> abrirPaginaLegal(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// "Termos de utilização · Política de privacidade": vai junto de tudo o que
/// pede para os aceitar. Aceitar um texto que não se consegue ler não é
/// consentimento (RGPD), e a Google exige a política acessível na app.
class LinksLegais extends StatelessWidget {
  const LinksLegais({super.key, this.alinhamento = WrapAlignment.start});

  final WrapAlignment alinhamento;

  @override
  Widget build(BuildContext context) {
    final estilo = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: const Size(0, 36),
      visualDensity: VisualDensity.compact,
    );
    return Wrap(
      alignment: alinhamento,
      children: [
        TextButton(
          style: estilo,
          onPressed: () => abrirPaginaLegal(Config.termosUrl),
          child: const Text('Termos de utilização'),
        ),
        TextButton(
          style: estilo,
          onPressed: () => abrirPaginaLegal(Config.privacidadeUrl),
          child: const Text('Política de privacidade'),
        ),
      ],
    );
  }
}
