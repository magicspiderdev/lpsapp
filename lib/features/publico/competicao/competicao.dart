import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/config.dart';
import '../../../core/rede/ligacao.dart';
import '../agenda/agenda.dart';

/// Competição: a época em que o clube está, as provas dela e os jogos.
///
/// `GET /api/v2/publico/competicao/provas`, `/provas/{slug}` e `/jogos`
/// (guia §4.19, esquema `Prova` do `openapi-v2.yaml`). Tudo sem login.
///
/// Duas regras que vêm do contrato e que se notam no ecrã:
///
/// - **Só jogos do clube.** Uma importação traz a liga inteira; as contagens
///   de [Prova] batem certo com as listas, de propósito.
/// - **A época actual deduz-se no servidor** (a mais recente com provas) e vem
///   na resposta: é essa que o selector abre, nunca o relógio do telemóvel.
class Prova {
  final String slug, nome, epoca;

  /// `liga`, `taca`, `torneio`, `amigavel` — lista aberta.
  final String formato;

  /// `masculino`, `feminino`, `misto` — lista aberta, e pode não vir.
  final String? genero;

  /// A página oficial da prova, quando existe.
  final String? urlExterno;
  final String? modalidade, modalidadeSlug;

  /// Contagens **só de jogos do clube**.
  final int total, realizados, proximos;

  const Prova({
    required this.slug,
    required this.nome,
    required this.epoca,
    this.formato = 'liga',
    this.genero,
    this.urlExterno,
    this.modalidade,
    this.modalidadeSlug,
    this.total = 0,
    this.realizados = 0,
    this.proximos = 0,
  });

  factory Prova.fromJson(Map<String, dynamic> j) {
    final modalidade = (j['modalidade'] as Map?)?.cast<String, dynamic>();
    final jogos = (j['jogos'] as Map?)?.cast<String, dynamic>();
    return Prova(
      slug: (j['slug'] ?? '') as String,
      nome: (j['nome'] ?? '') as String,
      epoca: (j['epoca'] ?? '') as String,
      formato: ((j['formato'] ?? 'liga') as String).toLowerCase(),
      genero: (j['genero'] as String?)?.toLowerCase(),
      urlExterno: j['url_externo'] as String?,
      modalidade: modalidade?['nome'] as String?,
      modalidadeSlug: modalidade?['slug'] as String?,
      total: (jogos?['total'] as num?)?.toInt() ?? 0,
      realizados: (jogos?['realizados'] as num?)?.toInt() ?? 0,
      proximos: (jogos?['proximos'] as num?)?.toInt() ?? 0,
    );
  }

  /// "Liga · Futsal · feminino", sem as partes que não vieram.
  String get legenda => [
    switch (formato) {
      'liga' => 'Liga',
      'taca' => 'Taça',
      'torneio' => 'Torneio',
      'amigavel' => 'Amigável',
      _ => null,
    },
    modalidade,
    genero,
  ].whereType<String>().join(' · ');
}

/// A resposta de `/competicao/provas`: onde estamos, e o que há.
class Provas {
  /// A época em que o clube está, deduzida pelo servidor.
  final String epocaActual;

  /// A época a que estas provas pertencem (a pedida, ou a actual).
  final String epoca;

  /// Todas as que existem, da mais recente para a mais antiga.
  final List<String> epocas;
  final List<Prova> provas;

  const Provas({required this.epocaActual, required this.epoca, this.epocas = const [], this.provas = const []});

  factory Provas.fromJson(Map<String, dynamic> j) => Provas(
    epocaActual: (j['epoca_actual'] ?? '') as String,
    epoca: (j['epoca'] ?? j['epoca_actual'] ?? '') as String,
    epocas: [
      for (final e in (j['epocas'] as List?) ?? const [])
        if (e is String) e,
    ],
    provas: [
      for (final p in (j['provas'] as List?) ?? const [])
        if (p is Map) Prova.fromJson(p.cast<String, dynamic>()),
    ],
  );
}

