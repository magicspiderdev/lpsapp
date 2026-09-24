import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../../../core/widgets/imagem_rede.dart';
import 'noticias.dart';

String quandoNoticia(DateTime? d) => d == null ? '' : DateFormat('d MMM', 'pt_PT').format(d);

class NoticiasPage extends ConsumerWidget {
  const NoticiasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(noticiasProvider);
    final mais = ref.watch(maisNoticiasProvider);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () => ref.refresh(noticiasProvider.future),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            final paginas = lista.valueOrNull?.valor.paginas;
            if (paginas != null && n.metrics.extentAfter < 400) {
              ref.read(maisNoticiasProvider.notifier).carregar(paginas);
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 20, Tema.margem, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEÕES DE PORTO SALVO',
                          style: t.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: Text('Notícias', style: t.headlineLarge)),
                            IconButton.filledTonal(
                              tooltip: 'O clube',
                              onPressed: () => context.push('/noticias/clube'),
                              icon: const Icon(Icons.info_outline_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ...lista.when(
                skipLoadingOnReload: true,
                loading: () => [const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
                error: (e, _) => [
                  SliverFillRemaining(
                    child: ErroView(erro: e, tentarDeNovo: () => ref.invalidate(noticiasProvider)),
                  ),
                ],
                data: (d) {
                  final noticias = [...d.valor.noticias, ...mais.noticias];
                  final haMais = mais.ultimaPagina < d.valor.paginas;
                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 0),
                      sliver: SliverToBoxAdapter(child: AvisoDesactualizado(d, margem: EdgeInsets.zero)),
                    ),
                    if (noticias.isEmpty)
                      const SliverFillRemaining(hasScrollBody: false, child: _Vazio())
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 0),
                        sliver: SliverToBoxAdapter(child: _Destaque(noticias.first)),
                      ),
                      if (noticias.length > 1)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(Tema.margem, 16, Tema.margem, 0),
                          sliver: SliverToBoxAdapter(
                            child: Bloco(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                children: [
                                  for (final (i, n) in noticias.skip(1).indexed) ...[
                                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                                    LinhaNoticia(n),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: haMais && !d.desactualizados
                              ? const Center(child: CircularProgressIndicator())
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A notícia mais recente, em grande, com o título sobre a fotografia.
class _Destaque extends StatelessWidget {
  const _Destaque(this.n);

  final NoticiaResumo n;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.go('/noticias/${n.slug}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tema.raio),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (n.capa != null)
                ImagemRede(
                  n.capa!.url,
                  falha: (_) => const DecoratedBox(decoration: BoxDecoration(gradient: Tema.gradienteClube)),
                )
              else
                const DecoratedBox(decoration: BoxDecoration(gradient: Tema.gradienteClube)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1],
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (n.categoria != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(100)),
                        child: Text(
                          n.categoria!.nome,
                          style: TextStyle(color: c.onPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      n.titulo,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    if (n.publicadoEm != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        quandoNoticia(n.publicadoEm),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uma notícia em linha: fotografia pequena, título e contexto.
///
/// Pública porque o artigo a reaproveita no "veja também" e a lista de uma
/// etiqueta é a mesma coisa noutro sítio.
class LinhaNoticia extends StatelessWidget {
  const LinhaNoticia(this.n, {super.key});

  final NoticiaResumo n;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return InkWell(
      onTap: () => context.go('/noticias/${n.slug}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox.square(
                dimension: 64,
                child: n.capa == null
                    ? const DecoratedBox(decoration: BoxDecoration(gradient: Tema.gradienteClube))
                    : ImagemRede(n.capa!.url, falha: (_) => ColoredBox(color: tema.colorScheme.surfaceContainer)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (n.categoria != null) n.categoria!.nome,
                      quandoNoticia(n.publicadoEm),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const IconePastilha(Icons.newspaper_rounded),
          const SizedBox(height: 16),
          Text('Ainda não há notícias', style: tema.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Quando o clube publicar, aparecem aqui.', textAlign: TextAlign.center, style: tema.textTheme.bodySmall),
        ],
      ),
    );
  }
}
