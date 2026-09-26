import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/config.dart';
import '../../../core/rede/ligacao.dart';

/// Informação geral do clube (`GET /api/v2/publico/clube`, guia §4.17). A
/// secretaria mantém-na no backoffice; o que não foi preenchido vem a `null`
/// ou vazio, e o ecrã esconde essa parte.
class Contacto {
  final String tipo, valor;
  final String? etiqueta;

  const Contacto({required this.tipo, required this.valor, this.etiqueta});

  factory Contacto.fromJson(Map<String, dynamic> j) => Contacto(
    tipo: (j['tipo'] ?? '') as String,
    valor: (j['valor'] ?? '') as String,
    etiqueta: j['etiqueta'] as String?,
  );
}

class Modalidade {
  final String nome;

  /// Para filtrar a agenda (`?modalidade=`).
  final String? slug, escaloes, descricao;

  /// Há página para abrir (`/clube/modalidades/{slug}`). Sem ela, a
  /// modalidade não se toca.
  final bool temPagina;

  const Modalidade({required this.nome, this.slug, this.escaloes, this.descricao, this.temPagina = false});

  factory Modalidade.fromJson(Map<String, dynamic> j) => Modalidade(
    nome: (j['nome'] ?? '') as String,
    slug: j['slug'] as String?,
    escaloes: Clube._texto(j['escaloes']),
    descricao: Clube._texto(j['descricao']),
    temPagina: j['tem_pagina'] == true && j['slug'] is String,
  );
}

/// A página de uma modalidade (`GET /clube/modalidades/{slug}`): o horário dos
/// treinos, os escalões, quem treina. O corpo é a mesma lista de blocos das
/// notícias, e não viaja em `/clube`, que é a chamada de arranque.
class PaginaModalidade {
  final Modalidade modalidade;
  final List<Map<String, dynamic>> corpo;

  const PaginaModalidade(this.modalidade, this.corpo);

  factory PaginaModalidade.fromJson(Map<String, dynamic> j) =>
      PaginaModalidade(Modalidade.fromJson({...j, 'tem_pagina': true}), [
        for (final b in (j['corpo'] as List?) ?? const [])
          if (b is Map) b.cast<String, dynamic>(),
      ]);
}

class Clube {
  /// Nome oficial; `null` se a secretaria ainda não o preencheu.
  final String? nome;
  final int? fundadoEm;
  final String? lema, historia, morada, mapaUrl, site;

  /// A mesma história com a formatação do backoffice, já limpa no servidor
  /// (a lista branca do bloco `texto`). Vem `null` junto com [historia].
  final String? historiaHtml;
  final List<Contacto> contactos;
  final List<String> horario;
  final List<Modalidade> modalidades;

  /// `rede` → endereço (facebook, instagram, youtube…). Lista aberta.
  final Map<String, String> redes;

  const Clube({
    required this.nome,
    this.fundadoEm,
    this.lema,
    this.historia,
    this.historiaHtml,
    this.morada,
    this.mapaUrl,
    this.site,
    this.contactos = const [],
    this.horario = const [],
    this.modalidades = const [],
    this.redes = const {},
  });

  factory Clube.fromJson(Map<String, dynamic> j) => Clube(
    nome: _texto(j['nome']),
    fundadoEm: (j['fundado_em'] as num?)?.toInt(),
    lema: _texto(j['lema']),
    historia: _texto(j['historia']),
    historiaHtml: _texto(j['historia_html']),
    morada: _texto(j['morada']),
    mapaUrl: _texto(j['mapa_url']),
    site: _texto(j['site']),
    contactos: [
      for (final c in (j['contactos'] as List?) ?? const []) Contacto.fromJson((c as Map).cast<String, dynamic>()),
    ],
    horario: [for (final h in (j['horario'] as List?) ?? const []) h.toString()],
    modalidades: [
      for (final m in (j['modalidades'] as List?) ?? const []) Modalidade.fromJson((m as Map).cast<String, dynamic>()),
    ],
    // Um objecto no contrato; vazio chega como `[]` (array vazio do PHP).
    redes: switch (j['redes']) {
      final Map<dynamic, dynamic> m => {
        for (final MapEntry(:key, :value) in m.entries)
          if (value is String && value.isNotEmpty) key.toString(): value,
      },
      _ => const {},
    },
  );

