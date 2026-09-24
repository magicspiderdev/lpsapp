import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tema/tema.dart';
import '../../../core/widgets/em_breve.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import 'noticias.dart';
import 'noticias_page.dart';

/// As notícias de uma etiqueta (`GET /noticias?etiqueta=`).
///
/// Uma etiqueta que não existe não é um erro: a API devolve lista vazia, e o
/// ecrã diz que não há nada com aquele tema.
class EtiquetaPage extends ConsumerWidget {
  const EtiquetaPage({super.key, required this.slug, this.nome});

  final String slug;

  /// O nome que vinha no artigo de onde se veio; sem ele, fica o slug.
  final String? nome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(noticiasDaEtiquetaProvider(slug));

    return Scaffold(
      appBar: AppBar(title: Text(nome ?? slug)),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(noticiasDaEtiquetaProvider(slug))),
        data: (d) {
          final noticias = d.valor.noticias;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(noticiasDaEtiquetaProvider(slug).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Tema.margem),
                  child: AvisoDesactualizado(d),
                ),
                if (noticias.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: PainelEmPreparacao(
                      icone: Icons.label_off_outlined,
                      titulo: 'Nada com este tema',
                      texto: 'Ainda não há notícias com esta etiqueta.',
                    ),
                  ),
                for (final n in noticias) LinhaNoticia(n),
              ],
            ),
          );
        },
      ),
    );
  }
}
