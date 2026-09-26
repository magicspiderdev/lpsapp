import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/config.dart';
import '../../../core/formatos.dart';
import '../../../core/rede/ligacao.dart';

/// Agenda do clube: jogos e eventos, por ordem de data.
///
/// `GET /api/v2/publico/agenda` (guia §4.17, esquemas `AgendaJogo` e
/// `AgendaEvento` do `openapi-v2.yaml`). Só jogos em que joga uma equipa do
/// clube — uma importação traz a liga inteira, mas agenda do Leões são os
/// jogos com o clube de um dos lados.
///
/// O mesmo modelo serve a competição (§4.19): os jogos de `/competicao/…` vêm
/// nesta forma, campo por campo, de propósito.
enum TipoItem { jogo, evento, desconhecido }

class Equipa {
  final String nome;
  final String? emblemaUrl;

  /// `true` = equipa do clube (para destacar). Nunca comparar nomes: o clube
  /// aparece escrito de várias maneiras no histórico importado.
  final bool doClube;

  const Equipa({required this.nome, this.emblemaUrl, this.doClube = false});

  factory Equipa.fromJson(Map<String, dynamic> j) => Equipa(
    nome: (j['nome'] ?? '') as String,
    emblemaUrl: j['emblema_url'] as String?,
    doClube: j['do_clube'] == true,
  );
}

class ItemAgenda {
  final TipoItem tipo;
  final String id, titulo;

  /// Slug do evento (os jogos não têm).
  final String? slug;

  /// Início real. `dataConfirmada`/`horaConfirmada` a `false` = ainda por marcar
  /// (o legado tem jogos com dia por confirmar).
  final DateTime inicio;

  /// Fim, quando o evento o declara.
  final DateTime? fim;
  final bool dataConfirmada, horaConfirmada;

  /// Nome da modalidade e da prova, para mostrar; os slugs são para filtrar e
  /// para abrir a página da prova.
  final String? modalidade, modalidadeSlug, prova, provaSlug;

  /// Jornada da prova, quando a prova as numera.
  final int? jornada;
  final String? local, resumo, descricao, capaUrl;
  final Equipa? casa, fora;
  final int? golosCasa, golosFora;

  /// Quem apitou e quanta gente lá esteve — só depois de alguém os registar.
  final String? arbitro;
  final int? espectadores;

  /// Há ficha escrita para este jogo. Vem nas listagens de propósito, para se
  /// saber onde há o que abrir sem pedir jogo a jogo (guia §4.19).
  final bool temFicha;

  /// `agendado`, `a_decorrer`, `terminado`, `adiado`, `cancelado` — lista aberta.
  final String estado;

  /// Id da sessão de bilhética, quando há bilhetes para este jogo ou evento.
  final String? sessaoBilhetes;

  const ItemAgenda({
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.inicio,
    required this.estado,
    this.slug,
    this.fim,
    this.dataConfirmada = true,
    this.horaConfirmada = true,
    this.modalidade,
    this.modalidadeSlug,
    this.prova,
    this.provaSlug,
    this.jornada,
    this.local,
    this.resumo,
    this.descricao,
    this.capaUrl,
    this.casa,
    this.fora,
    this.golosCasa,
    this.golosFora,
    this.arbitro,
    this.espectadores,
    this.temFicha = false,
    this.sessaoBilhetes,
  });

  factory ItemAgenda.fromJson(Map<String, dynamic> j) {
    final prova = (j['prova'] as Map?)?.cast<String, dynamic>();
    final modalidade = (j['modalidade'] as Map?)?.cast<String, dynamic>();
    return ItemAgenda(
      tipo: switch (j['tipo']) {
        'jogo' => TipoItem.jogo,
        'evento' => TipoItem.evento,
        _ => TipoItem.desconhecido,
      },
      id: j['id'].toString(),
      slug: j['slug'] as String?,
      titulo: (j['titulo'] ?? '') as String,
      inicio: dataApi(j['inicio']) ?? DateTime.now(),
      fim: dataApi(j['fim']),
      estado: (j['estado'] ?? 'agendado') as String,
      dataConfirmada: j['data_confirmada'] != false,
      horaConfirmada: j['hora_confirmada'] != false,
      modalidade: modalidade?['nome'] as String?,
      modalidadeSlug: modalidade?['slug'] as String?,
      prova: prova?['nome'] as String?,
      provaSlug: prova?['slug'] as String?,
      jornada: (prova?['jornada'] as num?)?.toInt(),
      local: j['local'] as String? ?? j['recinto'] as String?,
      resumo: j['resumo'] as String?,
      descricao: j['descricao'] as String?,
      capaUrl: (j['capa'] as Map?)?['url'] as String?,
      casa: j['equipa_casa'] is Map ? Equipa.fromJson((j['equipa_casa'] as Map).cast<String, dynamic>()) : null,
      fora: j['equipa_fora'] is Map ? Equipa.fromJson((j['equipa_fora'] as Map).cast<String, dynamic>()) : null,
      golosCasa: (j['resultado'] as Map?)?['casa'] as int?,
      golosFora: (j['resultado'] as Map?)?['fora'] as int?,
      arbitro: j['arbitro'] as String?,
      espectadores: (j['espectadores'] as num?)?.toInt(),
      temFicha: j['tem_ficha'] == true,
      sessaoBilhetes: (j['bilhetes'] as Map?)?['sessao']?.toString(),
    );
  }