/// A página de uma prova, numa só chamada.
class ProvaDetalhe {
  final Prova prova;

  /// Já jogados, do mais recente para trás. **Pela data, não por ter
  /// resultado**: um jogo de ontem que ninguém registou está aqui, com
  /// `resultado: null`, e é isso que se mostra.
  final List<ItemAgenda> realizados;

  /// Os que vêm aí, do mais próximo para a frente.
  final List<ItemAgenda> proximos;

  const ProvaDetalhe({required this.prova, this.realizados = const [], this.proximos = const []});

  factory ProvaDetalhe.fromJson(Map<String, dynamic> j) => ProvaDetalhe(
    prova: Prova.fromJson(((j['prova'] as Map?) ?? const {}).cast<String, dynamic>()),
    realizados: lerJogos(j['realizados']),
    proximos: lerJogos(j['proximos']),
  );
}

/// As provas de uma época; `null` = a actual, que o servidor deduz.
final provasProvider = StreamProvider.autoDispose.family<Dados<Provas>, String?>((ref, epoca) {
  if (modoDemonstracao) return Stream.value(Dados(provasExemplo(epoca), DateTime.now()));
  ref.watch(ligacaoProvider); // quando a ligação volta, actualiza
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'competicao.provas.${epoca ?? 'actual'}',
    pedido: () => dadosDe(dio.get('/competicao/provas', queryParameters: {'epoca': ?epoca})),
    ler: Provas.fromJson,
  );
});

/// Uma prova com os jogos do clube, já jogados e por jogar.
final provaProvider = StreamProvider.autoDispose.family<Dados<ProvaDetalhe>, String>((ref, slug) {
  if (modoDemonstracao) return Stream.value(Dados(provaExemplo(slug), DateTime.now()));
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'competicao.prova.$slug',
    pedido: () => dadosDe(dio.get('/competicao/provas/$slug')),
    ler: ProvaDetalhe.fromJson,
  );
});

/// Uma linha da ficha de um jogo (guia §4.19, esquema `FichaLinha`).
///
/// Todas as linhas têm a mesma forma: o que aconteceu, ao minuto quantos, de
/// que lado — e lêem-se assim, do apito inicial ao final.
class LinhaFicha {
  /// `golo`, `autogolo`, `penalti`, `penalti_falhado`, `amarelo`, `vermelho`,
  /// `substituicao`, `inicio`, `intervalo`, `fim`, `relato` — **lista aberta**:
  /// aparecem tipos novos sem aviso, e o que não se conhece ignora-se.
  final String tipo;

  /// Nulo nas linhas sem minuto — notas escritas depois. Vêm no fim.
  final int? minuto;

  /// `casa` ou `fora`; nulo no que não é de nenhuma equipa (apito, relato).
  final String? equipa;

  /// Quem marcou, viu o cartão, ou **entrou** na substituição.
  final String? atleta;

  /// Quem assistiu o golo, quem saiu na substituição, e a linha de relato.
  final String? assistencia, atletaSaiu, texto;

  /// Como ia o jogo **depois** desta linha, já calculado no servidor: a regra
  /// do autogolo (conta para a outra equipa) tem de ser a mesma em todo o lado.
  final int marcadorCasa, marcadorFora;

  const LinhaFicha({
    required this.tipo,
    this.minuto,
    this.equipa,
    this.atleta,
    this.assistencia,
    this.atletaSaiu,
    this.texto,
    this.marcadorCasa = 0,
    this.marcadorFora = 0,
  });

  factory LinhaFicha.fromJson(Map<String, dynamic> j) {
    final marcador = (j['marcador'] as Map?)?.cast<String, dynamic>();
    return LinhaFicha(
      tipo: (j['tipo'] ?? '') as String,
      minuto: (j['minuto'] as num?)?.toInt(),
      equipa: j['equipa'] as String?,
      atleta: j['atleta'] as String?,
      assistencia: j['assistencia'] as String?,
      atletaSaiu: j['atleta_saiu'] as String?,
      texto: j['texto'] as String?,
      marcadorCasa: (marcador?['casa'] as num?)?.toInt() ?? 0,
      marcadorFora: (marcador?['fora'] as num?)?.toInt() ?? 0,
    );
  }

