import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/cache/com_cache.dart';
import '../../../core/links.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/imagem_rede.dart';
import 'corpo_blocos.dart';
import 'noticias.dart';
import 'noticias_page.dart';

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
    // Botões redondos claros, legíveis por cima da fotografia da capa.
    final sobreCapa = IconButton.styleFrom(
      backgroundColor: tema.colorScheme.surfaceContainerLowest.withValues(alpha: 0.9),
      foregroundColor: tema.colorScheme.onSurface,
    );
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: n.capa == null ? null : MediaQuery.sizeOf(context).width * 0.8,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton.filled(
              tooltip: 'Voltar',
              style: sobreCapa,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              // Aberta por link não há nada atrás: vai para a lista.
              onPressed: () => context.canPop() ? context.pop() : context.go('/noticias'),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Builder(
                builder: (botao) => IconButton.filled(
                  tooltip: 'Partilhar',
                  style: sobreCapa,
                  icon: Icon(Icons.adaptive.share, size: 20),
                  onPressed: () => Links.partilhar(botao, titulo: n.titulo, link: Links.noticia(n.slug)),
                ),
              ),
            ),
          ],
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
              CorpoBlocos(n.corpo),
              if (n.etiquetas.isNotEmpty) _Etiquetas(n.etiquetas),
              if (n.relacionados.isNotEmpty) _Relacionados(n.relacionados),
              if (n.relacionadas.isNotEmpty) _VejaTambem(n.relacionadas),
            ],
          ),
        ),
      ],
    );
  }
}

/// As etiquetas do artigo. Cada uma abre a lista do seu tema.
class _Etiquetas extends StatelessWidget {
  const _Etiquetas(this.etiquetas);

  final List<Etiqueta> etiquetas;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in etiquetas)
            Material(
              color: c.surfaceContainerHigh,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(
                  Uri(path: '/noticias/etiqueta/${Uri.encodeComponent(e.slug)}', queryParameters: {'nome': e.nome})
                      .toString(),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Text(
                    e.nome,
                    style: TextStyle(color: c.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// O jogo da crónica, o evento da antevisão, a sessão cujos bilhetes estão à
/// venda. Só a sessão tem ecrã próprio; o resto mostra-se e fica por ali.
class _Relacionados extends StatelessWidget {
  const _Relacionados(this.itens);

  final List<Relacionado> itens;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nesta notícia', style: tema.textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final r in itens)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Bloco(
                padding: const EdgeInsets.all(12),
                onTap: r.rota == null ? null : () => context.push(r.rota!),
                child: Row(
                  children: [
                    IconePastilha(switch (r.tipo) {
                      'jogo' => Icons.sports_soccer_outlined,
                      'evento' => Icons.celebration_outlined,
                      'sessao' => Icons.confirmation_number_outlined,
                      _ => Icons.link_rounded,
                    }),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
                          if (_legenda(r) case final l when l.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(l, style: tema.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                    if (r.rota != null) Icon(Icons.chevron_right_rounded, color: tema.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _legenda(Relacionado r) => [
    ?switch (r.inicio) {
      final DateTime i => DateFormat("d 'de' MMMM', às' HH:mm", 'pt_PT').format(i),
      _ => null,
    },
    ?r.local,
    if (r.tipo == 'sessao' && r.estado == 'a_venda') 'Bilhetes à venda',
  ].join(' · ');
}

/// "Veja também": notícias que partilham etiquetas com esta.
class _VejaTambem extends StatelessWidget {
  const _VejaTambem(this.noticias);

  final List<NoticiaResumo> noticias;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Veja também', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          // A linha traz a sua própria margem lateral: aqui tira-se a do texto
          // para as fotografias alinharem com o corpo do artigo.
          for (final n in noticias)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: LinhaNoticia(n),
            ),
        ],
      ),
    );
  }
}
