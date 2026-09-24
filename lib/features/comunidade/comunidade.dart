import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/clientes.dart';
import '../../core/api/envelope.dart';
import '../../core/auth/sessao.dart';
import '../../core/cache/cache_local.dart';
import '../../core/cache/com_cache.dart';
import '../../core/rede/ligacao.dart';
import '../publico/agenda/agenda.dart';
import '../publico/bilheteira/bilheteira.dart' show SemSessao;

/// Comunidade Leões (guia §4.23): relatar resultados, adivinhar o resultado e
/// passatempos. Para qualquer conta v2 com sessão, sócia ou não.
///
/// Tudo o que se envia é estruturado — dois números, uma opção, uma inscrição.
/// **Não há mensagens livres** nesta etapa (ADR-13: primeiro é preciso quem
/// modere), por isso não há caixas de comentário à volta destes ecrãs. O único
/// texto que outros adeptos vêem é a alcunha da classificação.
///
/// Que botão mostrar decide-se por `aberto` e `motivo`, que vêm do servidor:
/// a app nunca calcula prazos a partir das datas.

/// Um resultado: o que alguém relatou, uma proposta, um palpite.
class Marcador {
  final int casa, fora;

  const Marcador(this.casa, this.fora);

  static Marcador? deJson(Object? j) => j is Map && j['casa'] is int && j['fora'] is int
      ? Marcador(j['casa'] as int, j['fora'] as int)
      : null;

  Map<String, dynamic> toJson() => {'casa': casa, 'fora': fora};

  @override
  String toString() => '$casa–$fora';

  @override
  bool operator ==(Object other) => other is Marcador && other.casa == casa && other.fora == fora;

  @override
  int get hashCode => Object.hash(casa, fora);
}

/// "2 pessoas dizem 3–1."
class Proposta {
  final Marcador marcador;
  final int relatos;

  const Proposta(this.marcador, this.relatos);
}

/// O bloco `relatos`: dizer como acabou, ao estilo do Waze.
class Relatos {
  final bool aberto;

  /// Porque não se pode relatar: `por_comecar`, `com_resultado`, `fechado`,
  /// `sem_jogo`. Lista aberta.
  final String? motivo;

  /// Pessoas diferentes que têm de dizer o mesmo para o resultado valer.
  final int necessarios;

  /// Até 3, a mais relatada primeiro.
  final List<Proposta> propostas;

  final Marcador? meu;

  /// O clube anulou o relato desta conta: já não pode relatar este jogo.
  final bool meuAnulado;

  /// A comunidade deu o resultado a este jogo.
  final Marcador? confirmado;

  const Relatos({
    required this.aberto,
    this.motivo,
    this.necessarios = 3,
    this.propostas = const [],
    this.meu,
    this.meuAnulado = false,
    this.confirmado,
  });

  factory Relatos.fromJson(Map<String, dynamic> j) => Relatos(
    aberto: j['aberto'] == true,
    motivo: j['motivo'] as String?,
    necessarios: (j['necessarios'] as num?)?.toInt() ?? 3,
    propostas: [
      for (final p in (j['propostas'] as List?) ?? const [])
        if (Marcador.deJson(p) case final m?) Proposta(m, ((p as Map)['relatos'] as num?)?.toInt() ?? 1),
    ],
    meu: Marcador.deJson(j['meu']),
    meuAnulado: (j['meu'] as Map?)?['anulado'] == true,
    confirmado: Marcador.deJson(j['confirmado']),
  );
}

/// O bloco `palpites`: "Adivinha o resultado".
class Palpites {
  final bool aberto;
  final int total;

  /// Agregada: não diz quem apostou em quê, pode mostrar-se à vontade.
  final int vitoriaCasa, empate, vitoriaFora;

  final Marcador? meu;

  /// `null` até o jogo estar terminado.
  final int? meusPontos;

  const Palpites({
    required this.aberto,
    this.total = 0,
    this.vitoriaCasa = 0,
    this.empate = 0,
    this.vitoriaFora = 0,
    this.meu,
    this.meusPontos,
  });