  bool get terminado => estado == 'terminado';
  bool get cancelado => estado == 'cancelado' || estado == 'adiado';
  bool get temBilhetes => sessaoBilhetes != null;
  bool get temResultado => golosCasa != null && golosFora != null;

  /// "Campeonato Nacional · 3.ª jornada", ou só o nome quando não há jornada.
  String? get provaComJornada => switch ((prova, jornada)) {
    (final String p, final int n) => '$p · $n.ª jornada',
    (final String p, _) => p,
    _ => null,
  };
}

/// Os itens de uma resposta da agenda (`data.itens`).
List<ItemAgenda> itensDaAgenda(Map<String, dynamic> d) => lerJogos(d['itens']);

/// Uma lista de jogos da competição — a mesma forma da agenda, de propósito.
List<ItemAgenda> lerJogos(Object? lista) => [
  for (final j in (lista as List?) ?? const [])
    if (j is Map) ItemAgenda.fromJson(j.cast<String, dynamic>()),
];

/// Quanto da agenda se pede. Sem parâmetros a API daria de hoje a 30 dias; os
/// dias para trás existem porque o resultado do fim-de-semana passado é a
/// primeira coisa que se vem cá ver à segunda-feira.
///
/// À frente vai-se a uma época inteira, e não a dois meses: o que o clube
/// marca com muita antecedência — o jantar de Natal, a assembleia, um torneio —
/// é publicado no backoffice e tem de aparecer no dia em que é publicado, não
/// dois meses antes de acontecer. O intervalo cabe no máximo da API (400 dias,
/// contando com os que se pedem para trás) e a agenda do clube tem umas dezenas
/// de itens por época, longe do `limite` de 100.
const _diasAtras = 7;
const _diasAFrente = 365;

String _dia(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Jogos e eventos, com cache: abre sem rede com a última agenda guardada.
final agendaProvider = StreamProvider.autoDispose<Dados<List<ItemAgenda>>>((ref) {
  if (modoDemonstracao) return Stream.value(Dados(agendaExemplo, DateTime.now()));
  ref.watch(ligacaoProvider); // quando a ligação volta, actualiza
  final dio = ref.read(dioPublicoProvider);
  final hoje = DateTime.now();
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'agenda',
    pedido: () => dadosDe(
      dio.get(
        '/agenda',
        queryParameters: {
          'de': _dia(hoje.subtract(const Duration(days: _diasAtras))),
          'ate': _dia(hoje.add(const Duration(days: _diasAFrente))),
          'limite': 100,
        },
      ),
    ),
    ler: itensDaAgenda,
  );
});

/// A ficha de um evento, `GET /agenda/eventos/{slug}` (guia público §4, desde
/// 2026-09-26): o mesmo objecto da agenda, mas **sem janela de datas** — é o
/// que abre um link partilhado meses depois. Só pelo `slug`. Um rascunho ou
/// arquivado é `404`; um cancelado abre-se, com `estado: cancelado`.
final eventoProvider = StreamProvider.autoDispose.family<Dados<ItemAgenda>, String>((ref, slug) {
  if (modoDemonstracao) {
    final e = agendaExemplo.where((i) => i.slug == slug).firstOrNull;
    return e == null
        ? Stream.error(const ApiException(erro: 'nao_encontrado', message: 'Evento não encontrado.', httpStatus: 404))
        : Stream.value(Dados(e, DateTime.now()));
  }
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'evento.$slug',
    pedido: () => dadosDe(dio.get('/agenda/eventos/${Uri.encodeComponent(slug)}')),
    ler: (d) => ItemAgenda.fromJson((d['evento'] as Map).cast<String, dynamic>()),
  );
});

