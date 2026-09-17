import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/cache/com_cache.dart';
import '../../../core/config.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../../../core/widgets/imagem_rede.dart';
import 'noticias.dart';

class NoticiaPage extends ConsumerWidget {
  const NoticiaPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticia = ref.watch(noticiaProvider(slug));

    return Scaffold(
      body: noticia.when(
        skipLoadingOnReload: true,
        loading: () => Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: ErroView(erro: e, tentarDeNovo: () => ref.invalidate(noticiaProvider(slug))),
        ),
        data: (d) => _conteudo(context, d),
      ),
    );
  }

  Widget _conteudo(BuildContext context, Dados<Noticia> d) {
    final n = d.valor;
    final tema = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: n.capa == null ? null : MediaQuery.sizeOf(context).width * 0.8,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: tema.colorScheme.surfaceContainerLowest.withValues(alpha: 0.9),
                foregroundColor: tema.colorScheme.onSurface,
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          flexibleSpace: n.capa == null
              ? null
              : FlexibleSpaceBar(stretchModes: const [StretchMode.zoomBackground], background: ImagemRede(n.capa!.url)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 20, Tema.margem + 4, 48),
          sliver: SliverList.list(
            children: [
              AvisoDesactualizado(d),
              Text(
                [
                  if (n.categoria != null) n.categoria!.nome.toUpperCase(),
                  if (n.publicadoEm != null)
                    DateFormat("d 'de' MMMM 'de' y", 'pt_PT').format(n.publicadoEm!).toUpperCase(),
                ].join('  ·  '),
                style: tema.textTheme.labelMedium?.copyWith(
                  color: tema.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(n.titulo, style: tema.textTheme.headlineMedium),
              if (n.resumo != null) ...[
                const SizedBox(height: 12),
                Text(
                  n.resumo!,
                  style: tema.textTheme.titleMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
              if (n.capa?.credito != null) ...[
                const SizedBox(height: 12),
                Text('Fotografia: ${n.capa!.credito}', style: tema.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              for (final b in n.corpo) ?_bloco(context, b),
            ],
          ),
        ),
      ],
    );
  }

  /// Só os tipos que a app já sabe compor; os outros ignoram-se (invariante I7).
  Widget? _bloco(BuildContext context, Map<String, dynamic> b) {
    final tema = Theme.of(context);
    Widget espaco(Widget w) => Padding(padding: const EdgeInsets.only(top: 16), child: w);

    return switch (b['tipo']) {
      'texto' => espaco(
        Text(_textoSimples(b['html'] as String? ?? ''), style: tema.textTheme.bodyLarge?.copyWith(height: 1.6)),
      ),
      'imagem' when b['uid'] is String => espaco(
        ClipRRect(
          borderRadius: BorderRadius.circular(Tema.raioPequeno),
          child: ImagemRede(b['url'] as String? ?? Config.mediaUrl(b['uid'] as String), fit: BoxFit.fitWidth),
        ),
      ),
      'citacao' => espaco(
        Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: tema.colorScheme.primary, width: 3)),
          ),
          child: Text(
            b['texto'] as String? ?? '',
            style: tema.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ),
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