  bool get daCasa => equipa == 'casa';
  bool get daFora => equipa == 'fora';

  /// Mudou o marcador nesta linha? É o que justifica mostrá-lo ao lado.
  bool get alteraMarcador => tipo == 'golo' || tipo == 'autogolo' || tipo == 'penalti';
}

/// Um jogo com a sua ficha: `GET /competicao/jogos/{id}`.
///
/// **A ficha não é o resultado.** O marcador oficial é `jogo.resultado`; a
/// ficha pode estar a meio de ser escrita e dar outra coisa.
class JogoComFicha {
  final ItemAgenda jogo;

  /// Vazia é o caso normal enquanto ninguém a escreveu — não é erro.
  final List<LinhaFicha> ficha;

  const JogoComFicha({required this.jogo, this.ficha = const []});

  factory JogoComFicha.fromJson(Map<String, dynamic> j) => JogoComFicha(
    jogo: ItemAgenda.fromJson(((j['jogo'] as Map?) ?? const {}).cast<String, dynamic>()),
    ficha: [
      for (final l in (j['ficha'] as List?) ?? const [])
        if (l is Map) LinhaFicha.fromJson(l.cast<String, dynamic>()),
    ],
  );
}

/// Um jogo e a ficha dele, com cache: a ficha de ontem abre sem rede.
final jogoProvider = StreamProvider.autoDispose.family<Dados<JogoComFicha>, String>((ref, id) {
  if (modoDemonstracao) return Stream.value(Dados(jogoExemplo(id), DateTime.now()));
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'competicao.jogo.$id',
    pedido: () => dadosDe(dio.get('/competicao/jogos/$id')),
    ler: JogoComFicha.fromJson,
  );
});

// ── Exemplos só para ver o desenho (modo de demonstração) ───────────────────

const _epocaExemplo = '2026-27';

Provas provasExemplo(String? epoca) {
  final e = epoca ?? _epocaExemplo;
  return Provas.fromJson({
    'epoca_actual': _epocaExemplo,
    'epoca': e,
    'epocas': const [_epocaExemplo, '2025-26', '2024-25'],
    'provas': e == _epocaExemplo
        ? const [
            {
              'slug': 'campeonato-nacional-hoquei-2026-27',
              'nome': 'Campeonato Nacional',
              'epoca': _epocaExemplo,
              'formato': 'liga',
              'genero': 'masculino',
              'modalidade': {'slug': 'hoquei-patins', 'nome': 'Hóquei em patins'},
              'jogos': {'total': 22, 'realizados': 9, 'proximos': 13},
            },
            {
              'slug': 'distrital-juvenis-futsal-2026-27',
              'nome': 'Distrital de juvenis',
              'epoca': _epocaExemplo,
              'formato': 'liga',
              'modalidade': {'slug': 'futsal', 'nome': 'Futsal'},
              'jogos': {'total': 18, 'realizados': 4, 'proximos': 14},
            },
            {
              'slug': 'taca-de-portugal-hoquei-2026-27',
              'nome': 'Taça de Portugal',
              'epoca': _epocaExemplo,
              'formato': 'taca',
              'modalidade': {'slug': 'hoquei-patins', 'nome': 'Hóquei em patins'},
              'jogos': {'total': 3, 'realizados': 2, 'proximos': 1},
            },
          ]
        : const [
            {
              'slug': 'campeonato-nacional-hoquei-2025-26',
              'nome': 'Campeonato Nacional',
              'epoca': '2025-26',
              'formato': 'liga',
              'modalidade': {'slug': 'hoquei-patins', 'nome': 'Hóquei em patins'},
              'jogos': {'total': 22, 'realizados': 22, 'proximos': 0},
            },
          ],
  });
}