  factory Palpites.fromJson(Map<String, dynamic> j) {
    final d = (j['distribuicao'] as Map?) ?? const {};
    return Palpites(
      aberto: j['aberto'] == true,
      total: (j['total'] as num?)?.toInt() ?? 0,
      vitoriaCasa: (d['vitoria_casa'] as num?)?.toInt() ?? 0,
      empate: (d['empate'] as num?)?.toInt() ?? 0,
      vitoriaFora: (d['vitoria_fora'] as num?)?.toInt() ?? 0,
      meu: Marcador.deJson(j['meu']),
      meusPontos: ((j['meu'] as Map?)?['pontos'] as num?)?.toInt(),
    );
  }
}

/// Um jogo com o bloco da comunidade. A lista, a ficha e a resposta a relatar
/// ou palpitar têm esta forma: depois de uma escrita, substitui-se tudo.
class JogoComunidade {
  final ItemAgenda jogo;
  final Relatos relatos;
  final Palpites palpites;

  const JogoComunidade({required this.jogo, required this.relatos, required this.palpites});

  factory JogoComunidade.fromJson(Map<String, dynamic> j) => JogoComunidade(
    jogo: ItemAgenda.fromJson(((j['jogo'] as Map?) ?? const {}).cast<String, dynamic>()),
    relatos: Relatos.fromJson(((j['relatos'] as Map?) ?? const {}).cast<String, dynamic>()),
    palpites: Palpites.fromJson(((j['palpites'] as Map?) ?? const {}).cast<String, dynamic>()),
  );
}

/// Uma linha da classificação do "Adivinha o resultado".
class LinhaClassificacao {
  final int posicao, pontos, exactos, palpites;
  final String? alcunha;
  final bool eu;

  const LinhaClassificacao({
    required this.posicao,
    required this.pontos,
    required this.exactos,
    required this.palpites,
    this.alcunha,
    this.eu = false,
  });

  factory LinhaClassificacao.fromJson(Map<String, dynamic> j) => LinhaClassificacao(
    posicao: (j['posicao'] as num?)?.toInt() ?? 0,
    pontos: (j['pontos'] as num?)?.toInt() ?? 0,
    exactos: (j['exactos'] as num?)?.toInt() ?? 0,
    palpites: (j['palpites'] as num?)?.toInt() ?? 0,
    alcunha: j['alcunha'] as String?,
    eu: j['eu'] == true,
  );
}

class Classificacao {
  final String? epoca;
  final int pontosExacto, pontosVencedor;

  /// Só quem escolheu alcunha. As posições contam toda a gente, por isso pode
  /// haver saltos na numeração — está certo, não se "corrige".
  final List<LinhaClassificacao> linhas;

  /// Onde fica quem vê, com ou sem alcunha. `null` se ainda não pontuou.
  final LinhaClassificacao? eu;

  const Classificacao({this.epoca, this.pontosExacto = 3, this.pontosVencedor = 1, this.linhas = const [], this.eu});

  factory Classificacao.fromJson(Map<String, dynamic> j) {
    final regras = (j['regras'] as Map?) ?? const {};
    return Classificacao(
      epoca: j['epoca'] as String?,
      pontosExacto: (regras['exacto'] as num?)?.toInt() ?? 3,
      pontosVencedor: (regras['vencedor'] as num?)?.toInt() ?? 1,
      linhas: [
        for (final l in (j['classificacao'] as List?) ?? const [])
          if (l is Map) LinhaClassificacao.fromJson(l.cast<String, dynamic>()),
      ],
      eu: switch (j['eu']) {
        final Map<dynamic, dynamic> m => LinhaClassificacao.fromJson({...m.cast<String, dynamic>(), 'eu': true}),
        _ => null,
      },
    );
  }
}

/// O perfil na comunidade: a alcunha (opcional) e se o clube suspendeu a conta.
class PerfilComunidade {
  final String? alcunha;
  final bool bloqueado;

  const PerfilComunidade({this.alcunha, this.bloqueado = false});

  factory PerfilComunidade.fromJson(Map<String, dynamic> j) =>
      PerfilComunidade(alcunha: j['alcunha'] as String?, bloqueado: j['bloqueado'] == true);
}

/// A participação desta conta num passatempo.
class Participacao {
  final int? opcao;
  final String? resposta;