// ── O passado, aos poucos ───────────────────────────────────────────────────

/// Quanto se recua de cada vez no separador dos anteriores.
const _passoAtras = 60;

/// Até onde se recua. Mais do que isto é arqueologia: o histórico inteiro não
/// interessa a quem desce com o polegar, e a agenda não é paginada — recua-se
/// por janelas de datas, uma por cada vez que se chega ao fim da lista.
const _recuoMaximo = 730;

/// Duas janelas seguidas sem nada é o sinal de que o histórico acabou. Uma só
/// não chega: entre duas épocas há meses sem jogos nem eventos.
const _vaziosParaDesistir = 2;

/// Jogos e eventos mais antigos do que a janela inicial, carregados a pedido.
class MaisAnteriores {
  final List<ItemAgenda> itens;

  /// O dia mais antigo já pedido; a próxima janela acaba na véspera dele.
  final DateTime desde;
  final bool aCarregar;

  /// Não há mais nada para trás (ou já se recuou o que valia a pena).
  final bool fim;
  final int vaziosSeguidos;

  const MaisAnteriores({
    required this.desde,
    this.itens = const [],
    this.aCarregar = false,
    this.fim = false,
    this.vaziosSeguidos = 0,
  });
}

final maisAnterioresProvider = NotifierProvider.autoDispose<MaisAnterioresController, MaisAnteriores>(
  MaisAnterioresController.new,
);

class MaisAnterioresController extends AutoDisposeNotifier<MaisAnteriores> {
  @override
  MaisAnteriores build() {
    // Quando a agenda base se renova, o que já se tinha recuado deixa de servir.
    ref.watch(agendaProvider.select((d) => d.valueOrNull?.obtidoEm));
    final inicio = DateTime.now().subtract(const Duration(days: _diasAtras));
    return MaisAnteriores(desde: DateUtils.dateOnly(inicio), fim: modoDemonstracao);
  }

  Future<void> carregar() async {
    final antes = state;
    if (antes.aCarregar || antes.fim || !ref.read(ligacaoProvider)) return;

    final ate = antes.desde.subtract(const Duration(days: 1));
    final de = ate.subtract(const Duration(days: _passoAtras - 1));
    state = MaisAnteriores(
      itens: antes.itens,
      desde: antes.desde,
      aCarregar: true,
      vaziosSeguidos: antes.vaziosSeguidos,
    );

    try {
      final dados = await dadosDe(
        ref.read(dioPublicoProvider).get('/agenda', queryParameters: {'de': _dia(de), 'ate': _dia(ate), 'limite': 100}),
      );
      final novos = itensDaAgenda(dados);
      final vazios = novos.isEmpty ? antes.vaziosSeguidos + 1 : 0;
      final chegouAoLimite = DateTime.now().difference(de).inDays >= _recuoMaximo;
      state = MaisAnteriores(
        itens: [...antes.itens, ...novos],
        desde: de,
        fim: chegouAoLimite || vazios >= _vaziosParaDesistir,
        vaziosSeguidos: vazios,
      );
    } on ApiException {
      state = antes; // sem rede ou serviço em baixo: fica o que já está
    }
  }
}

/// Exemplos só para ver o desenho (modo de demonstração).
final agendaExemplo = [for (final j in _exemplos) ItemAgenda.fromJson(j)];

DateTime _daqui(int dias, int hora, [int minuto = 0]) {
  final d = DateTime.now().add(Duration(days: dias));
  return DateTime(d.year, d.month, d.day, hora, minuto);
}