ProvaDetalhe provaExemplo(String slug) {
  final provas = provasExemplo(null).provas;
  final prova = provas.firstWhere((p) => p.slug == slug, orElse: () => provas.first);
  final jogos = agendaExemplo.where((j) => j.tipo == TipoItem.jogo).toList();
  return ProvaDetalhe(
    prova: prova,
    realizados: jogos.where((j) => j.inicio.isBefore(DateTime.now())).toList(),
    proximos: jogos.where((j) => !j.inicio.isBefore(DateTime.now())).toList(),
  );
}

/// Um jogo da agenda de exemplo, com ficha quando já se jogou.
JogoComFicha jogoExemplo(String id) {
  final jogos = agendaExemplo.where((j) => j.tipo == TipoItem.jogo).toList();
  final jogo = jogos.firstWhere((j) => j.id == id, orElse: () => jogos.first);
  return JogoComFicha(jogo: jogo, ficha: jogo.temResultado ? _fichaExemplo : const []);
}

/// Uma ficha cheia: golos dos dois lados, um autogolo (que conta para a outra
/// equipa), cartões, substituição, relato, e uma nota sem minuto no fim.
final _fichaExemplo = [
  for (final l in const <Map<String, dynamic>>[
    {
      'tipo': 'inicio',
      'minuto': 0,
      'marcador': {'casa': 0, 'fora': 0},
    },
    {
      'tipo': 'golo',
      'minuto': 7,
      'equipa': 'fora',
      'atleta': 'Tiago Marques',
      'assistencia': 'Miguel Faria',
      'marcador': {'casa': 0, 'fora': 1},
    },
    {
      'tipo': 'amarelo',
      'minuto': 14,
      'equipa': 'casa',
      'atleta': 'Rui Pinto',
      'marcador': {'casa': 0, 'fora': 1},
    },
    {
      'tipo': 'golo',
      'minuto': 19,
      'equipa': 'casa',
      'atleta': 'Diogo Nunes',
      'marcador': {'casa': 1, 'fora': 1},
    },
    {
      'tipo': 'intervalo',
      'minuto': 25,
      'marcador': {'casa': 1, 'fora': 1},
    },
    {
      'tipo': 'substituicao',
      'minuto': 28,
      'equipa': 'fora',
      'atleta': 'André Lopes',
      'atleta_saiu': 'Miguel Faria',
      'marcador': {'casa': 1, 'fora': 1},
    },
    {
      'tipo': 'penalti',
      'minuto': 33,
      'equipa': 'fora',
      'atleta': 'Tiago Marques',
      'marcador': {'casa': 1, 'fora': 2},
    },
    {
      'tipo': 'relato',
      'minuto': 36,
      'texto': 'Dez minutos de cerco à baliza dos Leões, com duas defesas grandes do guarda-redes.',
      'marcador': {'casa': 1, 'fora': 2},
    },
    {
      'tipo': 'autogolo',
      'minuto': 41,
      'equipa': 'fora',
      'atleta': 'André Lopes',
      'marcador': {'casa': 2, 'fora': 2},
    },
    {
      'tipo': 'vermelho',
      'minuto': 44,
      'equipa': 'casa',
      'atleta': 'Rui Pinto',
      'marcador': {'casa': 2, 'fora': 2},
    },
    {
      'tipo': 'golo',
      'minuto': 49,
      'equipa': 'fora',
      'atleta': 'André Lopes',
      'marcador': {'casa': 2, 'fora': 3},
    },
    {
      'tipo': 'fim',
      'minuto': 50,
      'marcador': {'casa': 2, 'fora': 3},
    },
    {
      'tipo': 'relato',
      'texto': 'Jogo decidido nos últimos dez minutos, com menos um jogador de cada lado.',
      'marcador': {'casa': 2, 'fora': 3},
    },
  ])
    LinhaFicha.fromJson(l),
];
