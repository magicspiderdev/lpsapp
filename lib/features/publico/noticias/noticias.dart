import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/rede/ligacao.dart';

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
    categoria: j['categoria'] is Map ? Categoria.fromJson((j['categoria'] as Map).cast<String, dynamic>()) : null,
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
        categoria: j['categoria'] is Map ? Categoria.fromJson((j['categoria'] as Map).cast<String, dynamic>()) : null,
        capa: Capa.fromJson(j['capa']),
        publicadoEm: j['publicado_em'] == null ? null : DateTime.tryParse(j['publicado_em'] as String),
      );
}

class PaginaNoticias {
  final List<NoticiaResumo> noticias;
  final int pagina, paginas;

  const PaginaNoticias(this.noticias, this.pagina, this.paginas);

  factory PaginaNoticias.fromJson(Map<String, dynamic> j) {
    final pag = (j['paginacao'] as Map).cast<String, dynamic>();
    return PaginaNoticias(
      [for (final n in j['noticias'] as List) NoticiaResumo.fromJson((n as Map).cast<String, dynamic>())],
      pag['pagina'] as int,
      pag['paginas'] as int,
    );
  }
}

const _porPagina = 12;

Future<Map<String, dynamic>> _pedirPagina(Dio dio, int pagina) =>
    dadosDe(dio.get('/noticias', queryParameters: {'pagina': pagina, 'por_pagina': _porPagina}));

/// Primeira página: com cache, abre sem rede.
final noticiasProvider = StreamProvider.autoDispose<Dados<PaginaNoticias>>((ref) {
  ref.watch(ligacaoProvider); // quando a ligação volta, actualiza
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'noticias.p1',
    pedido: () => _pedirPagina(dio, 1),
    ler: PaginaNoticias.fromJson,
  );
});

/// Páginas seguintes, carregadas ao fazer scroll. Só com rede; recomeçam quando a
/// primeira página muda.
class MaisNoticias {
  final List<NoticiaResumo> noticias;
  final int ultimaPagina;
  final bool aCarregar;

  const MaisNoticias({this.noticias = const [], this.ultimaPagina = 1, this.aCarregar = false});
}

final maisNoticiasProvider = NotifierProvider.autoDispose<MaisNoticiasController, MaisNoticias>(
  MaisNoticiasController.new,
);

class MaisNoticiasController extends AutoDisposeNotifier<MaisNoticias> {
  @override
  MaisNoticias build() {
    ref.watch(noticiasProvider.select((d) => d.valueOrNull?.obtidoEm));
    return const MaisNoticias();
  }

  Future<void> carregar(int paginas) async {
    if (state.aCarregar || state.ultimaPagina >= paginas || !ref.read(ligacaoProvider)) return;
    final antes = state;
    state = MaisNoticias(noticias: antes.noticias, ultimaPagina: antes.ultimaPagina, aCarregar: true);
    try {
      final p = PaginaNoticias.fromJson(await _pedirPagina(ref.read(dioPublicoProvider), antes.ultimaPagina + 1));
      state = MaisNoticias(noticias: [...antes.noticias, ...p.noticias], ultimaPagina: p.pagina);
    } catch (_) {
      state = antes; // sem rede: fica o que já está
    }
  }
}

final noticiaProvider = StreamProvider.autoDispose.family<Dados<Noticia>, String>((ref, slug) {
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'noticia.$slug',
    pedido: () => dadosDe(dio.get('/noticias/$slug')),
    ler: (j) => Noticia.fromJson((j['noticia'] as Map).cast<String, dynamic>()),
  );
});