final _exemplos = <Map<String, dynamic>>[
  {
    'tipo': 'jogo',
    'id': 1,
    'titulo': 'Leões Porto Salvo x Sporting CP',
    'inicio': _daqui(1, 21).toIso8601String(),
    'estado': 'agendado',
    'modalidade': {'slug': 'hoquei-patins', 'nome': 'Hóquei em patins'},
    'prova': {'slug': 'campeonato-nacional-hoquei-2026-27', 'nome': 'Campeonato Nacional', 'jornada': 4},
    'recinto': 'Pavilhão Municipal de Porto Salvo',
    'equipa_casa': {'nome': 'Leões Porto Salvo', 'do_clube': true},
    'equipa_fora': {'nome': 'Sporting CP'},
    'bilhetes': {'sessao': 'S1'},
  },
  {
    'tipo': 'evento',
    'id': 2,
    'slug': 'jantar-de-natal-do-clube',
    'titulo': 'Jantar de Natal do clube',
    'inicio': _daqui(3, 20).toIso8601String(),
    'fim': _daqui(3, 23, 30).toIso8601String(),
    'estado': 'agendado',
    'local': 'Sede do clube',
    'resumo': 'Jantar aberto a sócios e famílias, com entrega de prémios às equipas.',
    'descricao':
        'O jantar de Natal do clube é a noite em que as equipas todas se sentam '
        'à mesma mesa: seniores, formação, patinagem e os que já penduraram os '
        'patins mas continuam cá.\n\n'
        'A entrega dos prémios da época passada é depois da sobremesa. As '
        'inscrições fecham três dias antes, para a cozinha saber com quantos '
        'conta.',
    'bilhetes': {'sessao': 'S2'},
  },
  {
    'tipo': 'jogo',
    'id': 3,
    'titulo': 'Juvenis: Leões Porto Salvo x Oeiras',
    'inicio': _daqui(5, 10, 30).toIso8601String(),
    'estado': 'agendado',
    'hora_confirmada': false,
    'modalidade': {'slug': 'futsal', 'nome': 'Futsal'},
    'prova': {'slug': 'distrital-juvenis-futsal-2026-27', 'nome': 'Distrital de juvenis', 'jornada': 2},
    'recinto': 'Pavilhão Municipal de Porto Salvo',
    'equipa_casa': {'nome': 'Leões Porto Salvo', 'do_clube': true},
    'equipa_fora': {'nome': 'CD Oeiras'},
  },
  {
    'tipo': 'jogo',
    'id': 4,
    'titulo': 'Benfica x Leões Porto Salvo',
    'inicio': _daqui(-2, 19).toIso8601String(),
    'estado': 'terminado',
    'modalidade': {'slug': 'hoquei-patins', 'nome': 'Hóquei em patins'},
    'prova': {'slug': 'campeonato-nacional-hoquei-2026-27', 'nome': 'Campeonato Nacional', 'jornada': 3},
    'recinto': 'Pavilhão da Luz',
    'equipa_casa': {'nome': 'SL Benfica'},
    'equipa_fora': {'nome': 'Leões Porto Salvo', 'do_clube': true},
    'resultado': {'casa': 2, 'fora': 3},
    'arbitro': 'António Silva',
    'espectadores': 340,
    'tem_ficha': true,
  },
  {
    'tipo': 'evento',
    'id': 6,
    'slug': 'assembleia-geral-de-socios',
    'titulo': 'Assembleia Geral de sócios',
    'inicio': _daqui(8, 21).toIso8601String(),
    'estado': 'agendado',
    'local': 'Sede do clube',
    'resumo': 'Apresentação e votação das contas da época.',
    'descricao':
        'Ordem de trabalhos: relatório e contas da época, orçamento para a '
        'seguinte, e obras do pavilhão.\n\n'
        'A assembleia abre à hora marcada com metade dos sócios; meia hora '
        'depois, com os que estiverem na sala.',
  },
  {
    'tipo': 'jogo',
    'id': 7,
    'titulo': 'Patinagem: Torneio de Oeiras',
    'inicio': _daqui(2, 9, 30).toIso8601String(),
    'estado': 'agendado',
    'modalidade': {'slug': 'patinagem', 'nome': 'Patinagem artística'},
    'prova': {'slug': 'torneio-regional-patinagem-2026-27', 'nome': 'Torneio regional'},
    'recinto': 'Pavilhão de Oeiras',
    'equipa_casa': {'nome': 'Leões Porto Salvo', 'do_clube': true},
    'equipa_fora': {'nome': 'Vários clubes'},
  },
  {
    'tipo': 'evento',
    'id': 5,
    'slug': 'torneio-de-verao',
    'titulo': 'Torneio de Verão · inscrições abertas',
    'inicio': _daqui(12, 9).toIso8601String(),
    'estado': 'agendado',
    'local': 'Complexo desportivo',
    'resumo': 'Três dias de torneio para todos os escalões de formação.',
  },
];