  /// Texto vazio conta como não preenchido.
  static String? _texto(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

  /// O primeiro de cada tipo: é o dos atalhos "Ligar" e "Email".
  Contacto? get telefone => contactos.where((c) => c.tipo == 'telefone').firstOrNull;
  Contacto? get email => contactos.where((c) => c.tipo == 'email').firstOrNull;

  /// Há alguma coisa para a página "Contactos e horário".
  bool get temContactos => morada != null || contactos.isNotEmpty || site != null || horario.isNotEmpty;

  /// A secretaria ainda não preencheu nada além (talvez) das modalidades.
  bool get semInformacao =>
      historia == null && morada == null && site == null && contactos.isEmpty && horario.isEmpty && redes.isEmpty;
}

/// Com cache: abre sem rede com a última informação.
final clubeProvider = StreamProvider.autoDispose<Dados<Clube>>((ref) {
  if (modoDemonstracao) return Stream.value(Dados(clubeExemplo, DateTime.now()));
  ref.watch(ligacaoProvider); // quando a ligação volta, actualiza
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'clube',
    pedido: () => dadosDe(dio.get('/clube')),
    ler: (d) => Clube.fromJson((d['clube'] as Map).cast<String, dynamic>()),
  );
});

/// A página de uma modalidade, com cache como o resto do clube.
final paginaModalidadeProvider = StreamProvider.autoDispose.family<Dados<PaginaModalidade>, String>((ref, slug) {
  if (modoDemonstracao) {
    final m = clubeExemplo.modalidades.firstWhere((m) => m.slug == slug, orElse: () => Modalidade(nome: slug));
    return Stream.value(Dados(PaginaModalidade(m, corpoModalidadeExemplo), DateTime.now()));
  }
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'modalidade.$slug',
    pedido: () => dadosDe(dio.get('/clube/modalidades/$slug')),
    ler: (d) => PaginaModalidade.fromJson((d['modalidade'] as Map).cast<String, dynamic>()),
  );
});

/// Exemplo só para ver o desenho (modo de demonstração). Os dados verdadeiros
/// vêm do CISOC, onde a secretaria os mantém.
final clubeExemplo = Clube.fromJson({
  'nome': 'Clube Recreativo Leões de Porto Salvo',
  'fundado_em': 1972,
  'lema': 'A família leonina de Porto Salvo',
  'historia':
      'Fundado em 1972, o clube nasceu para dar desporto e convívio às famílias de Porto Salvo. '
      'Hoje tem centenas de atletas na formação, equipas em competições nacionais e distritais, e '
      'uma vida social que junta sócios de todas as idades.',
  'morada': 'Rua do Clube, 1 · 2740-000 Porto Salvo, Oeiras',
  'mapa_url': 'https://maps.google.com/?q=Le%C3%B5es+de+Porto+Salvo',
  'site': 'https://leoesdeportosalvo.pt',
  'contactos': [
    {'tipo': 'telefone', 'valor': '214 000 000', 'etiqueta': 'Secretaria'},
    {'tipo': 'email', 'valor': 'geral@leoesdeportosalvo.pt'},
    {'tipo': 'email', 'valor': 'socios@leoesdeportosalvo.pt', 'etiqueta': 'Sócios'},
  ],
  'horario': ['Dias úteis · 18:00 às 21:00', 'Sábados · 10:00 às 13:00'],
  'modalidades': [
    {'nome': 'Hóquei em patins', 'escaloes': 'Formação e seniores'},
    {'slug': 'futsal', 'nome': 'Futsal', 'escaloes': 'Formação', 'tem_pagina': true},
    {'nome': 'Patinagem artística', 'escaloes': 'Todos os escalões'},
    {'nome': 'Ginástica', 'escaloes': 'Formação'},
  ],
  'redes': {
    'facebook': 'https://facebook.com/leoesdeportosalvo',
    'instagram': 'https://instagram.com/leoesdeportosalvo',
    'youtube': 'https://youtube.com/@leoesdeportosalvo',
  },
});

/// O corpo da página de uma modalidade no modo de demonstração.
const corpoModalidadeExemplo = <Map<String, dynamic>>[
  {
    'tipo': 'texto',
    'html': '<p>O futsal dos Leões treina no pavilhão do clube, dos <strong>5 anos</strong> aos seniores.</p>',
  },
  {
    'tipo': 'tabela',
    'titulo': 'Horário de treinos',
    'cabecalho': true,
    'linhas': [
      ['Escalão', 'Nascidos em', 'Dias', 'Hora'],
      ['Petizes', '2020–2021', 'Ter e Qui', '18:00'],
      ['Traquinas', '2018–2019', 'Seg e Qua', '18:30'],
      ['Benjamins', '2016–2017', 'Seg, Qua e Sex', '19:15'],
      ['Infantis', '2014–2015', 'Ter e Qui', '19:30'],
    ],
  },
  {
    'tipo': 'tabela',
    'cabecalho': false,
    'estilo': 'claro',
    'linhas': [
      ['Coordenador', 'João Silva'],
      ['Inscrições', 'Na secretaria, de segunda a sexta'],
    ],
  },
  {
    'tipo': 'mapa',
    'local': 'Pavilhão dos Leões de Porto Salvo',
    'legenda': 'Onde treinamos',
    'url': 'https://www.google.com/maps/search/?api=1&query=Le%C3%B5es%20de%20Porto%20Salvo',
  },
];
