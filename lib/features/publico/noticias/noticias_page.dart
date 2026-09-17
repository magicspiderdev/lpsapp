import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/erro_view.dart';
import 'noticias.dart';

class NoticiasPage extends ConsumerWidget {
  const NoticiasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(noticiasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notícias')),
      body: lista.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(noticiasProvider)),
        data: (l) => RefreshIndicator(
          onRefresh: () => ref.refresh(noticiasProvider.future),
          child: l.noticias.isEmpty
              ? ListView(children: const [
                  Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Ainda não há notícias.'))),
                ])
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 400) ref.read(noticiasProvider.notifier).carregarMais();
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: l.noticias.length + (l.haMais ? 1 : 0),
                    itemBuilder: (context, i) => i == l.noticias.length
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _Cartao(l.noticias[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao(this.n);

  final NoticiaResumo n;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/noticias/${n.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (n.capa != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(n.capa!.url, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12)),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (n.categoria != null) n.categoria!.nome.toUpperCase(),
                      if (n.publicadoEm != null) DateFormat('d MMM y', 'pt_PT').format(n.publicadoEm!),
                    ].join(' · '),
                    style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(n.titulo, style: tema.textTheme.titleMedium),
                  if (n.resumo != null) ...[
                    const SizedBox(height: 4),
                    Text(n.resumo!, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
