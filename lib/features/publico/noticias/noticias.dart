import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';

class Categoria {
  final String slug, nome;
  final String? cor;

  const Categoria({required this.slug, required this.nome, this.cor});

  factory Categoria.fromJson(Map<String, dynamic> j) =>
      Categoria(slug: j['slug'] as String, nome: j['nome'] as String, cor: j['cor'] as String?);
}

class Capa {
  final String url;
  final int? largura, altura;
  final String? credito;

  const Capa({required this.url, this.largura, this.altura, this.credito});

  static Capa? fromJson(dynamic j) => j is Map
      ? Capa(
          url: j['url'] as String,
          largura: j['largura'] as int?,
          altura: j['altura'] as int?,
          credito: j['credito'] as String?,
        )
      : null;
}

class NoticiaResumo {
  final String slug, titulo;
  final String? resumo;
  final Categoria? categoria;
  final Capa? capa;
  final DateTime? publicadoEm;

  const NoticiaResumo({
    required this.slug,
    required this.titulo,
    this.resumo,
    this.categoria,
    this.capa,
    this.publicadoEm,
  });

  factory NoticiaResumo.fromJson(Map<String, dynamic> j) => NoticiaResumo(
        slug: j['slug'] as String,
        titulo: j['titulo'] as String,
        resumo: j['resumo'] as String?,
        categoria: j['categoria'] is Map
            ? Categoria.fromJson((j['categoria'] as Map).cast<String, dynamic>())
            : null,
        capa: Capa.fromJson(j['capa']),
        publicadoEm: j['publicado_em'] == null ? null : DateTime.tryParse(j['publicado_em'] as String),
      );
}

class Noticia extends NoticiaResumo {
  /// Lista de blocos `{tipo, ...}`. Tipos desconhecidos ignoram-se na leitura.
  final List<Map<String, dynamic>> corpo;

  Noticia.fromJson(Map<String, dynamic> j)
      : corpo = [
          for (final b in (j['corpo'] as List?) ?? const [])
            if (b is Map && b['tipo'] is String) b.cast<String, dynamic>(),
        ],
        super(
          slug: j['slug'] as String,
          titulo: j['titulo'] as String,
          resumo: j['resumo'] as String?,
          categoria: j['categoria'] is Map
              ? Categoria.fromJson((j['categoria'] as Map).cast<String, dynamic>())
              : null,
          capa: Capa.fromJson(j['capa']),
          publicadoEm: j['publicado_em'] == null ? null : DateTime.tryParse(j['publicado_em'] as String),
        );
}

class ListaNoticias {
  final List<NoticiaResumo> noticias;
  final int pagina, paginas;
  final bool aCarregarMais;

  const ListaNoticias(this.noticias, this.pagina, this.paginas, {this.aCarregarMais = false});

  bool get haMais => pagina < paginas;
}

final noticiasProvider = AsyncNotifierProvider<NoticiasController, ListaNoticias>(NoticiasController.new);

class NoticiasController extends AsyncNotifier<ListaNoticias> {
  static const _porPagina = 12;

  @override
  Future<ListaNoticias> build() => _pagina(1, const []);

  Future<void> carregarMais() async {
    final actual = state.valueOrNull;
    if (actual == null || !actual.haMais || actual.aCarregarMais) return;
    state = AsyncData(ListaNoticias(actual.noticias, actual.pagina, actual.paginas, aCarregarMais: true));
    try {
      state = AsyncData(await _pagina(actual.pagina + 1, actual.noticias));
    } catch (_) {
      state = AsyncData(actual); // mantém o que já está; o próximo scroll tenta outra vez
    }
  }

  Future<ListaNoticias> _pagina(int pagina, List<NoticiaResumo> anteriores) async {
    final data = await dadosDe(ref.read(dioPublicoProvider).get(
      '/noticias',
      queryParameters: {'pagina': pagina, 'por_pagina': _porPagina},
    ));
    final pag = (data['paginacao'] as Map).cast<String, dynamic>();
    return ListaNoticias(
      [
        ...anteriores,
        for (final n in data['noticias'] as List) NoticiaResumo.fromJson((n as Map).cast<String, dynamic>()),
      ],
      pag['pagina'] as int,
      pag['paginas'] as int,
    );
  }
}

final noticiaProvider = FutureProvider.autoDispose.family<Noticia, String>((ref, slug) async {
  final data = await dadosDe(ref.read(dioPublicoProvider).get('/noticias/$slug'));
  return Noticia.fromJson((data['noticia'] as Map).cast<String, dynamic>());
});
