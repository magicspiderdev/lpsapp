import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/config.dart';
import '../../../core/rede/ligacao.dart';
import '../noticias/noticias.dart' show Capa;

/// Para onde leva um item do menu (`GET /api/v2/publico/menu/app`, guia
/// público §9). O menu não traz rotas da app: traz o que é — a página
/// `quem-somos`, a secção `agenda` —, e a app sabe onde isso fica.
sealed class DestinoMenu {
  const DestinoMenu();

  /// `null` para um destino que a app não conhece: lista aberta, o item não se
  /// mostra (nunca rebenta).
  static DestinoMenu? fromJson(Map<String, dynamic> j) => switch (j['tipo']) {
    'pagina' when j['slug'] is String => DestinoPagina(j['slug'] as String, resumo: j['resumo'] as String?),
    'modalidade' when j['slug'] is String => DestinoModalidade(j['slug'] as String),
    'seccao' when rotasDasSeccoes.containsKey(j['seccao']) => DestinoSeccao(j['seccao'] as String),
    'url' when j['url'] is String && _http(j['url'] as String) => DestinoUrl(j['url'] as String),
    _ => null,
  };

  /// O servidor só aceita `http(s)`; confirma-se na mesma antes de abrir.
  static bool _http(String url) => url.startsWith('https://') || url.startsWith('http://');
}

class DestinoPagina extends DestinoMenu {
  const DestinoPagina(this.slug, {this.resumo});
  final String slug;
  final String? resumo;
}

class DestinoModalidade extends DestinoMenu {
  const DestinoModalidade(this.slug);
  final String slug;
}

class DestinoSeccao extends DestinoMenu {
  const DestinoSeccao(this.seccao);
  final String seccao;
}

class DestinoUrl extends DestinoMenu {
  const DestinoUrl(this.url);
  final String url;
}

/// As secções fixas que o menu pode apontar, e onde ficam na app. Uma secção
/// nova no servidor que não esteja aqui não aparece.
const rotasDasSeccoes = <String, String>{
  'noticias': '/noticias',
  'agenda': '/agenda',
  'competicao': '/agenda/competicao',
  'modalidades': '/noticias/clube/modalidades',
  'bilhetes': '/bilhetes',
  'clube': '/noticias/clube',
  'comunidade': '/comunidade',
};

class ItemMenu {
  final String rotulo;

  /// `null` num item que só abre o submenu ([filhos]).
  final DestinoMenu? destino;
  final List<ItemMenu> filhos;

  const ItemMenu({required this.rotulo, this.destino, this.filhos = const []});

  /// `null` se o item não se pode mostrar: destino desconhecido, ou um
  /// agrupador que fica sem nenhum filho que a app saiba abrir.
  static ItemMenu? fromJson(Map<String, dynamic> j, {bool filho = false}) {
    final rotulo = j['rotulo'];
    if (rotulo is! String || rotulo.trim().isEmpty) return null;

    final bruto = j['destino'];
    final destino = bruto is Map ? DestinoMenu.fromJson(bruto.cast<String, dynamic>()) : null;
    // Veio um destino e a app não o conhece: não se mostra.
    if (bruto != null && destino == null) return null;

    final filhos = filho
        ? const <ItemMenu>[]
        : [
            for (final f in (j['filhos'] as List?) ?? const [])
              if (f is Map) ?ItemMenu.fromJson(f.cast<String, dynamic>(), filho: true),
          ];

    // Um agrupador sem nada dentro abriria para nada.
    if (destino == null && filhos.isEmpty) return null;

    return ItemMenu(rotulo: rotulo.trim(), destino: destino, filhos: filhos);
  }

  static List<ItemMenu> listaDe(Map<String, dynamic> d) => [
    for (final i in (d['itens'] as List?) ?? const [])
      if (i is Map) ?ItemMenu.fromJson(i.cast<String, dynamic>()),
  ];

  /// O resumo para o cartão de entrada: o da página, ou o que o item leva.
  String get resumo => switch (destino) {
    DestinoPagina(:final resumo?) when resumo.trim().isNotEmpty => resumo,
    null => filhos.map((f) => f.rotulo).join(' · '),
    DestinoUrl() => 'Abre fora da app',
    _ => 'Ver mais',
  };

