import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config.dart';
import '../../../core/widgets/erro_view.dart';
import 'noticias.dart';

class NoticiaPage extends ConsumerWidget {
  const NoticiaPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticia = ref.watch(noticiaProvider(slug));
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: noticia.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(noticiaProvider(slug))),
        data: (n) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (n.capa != null) Image.network(n.capa!.url, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (n.publicadoEm != null)
                    Text(DateFormat("d 'de' MMMM 'de' y", 'pt_PT').format(n.publicadoEm!),
                        style: tema.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(n.titulo, style: tema.textTheme.headlineSmall),
                  for (final b in n.corpo) ?_bloco(context, b),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Só os tipos que a app já sabe compor; os outros ignoram-se (invariante I7).
  Widget? _bloco(BuildContext context, Map<String, dynamic> b) {
    final tema = Theme.of(context);
    Widget espaco(Widget w) => Padding(padding: const EdgeInsets.only(top: 12), child: w);

    return switch (b['tipo']) {
      'texto' => espaco(Text(_textoSimples(b['html'] as String? ?? ''), style: tema.textTheme.bodyLarge)),
      'imagem' when b['uid'] is String => espaco(Image.network(
          b['url'] as String? ?? Config.mediaUrl(b['uid'] as String),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        )),
      'citacao' => espaco(Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: tema.colorScheme.primary, width: 3)),
          ),
          child: Text(b['texto'] as String? ?? '',
              style: tema.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
        )),
      'separador' => espaco(const Divider()),
      _ => null,
    };
  }

  /// O HTML dos blocos de texto é limitado e já sanitizado no editor; por agora
  /// mostra-se como texto corrido, com os parágrafos preservados.
  static String _textoSimples(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|li|h\d)>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