  /// `null` até o clube anunciar os vencedores (`fase: resultados`).
  final bool? vencedor;

  const Participacao({this.opcao, this.resposta, this.vencedor});

  factory Participacao.fromJson(Map<String, dynamic> j) => Participacao(
    opcao: (j['opcao'] as num?)?.toInt(),
    resposta: j['resposta'] as String?,
    vencedor: j['vencedor'] as bool?,
  );
}

class Passatempo {
  final String uid, titulo;
  final String? resumo, descricao, premio, regulamento, imagemUrl, pergunta;

  /// `inscricao`, `escolha`, `texto`. Lista aberta: um tipo desconhecido não
  /// se consegue preencher, e fica sem botão.
  final String tipo;
  final List<String> opcoes;
  final bool soSocios;
  final int vencedores, participantes;

  /// `brevemente`, `a_decorrer`, `terminado`, `resultados`. Lista aberta.
  final String fase;
  final bool podeParticipar;

  /// `por_abrir`, `terminado`, `ja_participou`, `so_socios`, `bloqueado`.
  final String? motivo;

  /// Índice em [opcoes]; só depois de acabar, e só se houver.
  final int? respostaCerta;
  final Participacao? minha;

  const Passatempo({
    required this.uid,
    required this.titulo,
    required this.tipo,
    required this.fase,
    this.resumo,
    this.descricao,
    this.premio,
    this.regulamento,
    this.imagemUrl,
    this.pergunta,
    this.opcoes = const [],
    this.soSocios = false,
    this.vencedores = 1,
    this.participantes = 0,
    this.podeParticipar = false,
    this.motivo,
    this.respostaCerta,
    this.minha,
  });

  factory Passatempo.fromJson(Map<String, dynamic> j) => Passatempo(
    uid: j['uid'] as String,
    titulo: (j['titulo'] ?? '') as String,
    tipo: (j['tipo'] ?? '') as String,
    fase: (j['fase'] ?? '') as String,
    resumo: _texto(j['resumo']),
    descricao: _texto(j['descricao']),
    premio: _texto(j['premio']),
    regulamento: _texto(j['regulamento']),
    imagemUrl: (j['imagem'] as Map?)?['url'] as String?,
    pergunta: _texto(j['pergunta']),
    opcoes: [for (final o in (j['opcoes'] as List?) ?? const []) o.toString()],
    soSocios: j['so_socios'] == true,
    vencedores: (j['vencedores'] as num?)?.toInt() ?? 1,
    participantes: (j['participantes'] as num?)?.toInt() ?? 0,
    podeParticipar: j['pode_participar'] == true,
    motivo: j['motivo'] as String?,
    respostaCerta: (j['resposta_certa'] as num?)?.toInt(),
    minha: switch (j['minha_participacao']) {
      final Map<dynamic, dynamic> m => Participacao.fromJson(m.cast<String, dynamic>()),
      _ => null,
    },
  );

  static String? _texto(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

  /// Os tipos que a app sabe preencher.
  bool get tipoConhecido => tipo == 'inscricao' || tipo == 'escolha' || tipo == 'texto';
}

// ── Pedidos ────────────────────────────────────────────────────────────────

/// Todos os pedidos da comunidade pedem token. Sem sessão, o ecrã convida a
/// entrar em vez de fazer um pedido que só pode dar `401`.
void _exigeSessao(Ref ref) {
  if (ref.watch(sessaoProvider) is SessaoAnonima) throw const SemSessao();
}

/// `GET /comunidade/jogos?quando=` — `proximos` (por palpitar) ou `recentes`
/// (por relatar). Com cache, apagada com a sessão.
final jogosComunidadeProvider = StreamProvider.autoDispose.family<Dados<List<JogoComunidade>>, String>((ref, quando) {
  if (ref.watch(sessaoProvider) is SessaoAnonima) return Stream.error(const SemSessao());
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioContaProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'comunidade.jogos.$quando',
    pedido: () => dadosDe(dio.get('/comunidade/jogos', queryParameters: {'quando': quando})),
    ler: (d) => [
      for (final j in (d['jogos'] as List?) ?? const [])
        if (j is Map) JogoComunidade.fromJson(j.cast<String, dynamic>()),
    ],
  );
});

