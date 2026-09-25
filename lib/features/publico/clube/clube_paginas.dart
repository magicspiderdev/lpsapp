import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../../../core/widgets/imagem_rede.dart';
import '../noticias/corpo_blocos.dart';
import 'clube_widgets.dart';
import 'menu_clube.dart';

/// Abre o destino de um item do menu. Um item sem destino abre o seu submenu
/// (`/noticias/clube/menu/{indice}`), que é o `indice` do item no menu.
void abrirItemMenu(BuildContext context, ItemMenu item, {int? indice}) {
  switch (item.destino) {
    case DestinoPagina(:final slug):
      context.push('/noticias/clube/paginas/$slug');
    case DestinoModalidade(:final slug):
      context.push('/noticias/clube/modalidades/$slug');
    case DestinoSeccao(:final seccao):
      final rota = rotasDasSeccoes[seccao];
      if (rota != null) context.push(rota);
    case DestinoUrl(:final url):
      abrirLink(url);
    case null:
      if (indice != null) context.push('/noticias/clube/menu/$indice');
  }
}

/// As entradas que o clube pôs no menu da app, na página do Clube. Sem menu
/// (ou sem rede e sem cache) não aparece nada: o resto do ecrã não depende
/// dele.
class EntradasMenu extends ConsumerWidget {
  const EntradasMenu({super.key, required this.titulo});

  final Widget titulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itens = ref.watch(menuAppProvider).valueOrNull?.valor ?? const <ItemMenu>[];
    if (itens.isEmpty) return const SizedBox.shrink();

    final cartoes = [
      for (final (i, item) in itens.indexed)
        CartaoEntrada(
          icone: item.icone,
          titulo: item.rotulo,
          resumo: item.resumo,
          onTap: () => abrirItemMenu(context, item, indice: i),
        ),
    ];

    // Dois por linha, com a mesma altura — como os cartões "Conhecer o clube".
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titulo,
        for (var i = 0; i < cartoes.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.md),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cartoes[i]),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: i + 1 < cartoes.length ? cartoes[i + 1] : const SizedBox.shrink()),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// `/noticias/clube/menu/{indice}` — o submenu de um item sem destino.
class GrupoMenuPage extends ConsumerWidget {
  const GrupoMenuPage({super.key, required this.indice});

  final int indice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(menuAppProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: ErroView(erro: e, tentarDeNovo: () => ref.invalidate(menuAppProvider)),
          ),
          data: (d) {
            final itens = d.valor;
            // O menu mudou entretanto (o item saiu, ou deixou de ter submenu).
            final grupo = indice >= 0 && indice < itens.length ? itens[indice] : null;
            if (grupo == null || grupo.filhos.isEmpty) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(
                  child: Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: Text('Esta entrada já não existe.')),
                ),
              );
            }
            return Scaffold(
              appBar: AppBar(title: Text(grupo.rotulo)),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxl),
                children: [
                  AvisoDesactualizado(d),
                  for (final f in grupo.filhos)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IconePastilha(f.icone),
                      title: Text(f.rotulo),
                      subtitle: f.destino is DestinoPagina && (f.destino as DestinoPagina).resumo != null
                          ? Text((f.destino as DestinoPagina).resumo!)
                          : null,
                      trailing: Icon(f.destino is DestinoUrl ? Icons.open_in_new_rounded : Icons.chevron_right_rounded),
                      onTap: () => abrirItemMenu(context, f),
                    ),
                ],
              ),
            );
          },
        );
  }
}

/// `/noticias/clube/paginas/{slug}` — "Quem somos", "Estatutos"…
class PaginaClubePage extends ConsumerWidget {
  const PaginaClubePage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final estado = ref.watch(paginaClubeProvider(slug));

    return Scaffold(
      appBar: AppBar(title: Text(estado.valueOrNull?.valor.titulo ?? '')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(paginaClubeProvider(slug))),
        data: (d) {
          final p = d.valor;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(paginaClubeProvider(slug).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxxl),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AvisoDesactualizado(d),
                        if (p.capa != null) ...[
                          ClipRRect(
                            borderRadius: AppRadius.lgAll,
                            child: AspectRatio(aspectRatio: 4 / 3, child: ImagemRede(p.capa!.url)),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (p.resumo != null) Text(p.resumo!, style: t.textTheme.titleMedium),
                        CorpoBlocos(p.corpo),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
