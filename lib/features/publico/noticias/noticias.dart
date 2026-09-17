import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/config.dart';
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
  if (modoDemonstracao) return Stream.value(Dados(paginaNoticiasExemplo, DateTime.now()));
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
  if (modoDemonstracao) return Stream.value(Dados(noticiaExemplo(slug), DateTime.now()));
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

// ── Exemplos para o modo de demonstração (`--dart-define=LPS_DEMO=1`) ───────
//
// Só servem para ver o desenho enquanto o clube não publica notícias. As
// fotografias vêm de um serviço de imagens de exemplo.

String _foto(String semente) => 'https://picsum.photos/seed/$semente/1200/800';

final noticiasExemplo = <Map<String, dynamic>>[
  {
    'slug': 'vitoria-no-derby',
    'titulo': 'Vitória no dérbi diante do Sporting por 4-3',
    'resumo': 'Reviravolta nos últimos cinco minutos, com dois golos de Rui Martins e a bancada em euforia.',
    'categoria': {'slug': 'hoquei', 'nome': 'Hóquei em patins', 'cor': '#0b5d3b'},
    'capa': {'url': _foto('lps-derby'), 'credito': 'Foto: Ricardo Silva'},
    'publicado_em': '2026-09-16 22:40:00',
    'corpo': [
      {
        'tipo': 'texto',
        'html':
            '<p>O pavilhão esgotou e não desiludiu. Os Leões entraram a perder por 1-3 ao intervalo, mas a segunda parte foi outra história.</p>',
      },
      {'tipo': 'citacao', 'texto': 'Nunca duvidámos. Esta equipa vive destas noites.'},
      {
        'tipo': 'texto',
        'html':
            '<p>Com este resultado, o clube sobe ao terceiro lugar do campeonato, a dois pontos do segundo classificado.</p>',
      },
      {'tipo': 'imagem', 'uid': 'demo', 'url': 'https://picsum.photos/seed/lps-derby2/1200/800'},
    ],
  },
  {
    'slug': 'inscricoes-abertas-formacao',
    'titulo': 'Inscrições abertas para a formação 2026/2027',
    'resumo': 'Hóquei em patins, futsal, patinagem artística e ginástica, dos 4 aos 18 anos.',
    'categoria': {'slug': 'clube', 'nome': 'Clube', 'cor': '#0b5d3b'},
    'capa': {'url': _foto('lps-formacao')},
    'publicado_em': '2026-09-15 10:00:00',
    'corpo': [
      {
        'tipo': 'texto',
        'html': '<p>As inscrições decorrem na secretaria e no portal do sócio. Os treinos começam a 1 de outubro.</p>',
      },
      {'tipo': 'texto', 'html': '<p>Irmãos têm desconto de 20% na mensalidade a partir do segundo atleta.</p>'},
    ],
  },
  {
    'slug': 'jantar-de-natal',
    'titulo': 'Jantar de Natal do clube com entrega de prémios',
    'resumo': 'Bilhetes à venda na app a partir desta semana.',
    'categoria': {'slug': 'eventos', 'nome': 'Eventos', 'cor': '#12a15f'},
    'capa': {'url': _foto('lps-jantar')},
    'publicado_em': '2026-09-14 18:30:00',
    'corpo': [
      {
        'tipo': 'texto',
        'html': '<p>O jantar é na sede, com lugares limitados. Cada sócio pode levar dois convidados.</p>',
      },
      {'tipo': 'separador'},
      {'tipo': 'texto', 'html': '<p>Haverá entrega de prémios às equipas campeãs da época passada.</p>'},
    ],
  },
  {
    'slug': 'obras-no-pavilhao',
    'titulo': 'Pavilhão com piso novo já em outubro',
    'resumo': 'A obra arranca depois do jogo com o Oeiras e demora três semanas.',
    'categoria': {'slug': 'clube', 'nome': 'Clube', 'cor': '#0b5d3b'},
    'capa': {'url': _foto('lps-pavilhao')},
    'publicado_em': '2026-09-12 09:15:00',
    'corpo': [
      {'tipo': 'texto', 'html': '<p>Durante as obras, os treinos passam para o pavilhão municipal de Oeiras.</p>'},
    ],
  },
  {
    'slug': 'patinagem-medalhas',
    'titulo': 'Três medalhas na prova regional de patinagem',
    'resumo': 'Ouro em juvenis e dois bronzes em iniciados.',
    'categoria': {'slug': 'patinagem', 'nome': 'Patinagem', 'cor': '#12a15f'},
    'capa': {'url': _foto('lps-patinagem')},
    'publicado_em': '2026-09-10 20:05:00',
    'corpo': [
      {'tipo': 'texto', 'html': '<p>As atletas apuraram-se para o campeonato nacional, em novembro.</p>'},
    ],
  },
  {
    'slug': 'quotas-na-app',
    'titulo': 'Já pode pagar as quotas pela app',
    'resumo': 'MB WAY ou referência, sem ir à secretaria.',
    'categoria': {'slug': 'socios', 'nome': 'Sócios', 'cor': '#0b5d3b'},
    'capa': {'url': _foto('lps-quotas')},
    'publicado_em': '2026-09-08 11:00:00',
    'corpo': [
      {
        'tipo': 'texto',
        'html': '<p>Entre na área de sócio, toque em Pagar e escolha quantos meses quer regularizar.</p>',
      },
    ],
  },
];

final paginaNoticiasExemplo = PaginaNoticias([for (final n in noticiasExemplo) NoticiaResumo.fromJson(n)], 1, 1);

Noticia noticiaExemplo(String slug) =>
    Noticia.fromJson(noticiasExemplo.firstWhere((n) => n['slug'] == slug, orElse: () => noticiasExemplo.first));