/// Um jogo com o bloco da comunidade, e as escritas sobre ele. Cada escrita
/// devolve o jogo inteiro, que substitui o que se tinha.
final jogoComunidadeProvider = AsyncNotifierProvider.autoDispose
    .family<JogoComunidadeController, JogoComunidade, String>(JogoComunidadeController.new);

class JogoComunidadeController extends AutoDisposeFamilyAsyncNotifier<JogoComunidade, String> {
  @override
  Future<JogoComunidade> build(String id) async {
    _exigeSessao(ref);
    ref.watch(ligacaoProvider);
    final d = await dadosDe(ref.read(dioContaProvider).get('/comunidade/jogos/$id'));
    return JogoComunidade.fromJson(d);
  }

  /// Relata o resultado final. Devolve `true` quando foi este relato que o
  /// fez valer (`confirmou`): é o momento de agradecer.
  Future<bool> relatar(Marcador m) async {
    final d = await dadosDe(ref.read(dioContaProvider).post('/comunidade/jogos/$arg/resultado', data: m.toJson()));
    _substituir(d);
    return d['confirmou'] == true;
  }

  Future<void> palpitar(Marcador m) async =>
      _substituir(await dadosDe(ref.read(dioContaProvider).put('/comunidade/jogos/$arg/palpite', data: m.toJson())));

  Future<void> retirarPalpite() async =>
      _substituir(await dadosDe(ref.read(dioContaProvider).delete('/comunidade/jogos/$arg/palpite')));

  /// Recarrega depois de um erro que diz que o estado mudou (`jogo_com_resultado`,
  /// `palpites_fechados`…): o servidor sabe melhor.
  void recarregar() => ref.invalidateSelf();

  void _substituir(Map<String, dynamic> d) {
    state = AsyncData(JogoComunidade.fromJson(d));
    // As listas e os pontos mudaram com esta escrita.
    ref.invalidate(jogosComunidadeProvider);
    ref.invalidate(meusPalpitesProvider);
  }
}

/// `GET /comunidade/palpites` — os meus palpites, com os pontos.
final meusPalpitesProvider = StreamProvider.autoDispose<Dados<List<(ItemAgenda, Marcador, int?)>>>((ref) {
  if (ref.watch(sessaoProvider) is SessaoAnonima) return Stream.error(const SemSessao());
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioContaProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'comunidade.palpites',
    pedido: () => dadosDe(dio.get('/comunidade/palpites')),
    ler: (d) => [
      for (final p in (d['palpites'] as List?) ?? const [])
        if (p is Map && Marcador.deJson(p) != null)
          (
            ItemAgenda.fromJson(((p['jogo'] as Map?) ?? const {}).cast<String, dynamic>()),
            Marcador.deJson(p)!,
            (p['pontos'] as num?)?.toInt(),
          ),
    ],
  );
});

/// `GET /comunidade/classificacao` — a época mais recente com palpites.
final classificacaoProvider = StreamProvider.autoDispose<Dados<Classificacao>>((ref) {
  if (ref.watch(sessaoProvider) is SessaoAnonima) return Stream.error(const SemSessao());
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioContaProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'comunidade.classificacao',
    pedido: () => dadosDe(dio.get('/comunidade/classificacao')),
    ler: Classificacao.fromJson,
  );
});

/// A alcunha e o bloqueio. Sem cache: decide que botões aparecem.
final perfilComunidadeProvider = AsyncNotifierProvider.autoDispose<PerfilComunidadeController, PerfilComunidade>(
  PerfilComunidadeController.new,
);

class PerfilComunidadeController extends AutoDisposeAsyncNotifier<PerfilComunidade> {
  @override
  Future<PerfilComunidade> build() async {
    _exigeSessao(ref);
    ref.watch(ligacaoProvider);
    final d = await dadosDe(ref.read(dioContaProvider).get('/comunidade/perfil'));
    return PerfilComunidade.fromJson(((d['perfil'] as Map?) ?? d).cast<String, dynamic>());
  }