  IconData get icone => switch (destino) {
    null => Icons.folder_outlined,
    DestinoPagina() => Icons.article_outlined,
    DestinoModalidade() => Icons.sports_outlined,
    DestinoUrl() => Icons.open_in_new_rounded,
    DestinoSeccao(seccao: 'agenda') => Icons.event_outlined,
    DestinoSeccao(seccao: 'competicao') => Icons.emoji_events_outlined,
    DestinoSeccao(seccao: 'bilhetes') => Icons.confirmation_number_outlined,
    DestinoSeccao(seccao: 'noticias') => Icons.newspaper_outlined,
    DestinoSeccao(seccao: 'comunidade') => Icons.forum_outlined,
    DestinoSeccao() => Icons.shield_outlined,
  };
}

/// Uma página do clube (`GET /paginas/{slug}`): "Quem somos", "Estatutos"…
/// O corpo é a mesma lista de blocos das notícias.
class PaginaClube {
  final String slug, titulo;
  final String? resumo;
  final Capa? capa;
  final List<Map<String, dynamic>> corpo;

  const PaginaClube({required this.slug, required this.titulo, this.resumo, this.capa, this.corpo = const []});

  factory PaginaClube.fromJson(Map<String, dynamic> j) => PaginaClube(
    slug: (j['slug'] ?? '') as String,
    titulo: (j['titulo'] ?? '') as String,
    resumo: j['resumo'] is String && (j['resumo'] as String).trim().isNotEmpty ? j['resumo'] as String : null,
    capa: Capa.fromJson(j['capa']),
    corpo: [
      for (final b in (j['corpo'] as List?) ?? const [])
        if (b is Map) b.cast<String, dynamic>(),
    ],
  );
}

/// As entradas da secção Clube — o menu `app` que o clube monta no backoffice.
/// Com cache, como o resto do clube: abre sem rede com o último menu.
final menuAppProvider = StreamProvider.autoDispose<Dados<List<ItemMenu>>>((ref) {
  if (modoDemonstracao) return Stream.value(Dados(ItemMenu.listaDe(menuExemplo), DateTime.now()));
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'menu.app',
    pedido: () => dadosDe(dio.get('/menu/app')),
    ler: ItemMenu.listaDe,
  );
});

final paginaClubeProvider = StreamProvider.autoDispose.family<Dados<PaginaClube>, String>((ref, slug) {
  if (modoDemonstracao) {
    return Stream.value(Dados(PaginaClube.fromJson({...paginaExemplo, 'slug': slug}), DateTime.now()));
  }
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'pagina.$slug',
    pedido: () => dadosDe(dio.get('/paginas/$slug')),
    ler: (d) => PaginaClube.fromJson((d['pagina'] as Map).cast<String, dynamic>()),
  );
});

/// O menu no modo de demonstração.
const menuExemplo = <String, dynamic>{
  'menu': 'app',
  'itens': [
    {
      'rotulo': 'Quem somos',
      'destino': {'tipo': 'pagina', 'slug': 'quem-somos', 'resumo': 'A família leonina de Porto Salvo, desde 1972'},
      'filhos': [],
    },
    {
      'rotulo': 'Formação',
      'destino': null,
      'filhos': [
        {
          'rotulo': 'Escola de futebol',
          'destino': {'tipo': 'pagina', 'slug': 'escola-de-futebol', 'resumo': 'Dos 4 aos 12 anos'},
          'filhos': [],
        },
        {
          'rotulo': 'Futsal',
          'destino': {'tipo': 'modalidade', 'slug': 'futsal'},
          'filhos': [],
        },
      ],
    },
    {
      'rotulo': 'Loja',
      'destino': {'tipo': 'url', 'url': 'https://leoesdeportosalvo.pt/loja'},
      'filhos': [],
    },
  ],
};

/// Uma página no modo de demonstração: uma foto à esquerda e o texto à
/// direita, no mesmo card (`ocupa`).
const paginaExemplo = <String, dynamic>{
  'slug': 'quem-somos',
  'titulo': 'Quem somos',
  'resumo': 'A família leonina de Porto Salvo, desde 1972',
  'corpo': [
    {
      'tipo': 'texto',
      'html':
          '<p>O <strong>Clube Recreativo Leões de Porto Salvo</strong> nasceu em 1972 para dar desporto e convívio às famílias da terra.</p>',
    },
    {'tipo': 'citacao', 'texto': 'Quem veste esta camisola, veste Porto Salvo.', 'estilo': 'verde', 'ocupa': '1/3'},
    {
      'tipo': 'texto',
      'html':
          '<h3>Hoje</h3><p>Centenas de atletas na formação, equipas em provas nacionais e distritais, e uma vida social que junta sócios de todas as idades.</p>',
      'estilo': 'verde',
      'ocupa': '2/3',
    },
  ],
};