  /// `null` para sair da tabela. Nunca se preenche por omissão com o nome da
  /// pessoa: aparecer na classificação é uma escolha (RGPD).
  Future<void> mudarAlcunha(String? alcunha) async {
    final d = await dadosDe(ref.read(dioContaProvider).put('/comunidade/perfil', data: {'alcunha': alcunha}));
    state = AsyncData(PerfilComunidade.fromJson(((d['perfil'] as Map?) ?? d).cast<String, dynamic>()));
    ref.invalidate(classificacaoProvider);
  }

  /// O servidor respondeu `comunidade_bloqueada`: esconde os botões já.
  void bloqueada() => state = AsyncData(PerfilComunidade(alcunha: state.valueOrNull?.alcunha, bloqueado: true));
}

/// `GET /comunidade/passatempos` — a decorrer, a abrir, e os que acabaram há
/// menos de 60 dias.
final passatemposProvider = StreamProvider.autoDispose<Dados<List<Passatempo>>>((ref) {
  if (ref.watch(sessaoProvider) is SessaoAnonima) return Stream.error(const SemSessao());
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioContaProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'comunidade.passatempos',
    pedido: () => dadosDe(dio.get('/comunidade/passatempos')),
    ler: (d) => [
      for (final p in (d['passatempos'] as List?) ?? const [])
        if (p is Map && p['uid'] is String) Passatempo.fromJson(p.cast<String, dynamic>()),
    ],
  );
});

/// Um passatempo, e a participação nele.
final passatempoProvider = AsyncNotifierProvider.autoDispose.family<PassatempoController, Passatempo, String>(
  PassatempoController.new,
);

class PassatempoController extends AutoDisposeFamilyAsyncNotifier<Passatempo, String> {
  @override
  Future<Passatempo> build(String uid) async {
    _exigeSessao(ref);
    ref.watch(ligacaoProvider);
    final d = await dadosDe(ref.read(dioContaProvider).get('/comunidade/passatempos/$uid'));
    return Passatempo.fromJson(((d['passatempo'] as Map?) ?? d).cast<String, dynamic>());
  }

  /// Uma vez por conta, sem volta atrás: quem chama pede confirmação antes.
  /// `{opcao}` numa escolha, `{resposta}` num texto, `{}` numa inscrição.
  Future<void> participar({int? opcao, String? resposta}) async {
    final d = await dadosDe(
      ref
          .read(dioContaProvider)
          .post(
            '/comunidade/passatempos/$arg/participar',
            data: {'opcao': ?opcao, 'resposta': ?resposta},
          ),
    );
    state = AsyncData(Passatempo.fromJson(((d['passatempo'] as Map?) ?? d).cast<String, dynamic>()));
    ref.invalidate(passatemposProvider);
  }

  void recarregar() => ref.invalidateSelf();
}

/// Quanto dura um jogo, para efeitos de "já acabou": passada hora e meia do
/// início dá-se por terminado, mesmo que o estado ainda diga `agendado` — é
/// precisamente quando falta alguém dizer como acabou.
const duracaoDeUmJogo = Duration(minutes: 90);

/// Os jogos para a tab "Últimos": os de hoje e de ontem que já acabaram, o
/// mais recente primeiro.
///
/// É a única conta com datas na comunidade, e só decide o que fica em
/// destaque. Se ainda se pode relatar continua a ser o servidor a dizer
/// (`relatos.aberto`).
List<JogoComunidade> ultimosJogos(List<JogoComunidade> jogos, DateTime agora) {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final ontem = hoje.subtract(const Duration(days: 1));

  bool acabou(JogoComunidade c) {
    final j = c.jogo;
    final dia = DateTime(j.inicio.year, j.inicio.month, j.inicio.day);
    if (dia != hoje && dia != ontem) return false;
    if (j.terminado || j.golosCasa != null) return true;
    if (j.cancelado) return false;
    // Sem hora confirmada o início vem às 00:00, que não é hora de jogo
    // nenhum: um jogo assim só se dá por acabado no dia seguinte.
    if (!j.horaConfirmada) return dia == ontem;
    return !agora.isBefore(j.inicio.add(duracaoDeUmJogo));
  }

  return [for (final c in jogos) if (acabou(c)) c]..sort((a, b) => b.jogo.inicio.compareTo(a.jogo.inicio));
}
